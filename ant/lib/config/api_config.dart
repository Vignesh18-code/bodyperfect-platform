class ApiConfig {

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // ── Auth Endpoints ────────────────────────────────
  static String get register    => '$baseUrl/api/auth/register';
  static String get verifyOtp   => '$baseUrl/api/auth/verify-otp';
  static String get resendOtp   => '$baseUrl/api/auth/resend-otp';
  static String get login       => '$baseUrl/api/auth/login';
  static String get refresh         => '$baseUrl/api/auth/refresh';
  static String get forgotPassword  => '$baseUrl/api/auth/forgot-password';
  static String get resetPassword   => '$baseUrl/api/auth/reset-password';

  static String get logout => '$baseUrl/api/auth/logout';

  // ── User Endpoints ───────────────────────────────
  static String get userProfile      => '$baseUrl/api/user/profile';
  static String get userProfileImage => '$baseUrl/api/user/profile/image';

  // ── Notification Endpoints ──────────────────────
  static String notifications({int page = 0, int size = 20}) =>
      '$baseUrl/api/notifications?page=$page&size=$size';
  static String get notificationsUnread => '$baseUrl/api/notifications/unread-count';
  static String notificationRead(int id) => '$baseUrl/api/notifications/$id/read';
  static String get notificationsReadAll => '$baseUrl/api/notifications/read-all';
  static String notificationDelete(int id) => '$baseUrl/api/notifications/$id';

  // ── Appointment Endpoints ────────────────────────
  static String get appointments => '$baseUrl/api/appointments';
  static String appointmentReschedule(int id) => '$baseUrl/api/appointments/$id/reschedule';

  // ── Treatment Endpoints ──────────────────────────
  static String get treatmentActive    => '$baseUrl/api/treatment/active';
  static String get treatmentProtocols => '$baseUrl/api/treatment/protocols';
  static String get treatmentNextSession => '$baseUrl/api/treatment/sessions/next';

  static String treatmentProtocolById(int id) => '$baseUrl/api/treatment/protocols/$id';
  static String treatmentSessionsByMonth(int id, int year, int month) =>
      '$baseUrl/api/treatment/protocols/$id/sessions?year=$year&month=$month';
  static String treatmentSessionsByDate(String date) =>
      '$baseUrl/api/treatment/sessions/date?date=$date';
}
