class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String fullName;
  final String email;
  final String role;
  final int totalPoints;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.fullName,
    required this.email,
    required this.role,
    required this.totalPoints,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      totalPoints: json['totalPoints'] ?? 0,
    );
  }
  /*
   * Maps EXACTLY to backend LoginResponse.java:
   * {
   *   "accessToken": "eyJhbG...",
   *   "refreshToken": "eyJzd...",
   *   "fullName": "Vignesh Kumar",
   *   "email": "vignesh@gmail.com",
   *   "role": "PATIENT",
   *   "totalPoints": 100
   * }
   */
}