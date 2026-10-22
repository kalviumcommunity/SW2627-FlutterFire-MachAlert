import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/migrate_mock_machines.dart';

/// Test double implementing [MigrationTransport] for offline, deterministic testing.
class FakeMigrationTransport implements MigrationTransport {
  final List<RecordedGet> recordedGets = [];
  final List<RecordedPatch> recordedPatches = [];

  final Map<String, Map<String, dynamic>?> getResponses = {};
  final Map<String, MigrationResponse> patchResponses = {};
  final Map<String, Object> getExceptions = {};
  final Map<String, Object> patchExceptions = {};

  Map<String, dynamic>? Function(Uri uri)? onGet;
  MigrationResponse Function(Uri uri, Map<String, dynamic> body)? onPatch;

  bool isClosed = false;

  @override
  Future<Map<String, dynamic>?> getDocument({
    required Uri uri,
    required String? bearerToken,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    recordedGets.add(RecordedGet(uri: uri, bearerToken: bearerToken));

    final uriStr = uri.toString();

    if (getExceptions.containsKey(uriStr)) {
      throw getExceptions[uriStr]!;
    }

    if (onGet != null) {
      final custom = onGet!(uri);
      if (custom != null) return custom;
    }

    if (getResponses.containsKey(uriStr)) {
      return getResponses[uriStr];
    }

    // Default: return null (404 / absent)
    return null;
  }

  @override
  Future<MigrationResponse> patchDocument({
    required Uri uri,
    required String? bearerToken,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    recordedPatches.add(RecordedPatch(uri: uri, bearerToken: bearerToken, body: body));

    final uriStr = uri.toString();

    if (patchExceptions.containsKey(uriStr)) {
      throw patchExceptions[uriStr]!;
    }

    if (onPatch != null) {
      return onPatch!(uri, body);
    }

    if (patchResponses.containsKey(uriStr)) {
      return patchResponses[uriStr]!;
    }

    // Default: 200 OK
    return const MigrationResponse(statusCode: 200, body: '{}');
  }

  @override
  void close() {
    isClosed = true;
  }
}

class RecordedGet {
  final Uri uri;
  final String? bearerToken;
  RecordedGet({required this.uri, required this.bearerToken});
}

class RecordedPatch {
  final Uri uri;
  final String? bearerToken;
  final Map<String, dynamic> body;
  RecordedPatch({required this.uri, required this.bearerToken, required this.body});
}

Map<String, Map<String, dynamic>> createSampleValidFields() {
  return {
    'mock-cnc-01': {
      'id': {'stringValue': 'mock-cnc-01'},
      'name': {'stringValue': 'CNC Milling Machine 01'},
      'productionLine': {'stringValue': 'Line A'},
      'modelNumber': {'stringValue': 'VMC-850'},
      'status': {'stringValue': 'Operational'},
      'healthScore': {'doubleValue': 94.5},
      'temperature': {'doubleValue': 42.0},
      'vibration': {'doubleValue': 0.12},
      'lastInspection': {'timestampValue': '2026-10-15T08:30:00Z'},
      'createdAt': {'timestampValue': '2026-01-15T00:00:00Z'},
      'updatedAt': {'timestampValue': '2026-10-15T08:30:00Z'},
    },
    'mock-press-02': {
      'id': {'stringValue': 'mock-press-02'},
      'name': {'stringValue': 'Hydraulic Press 02'},
      'productionLine': {'stringValue': 'Line A'},
      'modelNumber': {'stringValue': 'HP-200T'},
      'status': {'stringValue': 'Warning'},
      'healthScore': {'doubleValue': 68.0},
      'temperature': {'doubleValue': 65.5},
      'vibration': {'doubleValue': 0.48},
      'lastInspection': {'timestampValue': '2026-10-18T14:00:00Z'},
      'createdAt': {'timestampValue': '2026-02-10T00:00:00Z'},
      'updatedAt': {'timestampValue': '2026-10-18T14:00:00Z'},
    },
    'mock-conveyor-03': {
      'id': {'stringValue': 'mock-conveyor-03'},
      'name': {'stringValue': 'Conveyor Belt 03'},
      'productionLine': {'stringValue': 'Line B'},
      'modelNumber': {'stringValue': 'CB-500-HD'},
      'status': {'stringValue': 'Operational'},
      'healthScore': {'doubleValue': 88.0},
      'temperature': {'doubleValue': 35.0},
      'vibration': {'doubleValue': 0.15},
      'lastInspection': {'timestampValue': '2026-10-12T10:15:00Z'},
      'createdAt': {'timestampValue': '2026-03-05T00:00:00Z'},
      'updatedAt': {'timestampValue': '2026-10-12T10:15:00Z'},
    },
    'mock-molding-04': {
      'id': {'stringValue': 'mock-molding-04'},
      'name': {'stringValue': 'Injection Molding Machine 04'},
      'productionLine': {'stringValue': 'Line B'},
      'modelNumber': {'stringValue': 'IMM-350X'},
      'status': {'stringValue': 'Under Maintenance'},
      'healthScore': {'doubleValue': 55.0},
      'temperature': {'doubleValue': 28.0},
      'vibration': {'doubleValue': 0.05},
      'lastInspection': {'timestampValue': '2026-10-20T16:45:00Z'},
      'createdAt': {'timestampValue': '2026-04-01T00:00:00Z'},
      'updatedAt': {'timestampValue': '2026-10-20T16:45:00Z'},
    },
    'mock-compressor-05': {
      'id': {'stringValue': 'mock-compressor-05'},
      'name': {'stringValue': 'Industrial Compressor 05'},
      'productionLine': {'stringValue': 'Line C'},
      'modelNumber': {'stringValue': 'AC-1200'},
      'status': {'stringValue': 'Critical'},
      'healthScore': {'doubleValue': 32.0},
      'temperature': {'doubleValue': 88.2},
      'vibration': {'doubleValue': 0.85},
      'lastInspection': {'timestampValue': '2026-10-21T09:00:00Z'},
      'createdAt': {'timestampValue': '2026-05-20T00:00:00Z'},
      'updatedAt': {'timestampValue': '2026-10-21T09:00:00Z'},
    },
  };
}

void populateLocalEmulator(FakeMigrationTransport transport, Map<String, Map<String, dynamic>> machines) {
  for (final entry in machines.entries) {
    final id = entry.key;
    final uriStr = 'http://127.0.0.1:8080/v1/projects/machalert/databases/(default)/documents/machines/$id';
    transport.getResponses[uriStr] = entry.value;
  }
}

void main() {
  group('Approval Gate & Argument Parsing', () {
    test('refuses execution with exit code 2 when approval flag is missing', () async {
      final transport = FakeMigrationTransport();
      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run([]);
      expect(code, equals(2));
      expect(err.toString(), contains('EXECUTION REFUSED: Missing explicit approval flag'));
      expect(transport.recordedGets, isEmpty);
      expect(transport.recordedPatches, isEmpty);
    });

    test('refuses execution with exit code 2 when unexpected arguments are provided', () async {
      final transport = FakeMigrationTransport();
      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run([
        '--execute-cloud-migration-approved',
        '--target=all',
      ]);
      expect(code, equals(2));
      expect(err.toString(), contains('Unexpected argument "--target=all"'));
      expect(transport.recordedGets, isEmpty);
      expect(transport.recordedPatches, isEmpty);
    });
  });

  group('Scope & Target Whitelist', () {
    test('targets exactly the five approved IDs and never targets users or faults', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(0));

      // Check all GET calls for local and cloud
      for (final getCall in transport.recordedGets) {
        expect(getCall.uri.path, contains('/documents/machines/'));
        expect(getCall.uri.path, isNot(contains('/users/')));
        expect(getCall.uri.path, isNot(contains('/faults/')));
        final docId = getCall.uri.pathSegments.last;
        expect(kApprovedMachineIds, contains(docId));
      }

      // Check all PATCH calls
      expect(transport.recordedPatches.length, equals(5));
      for (final patchCall in transport.recordedPatches) {
        expect(patchCall.uri.path, contains('/documents/machines/'));
        expect(patchCall.uri.path, isNot(contains('/users/')));
        expect(patchCall.uri.path, isNot(contains('/faults/')));
        final docId = patchCall.uri.pathSegments.last;
        expect(kApprovedMachineIds, contains(docId));
      }
    });
  });

  group('Pre-flight Validation & Execution Ordering', () {
    test('aborts with code 1 if any local emulator document is missing', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      // Remove one machine to simulate missing source data
      validMachines.remove('mock-compressor-05');
      populateLocalEmulator(transport, validMachines);

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(1));
      expect(err.toString(), contains('Found only 4 of 5 approved documents locally'));
      // No Cloud calls should be made
      expect(transport.recordedPatches, isEmpty);
    });

    test('aborts with code 1 if any local document fails schema validation', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      // Introduce schema corruption: invalid health score
      validMachines['mock-cnc-01']!['healthScore'] = {'stringValue': 'not-a-number'};
      populateLocalEmulator(transport, validMachines);

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(1));
      expect(err.toString(), contains('Schema validation failed. Zero Cloud writes executed'));
      expect(transport.recordedPatches, isEmpty);
    });

    test('completes all local validations and all Cloud preflights before first PATCH', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(0));

      // Total GET calls must be at least 10 (5 local emulator + 5 Cloud preflight) before any PATCH
      final localGets = transport.recordedGets.where((g) => g.uri.host == '127.0.0.1').toList();
      final cloudGets = transport.recordedGets.where((g) => g.uri.host == 'firestore.googleapis.com').toList();

      expect(localGets.length, equals(5));
      expect(cloudGets.length, equals(5));
      expect(transport.recordedPatches.length, equals(5));
    });
  });

  group('Conditional Create Preconditions & Skip Semantics', () {
    test('every PATCH write enforces currentDocument.exists=false query parameter', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      await runner.run(['--execute-cloud-migration-approved']);

      expect(transport.recordedPatches.length, equals(5));
      for (final patch in transport.recordedPatches) {
        expect(patch.uri.queryParameters['currentDocument.exists'], equals('false'));
      }
    });

    test('skips pre-existing Cloud documents without issuing PATCH writes', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      // Simulate mock-cnc-01 and mock-press-02 already existing in Cloud preflight
      final cloudPath1 = 'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01';
      final cloudPath2 = 'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-press-02';
      transport.getResponses[cloudPath1] = validMachines['mock-cnc-01'];
      transport.getResponses[cloudPath2] = validMachines['mock-press-02'];

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(0));

      // Exactly 3 PATCH calls should have been made (for conveyor, molding, compressor)
      expect(transport.recordedPatches.length, equals(3));
      final patchedIds = transport.recordedPatches.map((p) => p.uri.pathSegments.last).toList();
      expect(patchedIds, containsAll(['mock-conveyor-03', 'mock-molding-04', 'mock-compressor-05']));
      expect(patchedIds, isNot(contains('mock-cnc-01')));
      expect(patchedIds, isNot(contains('mock-press-02')));
    });

    test('HTTP 409 with status ALREADY_EXISTS is classified as verified SKIP', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      // Simulate concurrent creation returning HTTP 409 ALREADY_EXISTS on mock-cnc-01
      final patchUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01?currentDocument.exists=false';
      transport.patchResponses[patchUri] = MigrationResponse(
        statusCode: 409,
        body: jsonEncode({
          'error': {
            'code': 409,
            'message': 'Document already exists',
            'status': 'ALREADY_EXISTS',
          }
        }),
      );

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(0));
      expect(out.toString(), contains('[SKIP] mock-cnc-01: Precondition enforced: ALREADY_EXISTS (HTTP 409)'));
    });

    test('unrelated HTTP 409 (ABORTED) is reported as explicit failure and not misclassified as skip', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      // Simulate transaction contention returning HTTP 409 ABORTED on mock-cnc-01
      final patchUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01?currentDocument.exists=false';
      transport.patchResponses[patchUri] = MigrationResponse(
        statusCode: 409,
        body: jsonEncode({
          'error': {
            'code': 409,
            'message': 'Too much contention on these documents',
            'status': 'ABORTED',
          }
        }),
      );

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(1));
      expect(err.toString(), contains('Unrelated conflict: Database transaction ABORTED (HTTP 409)'));
      // Remaining 4 writes must not be attempted
      expect(transport.recordedPatches.length, equals(1));
    });

    test('ambiguous HTTP 409 is reconciled via read-only GET', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      var patchAttempted = false;
      final patchUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01?currentDocument.exists=false';
      transport.onPatch = (uri, body) {
        if (uri.toString() == patchUri) {
          patchAttempted = true;
          return const MigrationResponse(
            statusCode: 409,
            body: '{"error": {"code": 409, "message": "Conflict"}}',
          );
        }
        return const MigrationResponse(statusCode: 200, body: '{}');
      };

      // Reconcile GET returns the document: verifies it actually exists in Cloud
      final getUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01';
      transport.onGet = (uri) {
        if (patchAttempted && uri.toString() == getUri) {
          return validMachines['mock-cnc-01'];
        }
        return null;
      };

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(0));
      expect(out.toString(), contains('Precondition verified via GET: Document already exists in Cloud'));
    });
  });

  group('Timeout Reconciliation & Network Failures', () {
    test('PATCH timeout is reconciled via GET returning document and marked CREATED', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      var patchAttempted = false;
      final patchUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01?currentDocument.exists=false';
      transport.onPatch = (uri, body) {
        if (uri.toString() == patchUri) {
          patchAttempted = true;
          throw TimeoutException('PATCH timeout');
        }
        return const MigrationResponse(statusCode: 200, body: '{}');
      };

      // Reconcile GET: Cloud Firestore did commit the write before connection dropped
      final getUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01';
      transport.onGet = (uri) {
        if (patchAttempted && uri.toString() == getUri) {
          return validMachines['mock-cnc-01'];
        }
        return null;
      };

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(0));
      expect(out.toString(), contains('Reconciled via GET after Request Timeout'));
    });

    test('PATCH timeout reconciled via GET returning 404 is marked FAILED and halts further writes', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      final patchUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01?currentDocument.exists=false';
      transport.patchExceptions[patchUri] = TimeoutException('PATCH timeout');

      // Reconcile GET returns null (404 Not Found): the write never committed
      final getUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01';
      transport.getResponses[getUri] = null;

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(1));
      expect(err.toString(), contains('Write did not commit to Cloud Firestore'));
      expect(transport.recordedPatches.length, equals(1));
    });
  });

  group('HTTP Status Code Error Handling & Partial Failures', () {
    test('HTTP 401 halts migration immediately with code 1 and prompts firebase login', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      final patchUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01?currentDocument.exists=false';
      transport.patchResponses[patchUri] = const MigrationResponse(statusCode: 401, body: 'Unauthorized');

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(1));
      expect(err.toString(), contains('Firebase CLI session expired (HTTP 401)'));
      expect(err.toString(), contains('firebase login'));
    });

    test('HTTP 403 halts migration with code 1 and permission denied message', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      final patchUri =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-cnc-01?currentDocument.exists=false';
      transport.patchResponses[patchUri] = const MigrationResponse(statusCode: 403, body: 'Forbidden');

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(1));
      expect(err.toString(), contains('Permission denied on project machalert (HTTP 403)'));
    });

    test('partial failure on document 3 halts migration and records remaining as NOT ATTEMPTED', () async {
      final transport = FakeMigrationTransport();
      final validMachines = createSampleValidFields();
      populateLocalEmulator(transport, validMachines);

      // Document 1 succeeds, Document 2 succeeds, Document 3 fails with 500
      final patchUri3 =
          'https://firestore.googleapis.com/v1/projects/machalert/databases/(default)/documents/machines/mock-conveyor-03?currentDocument.exists=false';
      transport.patchResponses[patchUri3] = const MigrationResponse(statusCode: 500, body: 'Internal Server Error');

      final out = StringBuffer();
      final err = StringBuffer();

      final runner = MigrationRunner(
        transport: transport,
        tokenProvider: () async => 'fake-token',
        stdoutSink: out,
        stderrSink: err,
      );

      final code = await runner.run(['--execute-cloud-migration-approved']);
      expect(code, equals(1));
      expect(err.toString(), contains('Cloud Firestore service error (HTTP 500)'));
      expect(err.toString(), contains('Further writes cancelled'));

      // Check summary output
      final outText = out.toString();
      expect(outText, contains('MIGRATION EXECUTION SUMMARY (PARTIAL / HALTED)'));
      expect(outText, contains('Documents Successfully Created: 2'));
      expect(outText, contains('[mock-molding-04]'));
      expect(outText, contains('NOTATTEMPTED'));
      expect(outText, contains('Not attempted due to prior failure on mock-conveyor-03'));
      expect(outText, contains('[mock-compressor-05]'));

      // Only 3 PATCH calls were made
      expect(transport.recordedPatches.length, equals(3));
    });
  });
}
