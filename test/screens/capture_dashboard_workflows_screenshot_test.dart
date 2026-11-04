// ignore_for_file: subtype_of_sealed_class

import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/faults/my_reports_screen.dart';
import 'package:mach_alert/screens/maintenance/maintenance_task_form_screen.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

class _FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? displayName;

  _FakeUser({required this.uid, this.displayName});
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;
  _FakeFirebaseAuth(this._user);

  @override
  User? get currentUser => _user;
}

class _FakeFaultService extends Fake implements FaultService {
  final List<FaultModel> faults;
  _FakeFaultService(this.faults);

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) async {
    return faults.where((f) {
      if (machineId != null && f.machineId != machineId) return false;
      if (reportedBy != null && f.reportedBy != reportedBy) return false;
      return true;
    }).toList();
  }

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) {
    return Stream.value(faults);
  }

  @override
  Future<String?> getFaultImageUrl(
    FaultModel fault, {
    StorageService? storageService,
    int expiresInSeconds = 3600,
    String? callerRole,
    String? callerUid,
  }) async {
    return 'https://supabase.machalert.local/fault-images/${fault.storagePath}';
  }
}

void main() {
  const artifactDir = '/Users/jatinkashyap/.gemini/antigravity/brain/2f4c9bae-798d-4c78-aed7-38b045c27798';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Load Arial as Roboto
    final fontFile = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (fontFile.existsSync()) {
      final fontBytes = fontFile.readAsBytesSync();
      final fontLoader = FontLoader('Roboto');
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();
    }

    // Load MaterialIcons
    final iconFile = File('/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final iconBytes = iconFile.readAsBytesSync();
      final iconLoader = FontLoader('MaterialIcons');
      iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await iconLoader.load();
    }
  });

  testWidgets('Capture My Reports Screen Screenshot', (tester) async {
    tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintKey = GlobalKey();
    const currentUid = 'op-jatin-001';

    final now = DateTime.now();
    final myFaults = [
      FaultModel(
        id: 'FLT-001',
        machineId: 'MCH-CNC-01',
        machineName: '5-Axis CNC Milling Center',
        type: 'Mechanical',
        severity: 'Critical',
        status: 'Open',
        description: 'Main spindle bearing vibration alarm triggered during finish pass. High-frequency humming detected.',
        reportedBy: currentUid,
        reportedByName: 'Jatin Kashyap',
        storagePath: '$currentUid/spindle_bearing.jpg',
        storageProvider: 'supabase',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      FaultModel(
        id: 'FLT-002',
        machineId: 'MCH-HYD-04',
        machineName: 'Hydraulic Press 50T',
        type: 'Hydraulic',
        severity: 'High',
        status: 'In Progress',
        description: 'Slow pressure build-up on main ram cylinder. Valve seal inspection in progress by technician.',
        reportedBy: currentUid,
        reportedByName: 'Jatin Kashyap',
        storagePath: '$currentUid/valve_seal.jpg',
        storageProvider: 'supabase',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      FaultModel(
        id: 'FLT-003',
        machineId: 'MCH-ROB-02',
        machineName: 'Robotic Pick & Place Cell',
        type: 'Electrical',
        severity: 'Medium',
        status: 'Resolved',
        description: 'Gripper optical sensor calibration required after product size changeover. Sensor re-aligned.',
        reportedBy: currentUid,
        reportedByName: 'Jatin Kashyap',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];

    final fakeService = _FakeFaultService(myFaults);
    final operatorUser = UserModel(
      id: currentUid,
      name: 'Jatin Kashyap',
      email: 'jatin@machalert.com',
      role: AppConstants.roleOperator,
    );

    final appState = AppStateProvider()..setAuthenticated(operatorUser);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppStateProvider>.value(value: appState),
          Provider<FaultService>.value(value: fakeService),
        ],
        child: MaterialApp(
          theme: AppTheme.light.copyWith(
          textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
        ),
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: repaintKey,
            child: MyReportsScreen(
              faultService: fakeService,
              firebaseAuth: _FakeFirebaseAuth(
                _FakeUser(uid: currentUid, displayName: 'Jatin Kashyap'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('$artifactDir/my_reports_screen.png');
      await file.writeAsBytes(bytes);
    });
  });

  testWidgets('Capture Maintenance Task Form Screen with Fault Dropdown Screenshot', (tester) async {
    tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repaintKey = GlobalKey();

    final machine1 = MachineModel(
      id: 'MCH-CNC-01',
      name: '5-Axis CNC Milling Center',
      productionLine: 'Bay 3 - Machining',
      status: AppConstants.machineStatusOperational,
      healthScore: 92.0,
    );
    final machine2 = MachineModel(
      id: 'MCH-HYD-04',
      name: 'Hydraulic Press 50T',
      productionLine: 'Bay 1 - Stamping',
      status: AppConstants.machineStatusWarning,
      healthScore: 78.0,
    );

    final tech1 = UserModel(
      id: 'usr-tech-01',
      name: 'Marcus Vance',
      email: 'marcus@machalert.com',
      role: AppConstants.roleTechnician,
    );
    final tech2 = UserModel(
      id: 'usr-tech-02',
      name: 'Elena Rostova',
      email: 'elena@machalert.com',
      role: AppConstants.roleTechnician,
    );

    final fault1 = FaultModel(
      id: 'FLT-001',
      machineId: 'MCH-CNC-01',
      machineName: '5-Axis CNC Milling Center',
      type: 'Mechanical',
      severity: 'Critical',
      status: 'Open',
      description: 'Spindle vibration alarm triggered',
      reportedBy: 'op-001',
      createdAt: DateTime.now(),
    );

    final fakeService = _FakeFaultService([fault1]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light.copyWith(
          textTheme: AppTheme.light.textTheme.apply(fontFamily: 'Roboto'),
        ),
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: repaintKey,
          child: MaintenanceTaskFormScreen(
            faultService: fakeService,
            initialMachines: [machine1, machine2],
            initialTechnicians: [tech1, tech2],
            initialFaults: [fault1],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Select Machine 1
    await tester.tap(find.byKey(const ValueKey('maintenance-machine-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5-Axis CNC Milling Center (MCH-CNC-01)').last);
    await tester.pumpAndSettle();

    // Select Technician 1
    await tester.tap(find.byKey(const ValueKey('maintenance-technician-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcus Vance').last);
    await tester.pumpAndSettle();

    // Select Linked Fault
    await tester.tap(find.byKey(const ValueKey('maintenance-fault-id-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Spindle vibration alarm triggered').last);
    await tester.pumpAndSettle();

    // Enter notes
    await tester.enterText(
      find.byKey(const ValueKey('maintenance-notes-field')),
      'Perform urgent replacement of ceramic spindle bearing and calibrate dynamic runout prior to resuming production.',
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('$artifactDir/maintenance_task_form_screen.png');
      await file.writeAsBytes(bytes);
    });
  });
}
