import 'dart:typed_data';
import '../config/api_config.dart';
import 'api_service.dart';

class UserProfileData {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final int totalPoints;
  final int unreadNotifications;
  final String? referralCode;
  final String? profileImageUrl;
  final String? preferredTreatment;

  UserProfileData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.totalPoints,
    required this.unreadNotifications,
    this.referralCode,
    this.profileImageUrl,
    this.preferredTreatment,
  });

  /// Full URL (with base) for the profile image, or null if user has none.
  String? get fullImageUrl {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) return null;
    if (profileImageUrl!.startsWith('http')) return profileImageUrl;
    return ApiConfig.baseUrl + profileImageUrl!;
  }

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      totalPoints: json['totalPoints'] ?? 0,
      unreadNotifications: json['unreadNotifications'] ?? 0,
      referralCode: json['referralCode'],
      profileImageUrl: json['profileImageUrl'],
      preferredTreatment: json['preferredTreatment'],
    );
  }
}

class ProfileUpdateResult {
  final bool success;
  final String message;
  final UserProfileData? profile;

  ProfileUpdateResult({
    required this.success,
    required this.message,
    this.profile,
  });
}

class UserService {
  static Future<UserProfileData?> getProfile() async {
    final response = await ApiService.secureGet(ApiConfig.userProfile);

    if (response['success'] == true && response['data'] != null) {
      return UserProfileData.fromJson(response['data']);
    }

    return null;
  }

  /// Update name and/or preferred treatment.
  static Future<ProfileUpdateResult> updateProfile({
    String? fullName,
    String? preferredTreatment,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (preferredTreatment != null) {
      body['preferredTreatment'] = preferredTreatment;
    }

    final response = await ApiService.securePut(
      ApiConfig.userProfile,
      body: body,
    );

    if (response['success'] == true && response['data'] != null) {
      return ProfileUpdateResult(
        success: true,
        message: response['message'] ?? 'Profile updated',
        profile: UserProfileData.fromJson(response['data']),
      );
    }

    return ProfileUpdateResult(
      success: false,
      message: response['message'] ?? 'Failed to update profile',
    );
  }

  /// Upload bytes so browser-picked photos work as well as native files.
  static Future<ProfileUpdateResult> uploadProfileImage(
    Uint8List bytes,
    String filename,
  ) async {
    final response = await ApiService.secureUpload(
      ApiConfig.userProfileImage,
      bytes,
      filename: filename,
    );

    if (response['success'] == true && response['data'] != null) {
      return ProfileUpdateResult(
        success: true,
        message: response['message'] ?? 'Image uploaded',
        profile: UserProfileData.fromJson(response['data']),
      );
    }

    return ProfileUpdateResult(
      success: false,
      message: response['message'] ?? 'Failed to upload image',
    );
  }
}
