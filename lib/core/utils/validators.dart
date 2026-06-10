/// Form field validation helpers used across all PPN input forms.
///
/// Each validator returns `null` when the value is valid, or a human-readable
/// error message string when validation fails. This matches the contract
/// expected by Flutter's [TextFormField.validator].
class Validators {
  Validators._();

  /// Validates that [value] is a well-formed email address.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    // RFC 5322 simplified pattern — covers the vast majority of real addresses.
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  /// Validates that [value] meets the minimum password requirements.
  ///
  /// Currently enforces a minimum length of 6 characters.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  /// Validates a Nigerian phone number.
  ///
  /// Accepted formats:
  /// - Local: `08012345678`, `09012345678`, `07012345678`
  /// - International: `+2348012345678`, `2348012345678`
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    // Strip spaces, dashes, and parentheses for lenient input.
    final cleaned = value.replaceAll(RegExp(r'[\s\-()]'), '');

    // Match Nigerian mobile numbers in local or international format.
    final phoneRegex = RegExp(
      r'^(?:\+?234|0)(70|80|81|90|91|71)\d{8}$',
    );

    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Enter a valid Nigerian phone number';
    }

    return null;
  }

  /// Generic required-field validator.
  ///
  /// [fieldName] is used to build a contextual error message,
  /// e.g. `validateRequired(null, 'First name')` → `"First name is required"`.
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates that [value] is a positive numeric price.
  ///
  /// Allows integers and decimals. Commas are stripped before parsing.
  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Price is required';
    }

    // Remove commas and currency symbols so users can paste formatted values.
    final cleaned = value.replaceAll(RegExp(r'[₦,\s]'), '');

    final parsed = num.tryParse(cleaned);
    if (parsed == null) {
      return 'Enter a valid price';
    }

    if (parsed <= 0) {
      return 'Price must be greater than zero';
    }

    return null;
  }
}
