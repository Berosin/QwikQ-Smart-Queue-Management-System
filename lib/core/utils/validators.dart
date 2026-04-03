/// All form field validators for QwikQ.
/// Usage: TextFormField(validator: Validators.email)
class Validators {
  Validators._();

  // ── Email ────────────────────────────────────────────────────
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  // ── Password ─────────────────────────────────────────────────
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    if (value.length > 72) return 'Password is too long';
    return null;
  }

  static String? strongPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Include at least one uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Include at least one number';
    return null;
  }

  static String? Function(String?) confirmPassword(String original) {
    return (String? value) {
      if (value == null || value.isEmpty) return 'Please confirm your password';
      if (value != original) return 'Passwords do not match';
      return null;
    };
  }

  // ── Phone ────────────────────────────────────────────────────
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final cleaned = value.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
    if (cleaned.length < 10) return 'Enter a valid phone number';
    if (cleaned.length > 15) return 'Phone number is too long';
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) return 'Only digits allowed';
    return null;
  }

  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return phone(value);
  }

  // ── OTP ──────────────────────────────────────────────────────
  static String? otp(String? value) {
    if (value == null || value.isEmpty) return 'OTP is required';
    if (value.length != 6) return 'OTP must be 6 digits';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return 'Only digits allowed';
    return null;
  }

  // ── Name ────────────────────────────────────────────────────
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name is too short';
    if (value.trim().length > 60) return 'Name is too long';
    if (!RegExp(r"^[a-zA-Z\s\'\-\.]+$").hasMatch(value.trim())) {
      return 'Name contains invalid characters';
    }
    return null;
  }

  // ── Required ────────────────────────────────────────────────
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  static String? Function(String?) requiredWithLabel(String label) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) return '$label is required';
      return null;
    };
  }

  // ── Shop Fields ──────────────────────────────────────────────
  static String? shopName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Shop name is required';
    if (value.trim().length < 3) return 'Name must be at least 3 characters';
    if (value.trim().length > 80) return 'Name is too long';
    return null;
  }

  static String? address(String? value) {
    if (value == null || value.trim().isEmpty) return 'Address is required';
    if (value.trim().length < 10) return 'Please enter a complete address';
    return null;
  }

  static String? serviceTime(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final n = int.tryParse(value.trim());
    if (n == null) return 'Must be a number';
    if (n < 1) return 'Minimum 1 minute';
    if (n > 120) return 'Maximum 120 minutes';
    return null;
  }

  static String? maxTokens(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final n = int.tryParse(value.trim());
    if (n == null) return 'Must be a number';
    if (n < 1) return 'Minimum 1 token';
    if (n > 1000) return 'Maximum 1000 tokens';
    return null;
  }

  // ── URL ──────────────────────────────────────────────────────
  static String? optionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final regex = RegExp(r'^https?:\/\/.+\..+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid URL';
    return null;
  }

  // ── Number Range ─────────────────────────────────────────────
  static String? Function(String?) numberRange(int min, int max, String label) {
    return (String? value) {
      if (value == null || value.isEmpty) return '$label is required';
      final n = int.tryParse(value);
      if (n == null) return 'Enter a valid number';
      if (n < min) return '$label must be at least $min';
      if (n > max) return '$label must be at most $max';
      return null;
    };
  }
}