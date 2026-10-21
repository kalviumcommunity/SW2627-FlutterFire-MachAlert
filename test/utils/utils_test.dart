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
        expect(
          Validators.required('', 'Machine name'),
          'Machine name is required',
        );
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
        expect(
          Validators.email('not-an-email'),
          'Please enter a valid email address',
        );
        expect(Validators.email('user@'), 'Please enter a valid email address');
        expect(
          Validators.email('user@domain'),
          'Please enter a valid email address',
        );
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
        expect(
          Validators.password('12345'),
          'Password must be at least 6 characters',
        );
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
        expect(
          Validators.confirmPassword(null, 'secret123'),
          'Please confirm your password',
        );
        expect(
          Validators.confirmPassword('', 'secret123'),
          'Please confirm your password',
        );
        expect(
          Validators.confirmPassword('secret456', 'secret123'),
          'Passwords do not match',
        );
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
        expect(
          Validators.number('abc', 'Temperature'),
          'Temperature must be a valid number',
        );
      });

      test('returns null when value is a valid integer or double', () {
        expect(Validators.number('42'), isNull);
        expect(Validators.number('68.5'), isNull);
        expect(Validators.number('-10.2'), isNull);
      });
    });

    group('faultType validator', () {
      test('returns error when value is null, empty, or whitespace', () {
        expect(Validators.faultType(null), 'Fault type is required');
        expect(Validators.faultType(''), 'Fault type is required');
        expect(Validators.faultType('   '), 'Fault type is required');
      });

      test('returns error when type is not in AppConstants.faultTypes (e.g. Sensor, Software, Cosmic)', () {
        final invalidTypes = [
          'Sensor',
          'Software',
          'SoftwareBug',
          'Cosmic',
          'Nuclear',
          'Hardware',
          'Network',
        ];
        for (final invalid in invalidTypes) {
          expect(
            Validators.faultType(invalid),
            'Please select a valid fault type',
            reason: 'Type "$invalid" should be rejected as not in AppConstants.faultTypes',
          );
        }
      });

      test('returns null for each valid type in AppConstants.faultTypes', () {
        expect(Validators.faultType(AppConstants.faultTypeMechanical), isNull);
        expect(Validators.faultType(AppConstants.faultTypeElectrical), isNull);
        expect(Validators.faultType(AppConstants.faultTypeHydraulic), isNull);
        expect(Validators.faultType(AppConstants.faultTypeThermal), isNull);
        expect(Validators.faultType(AppConstants.faultTypePneumatic), isNull);
        expect(Validators.faultType(AppConstants.faultTypeOther), isNull);

        for (final type in AppConstants.faultTypes) {
          expect(Validators.faultType(type), isNull);
          expect(Validators.faultType(type.toLowerCase()), isNull);
          expect(Validators.faultType('  $type  '), isNull);
        }
      });
    });

    group('faultSeverity validator', () {
      test('returns error when value is null, empty, or whitespace', () {
        expect(Validators.faultSeverity(null), 'Severity is required');
        expect(Validators.faultSeverity(''), 'Severity is required');
        expect(Validators.faultSeverity('   '), 'Severity is required');
      });

      test('returns error when severity is not in AppConstants.severities', () {
        expect(
          Validators.faultSeverity('Catastrophic'),
          'Please select a valid severity level',
        );
        expect(
          Validators.faultSeverity('Minimal'),
          'Please select a valid severity level',
        );
      });

      test('returns null when severity is valid', () {
        for (final severity in AppConstants.severities) {
          expect(Validators.faultSeverity(severity), isNull);
          expect(Validators.faultSeverity(severity.toLowerCase()), isNull);
        }
      });
    });

    group('faultStatus validator', () {
      test('returns error when value is null, empty, or whitespace', () {
        expect(Validators.faultStatus(null), 'Status is required');
        expect(Validators.faultStatus(''), 'Status is required');
        expect(Validators.faultStatus('   '), 'Status is required');
      });

      test('returns error when status is not in AppConstants.faultStatuses', () {
        expect(
          Validators.faultStatus('Archived'),
          'Please select a valid fault status',
        );
        expect(
          Validators.faultStatus('Pending'),
          'Please select a valid fault status',
        );
      });

      test('returns null when status is valid', () {
        for (final status in AppConstants.faultStatuses) {
          expect(Validators.faultStatus(status), isNull);
          expect(Validators.faultStatus(status.toLowerCase()), isNull);
        }
      });
    });

    group('faultDescription validator', () {
      test('returns error when value is null, empty, or whitespace', () {
        expect(Validators.faultDescription(null), 'Fault description is required');
        expect(Validators.faultDescription(''), 'Fault description is required');
        expect(Validators.faultDescription('   '), 'Fault description is required');
      });

      test('returns error when description is shorter than default minLength (10)', () {
        expect(
          Validators.faultDescription('Broken'),
          'Description must be at least 10 characters',
        );
        expect(
          Validators.faultDescription('123456789'),
          'Description must be at least 10 characters',
        );
      });

      test('returns null when description is at least default minLength', () {
        expect(Validators.faultDescription('1234567890'), isNull);
        expect(
          Validators.faultDescription('Motor overheating on Line 1 spindle'),
          isNull,
        );
      });

      test('supports custom minLength parameter', () {
        expect(
          Validators.faultDescription('Short text', minLength: 15),
          'Description must be at least 15 characters',
        );
        expect(
          Validators.faultDescription('Short text with enough length', minLength: 15),
          isNull,
        );
      });
    });
  });
}
