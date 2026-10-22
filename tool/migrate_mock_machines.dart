import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Migration tool to conditionally create exactly five approved mock machine documents
/// from the local Firestore Emulator into Cloud Firestore project `machalert`.
///
/// STRICT SAFETY CONSTRAINTS:
/// 1. REQUIRES EXPLICIT APPROVAL GATE: Will not run unless `--execute-cloud-migration-approved`
///    is explicitly passed. Any other unexpected arguments are rejected with exit code 2.
/// 2. STRICTLY SCOPED: Targets only the `machines` collection and the five approved IDs:
///    - mock-cnc-01
///    - mock-press-02
///    - mock-conveyor-03
///    - mock-molding-04
///    - mock-compressor-05
/// 3. STRICT PRE-FLIGHT VALIDATION: All 5 documents must exist locally in the Firestore
///    Emulator and pass 100% schema validation across all 8 canonical fields and timestamps
///    before ANY Cloud write can occur.
/// 4. IDEMPOTENT CONDITIONAL CREATION: Uses `currentDocument.exists=false` query parameter
///    on PATCH requests to guarantee documents are never overwritten.
/// 5. SAFE HTTP 409 VERIFICATION & RECONCILIATION: Inspects response bodies and reconciles
///    with read-only GET before reporting skips; unrelated conflicts are reported as explicit failures.
/// 6. TIMEOUT & RECONCILIATION: Reconciles writes via GET after timeouts rather than retrying blindly.
/// 7. PARTIAL-FAILURE REPORTING: Tracks CREATED, SKIPPED, FAILED, and NOT ATTEMPTED per document.
/// 8. NEVER MODIFIES USERS OR FAULTS: Zero touch to `users`, `faults`, rules, or auth.
/// 9. ZERO CREDENTIAL EXPOSURE: OAuth access token is read into memory only and never logged.

void main(List<String> args) async {
  final runner = MigrationRunner();
  final exitCode = await runner.run(args);
  exit(exitCode);
}

const String kMigrationProjectId = 'machalert';
const String kRequiredApprovalFlag = '--execute-cloud-migration-approved';
const List<String> kApprovedMachineIds = [
  'mock-cnc-01',
  'mock-press-02',
  'mock-conveyor-03',
  'mock-molding-04',
  'mock-compressor-05',
];

/// Outcome classification for each approved document during migration.
enum DocumentOutcome {
  created,
  skipped,
  failed,
  notAttempted,
}

/// Detailed tracking record for a single document's migration lifecycle.
class DocumentMigrationRecord {
  final String documentId;
  DocumentOutcome outcome;
  String reason;

  DocumentMigrationRecord({
    required this.documentId,
    required this.outcome,
    required this.reason,
  });
}

/// Abstract transport layer enabling safe, isolated offline unit tests without Cloud access.
abstract class MigrationTransport {
  Future<Map<String, dynamic>?> getDocument({
    required Uri uri,
    required String? bearerToken,
    Duration timeout = const Duration(seconds: 15),
  });

  Future<MigrationResponse> patchDocument({
    required Uri uri,
    required String? bearerToken,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 30),
  });

  void close();
}

/// Response wrapper for HTTP operations without exposing raw sockets or credentials.
class MigrationResponse {
  final int statusCode;
  final String body;

  const MigrationResponse({
    required this.statusCode,
    required this.body,
  });
}

/// Production HTTP transport with bounded connection and request timeouts.
class HttpMigrationTransport implements MigrationTransport {
  final HttpClient _client;

  HttpMigrationTransport({HttpClient? client})
      : _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 15));

  @override
  Future<Map<String, dynamic>?> getDocument({
    required Uri uri,
    required String? bearerToken,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final req = await _client.getUrl(uri).timeout(timeout);
    if (bearerToken != null && bearerToken.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    }
    final res = await req.close().timeout(timeout);

    if (res.statusCode == 200) {
      final bodyStr = await res.transform(utf8.decoder).join().timeout(timeout);
      final json = jsonDecode(bodyStr) as Map<String, dynamic>;
      return (json['fields'] as Map<String, dynamic>?) ?? {};
    } else if (res.statusCode == 404) {
      await res.drain<void>().timeout(timeout);
      return null;
    } else if (res.statusCode == 401) {
      await res.drain<void>().timeout(timeout);
      throw const MigrationAuthException('Firebase CLI session expired (HTTP 401).');
    } else if (res.statusCode == 403) {
      await res.drain<void>().timeout(timeout);
      throw const MigrationPermissionException('Permission denied on Google Cloud project (HTTP 403).');
    } else {
      await res.drain<void>().timeout(timeout);
      throw MigrationHttpException(
        statusCode: res.statusCode,
        message: 'GET request failed with HTTP ${res.statusCode}',
      );
    }
  }

  @override
  Future<MigrationResponse> patchDocument({
    required Uri uri,
    required String? bearerToken,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final req = await _client.openUrl('PATCH', uri).timeout(timeout);
    if (bearerToken != null && bearerToken.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    }
    req.headers.contentType = ContentType.json;

    req.write(jsonEncode(body));
    final res = await req.close().timeout(timeout);
    final bodyStr = await res.transform(utf8.decoder).join().timeout(timeout);

    return MigrationResponse(statusCode: res.statusCode, body: bodyStr);
  }

  @override
  void close() {
    _client.close(force: true);
  }
}

/// Core migration orchestrator with dependency injection for transport and output sinks.
class MigrationRunner {
  final MigrationTransport _transport;
  final Future<String?> Function() _tokenProvider;
  final StringSink _stdout;
  final StringSink _stderr;

  MigrationRunner({
    MigrationTransport? transport,
    Future<String?> Function()? tokenProvider,
    StringSink? stdoutSink,
    StringSink? stderrSink,
  })  : _transport = transport ?? HttpMigrationTransport(),
        _tokenProvider = tokenProvider ?? _getFirebaseCliAccessToken,
        _stdout = stdoutSink ?? stdout,
        _stderr = stderrSink ?? stderr;

  Future<int> run(List<String> args) async {
    _stdout.writeln('===============================================================');
    _stdout.writeln('  MachAlert - Cloud Firestore Machine Migration Tool');
    _stdout.writeln('===============================================================');
    _stdout.writeln('Project: $kMigrationProjectId');
    _stdout.writeln('Scope: Exactly 5 approved mock machine documents');
    _stdout.writeln('Collections untouched: users (0), faults (0)');
    _stdout.writeln('---------------------------------------------------------------');

    // 1. Mandatory Approval Gate Check
    if (!args.contains(kRequiredApprovalFlag)) {
      _stderr.writeln('⛔ EXECUTION REFUSED: Missing explicit approval flag.');
      _stderr.writeln('');
      _stderr.writeln('To execute the migration with live Cloud Firestore writes, pass:');
      _stderr.writeln('  dart run tool/migrate_mock_machines.dart $kRequiredApprovalFlag');
      _stderr.writeln('');
      _stderr.writeln('If you want to perform a dry-run without writes, run:');
      _stderr.writeln('  dart run tool/dry_run_migration.dart');
      _stderr.writeln('===============================================================');
      return 2;
    }

    // 2. Reject any unexpected arguments to prevent arbitrary parameters or collection targeting
    for (final arg in args) {
      if (arg != kRequiredApprovalFlag) {
        _stderr.writeln('❌ Error: Unexpected argument "$arg". Only "$kRequiredApprovalFlag" is permitted.');
        return 2;
      }
    }

    _stdout.writeln('✓ Execution approval flag verified: $kRequiredApprovalFlag');
    _stdout.writeln('');

    // Initialize tracking records for all 5 documents
    final records = <String, DocumentMigrationRecord>{
      for (final id in kApprovedMachineIds)
        id: DocumentMigrationRecord(
          documentId: id,
          outcome: DocumentOutcome.notAttempted,
          reason: 'Pending execution',
        ),
    };

    try {
      // Step 1: Read local Firestore Emulator data
      _stdout.writeln('1. Inspecting local Firestore Emulator (127.0.0.1:8080)...');
      final localMachines = await _readLocalEmulatorMachines(
        host: '127.0.0.1',
        port: 8080,
        projectId: kMigrationProjectId,
        approvedIds: kApprovedMachineIds,
      );

      if (localMachines.length != kApprovedMachineIds.length) {
        _stderr.writeln('');
        _stderr.writeln(
          '❌ ABORTING: Found only ${localMachines.length} of ${kApprovedMachineIds.length} approved documents locally.',
        );
        _stderr.writeln('   All 5 approved documents must be present in the local emulator before migration.');
        _printSummary(records);
        return 1;
      }
      _stdout.writeln('   ✓ Found all 5 approved mock machine documents in local emulator.');

      // Step 2: Validate Schema for all 8 canonical fields from lib/utils/mock_machine_data.dart
      _stdout.writeln('');
      _stdout.writeln('2. Performing strict schema pre-flight validation on local records...');
      var schemaHasErrors = false;

      for (final id in kApprovedMachineIds) {
        final doc = localMachines[id];
        final errors = validateMachineSchema(id, doc);
        if (errors.isNotEmpty) {
          schemaHasErrors = true;
          _stdout.writeln('   ✗ [$id] Schema Malformed:');
          for (final err in errors) {
            _stdout.writeln('       • $err');
          }
        } else {
          _stdout.writeln('   ✓ [$id] Schema valid (8/8 canonical fields + timestamps verified)');
        }
      }

      if (schemaHasErrors) {
        _stderr.writeln('');
        _stderr.writeln('❌ ABORTING: Schema validation failed. Zero Cloud writes executed.');
        _printSummary(records);
        return 1;
      }
      _stdout.writeln('   ✓ All 5 local documents passed schema validation.');

      // Step 3: Read Cloud Firestore OAuth credentials
      _stdout.writeln('');
      _stdout.writeln('3. Resolving Firebase CLI credentials...');
      final cloudToken = await _tokenProvider();
      if (cloudToken == null || cloudToken.isEmpty) {
        _stderr.writeln(
          '   ❌ Error: Unable to resolve active Firebase CLI access token from ~/.config/configstore/firebase-tools.json.',
        );
        _stderr.writeln('   Please run `firebase login` to authenticate safely.');
        _printSummary(records);
        return 1;
      }
      _stdout.writeln('   ✓ Cloud authorization credentials resolved successfully.');

      // Step 4: Perform Cloud preflight checks for all five IDs
      _stdout.writeln('');
      _stdout.writeln('4. Performing Cloud pre-flight existence checks (projects/$kMigrationProjectId)...');
      final cloudPreflight = await _checkCloudDocuments(
        projectId: kMigrationProjectId,
        token: cloudToken,
        approvedIds: kApprovedMachineIds,
      );

      _stdout.writeln('   ✓ Cloud pre-flight inspection complete:');
      for (final id in kApprovedMachineIds) {
        final exists = cloudPreflight[id] ?? false;
        if (exists) {
          records[id]!.outcome = DocumentOutcome.skipped;
          records[id]!.reason = 'Detected in Cloud pre-flight (HTTP 200)';
          _stdout.writeln('     • $id: Already Exists in Cloud (Will SKIP)');
        } else {
          _stdout.writeln('     • $id: Absent in Cloud (Will conditionally CREATE)');
        }
      }

      // Step 5: Execute Conditional Create for each document
      _stdout.writeln('');
      _stdout.writeln('5. Executing conditional creates with precondition `currentDocument.exists=false`...');
      _stdout.writeln('---------------------------------------------------------------');

      for (final id in kApprovedMachineIds) {
        // Skip documents already detected in Cloud preflight
        if (records[id]!.outcome == DocumentOutcome.skipped) {
          _stdout.writeln('  • [SKIP (Pre-flight)] $id: Document already exists in Cloud Firestore.');
          continue;
        }

        final fields = localMachines[id]!;
        final writeResult = await _executeConditionalCreate(
          projectId: kMigrationProjectId,
          token: cloudToken,
          documentId: id,
          fields: fields,
        );

        if (writeResult.outcome == DocumentOutcome.created) {
          records[id]!.outcome = DocumentOutcome.created;
          records[id]!.reason = writeResult.reason;
          _stdout.writeln('  • [CREATED] $id: ${writeResult.reason}');
        } else if (writeResult.outcome == DocumentOutcome.skipped) {
          records[id]!.outcome = DocumentOutcome.skipped;
          records[id]!.reason = writeResult.reason;
          _stdout.writeln('  • [SKIP] $id: ${writeResult.reason}');
        } else {
          // Fatal write failure: record failure, stop issuing further writes
          records[id]!.outcome = DocumentOutcome.failed;
          records[id]!.reason = writeResult.reason;
          _stderr.writeln('  ✗ [FAILED] $id: ${writeResult.reason}');
          _stderr.writeln('');
          _stderr.writeln('⛔ HALTING MIGRATION: Further writes cancelled to prevent inconsistent state.');

          // Mark remaining documents as not attempted
          for (final remainingId in kApprovedMachineIds) {
            if (records[remainingId]!.outcome == DocumentOutcome.notAttempted) {
              records[remainingId]!.reason = 'Not attempted due to prior failure on $id';
            }
          }

          _printSummary(records);
          return 1;
        }
      }

      _stdout.writeln('---------------------------------------------------------------');
      _printSummary(records);
      return 0;
    } on MigrationAuthException catch (e) {
      _stderr.writeln('');
      _stderr.writeln('❌ FATAL AUTHENTICATION ERROR: ${e.message}');
      _stderr.writeln('   Please run `firebase login` to refresh your session.');
      _printSummary(records);
      return 1;
    } on MigrationPermissionException catch (e) {
      _stderr.writeln('');
      _stderr.writeln('❌ FATAL PERMISSION ERROR: ${e.message}');
      _printSummary(records);
      return 1;
    } catch (e) {
      _stderr.writeln('');
      _stderr.writeln('❌ UNEXPECTED ERROR: $e');
      _printSummary(records);
      return 1;
    } finally {
      _transport.close();
    }
  }

  Future<Map<String, Map<String, dynamic>>> _readLocalEmulatorMachines({
    required String host,
    required int port,
    required String projectId,
    required List<String> approvedIds,
  }) async {
    final results = <String, Map<String, dynamic>>{};

    for (final id in approvedIds) {
      final uri = Uri.parse('http://$host:$port/v1/projects/$projectId/databases/(default)/documents/machines/$id');
      final fields = await _transport.getDocument(uri: uri, bearerToken: 'owner');
      if (fields != null) {
        results[id] = fields;
      }
    }

    return results;
  }

  Future<Map<String, bool>> _checkCloudDocuments({
    required String projectId,
    required String token,
    required List<String> approvedIds,
  }) async {
    final results = <String, bool>{};

    for (final id in approvedIds) {
      final uri = Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$projectId/databases/(default)/documents/machines/$id',
      );

      final fields = await _transport.getDocument(uri: uri, bearerToken: token);
      results[id] = fields != null;
    }

    return results;
  }

  /// Executes conditional create and reconciles timeouts/409 conflicts via read-only GET.
  Future<_InternalWriteResult> _executeConditionalCreate({
    required String projectId,
    required String token,
    required String documentId,
    required Map<String, dynamic> fields,
  }) async {
    final patchUri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/machines/$documentId',
      {'currentDocument.exists': 'false'},
    );

    final getUri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/machines/$documentId',
    );

    MigrationResponse patchRes;
    try {
      patchRes = await _transport.patchDocument(
        uri: patchUri,
        bearerToken: token,
        body: {'fields': fields},
      );
    } on SocketException catch (e) {
      // Reconcile via GET before assuming failure or success
      return await _reconcileAfterNetworkError(
        getUri: getUri,
        token: token,
        documentId: documentId,
        networkErrorDescription: 'SocketException (${e.message})',
      );
    } on TimeoutException catch (e) {
      // Reconcile via GET before deciding what happened
      return await _reconcileAfterNetworkError(
        getUri: getUri,
        token: token,
        documentId: documentId,
        networkErrorDescription: 'Request Timeout ($e)',
      );
    } on Exception catch (e) {
      return _InternalWriteResult(
        outcome: DocumentOutcome.failed,
        reason: 'Network error during conditional create: $e',
      );
    }

    final statusCode = patchRes.statusCode;

    // 1. Success (HTTP 200..299)
    if (statusCode >= 200 && statusCode < 300) {
      return _InternalWriteResult(
        outcome: DocumentOutcome.created,
        reason: 'Document created successfully (HTTP $statusCode)',
      );
    }

    // 2. Conflict Handling (HTTP 409)
    if (statusCode == 409) {
      return await _handleConflictResponse(
        patchRes: patchRes,
        getUri: getUri,
        token: token,
        documentId: documentId,
      );
    }

    // 3. Authentication Failure (HTTP 401)
    if (statusCode == 401) {
      throw const MigrationAuthException('Firebase CLI session expired (HTTP 401).');
    }

    // 4. Permission Denied (HTTP 403)
    if (statusCode == 403) {
      throw const MigrationPermissionException('Permission denied on project $kMigrationProjectId (HTTP 403).');
    }

    // 5. Rate Limited (HTTP 429)
    if (statusCode == 429) {
      return _InternalWriteResult(
        outcome: DocumentOutcome.failed,
        reason: 'Rate limit exceeded by Cloud Firestore (HTTP 429). Aborting safely.',
      );
    }

    // 6. Server Error (HTTP 5xx)
    if (statusCode >= 500 && statusCode < 600) {
      return _InternalWriteResult(
        outcome: DocumentOutcome.failed,
        reason: 'Cloud Firestore service error (HTTP $statusCode). Aborting safely.',
      );
    }

    // 7. Other unexpected HTTP errors
    return _InternalWriteResult(
      outcome: DocumentOutcome.failed,
      reason: 'Unexpected HTTP $statusCode response from Cloud Firestore.',
    );
  }

  /// Inspects HTTP 409 response body to verify that the conflict represents document existence.
  Future<_InternalWriteResult> _handleConflictResponse({
    required MigrationResponse patchRes,
    required Uri getUri,
    required String token,
    required String documentId,
  }) async {
    String? errorStatus;
    String? errorMessage;

    try {
      final json = jsonDecode(patchRes.body) as Map<String, dynamic>?;
      final error = json?['error'] as Map<String, dynamic>?;
      errorStatus = error?['status']?.toString();
      errorMessage = error?['message']?.toString();
    } catch (_) {
      // Body not JSON
    }

    // Case A: Confirmed ALREADY_EXISTS from Firestore API
    if (errorStatus == 'ALREADY_EXISTS') {
      return _InternalWriteResult(
        outcome: DocumentOutcome.skipped,
        reason: 'Precondition enforced: ALREADY_EXISTS (HTTP 409)',
      );
    }

    // Case B: Confirmed FAILED_PRECONDITION where message describes existence
    if (errorStatus == 'FAILED_PRECONDITION' &&
        errorMessage != null &&
        (errorMessage.toLowerCase().contains('exists') || errorMessage.toLowerCase().contains('already'))) {
      return _InternalWriteResult(
        outcome: DocumentOutcome.skipped,
        reason: 'Precondition enforced: FAILED_PRECONDITION (HTTP 409)',
      );
    }

    // Case C: Unrelated conflict (e.g. ABORTED due to transaction contention)
    if (errorStatus == 'ABORTED') {
      return _InternalWriteResult(
        outcome: DocumentOutcome.failed,
        reason: 'Unrelated conflict: Database transaction ABORTED (HTTP 409), not document existence',
      );
    }

    // Case D: Ambiguous 409 — reconcile via read-only GET
    try {
      final existingDoc = await _transport.getDocument(uri: getUri, bearerToken: token);
      if (existingDoc != null) {
        return _InternalWriteResult(
          outcome: DocumentOutcome.skipped,
          reason: 'Precondition verified via GET: Document already exists in Cloud',
        );
      } else {
        return _InternalWriteResult(
          outcome: DocumentOutcome.failed,
          reason: 'HTTP 409 received but document is absent in Cloud (Unresolved conflict: $errorStatus)',
        );
      }
    } catch (e) {
      return _InternalWriteResult(
        outcome: DocumentOutcome.failed,
        reason: 'Ambiguous HTTP 409 conflict could not be reconciled via GET: $e',
      );
    }
  }

  /// Reconciles write status after a timeout or socket exception via read-only GET.
  Future<_InternalWriteResult> _reconcileAfterNetworkError({
    required Uri getUri,
    required String token,
    required String documentId,
    required String networkErrorDescription,
  }) async {
    _stdout.writeln('  ⚡ Network interruption ($networkErrorDescription). Reconciling document state via read-only GET...');
    try {
      final cloudDoc = await _transport.getDocument(uri: getUri, bearerToken: token);
      if (cloudDoc != null) {
        return _InternalWriteResult(
          outcome: DocumentOutcome.created,
          reason: 'Document verified present in Cloud Firestore (Reconciled via GET after $networkErrorDescription; creator confirmed present)',
        );
      } else {
        return _InternalWriteResult(
          outcome: DocumentOutcome.failed,
          reason: '$networkErrorDescription: Write did not commit to Cloud Firestore',
        );
      }
    } catch (e) {
      return _InternalWriteResult(
        outcome: DocumentOutcome.failed,
        reason: '$networkErrorDescription: Unable to reconcile Cloud state via GET ($e)',
      );
    }
  }

  void _printSummary(Map<String, DocumentMigrationRecord> records) {
    var createdCount = 0;
    var skippedCount = 0;
    var failedCount = 0;
    var notAttemptedCount = 0;

    for (final r in records.values) {
      switch (r.outcome) {
        case DocumentOutcome.created:
          createdCount++;
          break;
        case DocumentOutcome.skipped:
          skippedCount++;
          break;
        case DocumentOutcome.failed:
          failedCount++;
          break;
        case DocumentOutcome.notAttempted:
          notAttemptedCount++;
          break;
      }
    }

    final isPartialFailure = failedCount > 0 || notAttemptedCount > 0;

    _stdout.writeln('');
    _stdout.writeln('===============================================================');
    if (isPartialFailure) {
      _stdout.writeln('  MIGRATION EXECUTION SUMMARY (PARTIAL / HALTED)');
    } else {
      _stdout.writeln('  MIGRATION EXECUTION SUMMARY (SUCCESS)');
    }
    _stdout.writeln('===============================================================');
    _stdout.writeln('  • Approved Machines in Scope:     ${records.length}');
    _stdout.writeln('  • Documents Successfully Created: $createdCount');
    _stdout.writeln('  • Documents Verified Skipped:     $skippedCount');
    _stdout.writeln('  • Documents Failed:               $failedCount');
    _stdout.writeln('  • Documents Not Attempted:        $notAttemptedCount');
    _stdout.writeln('  • Documents Overwritten:          0 (Strictly Impossible)');
    _stdout.writeln('  • Documents Deleted:              0 (Strictly Untouched)');
    _stdout.writeln('  • Changes to "users":             0 (Strictly Untouched)');
    _stdout.writeln('  • Changes to "faults":            0 (Strictly Untouched)');
    _stdout.writeln('---------------------------------------------------------------');
    _stdout.writeln('Per-Document Audit:');
    for (final id in kApprovedMachineIds) {
      final rec = records[id];
      if (rec != null) {
        final outcomeTag = rec.outcome.name.toUpperCase().padRight(14);
        _stdout.writeln('  • [$id] $outcomeTag : ${rec.reason}');
      }
    }
    _stdout.writeln('===============================================================');
  }
}

class _InternalWriteResult {
  final DocumentOutcome outcome;
  final String reason;

  _InternalWriteResult({required this.outcome, required this.reason});
}

class MigrationAuthException implements Exception {
  final String message;
  const MigrationAuthException(this.message);
  @override
  String toString() => message;
}

class MigrationPermissionException implements Exception {
  final String message;
  const MigrationPermissionException(this.message);
  @override
  String toString() => message;
}

class MigrationHttpException implements Exception {
  final int statusCode;
  final String message;
  const MigrationHttpException({required this.statusCode, required this.message});
  @override
  String toString() => message;
}

List<String> validateMachineSchema(String id, Map<String, dynamic>? fields) {
  if (fields == null || fields.isEmpty) {
    return ['Document is missing or has empty fields map'];
  }

  final errors = <String>[];

  // 1. name: stringValue
  final name = fields['name']?['stringValue'];
  if (name is! String || name.trim().isEmpty) {
    errors.add('Field "name" is missing or not a valid stringValue');
  }

  // 2. productionLine: stringValue
  final productionLine = fields['productionLine']?['stringValue'];
  if (productionLine is! String || productionLine.trim().isEmpty) {
    errors.add('Field "productionLine" is missing or not a valid stringValue');
  }

  // 3. modelNumber: stringValue
  final modelNumber = fields['modelNumber']?['stringValue'];
  if (modelNumber is! String || modelNumber.trim().isEmpty) {
    errors.add('Field "modelNumber" is missing or not a valid stringValue');
  }

  // 4. status: stringValue (one of 4 recognized statuses)
  final status = fields['status']?['stringValue'];
  const recognizedStatuses = [
    'Operational',
    'Warning',
    'Critical',
    'Under Maintenance',
  ];
  if (status is! String || !recognizedStatuses.contains(status.trim())) {
    errors.add('Field "status" ("$status") is missing or not in recognized statuses $recognizedStatuses');
  }

  // 5. healthScore: doubleValue or integerValue (0.0 to 100.0)
  final healthScoreDouble = fields['healthScore']?['doubleValue'];
  final healthScoreInt = fields['healthScore']?['integerValue'];
  num? healthScore;
  if (healthScoreDouble is num) {
    healthScore = healthScoreDouble;
  } else if (healthScoreInt is String) {
    healthScore = num.tryParse(healthScoreInt);
  } else if (healthScoreInt is num) {
    healthScore = healthScoreInt;
  }
  if (healthScore == null || healthScore < 0.0 || healthScore > 100.0) {
    errors.add('Field "healthScore" is missing or not a valid number in [0.0, 100.0]');
  }

  // 6. temperature: doubleValue or integerValue
  final tempDouble = fields['temperature']?['doubleValue'];
  final tempInt = fields['temperature']?['integerValue'];
  num? temperature;
  if (tempDouble is num) {
    temperature = tempDouble;
  } else if (tempInt is String) {
    temperature = num.tryParse(tempInt);
  } else if (tempInt is num) {
    temperature = tempInt;
  }
  if (temperature == null) {
    errors.add('Field "temperature" is missing or not a valid numeric value');
  }

  // 7. vibration: doubleValue or integerValue
  final vibDouble = fields['vibration']?['doubleValue'];
  final vibInt = fields['vibration']?['integerValue'];
  num? vibration;
  if (vibDouble is num) {
    vibration = vibDouble;
  } else if (vibInt is String) {
    vibration = num.tryParse(vibInt);
  } else if (vibInt is num) {
    vibration = vibInt;
  }
  if (vibration == null) {
    errors.add('Field "vibration" is missing or not a valid numeric value');
  }

  // 8. lastInspection: timestampValue (valid ISO 8601 string)
  final lastInspection = fields['lastInspection']?['timestampValue'];
  DateTime? parsedInspection;
  if (lastInspection is String) {
    parsedInspection = DateTime.tryParse(lastInspection);
  }
  if (parsedInspection == null) {
    errors.add('Field "lastInspection" is missing or not a valid RFC3339 timestampValue');
  }

  // Secondary canonical timestamps: createdAt & updatedAt
  final createdAt = fields['createdAt']?['timestampValue'];
  DateTime? parsedCreatedAt;
  if (createdAt is String) {
    parsedCreatedAt = DateTime.tryParse(createdAt);
  }
  if (parsedCreatedAt == null) {
    errors.add('Field "createdAt" is missing or not a valid RFC3339 timestampValue');
  }

  final updatedAt = fields['updatedAt']?['timestampValue'];
  DateTime? parsedUpdatedAt;
  if (updatedAt is String) {
    parsedUpdatedAt = DateTime.tryParse(updatedAt);
  }
  if (parsedUpdatedAt == null) {
    errors.add('Field "updatedAt" is missing or not a valid RFC3339 timestampValue');
  }

  return errors;
}

Future<String?> _getFirebaseCliAccessToken() async {
  try {
    final home = Platform.environment['HOME'] ?? '';
    final configPath = '$home/.config/configstore/firebase-tools.json';
    final file = File(configPath);
    if (!await file.exists()) {
      return null;
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final tokens = json['tokens'] as Map<String, dynamic>?;
    return tokens?['access_token'] as String?;
  } catch (_) {
    return null;
  }
}
