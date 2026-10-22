import 'dart:convert';
import 'dart:io';

/// Command-line tool to safely seed mock machines into the local Cloud Firestore Emulator.
///
/// Designed as a pure Dart CLI tool with zero dependencies on the Flutter engine.
///
/// Usage:
///   dart run tool/seed_mock_machines.dart [--overwrite] [--host 127.0.0.1] [--port 8080]
void main(List<String> args) async {
  final overwrite = args.contains('--overwrite');

  var host = '127.0.0.1';
  final hostIndex = args.indexOf('--host');
  if (hostIndex != -1 && hostIndex + 1 < args.length) {
    host = args[hostIndex + 1];
  }

  var port = 8080;
  final portIndex = args.indexOf('--port');
  if (portIndex != -1 && portIndex + 1 < args.length) {
    port = int.tryParse(args[portIndex + 1]) ?? port;
  }

  const projectId = 'machalert';

  stdout.writeln('==============================================');
  stdout.writeln('  MachAlert - Mock Machine Seeder');
  stdout.writeln('==============================================');
  stdout.writeln('Target: Firestore Emulator at $host:$port');
  stdout.writeln('Project: $projectId');
  stdout.writeln('Mode: ${overwrite ? "Overwrite existing" : "Skip existing"}');
  stdout.writeln('');

  stdout.writeln('Checking Firestore Emulator connectivity...');
  final isRunning = await _isEmulatorRunning(host: host, port: port);

  if (!isRunning) {
    stderr.writeln(
      '❌ Error: Firestore Emulator is NOT reachable at $host:$port.',
    );
    stderr.writeln('');
    stderr.writeln('To start the Firestore Emulator:');
    stderr.writeln('  firebase emulators:start --only firestore');
    stderr.writeln('');
    exit(1);
  }

  stdout.writeln('✓ Emulator reachable. Seeding mock machines...');

  try {
    final count = await _seedEmulator(
      host: host,
      port: port,
      projectId: projectId,
      overwrite: overwrite,
    );

    stdout.writeln('');
    stdout.writeln('✓ Seeding complete! $count new machine(s) written.');
    stdout.writeln('');
    stdout.writeln('Available Mock Machines:');
    for (final machine in _mockMachines) {
      stdout.writeln(
        '  • [${machine["id"]}] ${machine["name"]} (${machine["productionLine"]}) - Status: ${machine["status"]}',
      );
    }
    stdout.writeln('');
    stdout.writeln('Verification:');
    stdout.writeln(
      '  1. Run MachAlert connected to the emulator or view Machine List / Report Fault screen.',
    );
    stdout.writeln(
      '  2. The Machine dropdown will display these 5 seeded machines.',
    );
    stdout.writeln('==============================================');
    exit(0);
  } catch (e, stack) {
    stderr.writeln('❌ Seeding failed with error: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

Future<bool> _isEmulatorRunning({required String host, required int port}) async {
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

final List<Map<String, dynamic>> _mockMachines = [
  {
    'id': 'mock-cnc-01',
    'machineId': 'mock-cnc-01',
    'name': 'CNC Milling Machine 01',
    'productionLine': 'Line A',
    'modelNumber': 'VMC-850',
    'status': 'Operational',
    'healthScore': 94.5,
    'temperature': 42.0,
    'vibration': 0.12,
    'lastInspection': '2026-10-15T08:30:00Z',
    'createdAt': '2026-01-15T00:00:00Z',
    'updatedAt': '2026-10-15T08:30:00Z',
  },
  {
    'id': 'mock-press-02',
    'machineId': 'mock-press-02',
    'name': 'Hydraulic Press 02',
    'productionLine': 'Line A',
    'modelNumber': 'HP-200T',
    'status': 'Warning',
    'healthScore': 68.0,
    'temperature': 65.5,
    'vibration': 0.48,
    'lastInspection': '2026-10-18T14:00:00Z',
    'createdAt': '2026-02-10T00:00:00Z',
    'updatedAt': '2026-10-18T14:00:00Z',
  },
  {
    'id': 'mock-conveyor-03',
    'machineId': 'mock-conveyor-03',
    'name': 'Conveyor Belt 03',
    'productionLine': 'Line B',
    'modelNumber': 'CB-500-HD',
    'status': 'Operational',
    'healthScore': 88.0,
    'temperature': 35.0,
    'vibration': 0.15,
    'lastInspection': '2026-10-12T10:15:00Z',
    'createdAt': '2026-03-05T00:00:00Z',
    'updatedAt': '2026-10-12T10:15:00Z',
  },
  {
    'id': 'mock-molding-04',
    'machineId': 'mock-molding-04',
    'name': 'Injection Molding Machine 04',
    'productionLine': 'Line B',
    'modelNumber': 'IMM-350X',
    'status': 'Under Maintenance',
    'healthScore': 55.0,
    'temperature': 28.0,
    'vibration': 0.05,
    'lastInspection': '2026-10-20T16:45:00Z',
    'createdAt': '2026-04-01T00:00:00Z',
    'updatedAt': '2026-10-20T16:45:00Z',
  },
  {
    'id': 'mock-compressor-05',
    'machineId': 'mock-compressor-05',
    'name': 'Industrial Compressor 05',
    'productionLine': 'Line C',
    'modelNumber': 'AC-1200',
    'status': 'Critical',
    'healthScore': 32.0,
    'temperature': 88.2,
    'vibration': 0.85,
    'lastInspection': '2026-10-21T09:00:00Z',
    'createdAt': '2026-05-20T00:00:00Z',
    'updatedAt': '2026-10-21T09:00:00Z',
  },
];

Future<int> _seedEmulator({
  required String host,
  required int port,
  required String projectId,
  required bool overwrite,
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

  final httpClient = HttpClient();
  final basePath =
      '/v1/projects/$projectId/databases/(default)/documents/machines';
  var seededCount = 0;

  try {
    for (final machine in _mockMachines) {
      final docId = machine['id'] as String;
      final docUri = Uri.parse('http://$host:$port$basePath/$docId');

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

      final encoded = _encodeFields(machine);
      patchReq.write(jsonEncode({'fields': encoded}));

      final patchRes = await patchReq.close();
      await patchRes.drain<void>();

      if (patchRes.statusCode >= 200 && patchRes.statusCode < 300) {
        seededCount++;
      } else {
        throw HttpException(
          'Failed to seed machine "$docId": HTTP ${patchRes.statusCode}',
          uri: docUri,
        );
      }
    }
  } finally {
    httpClient.close(force: true);
  }

  return seededCount;
}

Map<String, dynamic> _encodeFields(Map<String, dynamic> raw) {
  final encoded = <String, dynamic>{};
  raw.forEach((key, value) {
    if (value is String) {
      if (key == 'lastInspection' || key == 'createdAt' || key == 'updatedAt') {
        encoded[key] = {'timestampValue': value};
      } else {
        encoded[key] = {'stringValue': value};
      }
    } else if (value is int) {
      encoded[key] = {'integerValue': value.toString()};
    } else if (value is double) {
      encoded[key] = {'doubleValue': value};
    } else if (value is bool) {
      encoded[key] = {'booleanValue': value};
    } else if (value == null) {
      encoded[key] = {'nullValue': null};
    }
  });
  return encoded;
}
