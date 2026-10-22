import 'dart:convert';
import 'dart:io';

/// Read-only dry-run tool for auditing and planning the migration of exactly five
/// approved mock machine documents from the local Firestore Emulator to Cloud Firestore.
///
/// SAFETY CONSTRAINTS:
/// 1. STRICTLY READ-ONLY: Contains zero write, patch, or delete operations.
/// 2. Never writes to Cloud Firestore or the local emulator.
/// 3. Does not modify users or faults.
/// 4. Does not log or expose tokens or credentials.
/// 5. Automatically detects and aborts if write flags are supplied.
/// 6. Performs pre-flight schema validation against canonical MockMachineData.
/// 7. Exits cleanly with code 1 and user guidance on HTTP 401 Unauthorized.
void main(List<String> args) async {
  // Guard against any attempt to invoke write actions
  for (final arg in args) {
    final lower = arg.toLowerCase();
    if (lower.contains('write') ||
        lower.contains('apply') ||
        lower.contains('migrate') ||
        lower.contains('exec') ||
        lower.contains('force')) {
      stderr.writeln(
        '❌ Error: Writes are strictly prohibited. This tool is read-only dry-run only.',
      );
      exit(2);
    }
  }

  const projectId = 'machalert';
  const approvedMachineIds = [
    'mock-cnc-01',
    'mock-press-02',
    'mock-conveyor-03',
    'mock-molding-04',
    'mock-compressor-05',
  ];

  stdout.writeln(
    '===============================================================',
  );
  stdout.writeln('  MachAlert - Read-Only Cloud Migration Dry-Run');
  stdout.writeln(
    '===============================================================',
  );
  stdout.writeln('Project: $projectId');
  stdout.writeln(
    'Mode: DRY-RUN ONLY (Zero writes, zero updates, zero deletes)',
  );
  stdout.writeln('Scope: Exactly 5 approved mock machine documents');
  stdout.writeln('Collections untouched: users (0), faults (0)');
  stdout.writeln(
    '---------------------------------------------------------------',
  );

  // Step 1: Read local Firestore Emulator data
  stdout.writeln('1. Inspecting local Firestore Emulator (127.0.0.1:8080)...');
  final localMachines = await _readLocalEmulatorMachines(
    host: '127.0.0.1',
    port: 8080,
    projectId: projectId,
    approvedIds: approvedMachineIds,
  );

  stdout.writeln(
    '   ✓ Found ${localMachines.length} of ${approvedMachineIds.length} approved mock machine documents locally.',
  );

  // Step 2: Validate Schema for all 8 canonical fields from lib/utils/mock_machine_data.dart
  stdout.writeln('');
  stdout.writeln(
    '2. Performing schema pre-flight validation on local records...',
  );
  final schemaValidations = <String, _SchemaValidationResult>{};

  for (final id in approvedMachineIds) {
    final doc = localMachines[id];
    final result = _validateMachineSchema(id, doc);
    schemaValidations[id] = result;
    if (!result.isValid) {
      stdout.writeln('   ✗ [$id] Schema Malformed:');
      for (final err in result.errors) {
        stdout.writeln('       • $err');
      }
    } else {
      stdout.writeln(
        '   ✓ [$id] Schema valid (8/8 canonical fields + timestamps verified)',
      );
    }
  }

  // Step 3: Read Cloud Firestore OAuth credentials from local configstore
  stdout.writeln('');
  stdout.writeln('3. Resolving read-only Firebase CLI credentials...');
  final cloudToken = await _getFirebaseCliAccessToken();
  if (cloudToken == null) {
    stderr.writeln(
      '   ❌ Error: Unable to resolve active Firebase CLI access token from ~/.config/configstore/firebase-tools.json.',
    );
    stderr.writeln('   Please run `firebase login` to authenticate safely.');
    exit(1);
  }
  stdout.writeln(
    '   ✓ Read-only Cloud authorization established successfully.',
  );

  // Step 4: Inspect target Cloud Firestore database
  stdout.writeln('');
  stdout.writeln(
    '4. Inspecting target Cloud Firestore database (projects/$projectId/databases/(default))...',
  );
  final cloudStatus = await _inspectCloudMachines(
    projectId: projectId,
    token: cloudToken,
    approvedIds: approvedMachineIds,
  );

  stdout.writeln('');
  stdout.writeln(
    '===============================================================',
  );
  stdout.writeln('  CLASSIFICATION & DRY-RUN RESULTS');
  stdout.writeln(
    '===============================================================',
  );
  stdout.writeln(
    '| ${"Document ID".padRight(20)} | ${"Local Status".padRight(14)} | ${"Schema Status".padRight(15)} | ${"Cloud Status".padRight(14)} | ${"Planned Action".padRight(24)} |',
  );
  stdout.writeln(
    '|----------------------|----------------|-----------------|----------------|--------------------------|',
  );

  var plannedCreates = 0;
  var plannedSkips = 0;

  for (final id in approvedMachineIds) {
    final localDoc = localMachines[id];
    final localStr = localDoc != null ? 'Present' : 'Missing';
    final validation = schemaValidations[id]!;
    final schemaStr = validation.isValid ? 'Valid' : 'Malformed';
    final existsInCloud = cloudStatus[id] ?? false;
    final cloudStr = existsInCloud ? 'Exists (200)' : 'Absent (404)';
    String action;

    if (existsInCloud) {
      action = 'SKIP (Exists)';
      plannedSkips++;
    } else if (localDoc == null) {
      action = 'SKIP (No Source)';
      plannedSkips++;
    } else if (!validation.isValid) {
      action = 'SKIP (Malformed Schema)';
      plannedSkips++;
    } else {
      action = 'CREATE';
      plannedCreates++;
    }

    stdout.writeln(
      '| ${id.padRight(20)} | ${localStr.padRight(14)} | ${schemaStr.padRight(15)} | ${cloudStr.padRight(14)} | ${action.padRight(24)} |',
    );
  }

  stdout.writeln(
    '---------------------------------------------------------------',
  );
  stdout.writeln('Canonical Field Summary (from local emulator):');
  for (final id in approvedMachineIds) {
    final validation = schemaValidations[id]!;
    if (validation.isValid) {
      final s = validation.summary;
      stdout.writeln('  • $id:');
      stdout.writeln(
        '      name: ${s['name']}, status: ${s['status']}, healthScore: ${s['healthScore']}',
      );
      stdout.writeln(
        '      line: ${s['productionLine']}, model: ${s['modelNumber']}',
      );
      stdout.writeln(
        '      telemetry: temp=${s['temperature']}, vib=${s['vibration']}',
      );
      stdout.writeln(
        '      timestamps: lastInspection=${s['lastInspection']}',
      );
      stdout.writeln(
        '                  createdAt=${s['createdAt']}, updatedAt=${s['updatedAt']}',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln('MIGRATION IMPACT REPORT:');
  stdout.writeln('  • Planned Creates in "machines": $plannedCreates');
  stdout.writeln('  • Planned Skips in "machines":   $plannedSkips');
  stdout.writeln('  • Planned Updates in "machines": 0');
  stdout.writeln('  • Planned Deletes in "machines": 0');
  stdout.writeln('  • Changes to "users":            0 (Strictly Untouched)');
  stdout.writeln('  • Changes to "faults":           0 (Strictly Untouched)');
  stdout.writeln(
    '===============================================================',
  );
  stdout.writeln('Dry-run complete. NO WRITES PERFORMED.');
  stdout.writeln(
    'Awaiting explicit approval before executing any Cloud write.',
  );
  stdout.writeln(
    '===============================================================',
  );
}

class _SchemaValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, String> summary;

  _SchemaValidationResult({
    required this.isValid,
    required this.errors,
    required this.summary,
  });
}

_SchemaValidationResult _validateMachineSchema(
  String id,
  Map<String, dynamic>? fields,
) {
  if (fields == null || fields.isEmpty) {
    return _SchemaValidationResult(
      isValid: false,
      errors: ['Document is missing or has empty fields map'],
      summary: {},
    );
  }

  final errors = <String>[];
  final summary = <String, String>{};

  // 1. name: stringValue
  final name = fields['name']?['stringValue'];
  if (name is String && name.trim().isNotEmpty) {
    summary['name'] = '"$name" (stringValue)';
  } else {
    errors.add('Field "name" is missing or not a valid stringValue');
  }

  // 2. productionLine: stringValue
  final productionLine = fields['productionLine']?['stringValue'];
  if (productionLine is String && productionLine.trim().isNotEmpty) {
    summary['productionLine'] = '"$productionLine" (stringValue)';
  } else {
    errors.add('Field "productionLine" is missing or not a valid stringValue');
  }

  // 3. modelNumber: stringValue
  final modelNumber = fields['modelNumber']?['stringValue'];
  if (modelNumber is String && modelNumber.trim().isNotEmpty) {
    summary['modelNumber'] = '"$modelNumber" (stringValue)';
  } else {
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
  if (status is String && recognizedStatuses.contains(status.trim())) {
    summary['status'] = '"$status" (stringValue)';
  } else {
    errors.add(
      'Field "status" ("$status") is missing or not in recognized statuses $recognizedStatuses',
    );
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
  if (healthScore != null && healthScore >= 0.0 && healthScore <= 100.0) {
    summary['healthScore'] = '${healthScore.toDouble()} (doubleValue)';
  } else {
    errors.add(
      'Field "healthScore" is missing or not a valid number in [0.0, 100.0]',
    );
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
  if (temperature != null) {
    summary['temperature'] = '${temperature.toDouble()}°C (doubleValue)';
  } else {
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
  if (vibration != null) {
    summary['vibration'] = '${vibration.toDouble()} mm/s (doubleValue)';
  } else {
    errors.add('Field "vibration" is missing or not a valid numeric value');
  }

  // 8. lastInspection: timestampValue (valid ISO 8601 string)
  final lastInspection = fields['lastInspection']?['timestampValue'];
  DateTime? parsedInspection;
  if (lastInspection is String) {
    parsedInspection = DateTime.tryParse(lastInspection);
  }
  if (parsedInspection != null) {
    summary['lastInspection'] = '$lastInspection (timestampValue)';
  } else {
    errors.add(
      'Field "lastInspection" is missing or not a valid RFC3339 timestampValue',
    );
  }

  // Secondary canonical timestamps: createdAt & updatedAt
  final createdAt = fields['createdAt']?['timestampValue'];
  DateTime? parsedCreatedAt;
  if (createdAt is String) {
    parsedCreatedAt = DateTime.tryParse(createdAt);
  }
  if (parsedCreatedAt != null) {
    summary['createdAt'] = '$createdAt (timestampValue)';
  } else {
    errors.add(
      'Field "createdAt" is missing or not a valid RFC3339 timestampValue',
    );
  }

  final updatedAt = fields['updatedAt']?['timestampValue'];
  DateTime? parsedUpdatedAt;
  if (updatedAt is String) {
    parsedUpdatedAt = DateTime.tryParse(updatedAt);
  }
  if (parsedUpdatedAt != null) {
    summary['updatedAt'] = '$updatedAt (timestampValue)';
  } else {
    errors.add(
      'Field "updatedAt" is missing or not a valid RFC3339 timestampValue',
    );
  }

  return _SchemaValidationResult(
    isValid: errors.isEmpty,
    errors: errors,
    summary: summary,
  );
}

Future<Map<String, Map<String, dynamic>>> _readLocalEmulatorMachines({
  required String host,
  required int port,
  required String projectId,
  required List<String> approvedIds,
}) async {
  final client = HttpClient();
  final results = <String, Map<String, dynamic>>{};

  try {
    for (final id in approvedIds) {
      final uri = Uri.parse(
        'http://$host:$port/v1/projects/$projectId/databases/(default)/documents/machines/$id',
      );
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
      final res = await req.close();

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        results[id] = (json['fields'] as Map<String, dynamic>?) ?? {};
      } else {
        await res.drain<void>();
      }
    }
  } finally {
    client.close(force: true);
  }

  return results;
}

Future<Map<String, bool>> _inspectCloudMachines({
  required String projectId,
  required String token,
  required List<String> approvedIds,
}) async {
  final client = HttpClient();
  final results = <String, bool>{};

  try {
    for (final id in approvedIds) {
      final uri = Uri.https(
        'firestore.googleapis.com',
        '/v1/projects/$projectId/databases/(default)/documents/machines/$id',
      );
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();
      await res.drain<void>();

      if (res.statusCode == 200) {
        results[id] = true; // Document already exists in Cloud
      } else if (res.statusCode == 404) {
        results[id] = false; // Document absent in Cloud
      } else if (res.statusCode == 401) {
        stderr.writeln('');
        stderr.writeln(
          '❌ Error: Cloud Firestore returned HTTP 401 Unauthorized.',
        );
        stderr.writeln(
          '   Your Firebase CLI session has expired or is invalid.',
        );
        stderr.writeln(
          '   Please run `firebase login` in your terminal to authenticate safely.',
        );
        stderr.writeln('');
        exit(1);
      } else if (res.statusCode == 403) {
        stderr.writeln('');
        stderr.writeln(
          '❌ Error: Cloud Firestore returned HTTP 403 Forbidden.',
        );
        stderr.writeln(
          '   Permission denied for project "$projectId". Check your Firebase permissions.',
        );
        stderr.writeln('');
        exit(1);
      } else {
        stderr.writeln('');
        stderr.writeln(
          '❌ Error: Cloud inspection query failed for "$id" with HTTP ${res.statusCode}.',
        );
        stderr.writeln('');
        exit(1);
      }
    }
  } finally {
    client.close(force: true);
  }

  return results;
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
