// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

class FakeErrorDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final FirebaseException exception;

  FakeErrorDocumentReference(this.exception);

  @override
  String get id => 'err_user';

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    throw exception;
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    throw exception;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    throw exception;
  }
}

class FakeErrorCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final FirebaseException exception;

  FakeErrorCollectionReference(this.exception);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeErrorDocumentReference(exception);
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    throw exception;
  }
}

class FakeErrorFirestore extends Fake implements FirebaseFirestore {
  final FirebaseException exception;

  FakeErrorFirestore(this.exception);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeErrorCollectionReference(exception);
  }
}

void main() {
  group('UserService Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService userService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      userService = UserService(firestore: fakeFirestore);
    });

    test('Canonical document path is users/{uid}', () {
      final docRef = userService.userDoc('operator_001');
      expect(docRef.parent.id, AppConstants.usersCollection);
      expect(docRef.id, 'operator_001');
      expect(docRef.path, 'users/operator_001');
    });

    test('userDoc throws UserServiceException for empty or whitespace UID', () {
      expect(
        () => userService.userDoc(''),
        throwsA(
          isA<UserServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-uid',
          ),
        ),
      );
      expect(
        () => userService.userDoc('   '),
        throwsA(
          isA<UserServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-uid',
          ),
        ),
      );
    });

    group('getUserProfile & userProfileExists', () {
      test('returns null when document does not exist', () async {
        final profile = await userService.getUserProfile('non_existent');
        expect(profile, isNull);

        final exists = await userService.userProfileExists('non_existent');
        expect(exists, isFalse);
      });

      test('retrieves existing user profile successfully', () async {
        final now = DateTime(2026, 10, 14, 10, 0);
        await fakeFirestore.collection('users').doc('user_123').set({
          'uid': 'user_123',
          'displayName': 'Ravi Patel',
          'email': 'ravi@factory.com',
          'role': 'operator',
          'createdAt': Timestamp.fromDate(now),
        });

        final profile = await userService.getUserProfile('user_123');
        expect(profile, isNotNull);
        expect(profile!.id, 'user_123');
        expect(profile.name, 'Ravi Patel');
        expect(profile.email, 'ravi@factory.com');
        expect(profile.role, 'operator');
        expect(profile.createdAt, now);

        final exists = await userService.userProfileExists('user_123');
        expect(exists, isTrue);
      });

      test('safely handles missing optional fields', () async {
        await fakeFirestore.collection('users').doc('minimal_user').set({
          'uid': 'minimal_user',
          'email': 'minimal@factory.com',
        });

        final profile = await userService.getUserProfile('minimal_user');
        expect(profile, isNotNull);
        expect(profile!.id, 'minimal_user');
        expect(profile.name, '');
        expect(profile.email, 'minimal@factory.com');
        expect(profile.role, '');
        expect(profile.createdAt, isNull);
        expect(profile.updatedAt, isNull);
      });

      test('preserves unrecognized role string rather than silently converting to operator', () async {
        await fakeFirestore.collection('users').doc('unrecognized_user').set({
          'uid': 'unrecognized_user',
          'displayName': 'Custom Auditor',
          'email': 'auditor@factory.com',
          'role': 'auditor',
        });

        final profile = await userService.getUserProfile('unrecognized_user');
        expect(profile, isNotNull);
        expect(profile!.role, 'auditor');
        expect(profile.hasRecognizedRole, isFalse);
      });
    });

    group('createProfileIfAbsent', () {
      test(
        'creates new profile with default role operator if absent',
        () async {
          final profile = await userService.createProfileIfAbsent(
            uid: 'new_user_1',
            email: 'newuser@factory.com',
            displayName: 'New Worker',
          );

          expect(profile.id, 'new_user_1');
          expect(profile.name, 'New Worker');
          expect(profile.email, 'newuser@factory.com');
          expect(profile.role, AppConstants.roleOperator);

          final doc = await fakeFirestore
              .collection('users')
              .doc('new_user_1')
              .get();
          expect(doc.exists, isTrue);
          expect(doc.data()!['role'], AppConstants.roleOperator);
          expect(doc.data()!['email'], 'newuser@factory.com');
          expect(doc.data()!['displayName'], 'New Worker');
        },
      );

      test(
        'allows explicit recognized non-manager role during registration',
        () async {
          final profile = await userService.createProfileIfAbsent(
            uid: 'tech_01',
            email: 'tech@factory.com',
            displayName: 'Tech Specialist',
            role: AppConstants.roleTechnician,
          );

          expect(profile.role, AppConstants.roleTechnician);

          final doc = await fakeFirestore
              .collection('users')
              .doc('tech_01')
              .get();
          expect(doc.data()!['role'], AppConstants.roleTechnician);
        },
      );

      test(
        'rejects self-assigning manager role during createProfileIfAbsent',
        () async {
          expect(
            () => userService.createProfileIfAbsent(
              uid: 'sneaky_admin',
              email: 'sneaky@factory.com',
              role: AppConstants.roleManager,
            ),
            throwsA(
              isA<UserServiceException>().having(
                (e) => e.code,
                'code',
                'role-escalation-denied',
              ),
            ),
          );

          final doc = await fakeFirestore
              .collection('users')
              .doc('sneaky_admin')
              .get();
          expect(doc.exists, isFalse);
        },
      );

      test(
        'rejects invalid role string during createProfileIfAbsent',
        () async {
          expect(
            () => userService.createProfileIfAbsent(
              uid: 'invalid_user',
              email: 'invalid@factory.com',
              role: 'superadmin',
            ),
            throwsA(
              isA<UserServiceException>().having(
                (e) => e.code,
                'code',
                'invalid-role',
              ),
            ),
          );
        },
      );

      test('does NOT overwrite an existing profile', () async {
        final originalDate = DateTime(2026, 9, 1, 8, 0);
        await fakeFirestore.collection('users').doc('existing_user').set({
          'uid': 'existing_user',
          'displayName': 'Original Name',
          'email': 'existing@factory.com',
          'role': AppConstants.roleManager,
          'createdAt': Timestamp.fromDate(originalDate),
        });

        final result = await userService.createProfileIfAbsent(
          uid: 'existing_user',
          email: 'changed@factory.com',
          displayName: 'Changed Name',
          role: AppConstants.roleOperator,
        );

        expect(result.name, 'Original Name');
        expect(result.email, 'existing@factory.com');
        expect(result.role, AppConstants.roleManager);

        final doc = await fakeFirestore
            .collection('users')
            .doc('existing_user')
            .get();
        expect(doc.data()!['displayName'], 'Original Name');
        expect(doc.data()!['email'], 'existing@factory.com');
        expect(doc.data()!['role'], AppConstants.roleManager);
      });
    });

    group('createUserProfile', () {
      test('creates profile when given valid UserModel', () async {
        final user = UserModel(
          id: 'user_create',
          name: 'Priya Verma',
          email: 'priya@factory.com',
          role: AppConstants.roleOperator,
        );

        await userService.createUserProfile(user);

        final doc = await fakeFirestore
            .collection('users')
            .doc('user_create')
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['role'], AppConstants.roleOperator);
        expect(doc.data()!['displayName'], 'Priya Verma');
      });

      test(
        'rejects self-assigning manager role in createUserProfile',
        () async {
          final user = UserModel(
            id: 'user_manager_attempt',
            name: 'Manager Wannabe',
            email: 'wannabe@factory.com',
            role: AppConstants.roleManager,
          );

          expect(
            () => userService.createUserProfile(user),
            throwsA(
              isA<UserServiceException>().having(
                (e) => e.code,
                'code',
                'role-escalation-denied',
              ),
            ),
          );
        },
      );

      test('rejects invalid role in createUserProfile', () async {
        final user = UserModel(
          id: 'invalid_role_user',
          name: 'Invalid Role',
          email: 'invalid@factory.com',
          role: 'director',
        );

        expect(
          () => userService.createUserProfile(user),
          throwsA(
            isA<UserServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-role',
            ),
          ),
        );
      });
    });

    group('updateProfile & updateUserProfile & updateUserRole', () {
      test(
        'updateProfile modifies only allowed fields and touches updatedAt',
        () async {
          await fakeFirestore.collection('users').doc('user_update_1').set({
            'uid': 'user_update_1',
            'displayName': 'Old Name',
            'email': 'update@factory.com',
            'role': AppConstants.roleOperator,
          });

          await userService.updateProfile(
            uid: 'user_update_1',
            displayName: 'New Better Name',
          );

          final doc = await fakeFirestore
              .collection('users')
              .doc('user_update_1')
              .get();
          expect(doc.data()!['displayName'], 'New Better Name');
          expect(doc.data()!['name'], 'New Better Name');
          expect(doc.data()!['role'], AppConstants.roleOperator);
          expect(doc.data()!['updatedAt'], isNotNull);
        },
      );

      test('updateUserProfile modifies only permitted fields without altering role, email, or uid', () async {
        final originalDate = DateTime(2026, 9, 1, 10, 0);
        await fakeFirestore.collection('users').doc('user_update_2').set({
          'uid': 'user_update_2',
          'userId': 'user_update_2',
          'displayName': 'Original Operator',
          'name': 'Original Operator',
          'email': 'original@factory.com',
          'role': AppConstants.roleOperator,
          'createdAt': Timestamp.fromDate(originalDate),
        });

        // Even if caller passes modified role, email, or createdAt in UserModel:
        final updatedModel = UserModel(
          id: 'user_update_2',
          name: 'Renamed Operator',
          email: 'malicious_changed_email@factory.com',
          role: AppConstants.roleManager, // caller tries to pass manager role
          createdAt: DateTime(2025, 1, 1),
        );

        await userService.updateUserProfile(updatedModel);

        final doc = await fakeFirestore
            .collection('users')
            .doc('user_update_2')
            .get();

        // Allowed fields are updated
        expect(doc.data()!['displayName'], 'Renamed Operator');
        expect(doc.data()!['name'], 'Renamed Operator');
        expect(doc.data()!['updatedAt'], isNotNull);

        // Protected fields are strictly preserved!
        expect(doc.data()!['role'], AppConstants.roleOperator);
        expect(doc.data()!['email'], 'original@factory.com');
        expect(doc.data()!['uid'], 'user_update_2');
      });

      test('updateUserRole updates target role for recognized roles', () async {
        await fakeFirestore.collection('users').doc('worker_1').set({
          'uid': 'worker_1',
          'displayName': 'Worker',
          'email': 'worker@factory.com',
          'role': AppConstants.roleOperator,
        });

        await userService.updateUserRole(
          targetUid: 'worker_1',
          newRole: AppConstants.roleTechnician,
        );

        final doc = await fakeFirestore
            .collection('users')
            .doc('worker_1')
            .get();
        expect(doc.data()!['role'], AppConstants.roleTechnician);
        expect(doc.data()!['updatedAt'], isNotNull);
      });

      test('updateUserRole rejects unrecognized roles', () async {
        expect(
          () => userService.updateUserRole(
            targetUid: 'worker_1',
            newRole: 'super_admin',
          ),
          throwsA(
            isA<UserServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-role',
            ),
          ),
        );
      });
    });

    group('streamUserProfile', () {
      test('emits profile updates in real time', () async {
        final stream = userService.streamUserProfile('stream_user');

        final emissions = <UserModel?>[];
        final sub = stream.listen(emissions.add);

        // Document does not exist initially
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.isNotEmpty, isTrue);
        expect(emissions.last, isNull);

        // Create document
        await fakeFirestore.collection('users').doc('stream_user').set({
          'uid': 'stream_user',
          'displayName': 'Streaming Operator',
          'email': 'stream@factory.com',
          'role': 'operator',
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last, isNotNull);
        expect(emissions.last!.name, 'Streaming Operator');
        expect(emissions.last!.role, 'operator');

        await sub.cancel();
      });
    });

    group('Firestore Exception Handling', () {
      test(
        'maps permission-denied FirebaseException to UserServiceException',
        () async {
          final errorFirestore = FakeErrorFirestore(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: 'Missing permissions',
            ),
          );

          final errorService = UserService(firestore: errorFirestore);

          expect(
            () => errorService.getUserProfile('any_id'),
            throwsA(
              isA<UserServiceException>()
                  .having((e) => e.code, 'code', 'permission-denied')
                  .having(
                    (e) => e.message,
                    'message',
                    'You do not have permission to access or modify this profile.',
                  ),
            ),
          );
        },
      );

      test(
        'maps unavailable FirebaseException to UserServiceException',
        () async {
          final errorFirestore = FakeErrorFirestore(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
              message: 'Server unreachable',
            ),
          );

          final errorService = UserService(firestore: errorFirestore);

          expect(
            () => errorService.createProfileIfAbsent(
              uid: 'any_id',
              email: 'test@factory.com',
            ),
            throwsA(
              isA<UserServiceException>()
                  .having((e) => e.code, 'code', 'unavailable')
                  .having(
                    (e) => e.message,
                    'message',
                    contains('network connection'),
                  ),
            ),
          );
        },
      );

      test('UserServiceException equality and toString', () {
        final ex1 = UserServiceException(code: 'not-found');
        final ex2 = UserServiceException(code: 'not-found');
        final ex3 = UserServiceException(code: 'permission-denied');

        expect(ex1, equals(ex2));
        expect(ex1.hashCode, equals(ex2.hashCode));
        expect(ex1, isNot(equals(ex3)));
        expect(ex1.toString(), contains('not-found'));
      });
    });

    group('getUsersByRole', () {
      test(
        'rejects unrecognized role with typed UserServiceException',
        () async {
          expect(
            () => userService.getUsersByRole('invalid_role'),
            throwsA(
              isA<UserServiceException>().having(
                (e) => e.code,
                'code',
                'invalid-role',
              ),
            ),
          );
        },
      );

      test(
        'queries users collection by role and sorts by display name',
        () async {
          await fakeFirestore.collection('users').doc('u1').set({
            'uid': 'u1',
            'name': 'Zach Technician',
            'email': 'zach@factory.com',
            'role': 'technician',
          });
          await fakeFirestore.collection('users').doc('u2').set({
            'uid': 'u2',
            'name': 'Alice Technician',
            'email': 'alice@factory.com',
            'role': 'technician',
          });
          await fakeFirestore.collection('users').doc('u3').set({
            'uid': 'u3',
            'name': 'Manager Bob',
            'email': 'bob@factory.com',
            'role': 'manager',
          });

          final technicians = await userService.getUsersByRole('technician');

          expect(technicians.length, 2);
          expect(technicians.first.name, 'Alice Technician');
          expect(technicians.last.name, 'Zach Technician');
          expect(technicians.every((u) => u.role == 'technician'), isTrue);
        },
      );

      test(
        'maps Firestore failures safely without raw error leakage',
        () async {
          const rawInternalError =
              'Database internal memory fault at 0xdeadbeef';
          final errorFirestore = FakeErrorFirestore(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: rawInternalError,
            ),
          );

          final errorService = UserService(firestore: errorFirestore);

          expect(
            () => errorService.getUsersByRole('technician'),
            throwsA(
              isA<UserServiceException>()
                  .having((e) => e.code, 'code', 'permission-denied')
                  .having(
                    (e) => e.message,
                    'message',
                    isNot(contains(rawInternalError)),
                  ),
            ),
          );
        },
      );
    });

    group('getUsersByRole', () {
      test('rejects unrecognized role with typed UserServiceException', () async {
        expect(
          () => userService.getUsersByRole('invalid_role'),
          throwsA(
            isA<UserServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-role',
            ),
          ),
        );
      });

      test('queries users collection by role and sorts by display name', () async {
        await fakeFirestore.collection('users').doc('u1').set({
          'uid': 'u1',
          'name': 'Zach Technician',
          'email': 'zach@factory.com',
          'role': 'technician',
        });
        await fakeFirestore.collection('users').doc('u2').set({
          'uid': 'u2',
          'name': 'Alice Technician',
          'email': 'alice@factory.com',
          'role': 'technician',
        });
        await fakeFirestore.collection('users').doc('u3').set({
          'uid': 'u3',
          'name': 'Manager Bob',
          'email': 'bob@factory.com',
          'role': 'manager',
        });

        final technicians = await userService.getUsersByRole('technician');

        expect(technicians.length, 2);
        expect(technicians.first.name, 'Alice Technician');
        expect(technicians.last.name, 'Zach Technician');
        expect(technicians.every((u) => u.role == 'technician'), isTrue);
      });

      test('maps Firestore failures safely without raw error leakage', () async {
        const rawInternalError = 'Database internal memory fault at 0xdeadbeef';
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: rawInternalError,
          ),
        );

        final errorService = UserService(firestore: errorFirestore);

        expect(
          () => errorService.getUsersByRole('technician'),
          throwsA(
            isA<UserServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains(rawInternalError)),
                ),
          ),
        );
      });
    });
  });
}
