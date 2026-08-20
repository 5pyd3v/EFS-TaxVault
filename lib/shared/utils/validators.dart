abstract final class Validators {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? required(
    String? value, {
    String message = 'This field is required',
  }) {
    if ((value ?? '').trim().isEmpty) return message;
    return null;
  }

  static String? phone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (digits.length < 10) return 'Enter a valid phone number';
    return null;
  }

  static String? pin(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'PIN is required';
    if (!RegExp(r'^\d{4,8}$').hasMatch(v)) return 'Enter your PIN';
    return null;
  }
}
