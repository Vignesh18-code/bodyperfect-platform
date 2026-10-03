import '../config/api_config.dart';
import '../models/api_response.dart';
import '../models/login_response.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'session_refresh.dart';

class AuthService {
  // ── Register ─────────────────────────────────────
  static Future<ApiResponse> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String preferredTreatment,
  }) async {
    final result = await ApiService.post(ApiConfig.register, {
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'password': password,
      'preferredTreatment': preferredTreatment,
    });

    return ApiResponse(
      success: result['success'] ?? false,
      message: result['message'] ?? 'Something went wrong',
    );
  }

  // ── Verify OTP ───────────────────────────────────
  static Future<ApiResponse<LoginResponse>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final result = await ApiService.post(ApiConfig.verifyOtp, {
      'email': email,
      'otp': otp,
    });

    return ApiResponse(
      success: result['success'] ?? false,
      message: result['message'] ?? 'Something went wrong',
      data: result['data'] != null
          ? LoginResponse.fromJson(result['data'])
          : null,
    );
  }

  // ── Resend OTP ───────────────────────────────────
  static Future<ApiResponse> resendOtp(String email) async {
    final encodedEmail = Uri.encodeQueryComponent(email);
    final result = await ApiService.post(
      '${ApiConfig.resendOtp}?email=$encodedEmail',
      {},
    );

    return ApiResponse(
      success: result['success'] ?? false,
      message: result['message'] ?? 'Something went wrong',
    );
  }

  // ── Login ────────────────────────────────────────
  static Future<ApiResponse<LoginResponse>> login({
    required String email,
    required String password,
  }) async {
    final result = await ApiService.post(ApiConfig.login, {
      'email': email,
      'password': password,
    });

    return ApiResponse(
      success: result['success'] ?? false,
      message: result['message'] ?? 'Something went wrong',
      data: result['data'] != null
          ? LoginResponse.fromJson(result['data'])
          : null,
    );
  }

  // ── Forgot Password (send OTP) ────────────────────
  static Future<ApiResponse> forgotPassword(String email) async {
    final result = await ApiService.post(ApiConfig.forgotPassword, {
      'email': email,
    });

    return ApiResponse(
      success: result['success'] ?? false,
      message: result['message'] ?? 'Something went wrong',
    );
  }

  // ── Reset Password (verify OTP + new password) ──
  static Future<ApiResponse> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final result = await ApiService.post(ApiConfig.resetPassword, {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });

    return ApiResponse(
      success: result['success'] ?? false,
      message: result['message'] ?? 'Something went wrong',
    );
  }

  static Future<void> handleLoginSuccess(LoginResponse data) async {
    await StorageService.saveLoginData(data);
  }

  static Future<void> logout() async {
    // Server revocation is attempted before clearing the local session.
    await ApiService.securePost(ApiConfig.logout, {});
    await StorageService.clearAll();
  }

  static Future<bool> isLoggedIn() async {
    if (!await StorageService.isLoggedIn()) return false;
    final result = await ApiService.refreshSession();
    return result != RefreshResult.invalid;
  }
}
