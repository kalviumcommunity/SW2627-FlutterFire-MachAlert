import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/utils/validators.dart';

void main() {
  group('AppConstants Tests', () {
    test('constants have expected values', () {
      expect(AppConstants.appName, 'MachAlert');
      expect(AppConstants.appVersion, '1.0.0');

      // Collections
      expect(AppConstants.usersCollection, 'users');
      expect(AppConstants.machinesCollection, 'machines');
      expect(AppConstants.faultsCollection, 'faults');
      expect(AppConstants.maintenanceCollection, 'maintenance');
      expect(AppConstants.alertsCollection, 'alerts');

      // Roles
      expect(AppConstants.userRoles, contains('operator'));
      expect(AppConstants.userRoles, contains('technician'));
      expect(AppConstants.userRoles, contains('manager'));

      // Machine statuses
      expect(AppConstants.machineStatuses, contains('Operational'));
      expect(AppConstants.machineStatuses, contains('Warning'));
      expect(AppConstants.machineStatuses, contains('Critical'));
      expect(AppConstants.machineStatuses, contains('Under Maintenance'));

      // Severities
      expect(AppConstants.severities, contains('Low'));
      expect(AppConstants.severities, contains('Medium'));
      expect(AppConstants.severities, contains('High'));
      expect(AppConstants.severities, contains('Critical'));

      // Fault statuses
      expect(AppConstants.faultStatuses, contains('Open'));
      expect(AppConstants.faultStatuses, contains('In Progress'));
      expect(AppConstants.faultStatuses, contains('Resolved'));

      // Maintenance statuses
      expect(AppConstants.maintenanceStatuses, contains('Pending'));
      expect(AppConstants.maintenanceStatuses, contains('In Progress'));
      expect(AppConstants.maintenanceStatuses, contains('Resolved'));

      // Fault types
      expect(AppConstants.faultTypes, contains('Mechanical'));
      expect(AppConstants.faultTypes, contains('Electrical'));
      expect(AppConstants.faultTypes, contains('Hydraulic'));
      expect(AppConstants.faultTypes, contains('Thermal'));
      expect(AppConstants.faultTypes, contains('Pneumatic'));
      expect(AppConstants.faultTypes, contains('Other'));
    });
  });

  group('Validators Tests', () {
    group('required validator', () {
      test('returns error message when value is null or empty', () {
        expect(Validators.required(null), 'This field is required');
        expect(Validators.required(''), 'This field is required');
        expect(Validators.required('   '), 'This field is required');
        expect(Validators.required('', 'Machine name'), 'Machine name is required');
      });

      test('returns null when value is non-empty', () {
        expect(Validators.required('CNC Machine'), isNull);
        expect(Validators.required('  valid text  '), isNull);
      });
    });

    group('email validator', () {
      test('returns error when empty or invalid format', () {
        expect(Validators.email(null), 'Email is required');
        expect(Validators.email(''), 'Email is required');
        expect(Validators.email('not-an-email'), 'Please enter a valid email address');
        expect(Validators.email('user@'), 'Please enter a valid email address');
        expect(Validators.email('user@domain'), 'Please enter a valid email address');
      });

      test('returns null when email format is valid', () {
        expect(Validators.email('operator@machalert.com'), isNull);
        expect(Validators.email('technician.1@factory.org'), isNull);
      });

      test('isValidEmail boolean helper works correctly', () {
        expect(Validators.isValidEmail('valid@example.com'), isTrue);
        expect(Validators.isValidEmail('invalid'), isFalse);
        expect(Validators.isValidEmail(null), isFalse);
      });
    });

    group('password validator', () {
      test('returns error when empty or below minimum length', () {
        expect(Validators.password(null), 'Password is required');
        expect(Validators.password(''), 'Password is required');
        expect(Validators.password('12345'), 'Password must be at least 6 characters');
        expect(
          Validators.password('1234567', minLength: 8),
          'Password must be at least 8 characters',
        );
      });

      test('returns null when password meets minimum length', () {
        expect(Validators.password('123456'), isNull);
        expect(Validators.password('securePassword123'), isNull);
        expect(Validators.password('12345678', minLength: 8), isNull);
      });

      test('isValidPassword boolean helper works correctly', () {
        expect(Validators.isValidPassword('123456'), isTrue);
        expect(Validators.isValidPassword('12345'), isFalse);
        expect(Validators.isValidPassword(null), isFalse);
      });
    });

    group('confirmPassword validator', () {
      test('returns error when empty or does not match', () {
        expect(Validators.confirmPassword(null, 'secret123'), 'Please confirm your password');
        expect(Validators.confirmPassword('', 'secret123'), 'Please confirm your password');
        expect(Validators.confirmPassword('secret456', 'secret123'), 'Passwords do not match');
      });

      test('returns null when passwords match', () {
        expect(Validators.confirmPassword('secret123', 'secret123'), isNull);
      });
    });

    group('number validator', () {
      test('returns error when value is null, empty, or not a number', () {
        expect(Validators.number(null), 'Value is required');
        expect(Validators.number(''), 'Value is required');
        expect(Validators.number('abc'), 'Value must be a valid number');
        expect(Validators.number('abc', 'Temperature'), 'Temperature must be a valid number');
      });

      test('returns null when value is a valid integer or double', () {
        expect(Validators.number('42'), isNull);
        expect(Validators.number('68.5'), isNull);
        expect(Validators.number('-10.2'), isNull);
      });
    });
  });
}
