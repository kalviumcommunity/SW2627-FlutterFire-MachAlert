import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/utils/app_constants.dart';

/// Helper to generate an unsigned mock JWT accepted by the Firebase Firestore Emulator.
String _createMockJwt(String uid) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': uid,
            'user_id': uid,
            'aud': 'machalert',
          }),
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

  String get basePath => '/v1/projects/$projectId/databases/(default)/documents';

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

  /// Sends a POST request to create a document in a collection with an optional auth token.
  Future<int> createDocument(
    String collection,
    Map<String, dynamic> rawFields, {
    String? token,
  }) async {
    final uri = Uri.parse('http://$host:$port$basePath/$collection');
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

  /// Encodes Dart primitives into Firestore REST API value maps.
  Map<String, dynamic> _encodeFields(Map<String, dynamic> raw) {
    final encoded = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value is String) {
        encoded[key] = {'stringValue': value};
      } else if (value is int) {
        encoded[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        encoded[key] = {'doubleValue': value};
      } else if (value is bool) {
        encoded[key] = {'booleanValue': value};
      } else if (value == null) {
        encoded[key] = {'nullValue': null};
      } else if (value is List) {
        encoded[key] = {
          'arrayValue': {
            'values': value.map((e) => {'stringValue': e.toString()}).toList(),
          },
        };
      }
    });
    return encoded;
  }
}

void main() {
  group('Faults Collection Schema & Model Verification', () {
    test('FaultModel schema conforms to expected collection constants', () {
      expect(AppConstants.faultsCollection, 'faults');
      expect(AppConstants.severities, ['Low', 'Medium', 'High', 'Critical']);
      expect(AppConstants.faultStatuses, ['Open', 'In Progress', 'Resolved']);
      expect(AppConstants.faultTypes, [
        'Mechanical',
        'Electrical',
        'Hydraulic',
        'Thermal',
        'Pneumatic',
        'Other',
      ]);
    });

    test('FaultModel creates with all required fields matching PRD Section 15.3', () {
      final fault = FaultModel(
        id: 'flt_test_01',
        machineId: 'MCH-LINE1-CNC03',
        machineName: 'CNC Milling Machine 03',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Spindle overheating and emitting smoke',
        reportedBy: 'user_operator_1',
        reportedByName: 'Rajesh Sharma',
        status: AppConstants.faultStatusOpen,
        imageUrl: 'https://example.com/fault.jpg',
        createdAt: DateTime(2026, 10, 21, 10, 0),
      );

      final map = fault.toMap();
      expect(map['machineId'], 'MCH-LINE1-CNC03');
      expect(map['type'], 'Thermal');
      expect(map['severity'], 'High');
      expect(map['description'], isNotEmpty);
      expect(map['reportedBy'], 'user_operator_1');
      expect(map['status'], 'Open');
    });
  });

  group('Firestore Security Rules - Faults Collection Emulator Tests', () {
    late FirestoreEmulatorTestClient client;
    bool emulatorAvailable = false;

    final tokenOp1 = _createMockJwt('sec_op_1');
    final tokenOp2 = _createMockJwt('sec_op_2');
    final tokenTech = _createMockJwt('sec_tech_1');
    final tokenMgr = _createMockJwt('sec_mgr_1');

    setUpAll(() async {
      emulatorAvailable = await _isEmulatorRunning();
      client = FirestoreEmulatorTestClient();

      if (emulatorAvailable) {
        // Seed user role documents via admin token
        await client.adminSetDocument('users/sec_op_1', {
          'uid': 'sec_op_1',
          'role': 'operator',
          'name': 'Operator One',
        });
        await client.adminSetDocument('users/sec_op_2', {
          'uid': 'sec_op_2',
          'role': 'operator',
          'name': 'Operator Two',
        });
        await client.adminSetDocument('users/sec_tech_1', {
          'uid': 'sec_tech_1',
          'role': 'technician',
          'name': 'Technician One',
        });
        await client.adminSetDocument('users/sec_mgr_1', {
          'uid': 'sec_mgr_1',
          'role': 'manager',
          'name': 'Manager One',
        });
      }
    });

    tearDownAll(() {
      client.close();
    });

    test('Unauthenticated fault creation is denied (403)', () async {
      if (!emulatorAvailable) {
        return; // Evaluated when running with Firebase emulator
      }

      final status = await client.createDocument('faults', {
        'machineId': 'MCH-01',
        'type': 'Thermal',
        'severity': 'High',
        'description': 'Overheating spindle',
        'reportedBy': 'sec_op_1',
        'status': 'Open',
      });

      expect(status, 403);
    });

    test('Valid authenticated fault creation is allowed (200)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'Thermal',
          'severity': 'High',
          'description': 'Overheating spindle',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
          'machineName': 'Milling Machine 01',
          'reportedByName': 'Operator One',
        },
        token: tokenOp1,
      );

      expect(status, 200);
    });

    test('Missing required machineId is denied (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'type': 'Thermal',
          'severity': 'High',
          'description': 'Overheating spindle',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Empty required machineId is denied (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': '',
          'type': 'Thermal',
          'severity': 'High',
          'description': 'Overheating spindle',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Missing required description is denied (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'Thermal',
          'severity': 'High',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Empty description is denied (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'Thermal',
          'severity': 'High',
          'description': '',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Incorrectly typed machineId is denied (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 12345, // integer instead of string
          'type': 'Thermal',
          'severity': 'High',
          'description': 'Overheating spindle',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Invalid severity value is rejected (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'Thermal',
          'severity': 'SuperCritical', // Not in AppConstants.severities
          'description': 'Overheating spindle',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Invalid fault type value is rejected (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'AlienInvasion', // Not in AppConstants.faultTypes
          'severity': 'Critical',
          'description': 'Strange alien noise',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Invalid fault status value is rejected (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'Electrical',
          'severity': 'Low',
          'description': 'Flickering indicator',
          'reportedBy': 'sec_op_1',
          'status': 'PendingApproval', // Not in AppConstants.faultStatuses
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('User cannot submit fault using another user UID (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      // tokenOp1 (sec_op_1) attempts to submit reportedBy = sec_op_2
      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'Thermal',
          'severity': 'High',
          'description': 'Attempting impersonation',
          'reportedBy': 'sec_op_2',
          'status': 'Open',
        },
        token: tokenOp1,
      );

      expect(status, 403);
    });

    test('Attempting to modify immutable reportedBy during update is rejected (403)', () async {
      if (!emulatorAvailable) {
        return;
      }

      const faultPath = 'faults/fault_immutable_reportedby_test';

      await client.adminSetDocument(faultPath, {
        'machineId': 'MCH-01',
        'type': 'Thermal',
        'severity': 'High',
        'description': 'Original report',
        'reportedBy': 'sec_op_1',
        'status': 'Open',
      });

      // Manager attempts to change reportedBy to another user -> 403
      final status = await client.updateDocument(
        faultPath,
        {'reportedBy': 'sec_op_2'},
        token: tokenMgr,
      );
      expect(status, 403);
    });

    test('Fault creation allows ISO 8601 string createdAt from FaultModel.toMap (200)', () async {
      if (!emulatorAvailable) {
        return;
      }

      final status = await client.createDocument(
        'faults',
        {
          'machineId': 'MCH-01',
          'type': 'Thermal',
          'severity': 'High',
          'description': 'ISO date created fault',
          'reportedBy': 'sec_op_1',
          'status': 'Open',
          'createdAt': DateTime(2026, 10, 21, 12, 0).toIso8601String(),
        },
        token: tokenOp1,
      );

      expect(status, 200);
    });

    test('Role-based update and delete permissions remain enforced', () async {
      if (!emulatorAvailable) {
        return;
      }

      const faultPath = 'faults/fault_role_lifecycle_test';

      // 1. Seed fault with reportedBy = sec_op_1
      await client.adminSetDocument(faultPath, {
        'machineId': 'MCH-01',
        'type': 'Thermal',
        'severity': 'High',
        'description': 'Initial report',
        'reportedBy': 'sec_op_1',
        'status': 'Open',
      });

      // 2. Unrelated Operator 2 attempts update -> 403
      final op2UpdateStatus = await client.updateDocument(
        faultPath,
        {'description': 'Unauthorized edit'},
        token: tokenOp2,
      );
      expect(op2UpdateStatus, 403);

      // 3. Original Reporter (Operator 1) updates own report -> 200
      final op1UpdateStatus = await client.updateDocument(
        faultPath,
        {'description': 'Updated notes by reporter'},
        token: tokenOp1,
      );
      expect(op1UpdateStatus, 200);

      // 4. Technician updates status to "In Progress" -> 200
      final techUpdateStatus = await client.updateDocument(
        faultPath,
        {'status': 'In Progress'},
        token: tokenTech,
      );
      expect(techUpdateStatus, 200);

      // 5. Manager updates status to "Resolved" -> 200
      final mgrUpdateStatus = await client.updateDocument(
        faultPath,
        {'status': 'Resolved'},
        token: tokenMgr,
      );
      expect(mgrUpdateStatus, 200);

      // 6. Operator attempts delete -> 403
      final opDeleteStatus = await client.deleteDocument(
        faultPath,
        token: tokenOp1,
      );
      expect(opDeleteStatus, 403);

      // 7. Technician attempts delete -> 403
      final techDeleteStatus = await client.deleteDocument(
        faultPath,
        token: tokenTech,
      );
      expect(techDeleteStatus, 403);

      // 8. Manager deletes fault -> 200
      final mgrDeleteStatus = await client.deleteDocument(
        faultPath,
        token: tokenMgr,
      );
      expect(mgrDeleteStatus, 200);
    });
  });
}
