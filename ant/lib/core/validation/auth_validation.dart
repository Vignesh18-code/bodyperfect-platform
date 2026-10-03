/// Patient-facing validation matching the API's current registration/reset rules.
class AuthValidation {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? name(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 2 || length > 100 ? 'Name must be 2–100 characters' : null;
  }

  static String? phone(String? value) =>
      RegExp(r'^[0-9]{9}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Please enter a valid 9-digit phone number';

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8 || value.length > 72) {
      return 'Password must be 8–72 characters';
    }
    if (!RegExp(r'^[A-Za-z0-9@$!%*?&]+$').hasMatch(value)) {
      return 'Use letters, numbers and these symbols: @\$!%*?&';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must have an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must have a lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Password must have a number';
    if (!RegExp(r'[@$!%*?&]').hasMatch(value)) {
      return 'Password must have a special character (@\$!%*?&)';
    }
    return null;
  }
}
