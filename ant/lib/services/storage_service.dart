import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response.dart';

class StorageService {
  static int sessionGeneration = 0;
  static const _tokenPairKey = "token_pair";
  static Future<void> _writes = Future.value();

  static Future<void> _serialize(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  // Secure storage for tokens (encrypted)
  static const _secureStorage = FlutterSecureStorage();

  // Keys
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _fullNameKey = 'full_name';
  static const _emailKey = 'email';
  static const _roleKey = 'role';
  static const _totalPointsKey = 'total_points';
  static const _isLoggedInKey = 'is_logged_in';

  // ── Save all login data ──────────────────────────
  static Future<void> saveLoginData(LoginResponse data) {
    final generation = ++sessionGeneration;
    return _serialize(() async {
      if (generation != sessionGeneration) return;
      await _writeTokens(data.accessToken, data.refreshToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fullNameKey, data.fullName);
      await prefs.setString(_emailKey, data.email);
      await prefs.setString(_roleKey, data.role);
      await prefs.setInt(_totalPointsKey, data.totalPoints);
      await prefs.setBool(_isLoggedInKey, true);
    });
  }

  static Future<void> _writeTokens(String access, String refresh) async {
    await _secureStorage.write(
      key: _tokenPairKey,
      value: jsonEncode({'accessToken': access, 'refreshToken': refresh}),
    );
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  // ── Get tokens ───────────────��───────────────────
  static Future<String?> getAccessToken() async {
    await _writes;
    final pair = await _secureStorage.read(key: _tokenPairKey);
    if (pair != null) return jsonDecode(pair)["accessToken"] as String?;
    return await _secureStorage.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    await _writes;
    final pair = await _secureStorage.read(key: _tokenPairKey);
    if (pair != null) return jsonDecode(pair)["refreshToken"] as String?;
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  static Future<void> updateTokens(
    String access,
    String refresh, {
    required int generation,
  }) {
    return _serialize(() async {
      if (generation != sessionGeneration) return;
      await _writeTokens(access, refresh);
    });
  }

  // ── Get user info ────────────────────────────────
  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fullNameKey);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  static Future<int> getTotalPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalPointsKey) ?? 0;
  }

  // ── Check if logged in ───────────────────────────
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // ── Clear all data (logout) ──────────────────────
  static Future<void> clearAll() async {
    sessionGeneration++;
    await _serialize(() async {
      final prefs = await SharedPreferences.getInstance();
      await _secureStorage.deleteAll();
      await prefs.clear();
    });
  }
}
