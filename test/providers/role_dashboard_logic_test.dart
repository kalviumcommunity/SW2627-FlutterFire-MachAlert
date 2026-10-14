import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/services/user_service.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  FakeUser({required this.uid, this.email, this.displayName});
}

Future<void> flushEvents() async {
  await pumpEventQueue(times: 20);
}

void main() {
  group('Role based dashboard logic', () {
    test('loads operator role from Firestore after authentication', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('users').doc('operator-1').set({
        'uid': 'operator-1',
        'displayName': 'Operator One',
        'email': 'operator@machalert.com',
        'role': 'operator',
      });

      final userService = UserService(firestore: firestore);

      final authController = StreamController<User?>.broadcast();

      final provider = AppStateProvider(
        authStream: authController.stream,
        userService: userService,
      );

      addTearDown(() async {
        provider.dispose();
        await authController.close();
      });

      authController.add(
        FakeUser(uid: 'operator-1', email: 'operator@machalert.com'),
      );

      await flushEvents();

      expect(provider.status, AppStatus.authenticated);

      expect(provider.user?.role, 'operator');

      expect(provider.user?.name, 'Operator One');
    });

    test('updates dashboard role when Firestore profile changes', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('users').doc('worker-1').set({
        'uid': 'worker-1',
        'displayName': 'Worker',
        'email': 'worker@machalert.com',
        'role': 'operator',
      });

      final userService = UserService(firestore: firestore);

      final authController = StreamController<User?>.broadcast();

      final provider = AppStateProvider(
        authStream: authController.stream,
        userService: userService,
      );

      addTearDown(() async {
        provider.dispose();
        await authController.close();
      });

      authController.add(
        FakeUser(uid: 'worker-1', email: 'worker@machalert.com'),
      );

      await flushEvents();

      expect(provider.user?.role, 'operator');

      await firestore.collection('users').doc('worker-1').update({
        'role': 'technician',
      });

      await flushEvents();

      expect(provider.user?.role, 'technician');
    });

    test('missing Firestore profile keeps safe unresolved role', () async {
      final firestore = FakeFirebaseFirestore();

      final userService = UserService(firestore: firestore);

      final authController = StreamController<User?>.broadcast();

      final provider = AppStateProvider(
        authStream: authController.stream,
        userService: userService,
      );

      addTearDown(() async {
        provider.dispose();
        await authController.close();
      });

      authController.add(
        FakeUser(uid: 'missing-user', email: 'missing@machalert.com'),
      );

      await flushEvents();

      expect(provider.status, AppStatus.authenticated);

      expect(provider.user?.role, '');
    });

    test('sign out clears role and user profile', () async {
      final firestore = FakeFirebaseFirestore();

      await firestore.collection('users').doc('manager-1').set({
        'uid': 'manager-1',
        'displayName': 'Manager',
        'email': 'manager@machalert.com',
        'role': 'manager',
      });

      final userService = UserService(firestore: firestore);

      final authController = StreamController<User?>.broadcast();

      final provider = AppStateProvider(
        authStream: authController.stream,
        userService: userService,
      );

      addTearDown(() async {
        provider.dispose();
        await authController.close();
      });

      authController.add(
        FakeUser(uid: 'manager-1', email: 'manager@machalert.com'),
      );

      await flushEvents();

      expect(provider.user?.role, 'manager');

      authController.add(null);

      await flushEvents();

      expect(provider.status, AppStatus.unauthenticated);

      expect(provider.user, isNull);
    });
  });
}
