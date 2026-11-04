// ignore_for_file: subtype_of_sealed_class

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/faults/my_reports_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  FakeUser({required this.uid, this.email, this.displayName});
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  FakeFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  void setCurrentUser(User? user) {
    _currentUser = user;
  }

  @override
  Stream<User?> authStateChanges() => Stream.value(_currentUser);
}

class MockStorageService extends Fake implements StorageService {
  @override
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) async {
    return 'https://signed.supabase.co/storage/v1/object/sign/fault-images/$path?token=valid';
  }
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakeFirebaseAuth fakeAuth;
  late FaultService faultService;
  late StorageService storageService;

  late FaultModel operatorFaultOpen;
  late FaultModel operatorFaultInProgress;
  late FaultModel operatorFaultResolved;
  late FaultModel foreignOperatorFault;

  const currentOperatorUid = 'op_current_user_777';
  const foreignOperatorUid = 'op_foreign_user_888';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth(
      initialUser: FakeUser(
        uid: currentOperatorUid,
        email: 'operator@machalert.com',
        displayName: 'John Operator',
      ),
    );

    faultService = FaultService(
      firestore: fakeFirestore,
      firebaseAuth: fakeAuth,
    );
    storageService = MockStorageService();

    operatorFaultOpen = FaultModel(
      id: 'OP-FLT-001',
      machineId: 'MCH-01',
      machineName: 'CNC Milling Center',
      type: 'Mechanical',
      severity: 'Critical',
      status: 'Open',
      description: 'Main spindle vibrating excessively',
      reportedBy: currentOperatorUid,
      reportedByName: 'John Operator',
      storagePath: '$currentOperatorUid/spindle.jpg',
      storageProvider: 'supabase',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    );

    operatorFaultInProgress = FaultModel(
      id: 'OP-FLT-002',
      machineId: 'MCH-02',
      machineName: 'Hydraulic Press',
      type: 'Hydraulic',
      severity: 'High',
      status: 'In Progress',
      description: 'Slow cylinder pressure build-up',
      reportedBy: currentOperatorUid,
      reportedByName: 'John Operator',
      createdAt: DateTime.now().subtract(const Duration(hours: 10)),
    );

    operatorFaultResolved = FaultModel(
      id: 'OP-FLT-003',
      machineId: 'MCH-01',
      machineName: 'CNC Milling Center',
      type: 'Electrical',
      severity: 'Low',
      status: 'Resolved',
      description: 'Sensor cable zip-tied',
      reportedBy: currentOperatorUid,
      reportedByName: 'John Operator',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

    foreignOperatorFault = FaultModel(
      id: 'FOREIGN-FLT-999',
      machineId: 'MCH-03',
      machineName: 'Conveyor Unit',
      type: 'Mechanical',
      severity: 'High',
      status: 'Open',
      description: 'Roller belt slipping',
      reportedBy: foreignOperatorUid,
      reportedByName: 'Alice Foreign',
      storagePath: '$foreignOperatorUid/roller.jpg',
      storageProvider: 'supabase',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    await fakeFirestore.collection('faults').doc(operatorFaultOpen.id).set(operatorFaultOpen.toFirestoreMap());
    await fakeFirestore.collection('faults').doc(operatorFaultInProgress.id).set(operatorFaultInProgress.toFirestoreMap());
    await fakeFirestore.collection('faults').doc(operatorFaultResolved.id).set(operatorFaultResolved.toFirestoreMap());
    await fakeFirestore.collection('faults').doc(foreignOperatorFault.id).set(foreignOperatorFault.toFirestoreMap());
  });

  Widget buildMyReportsScreen() {
    return MaterialApp(
      home: MyReportsScreen(
        faultService: faultService,
        storageService: storageService,
        firebaseAuth: fakeAuth,
      ),
    );
  }

  testWidgets(
    'My Reports displays only reports submitted by the authenticated operator',
    (tester) async {
      await tester.pumpWidget(buildMyReportsScreen());
      await tester.pumpAndSettle();

      // Authenticated operator's faults are visible
      expect(find.text('CNC Milling Center'), findsWidgets);
      expect(find.text('Hydraulic Press'), findsOneWidget);
      expect(find.text('Main spindle vibrating excessively'), findsOneWidget);
      expect(find.text('Slow cylinder pressure build-up'), findsOneWidget);
      expect(find.text('Sensor cable zip-tied'), findsOneWidget);

      // Foreign operator's report is NEVER visible in My Reports
      expect(find.text('Conveyor Unit'), findsNothing);
      expect(find.text('Roller belt slipping'), findsNothing);
      expect(find.text('Alice Foreign'), findsNothing);
    },
  );

  testWidgets(
    'Filter chips filter faults by status accurately',
    (tester) async {
      await tester.pumpWidget(buildMyReportsScreen());
      await tester.pumpAndSettle();

      // Initially 'All' is selected: all 3 reports present
      expect(find.text('Main spindle vibrating excessively'), findsOneWidget);
      expect(find.text('Slow cylinder pressure build-up'), findsOneWidget);
      expect(find.text('Sensor cable zip-tied'), findsOneWidget);

      // Filter by 'Open'
      await tester.tap(find.byKey(const ValueKey('filter-chip-Open')));
      await tester.pumpAndSettle();

      expect(find.text('Main spindle vibrating excessively'), findsOneWidget);
      expect(find.text('Slow cylinder pressure build-up'), findsNothing);
      expect(find.text('Sensor cable zip-tied'), findsNothing);

      // Filter by 'In Progress'
      await tester.tap(find.byKey(const ValueKey('filter-chip-In Progress')));
      await tester.pumpAndSettle();

      expect(find.text('Main spindle vibrating excessively'), findsNothing);
      expect(find.text('Slow cylinder pressure build-up'), findsOneWidget);
      expect(find.text('Sensor cable zip-tied'), findsNothing);

      // Filter by 'Resolved'
      await tester.tap(find.byKey(const ValueKey('filter-chip-Resolved')));
      await tester.pumpAndSettle();

      expect(find.text('Main spindle vibrating excessively'), findsNothing);
      expect(find.text('Slow cylinder pressure build-up'), findsNothing);
      expect(find.text('Sensor cable zip-tied'), findsOneWidget);
    },
  );

  testWidgets(
    'Fault cards show machine name, machine ID, description, severity, status, and reporter name',
    (tester) async {
      await tester.pumpWidget(buildMyReportsScreen());
      await tester.pumpAndSettle();

      expect(find.text('CNC Milling Center'), findsWidgets);
      expect(find.text('Machine ID: MCH-01'), findsWidgets);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Open'), findsWidgets);
      expect(find.text('By John Operator'), findsWidgets);
      expect(find.text('Main spindle vibrating excessively'), findsOneWidget);
    },
  );

  testWidgets(
    'Attached photo dialog opens and retrieves signed URL for operator report',
    (tester) async {
      await tester.pumpWidget(buildMyReportsScreen());
      await tester.pumpAndSettle();

      // Photo button appears for fault with image
      final photoBtn = find.byKey(ValueKey('view-photo-btn-${operatorFaultOpen.id}'));
      expect(photoBtn, findsOneWidget);

      await tester.tap(photoBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      // Dialog opens with image preview
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('CNC Milling Center'), findsWidgets);
    },
  );

  testWidgets(
    'Dashboard My Reports action card navigates to MyReportsScreen',
    (tester) async {
      final operatorUser = UserModel(
        id: currentOperatorUid,
        name: 'John Operator',
        email: 'operator@machalert.com',
        role: AppConstants.roleOperator,
      );

      final authService = AuthService(firebaseAuth: fakeAuth);
      final appStateProvider = AppStateProvider()
        ..setAuthenticated(operatorUser);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appStateProvider),
            Provider<AuthService>.value(value: authService),
            Provider<FaultService>.value(value: faultService),
            Provider<FirebaseAuth>.value(value: fakeAuth),
          ],
          child: MaterialApp(
            home: const HomeScreen(),
            routes: {
              '/faults/my_reports': (_) => MyReportsScreen(
                faultService: faultService,
                firebaseAuth: fakeAuth,
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find My Reports action card on Operator Dashboard
      final myReportsCard = find.text('My Reports');
      expect(myReportsCard, findsOneWidget);

      await tester.tap(myReportsCard);
      await tester.pumpAndSettle();

      // Verifies navigation to MyReportsScreen
      expect(find.byType(MyReportsScreen), findsOneWidget);
    },
  );
}
