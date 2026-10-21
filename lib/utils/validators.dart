import 'app_constants.dart';

class Validators {
  Validators._();

  /// Validates that a string is not null, empty, or whitespace only.
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates standard email address format.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password with configurable minimum length (default 6).
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    return null;
  }

  /// Validates confirm password matches the primary password.
  static String? confirmPassword(String? value, String? originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates numeric input for sensor readings or scores.
  static String? number(String? value, [String fieldName = 'Value']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a valid number';
    }
    return null;
  }

  /// Helper boolean check for valid email.
  static bool isValidEmail(String? value) {
    return email(value) == null;
  }

  /// Helper boolean check for valid password.
  static bool isValidPassword(String? value, {int minLength = 6}) {
    return password(value, minLength: minLength) == null;
  }

  /// Validates that a fault type is selected and is one of [AppConstants.faultTypes].
  static String? faultType(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Fault type is required';
    }
    final trimmed = value.trim();
    final isValid = AppConstants.faultTypes.any(
      (type) => type.toLowerCase() == trimmed.toLowerCase(),
    );
    if (!isValid) {
      return 'Please select a valid fault type';
    }
    return null;
  }

  /// Validates that a severity is selected and is one of [AppConstants.severities].
  static String? faultSeverity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Severity is required';
    }
    final trimmed = value.trim();
    final isValid = AppConstants.severities.any(
      (sev) => sev.toLowerCase() == trimmed.toLowerCase(),
    );
    if (!isValid) {
      return 'Please select a valid severity level';
    }
    return null;
  }

  /// Validates that a fault status is valid according to [AppConstants.faultStatuses].
  static String? faultStatus(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Status is required';
    }
    final trimmed = value.trim();
    final isValid = AppConstants.faultStatuses.any(
      (status) => status.toLowerCase() == trimmed.toLowerCase(),
    );
    if (!isValid) {
      return 'Please select a valid fault status';
    }
    return null;
  }

  /// Validates that a fault description is non-empty and meets [minLength].
  static String? faultDescription(String? value, {int minLength = 10}) {
    if (value == null || value.trim().isEmpty) {
      return 'Fault description is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < minLength) {
      return 'Description must be at least $minLength characters';
    }
    return null;
  }
}
