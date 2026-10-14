// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Login screen displays email and password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Login password visibility toggles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    TextField field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.obscureText, isTrue);

    await tester.tap(find.text('Show Password'));
    await tester.pump();

    field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.obscureText, isFalse);
  });

  testWidgets('Signup screen displays all fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  testWidgets('Signup submit button is enabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sign Up'),
    );

    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'Signup provisions user profile in Firestore when UserService is provided',
    (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      final fakeUser = _FakeAuthUser(
        uid: 'new_signup_uid',
        email: 'signup@test.com',
      );
      final authService = _MockAuthService(user: fakeUser);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: authService),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Dev Patel',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'dev@test.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'secure123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'secure123',
      );
      await tester.pump();

      final submitButton = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();

      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      final doc = await fakeFirestore
          .collection('users')
          .doc('new_signup_uid')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], 'Dev Patel');
      expect(doc.data()!['role'], AppConstants.roleOperator);
    },
  );

  testWidgets('Signup surfaces profile creation error safely in SnackBar', (
    tester,
  ) async {
    final errorFirestore = _FakeErrorFirestore(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Network offline',
      ),
    );
    final errorService = UserService(firestore: errorFirestore);

    final fakeUser = _FakeAuthUser(
      uid: 'failing_user_uid',
      email: 'fail@test.com',
    );
    final authService = _MockAuthService(user: fakeUser);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: authService),
          Provider<UserService>.value(value: errorService),
        ],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'Dev Patel',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'dev@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secure123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm Password'),
      'secure123',
    );
    await tester.pump();

    final submitButton = find.widgetWithText(ElevatedButton, 'Sign Up');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Account created, but could not set up user profile'),
      findsOneWidget,
    );
  });
}

class _FakeAuthUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  _FakeAuthUser({required this.uid, this.email});

  @override
  Future<void> updateDisplayName(String? displayName) async {}
}

class _FakeCredential extends Fake implements UserCredential {
  @override
  final User? user;

  _FakeCredential({this.user});
}

class _MockAuthService extends Fake implements AuthService {
  final User? user;

  _MockAuthService({this.user});

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return _FakeCredential(user: user);
  }
}

class _FakeErrorDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final FirebaseException exception;

  _FakeErrorDocumentReference(this.exception);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    throw exception;
  }
}

class _FakeErrorCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final FirebaseException exception;

  _FakeErrorCollectionReference(this.exception);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _FakeErrorDocumentReference(exception);
  }
}

class _FakeErrorFirestore extends Fake implements FirebaseFirestore {
  final FirebaseException exception;

  _FakeErrorFirestore(this.exception);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeErrorCollectionReference(exception);
  }
}
