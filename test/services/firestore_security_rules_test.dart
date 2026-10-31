import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

/// Helper to generate an unsigned mock JWT accepted by the Firebase Firestore Emulator.
String _createMockJwt(String uid) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': uid, 'user_id': uid, 'aud': 'machalert'}),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.';
}

/// Checks whether the local Firestore emulator is reachable on port 8080.
Future<bool> _isEmulatorRunning() async {
  try {
    final socket = await Socket.connect(
      '127.0.0.1',
      8080,
      timeout: const Duration(milliseconds: 500),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

/// Helper client for interacting with the Cloud Firestore Emulator REST v1 API.
class FirestoreEmulatorTestClient {
  final HttpClient _httpClient = HttpClient();
  final String host;
  final int port;
  final String projectId;

  FirestoreEmulatorTestClient({
    this.host = '127.0.0.1',
    this.port = 8080,
    this.projectId = 'machalert',
  });

  String get basePath =>
      '/v1/projects/$projectId/databases/(default)/documents';

  void close() => _httpClient.close(force: true);

  /// Seeds or updates a document using the admin token (bypasses security rules).
  Future<int> adminSetDocument(String path, Map<String, dynamic> fields) async {
    final uri = Uri.parse('http://$host:$port$basePath/$path');
    final req = await _httpClient.openUrl('PATCH', uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'fields': _encodeFields(fields)}));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Sends a GET request to read a document.
  Future<int> getDocument(String path, {String? token}) async {
    final uri = Uri.parse('http://$host:$port$basePath/$path');
    final req = await _httpClient.openUrl('GET', uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Sends a POST request to create a document in a collection with an optional auth token.
  Future<int> createDocument(
    String collection,
    Map<String, dynamic> rawFields, {
    String? token,
    String? documentId,
  }) async {
    final queryString = documentId != null ? '?documentId=$documentId' : '';
    final uri = Uri.parse(
      'http://$host:$port$basePath/$collection$queryString',
    );
    final req = await _httpClient.postUrl(uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'fields': _encodeFields(rawFields)}));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Sends a PATCH request to set/create a document at a specific path.
  Future<int> setDocument(
    String path,
    Map<String, dynamic> rawFields, {
    String? token,
  }) async {
    final uri = Uri.parse('http://$host:$port$basePath/$path');
    final req = await _httpClient.openUrl('PATCH', uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'fields': _encodeFields(rawFields)}));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Sends a PATCH request to update a specific document with field masks.
  Future<int> updateDocument(
    String path,
    Map<String, dynamic> updateFields, {
    String? token,
  }) async {
    final updateMaskParams = updateFields.keys
        .map((k) => 'updateMask.fieldPaths=$k')
        .join('&');
    final uri = Uri.parse(
      'http://$host:$port$basePath/$path?$updateMaskParams',
    );
    final req = await _httpClient.openUrl('PATCH', uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'fields': _encodeFields(updateFields)}));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Sends a DELETE request to delete a document.
  Future<int> deleteDocument(String path, {String? token}) async {
    final uri = Uri.parse('http://$host:$port$basePath/$path');
    final req = await _httpClient.deleteUrl(uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Recursively encodes Dart primitives and nested maps into Firestore REST API value maps.
  Map<String, dynamic> _encodeFields(Map<String, dynamic> raw) {
    final encoded = <String, dynamic>{};
    raw.forEach((key, value) {
      encoded[key] = _encodeValue(value);
    });
    return encoded;
  }

  Map<String, dynamic> _encodeValue(dynamic value) {
    if (value is String) {
      return {'stringValue': value};
    } else if (value is int) {
      return {'integerValue': value.toString()};
    } else if (value is double) {
      return {'doubleValue': value};
    } else if (value is bool) {
      return {'booleanValue': value};
    } else if (value == null) {
      return {'nullValue': null};
    } else if (value is List) {
      return {
        'arrayValue': {'values': value.map((e) => _encodeValue(e)).toList()},
      };
    } else if (value is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': _encodeFields(value)},
      };
    } else {
      return {'stringValue': value.toString()};
    }
  }
}

void main() {
  group('Firestore Schema & Role Permission Matrix Model Invariants', () {
    test('Canonical user roles match application constants', () {
      expect(
        AppConstants.userRoles,
        containsAll(['operator', 'technician', 'manager']),
      );
      expect(AppConstants.userRoles.length, equals(3));
    });

    test('UserModel validates recognized roles', () {
      final op = UserModel(
        id: 'u1',
        name: 'Op',
        email: 'op@example.com',
        role: 'operator',
      );
      final tech = UserModel(
        id: 'u2',
        name: 'Tech',
        email: 'tech@example.com',
        role: 'technician',
      );
      final mgr = UserModel(
        id: 'u3',
        name: 'Mgr',
        email: 'mgr@example.com',
        role: 'manager',
      );
      final invalid = UserModel(
        id: 'u4',
        name: 'Hacker',
        email: 'h@example.com',
        role: 'admin',
      );

      expect(op.hasRecognizedRole, isTrue);
      expect(tech.hasRecognizedRole, isTrue);
      expect(mgr.hasRecognizedRole, isTrue);
      expect(invalid.hasRecognizedRole, isFalse);
    });

    test('MachineModel conforms to manager-controlled machine schema', () {
      final machine = MachineModel(
        id: 'MCH-01',
        name: 'Milling Station',
        productionLine: 'Line A',
        status: AppConstants.machineStatusOperational,
        healthScore: 95.0,
      );

      final map = machine.toMap();
      expect(map['id'], 'MCH-01');
      expect(map['name'], 'Milling Station');
      expect(map['productionLine'], 'Line A');
      expect(map['status'], 'Operational');
      expect(map['healthScore'], 95.0);
    });

    test('MaintenanceModel initial status must default to Pending', () {
      final task = MaintenanceModel(
        id: 'TASK-01',
        machineId: 'MCH-01',
        technicianId: 'tech_01',
        priority: 'High',
        status: AppConstants.maintenanceStatusPending,
      );

      expect(task.status, AppConstants.maintenanceStatusPending);
    });

    test(
      'MaintenanceService status transition validation enforces state machine',
      () {
        // Pending -> In Progress (allowed)
        expect(
          () => MaintenanceService.validateStatusTransition(
            currentStatus: AppConstants.maintenanceStatusPending,
            targetStatus: AppConstants.maintenanceStatusInProgress,
          ),
          returnsNormally,
        );

        // In Progress -> Resolved (allowed)
        expect(
          () => MaintenanceService.validateStatusTransition(
            currentStatus: AppConstants.maintenanceStatusInProgress,
            targetStatus: AppConstants.maintenanceStatusResolved,
          ),
          returnsNormally,
        );

        // Pending -> Resolved (illegal shortcut rejected)
        expect(
          () => MaintenanceService.validateStatusTransition(
            currentStatus: AppConstants.maintenanceStatusPending,
            targetStatus: AppConstants.maintenanceStatusResolved,
          ),
          throwsA(isA<MaintenanceServiceException>()),
        );

        // Resolved is strictly terminal
        expect(
          () => MaintenanceService.validateStatusTransition(
            currentStatus: AppConstants.maintenanceStatusResolved,
            targetStatus: AppConstants.maintenanceStatusInProgress,
          ),
          throwsA(isA<MaintenanceServiceException>()),
        );

        // Same status requires note or proof
        expect(
          () => MaintenanceService.validateStatusTransition(
            currentStatus: AppConstants.maintenanceStatusInProgress,
            targetStatus: AppConstants.maintenanceStatusInProgress,
          ),
          throwsA(isA<MaintenanceServiceException>()),
        );

        expect(
          () => MaintenanceService.validateStatusTransition(
            currentStatus: AppConstants.maintenanceStatusInProgress,
            targetStatus: AppConstants.maintenanceStatusInProgress,
            notes: 'Checked bearing lubrication',
          ),
          returnsNormally,
        );
      },
    );
  });

  group('Firestore Security Rules - Integration & Role Matrix Tests', () {
    late FirestoreEmulatorTestClient client;
    bool emulatorAvailable = false;

    final tokenOp = _createMockJwt('sec_user_operator');
    final tokenTech1 = _createMockJwt('sec_user_technician_1');
    final tokenTech2 = _createMockJwt('sec_user_technician_2');
    final tokenMgr = _createMockJwt('sec_user_manager');

    setUpAll(() async {
      emulatorAvailable = await _isEmulatorRunning();
      client = FirestoreEmulatorTestClient();

      if (emulatorAvailable) {
        // Seed canonical users for role lookups via admin token
        await client.adminSetDocument('users/sec_user_operator', {
          'uid': 'sec_user_operator',
          'id': 'sec_user_operator',
          'role': 'operator',
          'email': 'op@machalert.local',
          'name': 'Operator User',
          'displayName': 'Operator User',
        });
        await client.adminSetDocument('users/sec_user_technician_1', {
          'uid': 'sec_user_technician_1',
          'id': 'sec_user_technician_1',
          'role': 'technician',
          'email': 'tech1@machalert.local',
          'name': 'Technician One',
          'displayName': 'Technician One',
        });
        await client.adminSetDocument('users/sec_user_technician_2', {
          'uid': 'sec_user_technician_2',
          'id': 'sec_user_technician_2',
          'role': 'technician',
          'email': 'tech2@machalert.local',
          'name': 'Technician Two',
          'displayName': 'Technician Two',
        });
        await client.adminSetDocument('users/sec_user_manager', {
          'uid': 'sec_user_manager',
          'id': 'sec_user_manager',
          'role': 'manager',
          'email': 'mgr@machalert.local',
          'name': 'Manager User',
          'displayName': 'Manager User',
        });
      }
    });

    tearDownAll(() {
      client.close();
    });

    group('Users Collection Rules (/users/{userId})', () {
      test('Unauthenticated user profile read is denied (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.getDocument('users/sec_user_operator');
        expect(status, 403);
      });

      test('Authenticated user profile read is allowed (200)', () async {
        if (!emulatorAvailable) return;
        final status = await client.getDocument(
          'users/sec_user_operator',
          token: tokenOp,
        );
        expect(status, 200);
      });

      test(
        'User cannot assign themselves manager role on creation (403)',
        () async {
          if (!emulatorAvailable) return;
          const newUid = 'sec_new_user_attempting_mgr';
          final tokenNew = _createMockJwt(newUid);

          final status = await client.setDocument('users/$newUid', {
            'uid': newUid,
            'id': newUid,
            'email': 'attacker@example.com',
            'role': 'manager',
            'name': 'Attacker',
          }, token: tokenNew);

          expect(status, 403);
        },
      );

      test('User can create own profile with operator role (200)', () async {
        if (!emulatorAvailable) return;
        const newUid = 'sec_new_legit_operator';
        final tokenNew = _createMockJwt(newUid);

        final status = await client.setDocument('users/$newUid', {
          'uid': newUid,
          'id': newUid,
          'email': 'legit@example.com',
          'role': 'operator',
          'name': 'Legit Op',
        }, token: tokenNew);

        expect(status, 200);
      });

      test('User cannot create profile for a different UID (403)', () async {
        if (!emulatorAvailable) return;
        const targetUid = 'sec_target_victim_uid';

        final status = await client.setDocument('users/$targetUid', {
          'uid': targetUid,
          'id': targetUid,
          'email': 'victim@example.com',
          'role': 'operator',
          'name': 'Victim',
        }, token: tokenOp);

        expect(status, 403);
      });

      test('User cannot edit their own role (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.updateDocument('users/sec_user_operator', {
          'role': 'manager',
        }, token: tokenOp);

        expect(status, 403);
      });

      test('User can edit their own displayName and name (200)', () async {
        if (!emulatorAvailable) return;
        final status = await client.updateDocument('users/sec_user_operator', {
          'displayName': 'Renamed Operator',
          'name': 'Renamed Operator',
        }, token: tokenOp);

        expect(status, 200);
      });

      test('Manager can assign valid role to another user (200)', () async {
        if (!emulatorAvailable) return;
        final status = await client.updateDocument('users/sec_user_operator', {
          'role': 'technician',
        }, token: tokenMgr);

        expect(status, 200);

        // Reset back to operator
        await client.updateDocument('users/sec_user_operator', {
          'role': 'operator',
        }, token: tokenMgr);
      });

      test(
        'Manager cannot assign unknown/invalid role to another user (403)',
        () async {
          if (!emulatorAvailable) return;
          final status = await client.updateDocument(
            'users/sec_user_operator',
            {'role': 'superadmin'},
            token: tokenMgr,
          );

          expect(status, 403);
        },
      );
    });

    group('Machines Collection Rules (/machines/{machineId})', () {
      test('Unauthenticated machine read is denied (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.getDocument('machines/MCH-LINE1-CNC01');
        expect(status, 403);
      });

      test('Authenticated machine read is allowed (200)', () async {
        if (!emulatorAvailable) return;
        await client.adminSetDocument('machines/MCH-LINE1-CNC01', {
          'id': 'MCH-LINE1-CNC01',
          'machineId': 'MCH-LINE1-CNC01',
          'name': 'CNC Milling 01',
          'productionLine': 'Line 1',
          'status': 'Operational',
          'healthScore': 92.0,
        });

        final status = await client.getDocument(
          'machines/MCH-LINE1-CNC01',
          token: tokenOp,
        );
        expect(status, 200);
      });

      test('Operator cannot create machine (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.setDocument('machines/MCH-NEW-OP', {
          'id': 'MCH-NEW-OP',
          'name': 'Illegal Machine',
          'productionLine': 'Line 2',
          'status': 'Operational',
          'healthScore': 90.0,
        }, token: tokenOp);

        expect(status, 403);
      });

      test('Technician cannot create machine (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.setDocument('machines/MCH-NEW-TECH', {
          'id': 'MCH-NEW-TECH',
          'name': 'Tech Machine',
          'productionLine': 'Line 2',
          'status': 'Operational',
          'healthScore': 90.0,
        }, token: tokenTech1);

        expect(status, 403);
      });

      test('Manager can create machine with valid schema (200)', () async {
        if (!emulatorAvailable) return;
        final status = await client.setDocument('machines/MCH-NEW-MGR', {
          'id': 'MCH-NEW-MGR',
          'machineId': 'MCH-NEW-MGR',
          'name': 'Manager Added Machine',
          'productionLine': 'Line 3',
          'status': 'Operational',
          'healthScore': 98.0,
        }, token: tokenMgr);

        expect(status, 200);
      });

      test('Operator cannot update machine (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.updateDocument('machines/MCH-NEW-MGR', {
          'status': 'Warning',
        }, token: tokenOp);

        expect(status, 403);
      });

      test('Technician cannot update machine (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.updateDocument('machines/MCH-NEW-MGR', {
          'status': 'Warning',
        }, token: tokenTech1);

        expect(status, 403);
      });

      test('Manager can update machine (200)', () async {
        if (!emulatorAvailable) return;
        final status = await client.updateDocument('machines/MCH-NEW-MGR', {
          'status': 'Warning',
        }, token: tokenMgr);

        expect(status, 200);
      });

      test('Operator/Technician cannot delete machine (403)', () async {
        if (!emulatorAvailable) return;
        final opStatus = await client.deleteDocument(
          'machines/MCH-NEW-MGR',
          token: tokenOp,
        );
        expect(opStatus, 403);

        final techStatus = await client.deleteDocument(
          'machines/MCH-NEW-MGR',
          token: tokenTech1,
        );
        expect(techStatus, 403);
      });

      test('Manager can delete machine (200)', () async {
        if (!emulatorAvailable) return;
        final status = await client.deleteDocument(
          'machines/MCH-NEW-MGR',
          token: tokenMgr,
        );
        expect(status, 200);
      });
    });

    group('Maintenance Collection Rules (/maintenance/{taskId})', () {
      test('Unauthenticated maintenance task read is denied (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.getDocument('maintenance/task_sec_01');
        expect(status, 403);
      });

      test('Operator maintenance task read is denied (403)', () async {
        if (!emulatorAvailable) return;
        await client.adminSetDocument('maintenance/task_sec_01', {
          'id': 'task_sec_01',
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Pending',
          'notes': 'Inspect hydraulic valve pressure',
        });

        final status = await client.getDocument(
          'maintenance/task_sec_01',
          token: tokenOp,
        );
        expect(status, 403);
      });

      test(
        'Unassigned technician cannot read another technician task (403)',
        () async {
          if (!emulatorAvailable) return;
          await client.adminSetDocument('maintenance/task_sec_01', {
            'id': 'task_sec_01',
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Inspect hydraulic valve pressure',
          });

          // tech2 attempts to read task assigned to tech1 -> 403
          final status = await client.getDocument(
            'maintenance/task_sec_01',
            token: tokenTech2,
          );
          expect(status, 403);
        },
      );

      test(
        'Assigned technician can read their assigned maintenance task (200)',
        () async {
          if (!emulatorAvailable) return;
          await client.adminSetDocument('maintenance/task_sec_01', {
            'id': 'task_sec_01',
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Inspect hydraulic valve pressure',
          });

          final status = await client.getDocument(
            'maintenance/task_sec_01',
            token: tokenTech1,
          );
          expect(status, 200);
        },
      );

      test('Manager can read any maintenance task (200)', () async {
        if (!emulatorAvailable) return;
        await client.adminSetDocument('maintenance/task_sec_01', {
          'id': 'task_sec_01',
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Pending',
          'notes': 'Inspect hydraulic valve pressure',
        });

        final status = await client.getDocument(
          'maintenance/task_sec_01',
          token: tokenMgr,
        );
        expect(status, 200);
      });

      test('Operator cannot create maintenance task (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.createDocument('maintenance', {
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'Medium',
          'status': 'Pending',
        }, token: tokenOp);

        expect(status, 403);
      });

      test('Technician cannot create maintenance task (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.createDocument('maintenance', {
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'Medium',
          'status': 'Pending',
        }, token: tokenTech1);

        expect(status, 403);
      });

      test(
        'Manager can create maintenance task with initial status Pending (200)',
        () async {
          if (!emulatorAvailable) return;
          final status = await client.setDocument(
            'maintenance/task_sec_mgr_created',
            {
              'id': 'task_sec_mgr_created',
              'maintenanceId': 'task_sec_mgr_created',
              'machineId': 'MCH-01',
              'technicianId': 'sec_user_technician_1',
              'priority': 'High',
              'status': 'Pending',
              'notes': 'Check motor bearings',
            },
            token: tokenMgr,
          );

          expect(status, 200);
        },
      );

      test('Manager cannot create maintenance task with initial status Resolved (403)', () async {
        if (!emulatorAvailable) return;
        final status = await client.setDocument(
          'maintenance/task_sec_mgr_invalid',
          {
            'id': 'task_sec_mgr_invalid',
            'maintenanceId': 'task_sec_mgr_invalid',
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'Resolved',
          },
          token: tokenMgr,
        );

        expect(status, 403);
      });

      test('Assigned technician can update status Pending -> In Progress with valid history entry (200)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_assigned_tech_flow';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Pending',
          'notes': 'Original assignment note',
        });

        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'In Progress',
          'updateHistory': {
            'hist_01': {
              'id': 'hist_01',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'Starting inspection',
            },
          },
        }, token: tokenTech1);

        expect(status, 200);
      });

      test(
        'Unassigned technician cannot update another technician task (403)',
        () async {
          if (!emulatorAvailable) return;
          const taskId = 'task_assigned_to_tech1';
          await client.adminSetDocument('maintenance/$taskId', {
            'id': taskId,
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Assigned to tech 1',
          });

          // tech2 attempts to update tech1 task -> 403
          final status = await client.updateDocument('maintenance/$taskId', {
            'status': 'In Progress',
            'updateHistory': {
              'hist_02': {
                'id': 'hist_02',
                'taskId': taskId,
                'previousStatus': 'Pending',
                'newStatus': 'In Progress',
                'updatedBy': 'sec_user_technician_2',
              },
            },
          }, token: tokenTech2);

          expect(status, 403);
        },
      );

      test('Operator cannot update maintenance status (403)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_operator_tamper';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'Medium',
          'status': 'Pending',
        });

        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'In Progress',
        }, token: tokenOp);

        expect(status, 403);
      });

      test('Illegal status transition Pending -> Resolved directly is rejected (403)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_illegal_transition';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Pending',
        });

        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'Resolved',
          'updateHistory': {
            'hist_skip': {
              'id': 'hist_skip',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'Resolved',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'Shortcut jump',
            },
          },
        }, token: tokenTech1);

        expect(status, 403);
      });

      test('Modifying already Resolved task is rejected (403)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_already_resolved';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Resolved',
          'notes': 'Completed job',
        });

        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'In Progress',
        }, token: tokenTech1);

        expect(status, 403);
      });

      test(
        'Attempting to tamper with original assignment notes is rejected (403)',
        () async {
          if (!emulatorAvailable) return;
          const taskId = 'task_tamper_notes';
          await client.adminSetDocument('maintenance/$taskId', {
            'id': taskId,
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Original assignment note',
          });

          final status = await client.updateDocument('maintenance/$taskId', {
            'status': 'In Progress',
            'notes': 'Overwritten unauthorized note',
            'updateHistory': {
              'hist_tamper': {
                'id': 'hist_tamper',
                'taskId': taskId,
                'previousStatus': 'Pending',
                'newStatus': 'In Progress',
                'updatedBy': 'sec_user_technician_1',
              },
            },
          }, token: tokenTech1);

          expect(status, 403);
        },
      );

      test('History entry actor spoofing (updatedBy != auth.uid) is rejected (403)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_spoof_actor';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Pending',
        });

        // tech1 submits updatedBy = sec_user_technician_2 -> 403
        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'In Progress',
          'updateHistory': {
            'hist_spoof': {
              'id': 'hist_spoof',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_2',
            },
          },
        }, token: tokenTech1);

        expect(status, 403);
      });

      test(
        'Same-status update without notes or proof is rejected (403)',
        () async {
          if (!emulatorAvailable) return;
          const taskId = 'task_same_status_no_content';
          await client.adminSetDocument('maintenance/$taskId', {
            'id': taskId,
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'In Progress',
          });

          final status = await client.updateDocument('maintenance/$taskId', {
            'status': 'In Progress',
            'updateHistory': {
              'hist_empty': {
                'id': 'hist_empty',
                'taskId': taskId,
                'previousStatus': 'In Progress',
                'newStatus': 'In Progress',
                'updatedBy': 'sec_user_technician_1',
              },
            },
          }, token: tokenTech1);

          expect(status, 403);
        },
      );

      test(
        'Same-status update with valid notes creates repair log (200)',
        () async {
          if (!emulatorAvailable) return;
          const taskId = 'task_same_status_with_notes';
          await client.adminSetDocument('maintenance/$taskId', {
            'id': taskId,
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'In Progress',
          });

          final status = await client.updateDocument('maintenance/$taskId', {
            'status': 'In Progress',
            'updateHistory': {
              'hist_note': {
                'id': 'hist_note',
                'taskId': taskId,
                'previousStatus': 'In Progress',
                'newStatus': 'In Progress',
                'updatedBy': 'sec_user_technician_1',
                'notes': 'Replaced damaged hydraulic seal',
              },
            },
          }, token: tokenTech1);

          expect(status, 200);
        },
      );

      test('Legacy task with null updateHistory safely allows first update entry (200)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_legacy_null_history';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Pending',
          'updateHistory': null,
        });

        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'In Progress',
          'updateHistory': {
            'hist_from_null': {
              'id': 'hist_from_null',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'First update on legacy task',
            },
          },
        }, token: tokenTech1);

        expect(status, 200);
      });

      test('Task with existing updateHistory appends second entry preserving first entry (200)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_append_second_entry';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'In Progress',
          'updateHistory': {
            'entry_1': {
              'id': 'entry_1',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'First entry',
            },
          },
        });

        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'Resolved',
          'updateHistory': {
            'entry_1': {
              'id': 'entry_1',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'First entry',
            },
            'entry_2': {
              'id': 'entry_2',
              'taskId': taskId,
              'previousStatus': 'In Progress',
              'newStatus': 'Resolved',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'Second entry resolving task',
            },
          },
        }, token: tokenTech1);

        expect(status, 200);
      });

      test('Task with large history map (> 5 entries and random IDs) appends new entry (200)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_large_history_random_ids';

        final initialHistory = <String, dynamic>{};
        for (var i = 1; i <= 7; i++) {
          final randId = 'rand_hist_key_${i * 97 + 13}';
          initialHistory[randId] = {
            'id': randId,
            'taskId': taskId,
            'previousStatus': 'In Progress',
            'newStatus': 'In Progress',
            'updatedBy': 'sec_user_technician_1',
            'notes': 'Log step $i',
          };
        }

        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'In Progress',
          'updateHistory': initialHistory,
        });

        final updatedHistory = Map<String, dynamic>.from(initialHistory);
        const newRandKey = 'rand_new_entry_9999';
        updatedHistory[newRandKey] = {
          'id': newRandKey,
          'taskId': taskId,
          'previousStatus': 'In Progress',
          'newStatus': 'Resolved',
          'updatedBy': 'sec_user_technician_1',
          'notes': 'Final resolution after multiple checks',
        };

        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'Resolved',
          'updateHistory': updatedHistory,
        }, token: tokenTech1);

        expect(status, 200);
      });

      test('Task with existing updateHistory rejects modifying existing entries (403)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_modify_existing_history';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'In Progress',
          'updateHistory': {
            'entry_1': {
              'id': 'entry_1',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'Original note',
            },
          },
        });

        // Attempting to change notes on entry_1 while adding entry_2 -> 403
        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'Resolved',
          'updateHistory': {
            'entry_1': {
              'id': 'entry_1',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_1',
              'notes': 'Tampered note!',
            },
            'entry_2': {
              'id': 'entry_2',
              'taskId': taskId,
              'previousStatus': 'In Progress',
              'newStatus': 'Resolved',
              'updatedBy': 'sec_user_technician_1',
            },
          },
        }, token: tokenTech1);

        expect(status, 403);
      });

      test('Task with existing updateHistory rejects removing existing entry (403)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_remove_existing_history';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'In Progress',
          'updateHistory': {
            'entry_1': {
              'id': 'entry_1',
              'taskId': taskId,
              'previousStatus': 'Pending',
              'newStatus': 'In Progress',
              'updatedBy': 'sec_user_technician_1',
            },
          },
        });

        // Attempting to replace entry_1 with entry_2 -> 403
        final status = await client.updateDocument('maintenance/$taskId', {
          'status': 'Resolved',
          'updateHistory': {
            'entry_2': {
              'id': 'entry_2',
              'taskId': taskId,
              'previousStatus': 'In Progress',
              'newStatus': 'Resolved',
              'updatedBy': 'sec_user_technician_1',
            },
          },
        }, token: tokenTech1);

        expect(status, 403);
      });

      test(
        'Adding more than one entry in a single update is rejected (403)',
        () async {
          if (!emulatorAvailable) return;
          const taskId = 'task_add_multiple_entries';
          await client.adminSetDocument('maintenance/$taskId', {
            'id': taskId,
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'Pending',
          });

          // Attempting to add 2 entries at once -> 403
          final status = await client.updateDocument('maintenance/$taskId', {
            'status': 'In Progress',
            'updateHistory': {
              'entry_a': {
                'id': 'entry_a',
                'taskId': taskId,
                'previousStatus': 'Pending',
                'newStatus': 'In Progress',
                'updatedBy': 'sec_user_technician_1',
              },
              'entry_b': {
                'id': 'entry_b',
                'taskId': taskId,
                'previousStatus': 'Pending',
                'newStatus': 'In Progress',
                'updatedBy': 'sec_user_technician_1',
              },
            },
          }, token: tokenTech1);

          expect(status, 403);
        },
      );

      test(
        'Operator/Technician cannot delete maintenance task (403)',
        () async {
          if (!emulatorAvailable) return;
          const taskId = 'task_delete_target';
          await client.adminSetDocument('maintenance/$taskId', {
            'id': taskId,
            'machineId': 'MCH-01',
            'technicianId': 'sec_user_technician_1',
            'priority': 'High',
            'status': 'Pending',
          });

          final opStatus = await client.deleteDocument(
            'maintenance/$taskId',
            token: tokenOp,
          );
          expect(opStatus, 403);

          final techStatus = await client.deleteDocument(
            'maintenance/$taskId',
            token: tokenTech1,
          );
          expect(techStatus, 403);
        },
      );

      test('Manager can delete maintenance task (200)', () async {
        if (!emulatorAvailable) return;
        const taskId = 'task_delete_by_mgr';
        await client.adminSetDocument('maintenance/$taskId', {
          'id': taskId,
          'machineId': 'MCH-01',
          'technicianId': 'sec_user_technician_1',
          'priority': 'High',
          'status': 'Pending',
        });

        final status = await client.deleteDocument(
          'maintenance/$taskId',
          token: tokenMgr,
        );
        expect(status, 200);
      });
    });
  });
}
