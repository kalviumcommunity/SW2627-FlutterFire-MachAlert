import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/utils/emulator_config.dart';

class _MockFirestoreForConfigTest extends Fake implements FirebaseFirestore {
  String? emulatorHost;
  int? emulatorPort;
  bool? sslEnabled;
  bool useFirestoreEmulatorCalled = false;

  @override
  void useFirestoreEmulator(
    String host,
    int port, {
    bool sslEnabled = false,
    bool automaticHostMapping = true,
  }) {
    useFirestoreEmulatorCalled = true;
    emulatorHost = host;
    emulatorPort = port;
    this.sslEnabled = sslEnabled;
  }
}

class _MockStorageForConfigTest extends Fake implements FirebaseStorage {
  String? emulatorHost;
  int? emulatorPort;
  int useStorageEmulatorCallCount = 0;

  @override
  Future<void> useStorageEmulator(
    String host,
    int port, {
    bool automaticHostMapping = true,
  }) async {
    useStorageEmulatorCallCount++;
    emulatorHost = host;
    emulatorPort = port;
  }
}

void main() {
  setUp(() {
    EmulatorConfig.overrideUseEmulator = null;
    EmulatorConfig.resetStorageConfiguration();
  });

  tearDown(() {
    EmulatorConfig.overrideUseEmulator = null;
    EmulatorConfig.resetStorageConfiguration();
  });

  group('EmulatorConfig Tests', () {
    test('default constants match firebase.json emulator setup', () {
      expect(EmulatorConfig.defaultFirestorePort, equals(8080));
      expect(EmulatorConfig.defaultStoragePort, equals(9199));
      expect(EmulatorConfig.androidHost, equals('10.0.2.2'));
      expect(EmulatorConfig.defaultHost, equals('127.0.0.1'));
    });

    test('storageHost resolves platform-specific host', () {
      final host = EmulatorConfig.storageHost;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        expect(host, equals('10.0.2.2'));
      } else {
        expect(host, equals('127.0.0.1'));
      }
    });

    test('firestoreHost resolves platform-specific host', () {
      final host = EmulatorConfig.firestoreHost;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        expect(host, equals('10.0.2.2'));
      } else {
        expect(host, equals('127.0.0.1'));
      }
    });

    test('androidHost is safe loopback mapping for Android Virtual Device', () {
      expect(EmulatorConfig.androidHost, isNot(equals('127.0.0.1')));
      expect(EmulatorConfig.androidHost, isNot(equals('localhost')));
      expect(EmulatorConfig.androidHost, equals('10.0.2.2'));
    });

    test(
      'default configuration in debug mode selects emulator mode safely',
      () {
        expect(EmulatorConfig.shouldUseEmulator, isTrue);
        expect(EmulatorConfig.isCloudMode, isFalse);
      },
    );

    test('explicit cloud mode override disables emulator connection', () {
      EmulatorConfig.overrideUseEmulator = false;

      expect(EmulatorConfig.shouldUseEmulator, isFalse);
      expect(EmulatorConfig.isCloudMode, isTrue);
    });

    test('explicit emulator mode override enables emulator connection', () {
      EmulatorConfig.overrideUseEmulator = true;

      expect(EmulatorConfig.shouldUseEmulator, isTrue);
      expect(EmulatorConfig.isCloudMode, isFalse);
    });

    test(
      'configureFirestore calls useFirestoreEmulator when in emulator mode',
      () {
        final mockFirestore = _MockFirestoreForConfigTest();

        final result = EmulatorConfig.configureFirestore(
          firestore: mockFirestore,
          useEmulator: true,
          host: '127.0.0.1',
          port: 8080,
        );

        expect(result, isTrue);
        expect(mockFirestore.useFirestoreEmulatorCalled, isTrue);
        expect(mockFirestore.emulatorHost, equals('127.0.0.1'));
        expect(mockFirestore.emulatorPort, equals(8080));
        expect(mockFirestore.sslEnabled, isFalse);
      },
    );

    test('configureFirestore does NOT call useFirestoreEmulator when in cloud mode', () {
      final mockFirestore = _MockFirestoreForConfigTest();

      final result = EmulatorConfig.configureFirestore(
        firestore: mockFirestore,
        useEmulator: false,
      );

      expect(result, isFalse);
      expect(mockFirestore.useFirestoreEmulatorCalled, isFalse);
      expect(mockFirestore.emulatorHost, isNull);
    });

    test('configureFirestore honors overrideUseEmulator = false', () {
      EmulatorConfig.overrideUseEmulator = false;
      final mockFirestore = _MockFirestoreForConfigTest();

      final result = EmulatorConfig.configureFirestore(
        firestore: mockFirestore,
      );

      expect(result, isFalse);
      expect(mockFirestore.useFirestoreEmulatorCalled, isFalse);
    });

    test('configureFirestoreEmulator delegates properly for backward compatibility', () {
      final mockFirestore = _MockFirestoreForConfigTest();

      final result = EmulatorConfig.configureFirestoreEmulator(
        firestore: mockFirestore,
        useEmulator: false,
      );

      expect(result, isFalse);
      expect(mockFirestore.useFirestoreEmulatorCalled, isFalse);
    });

    test('shouldUseStorageEmulator and isStorageCloudMode follow debug and override settings', () {
      expect(EmulatorConfig.shouldUseStorageEmulator, isTrue);
      expect(EmulatorConfig.isStorageCloudMode, isFalse);

      EmulatorConfig.overrideUseEmulator = false;
      expect(EmulatorConfig.shouldUseStorageEmulator, isFalse);
      expect(EmulatorConfig.isStorageCloudMode, isTrue);

      EmulatorConfig.overrideUseEmulator = true;
      expect(EmulatorConfig.shouldUseStorageEmulator, isTrue);
      expect(EmulatorConfig.isStorageCloudMode, isFalse);
    });

    test(
      'configureStorage calls useStorageEmulator when in emulator mode',
      () async {
        final mockStorage = _MockStorageForConfigTest();

        final result = await EmulatorConfig.configureStorage(
          storage: mockStorage,
          useEmulator: true,
          host: '127.0.0.1',
          port: 9199,
        );

        expect(result, isTrue);
        expect(mockStorage.useStorageEmulatorCallCount, equals(1));
        expect(mockStorage.emulatorHost, equals('127.0.0.1'));
        expect(mockStorage.emulatorPort, equals(9199));
      },
    );

    test(
      'configureStorage does NOT call useStorageEmulator when in cloud mode',
      () async {
        final mockStorage = _MockStorageForConfigTest();

        final result = await EmulatorConfig.configureStorage(
          storage: mockStorage,
          useEmulator: false,
        );

        expect(result, isFalse);
        expect(mockStorage.useStorageEmulatorCallCount, equals(0));
        expect(mockStorage.emulatorHost, isNull);
      },
    );

    test(
      'configureStorage avoids configuring the same instance twice',
      () async {
        final mockStorage = _MockStorageForConfigTest();

        final result1 = await EmulatorConfig.configureStorage(
          storage: mockStorage,
          useEmulator: true,
        );
        expect(result1, isTrue);
        expect(mockStorage.useStorageEmulatorCallCount, equals(1));

        // Second call with same instance
        final result2 = await EmulatorConfig.configureStorage(
          storage: mockStorage,
          useEmulator: true,
        );
        expect(result2, isTrue);
        expect(
          mockStorage.useStorageEmulatorCallCount,
          equals(1),
        ); // Still 1, not 2
      },
    );

    test('configureStorage honors overrideUseEmulator = false', () async {
      EmulatorConfig.overrideUseEmulator = false;
      final mockStorage = _MockStorageForConfigTest();

      final result = await EmulatorConfig.configureStorage(
        storage: mockStorage,
      );

      expect(result, isFalse);
      expect(mockStorage.useStorageEmulatorCallCount, equals(0));
    });

    test('UserService writes to selected Firestore instance without production write in tests', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final userService = UserService(firestore: fakeFirestore);

      final profile = await userService.createProfileIfAbsent(
        uid: 'cloud_test_uid_456',
        email: 'cloudtest@example.com',
        displayName: 'Cloud Test User',
        role: AppConstants.roleOperator,
      );

      expect(profile.id, equals('cloud_test_uid_456'));
      expect(profile.role, equals(AppConstants.roleOperator));
      expect(profile.email, equals('cloudtest@example.com'));

      final doc = await fakeFirestore
          .collection('users')
          .doc('cloud_test_uid_456')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['uid'], equals('cloud_test_uid_456'));
      expect(doc.data()!['userId'], equals('cloud_test_uid_456'));
      expect(doc.data()!['email'], equals('cloudtest@example.com'));
      expect(doc.data()!['displayName'], equals('Cloud Test User'));
      expect(doc.data()!['role'], equals('operator'));
      expect(doc.data()!['createdAt'], isNotNull);
      expect(doc.data()!['updatedAt'], isNotNull);
    });
  });
}
