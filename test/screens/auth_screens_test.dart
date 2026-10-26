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

  testWidgets('Login screen displays Google Sign-In button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.byKey(const Key('google_sign_in_button')), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
  });

  testWidgets('Login screen triggers Google Sign-In on tap', (tester) async {
    final fakeUser = _FakeAuthUser(
      uid: 'google_login_uid',
      email: 'googleuser@test.com',
      displayName: 'Google User',
    );
    final mockAuth = _MockAuthService(user: fakeUser);
    final fakeFirestore = FakeFirebaseFirestore();
    final userService = UserService(firestore: fakeFirestore);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: mockAuth),
          Provider<UserService>.value(value: userService),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    final googleButton = find.byKey(const Key('google_sign_in_button'));
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pumpAndSettle();

    expect(mockAuth.signInWithGoogleCalled, isTrue);

    final doc = await fakeFirestore
        .collection('users')
        .doc('google_login_uid')
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['role'], AppConstants.roleOperator);
    expect(doc.data()!['email'], 'googleuser@test.com');
    expect(doc.data()!['displayName'], 'Google User');
  });

  testWidgets(
    'Login screen does not overwrite existing Firestore profile for existing Google user',
    (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('users').doc('existing_login_user').set({
        'uid': 'existing_login_user',
        'userId': 'existing_login_user',
        'displayName': 'Existing Manager',
        'name': 'Existing Manager',
        'email': 'manager@test.com',
        'role': AppConstants.roleManager,
      });

      final fakeUser = _FakeAuthUser(
        uid: 'existing_login_user',
        email: 'manager@test.com',
        displayName: 'Existing Manager',
      );
      final mockAuth = _MockAuthService(user: fakeUser);
      final userService = UserService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_in_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);

      final doc = await fakeFirestore
          .collection('users')
          .doc('existing_login_user')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], 'Existing Manager');
      expect(doc.data()!['role'], AppConstants.roleManager);
    },
  );

  testWidgets(
    'Login screen creates Firestore profile even when unmounted during Google Sign-In',
    (tester) async {
      final fakeUser = _FakeAuthUser(
        uid: 'unmounted_login_user',
        email: 'unmounted@test.com',
        displayName: 'Unmounted Login User',
      );
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      late StateSetter parentSetState;
      bool showLogin = true;

      final mockAuth = _MockAuthService(
        user: fakeUser,
        onSignInWithGoogle: () {
          // Simulate AuthGate switching screens upon authStateChanges event:
          parentSetState(() {
            showLogin = false;
          });
        },
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                return showLogin
                    ? const LoginScreen()
                    : const Scaffold(body: Text('Home Dashboard'));
              },
            ),
          ),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_in_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);
      expect(find.text('Home Dashboard'), findsOneWidget);

      final doc = await fakeFirestore
          .collection('users')
          .doc('unmounted_login_user')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['email'], 'unmounted@test.com');
      expect(doc.data()!['role'], AppConstants.roleOperator);
    },
  );

  testWidgets(
    'Login screen displays error snackbar when Google Sign-In fails',
    (tester) async {
      final mockAuth = _MockAuthService();
      mockAuth.googleErrorToThrow = AuthServiceException(
        code: 'google-sign-in-failed',
        message: 'Google Sign-In failed. Please try again.',
      );
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_in_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);
      expect(
        find.text('Google Sign-In failed. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Login screen handles cancelled Google Sign-In without error snackbar',
    (tester) async {
      final mockAuth = _MockAuthService();
      mockAuth.returnNullOnGoogleSignIn = true;
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_in_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

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

  testWidgets('Signup screen displays Google Sign-Up button and OR divider', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(find.text('Sign up with Google'), findsOneWidget);
    expect(find.byKey(const Key('google_sign_up_button')), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
  });

  testWidgets(
    'Signup screen triggers Google Sign-In and provisions new user profile in Firestore',
    (tester) async {
      final fakeUser = _FakeAuthUser(
        uid: 'google_signup_user_1',
        email: 'googlesignup@test.com',
        displayName: 'Google Newbie',
      );
      final mockAuth = _MockAuthService(user: fakeUser);
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_up_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);

      final doc = await fakeFirestore
          .collection('users')
          .doc('google_signup_user_1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], 'Google Newbie');
      expect(doc.data()!['email'], 'googlesignup@test.com');
      expect(doc.data()!['role'], AppConstants.roleOperator);
    },
  );

  testWidgets(
    'Signup screen does not overwrite existing Firestore profile for existing Google user',
    (tester) async {
      final fakeFirestore = FakeFirebaseFirestore();
      await fakeFirestore.collection('users').doc('existing_google_user').set({
        'uid': 'existing_google_user',
        'userId': 'existing_google_user',
        'displayName': 'Senior Technician',
        'name': 'Senior Technician',
        'email': 'senior@test.com',
        'role': AppConstants.roleTechnician,
      });

      final fakeUser = _FakeAuthUser(
        uid: 'existing_google_user',
        email: 'senior@test.com',
        displayName: 'Senior Technician',
      );
      final mockAuth = _MockAuthService(user: fakeUser);
      final userService = UserService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_up_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);

      final doc = await fakeFirestore
          .collection('users')
          .doc('existing_google_user')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['displayName'], 'Senior Technician');
      expect(doc.data()!['role'], AppConstants.roleTechnician);
    },
  );

  testWidgets(
    'Signup screen displays error snackbar when Google Sign-In fails',
    (tester) async {
      final mockAuth = _MockAuthService();
      mockAuth.googleErrorToThrow = AuthServiceException(
        code: 'google-sign-in-failed',
        message: 'Google Sign-In failed. Please try again.',
      );
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_up_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);
      expect(
        find.text('Google Sign-In failed. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Signup screen handles cancelled Google Sign-In without error snackbar',
    (tester) async {
      final mockAuth = _MockAuthService();
      mockAuth.returnNullOnGoogleSignIn = true;
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: const MaterialApp(home: SignupScreen()),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_up_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'Signup screen creates Firestore profile even when unmounted during Google Sign-Up',
    (tester) async {
      final fakeUser = _FakeAuthUser(
        uid: 'unmounted_signup_user',
        email: 'unmounted_signup@test.com',
        displayName: 'Unmounted Signup User',
      );
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      late StateSetter parentSetState;
      bool showSignup = true;

      final mockAuth = _MockAuthService(
        user: fakeUser,
        onSignInWithGoogle: () {
          // Simulate AuthGate switching screens upon authStateChanges event:
          parentSetState(() {
            showSignup = false;
          });
        },
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuth),
            Provider<UserService>.value(value: userService),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                parentSetState = setState;
                return showSignup
                    ? const SignupScreen()
                    : const Scaffold(body: Text('Home Dashboard'));
              },
            ),
          ),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_up_button'));
      await tester.ensureVisible(googleButton);
      await tester.tap(googleButton);
      await tester.pumpAndSettle();

      expect(mockAuth.signInWithGoogleCalled, isTrue);
      expect(find.text('Home Dashboard'), findsOneWidget);

      final doc = await fakeFirestore
          .collection('users')
          .doc('unmounted_signup_user')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['email'], 'unmounted_signup@test.com');
      expect(doc.data()!['role'], AppConstants.roleOperator);
    },
  );
}

class _FakeAuthUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  _FakeAuthUser({required this.uid, this.email, this.displayName});

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
  bool signInWithGoogleCalled = false;
  Object? googleErrorToThrow;
  bool returnNullOnGoogleSignIn = false;
  VoidCallback? onSignInWithGoogle;

  _MockAuthService({this.user, this.onSignInWithGoogle});

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return _FakeCredential(user: user);
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    signInWithGoogleCalled = true;
    onSignInWithGoogle?.call();
    if (googleErrorToThrow != null) {
      throw googleErrorToThrow!;
    }
    if (returnNullOnGoogleSignIn) {
      return null;
    }
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
