import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/machine_model.dart';
import 'app_constants.dart';
import 'mock_machine_data.dart';

/// Utility to safely seed mock machines into local development environments
/// or the Cloud Firestore Emulator.
///
/// Safety guarantees:
/// - Explicitly restricted to development environments and local emulators.
/// - Idempotent and repeatable: skips existing documents by default to prevent
///   duplicates or accidental overwriting of user data.
/// - Never runs automatically in production.
class MockMachineSeeder {
  MockMachineSeeder._();

  /// Default local Firestore emulator host.
  static const String defaultEmulatorHost = '127.0.0.1';

  /// Default local Firestore emulator port.
  static const int defaultEmulatorPort = 8080;

  /// Default project identifier matching firebase.json.
  static const String defaultProjectId = 'machalert';

  /// Checks whether a local Firestore Emulator is running and reachable.
  static Future<bool> isEmulatorRunning({
    String host = defaultEmulatorHost,
    int port = defaultEmulatorPort,
  }) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 500),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Seeds mock machines using a [FirebaseFirestore] instance.
  ///
  /// Intended for automated unit/widget tests and local development testing.
  /// [isDevelopmentOnly] must be true to execute; otherwise a [StateError] is thrown.
  /// If [overwrite] is false (default), existing documents with the same ID are skipped.
  ///
  /// Returns the number of machine documents written.
  static Future<int> seedFirestore(
    FirebaseFirestore firestore, {
    bool overwrite = false,
    bool isDevelopmentOnly = true,
    List<MachineModel>? machines,
  }) async {
    if (!isDevelopmentOnly) {
      throw StateError(
        'Mock machine seeding is strictly prohibited in production environments.',
      );
    }

    final collection = firestore.collection(AppConstants.machinesCollection);
    final listToSeed = machines ?? MockMachineData.sampleMachines;
    var seededCount = 0;

    for (final machine in listToSeed) {
      final docRef = collection.doc(machine.id);

      if (!overwrite) {
        final existing = await docRef.get();
        if (existing.exists) {
          continue;
        }
      }

      final data = machine.toFirestoreMap(isUpdate: false);
      if (machine.createdAt != null) {
        data['createdAt'] = Timestamp.fromDate(machine.createdAt!);
      }
      if (machine.updatedAt != null) {
        data['updatedAt'] = Timestamp.fromDate(machine.updatedAt!);
      }

      await docRef.set(data);
      seededCount++;
    }

    return seededCount;
  }

  /// Seeds mock machines directly into the local Cloud Firestore Emulator via REST v1 API.
  ///
  /// Uses the administrative bearer token (`Bearer owner`) accepted by the emulator.
  /// Guarantees safety:
  /// - Refuses to connect if [host] is not a local loopback address.
  /// - Skips existing documents when [overwrite] is false.
  ///
  /// Returns the number of machine documents written.
  static Future<int> seedEmulator({
    String host = defaultEmulatorHost,
    int port = defaultEmulatorPort,
    String projectId = defaultProjectId,
    bool overwrite = false,
    List<MachineModel>? machines,
  }) async {
    final normalizedHost = host.trim().toLowerCase();
    final isLocal =
        normalizedHost == '127.0.0.1' ||
        normalizedHost == 'localhost' ||
        normalizedHost == '::1' ||
        normalizedHost == '10.0.2.2';

    if (!isLocal) {
      throw StateError(
        'Emulator seeding is strictly restricted to local hosts ($host is not local).',
      );
    }

    final isRunning = await isEmulatorRunning(host: host, port: port);
    if (!isRunning) {
      throw StateError(
        'Firestore Emulator is not reachable at $host:$port. '
        'Start the emulator with: firebase emulators:start --only firestore',
      );
    }

    final httpClient = HttpClient();
    final basePath =
        '/v1/projects/$projectId/databases/(default)/documents/${AppConstants.machinesCollection}';
    final listToSeed = machines ?? MockMachineData.sampleMachines;
    var seededCount = 0;

    try {
      for (final machine in listToSeed) {
        final docUri = Uri.parse('http://$host:$port$basePath/${machine.id}');

        if (!overwrite) {
          final getReq = await httpClient.getUrl(docUri);
          getReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
          final getRes = await getReq.close();
          await getRes.drain<void>();

          if (getRes.statusCode == 200) {
            continue;
          }
        }

        final patchReq = await httpClient.openUrl('PATCH', docUri);
        patchReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
        patchReq.headers.contentType = ContentType.json;

        final rawFields = <String, dynamic>{
          'id': machine.id,
          'machineId': machine.id,
          'name': machine.name,
          'productionLine': machine.productionLine,
          'status': machine.status,
          'healthScore': machine.healthScore,
        };

        if (machine.modelNumber != null) {
          rawFields['modelNumber'] = machine.modelNumber;
        }
        if (machine.temperature != null) {
          rawFields['temperature'] = machine.temperature;
        }
        if (machine.vibration != null) {
          rawFields['vibration'] = machine.vibration;
        }
        if (machine.lastInspection != null) {
          rawFields['lastInspection'] = machine.lastInspection;
        }
        if (machine.createdAt != null) {
          rawFields['createdAt'] = machine.createdAt;
        }
        if (machine.updatedAt != null) {
          rawFields['updatedAt'] = machine.updatedAt;
        }

        final encoded = _encodeFields(rawFields);
        patchReq.write(jsonEncode({'fields': encoded}));

        final patchRes = await patchReq.close();
        await patchRes.drain<void>();

        if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
          seededCount++;
        } else {
          throw HttpException(
            'Failed to seed machine "${machine.id}": HTTP ${patchRes.statusCode}',
            uri: docUri,
          );
        }
      }
    } finally {
      httpClient.close(force: true);
    }

    return seededCount;
  }

  /// Encodes Dart primitives into Firestore REST v1 API value maps.
  static Map<String, dynamic> _encodeFields(Map<String, dynamic> raw) {
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
      } else if (value is DateTime) {
        encoded[key] = {'timestampValue': value.toUtc().toIso8601String()};
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
