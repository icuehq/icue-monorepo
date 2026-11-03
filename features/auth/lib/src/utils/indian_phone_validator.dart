/// Utility for validating and normalizing Indian mobile numbers.
class IndianPhoneValidator {
  const IndianPhoneValidator._();

  static final RegExp _indianMobileRegex = RegExp(r'^[6-9]\d{9}$');

  /// Normalizes an input string by removing spaces, hyphens, and leading +91, 91, or 0.
  static String normalize(String input) {
    var cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  /// Checks if the input is a valid 10-digit Indian mobile number.
  /// Indian mobile numbers start with 6, 7, 8, or 9.
  static bool isValid(String? input) {
    if (input == null) return false;
    final normalized = normalize(input);
    return _indianMobileRegex.hasMatch(normalized);
  }

  /// Validates the input and returns a user-friendly error message, or `null` if valid.
  static String? validate(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Please enter mobile number';
    }
    final normalized = normalize(input);
    if (normalized.length != 10 || !_indianMobileRegex.hasMatch(normalized)) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }
}
