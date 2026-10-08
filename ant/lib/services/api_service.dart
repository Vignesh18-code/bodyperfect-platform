import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';
import 'session_refresh.dart';
import '../config/api_config.dart';

class ApiService {
  static final _sessionRefresh = SessionRefresh(
    readAccessToken: StorageService.getAccessToken,
    refresh: _rotateTokens,
  );

  static Map<String, dynamic> _failure(String message, String code) => {
    'success': false,
    'message': message,
    'code': code,
  };

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return _failure('Unexpected server response', 'SERVER_ERROR');
    }
    return {...decoded, 'httpStatus': response.statusCode};
  }

  static Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      return _decode(
        await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30)),
      );
    } catch (_) {
      return _failure('Connection failed. Please try again', 'UNAVAILABLE');
    }
  }

  static Future<Map<String, dynamic>> secureGet(String url) =>
      _secure('GET', url);
  static Future<Map<String, dynamic>> securePost(
    String url,
    Map<String, dynamic> body,
  ) => _secure('POST', url, body);
  static Future<Map<String, dynamic>> securePut(
    String url, {
    Map<String, dynamic>? body,
  }) => _secure('PUT', url, body);
  static Future<Map<String, dynamic>> securePatch(
    String url, {
    Map<String, dynamic>? body,
  }) => _secure('PATCH', url, body);
  static Future<Map<String, dynamic>> secureDelete(String url) =>
      _secure('DELETE', url);

  static Future<Map<String, dynamic>> _secure(
    String method,
    String url, [
    Map<String, dynamic>? body,
  ]) async {
    try {
      var token = await StorageService.getAccessToken();
      if (token == null) {
        return _failure('Please login again', 'SESSION_EXPIRED');
      }
      Future<http.Response> send(String access) async {
        final request = http.Request(method, Uri.parse(url));
        request.headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $access',
        });
        if (body != null) request.body = jsonEncode(body);
        return http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 30)),
        ).timeout(const Duration(seconds: 30));
      }

      var response = await send(token);
      if (response.statusCode == 401) {
        final result = await refreshSession(rejectedAccessToken: token);
        if (result != RefreshResult.refreshed) return _refreshFailure(result);
        token = await StorageService.getAccessToken();
        if (token == null) return _refreshFailure(RefreshResult.invalid);
        response = await send(token);
      }
      return _decode(response);
    } catch (_) {
      return _failure('Connection failed. Please try again', 'UNAVAILABLE');
    }
  }

  /// Fetch private files with the same token rotation as JSON requests.
  static Future<Uint8List> securePdf(String url) async {
    var token = await StorageService.getAccessToken();
    if (token == null) throw StateError('Please sign in again.');
    Future<http.Response> send(String access) => http
        .get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $access',
            'Accept': 'application/pdf',
          },
        )
        .timeout(const Duration(seconds: 30));
    var response = await send(token);
    if (response.statusCode == 401) {
      final result = await refreshSession(rejectedAccessToken: token);
      if (result != RefreshResult.refreshed) {
        throw StateError('Please sign in again.');
      }
      token = await StorageService.getAccessToken();
      if (token == null) throw StateError('Please sign in again.');
      response = await send(token);
    }
    if (response.statusCode != 200 ||
        !(response.headers['content-type'] ?? '').startsWith(
          'application/pdf',
        ) ||
        response.bodyBytes.length > 5 * 1024 * 1024 ||
        response.bodyBytes.length < 5 ||
        ascii.decode(response.bodyBytes.take(5).toList(), allowInvalid: true) !=
            '%PDF-') {
      throw StateError('Report unavailable. Refresh and try again.');
    }
    return response.bodyBytes;
  }

  static Future<Map<String, dynamic>> secureUpload(
    String url,
    Uint8List bytes, {
    required String filename,
    String fieldName = 'file',
  }) async {
    try {
      var token = await StorageService.getAccessToken();
      if (token == null) return _refreshFailure(RefreshResult.invalid);
      Future<http.Response> send(String access) async {
        final request = http.MultipartRequest('POST', Uri.parse(url));
        request.headers['Authorization'] = 'Bearer $access';
        final extension = filename.split('.').last.toLowerCase();
        final mediaType = switch (extension) {
          'png' => http.MediaType('image', 'png'),
          'jpg' || 'jpeg' => http.MediaType('image', 'jpeg'),
          'webp' => http.MediaType('image', 'webp'),
          _ => http.MediaType('application', 'octet-stream'),
        };
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: filename,
            contentType: mediaType,
          ),
        );
        return http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 60)),
        ).timeout(const Duration(seconds: 60));
      }

      var response = await send(token);
      if (response.statusCode == 401) {
        final result = await refreshSession(rejectedAccessToken: token);
        if (result != RefreshResult.refreshed) return _refreshFailure(result);
        token = await StorageService.getAccessToken();
        if (token == null) return _refreshFailure(RefreshResult.invalid);
        response = await send(token);
      }
      return _decode(response);
    } catch (_) {
      return _failure('Upload failed. Please try again', 'UNAVAILABLE');
    }
  }

  static Map<String, dynamic> _refreshFailure(RefreshResult result) =>
      result == RefreshResult.invalid
      ? _failure('Session expired. Please login again', 'SESSION_EXPIRED')
      : _failure('Connection unavailable. Please try again', 'UNAVAILABLE');

  static Future<RefreshResult> refreshSession({String? rejectedAccessToken}) =>
      _sessionRefresh.run(rejectedAccessToken: rejectedAccessToken);

  static Future<RefreshResult> _rotateTokens() async {
    final generation = StorageService.sessionGeneration;
    try {
      final refresh = await StorageService.getRefreshToken();
      if (refresh == null) return RefreshResult.invalid;
      final response = await http
          .post(
            Uri.parse(ApiConfig.refresh),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(const Duration(seconds: 10));
      if (generation != StorageService.sessionGeneration) {
        return RefreshResult.invalid;
      }
      if (response.statusCode == 401) {
        await StorageService.clearAll();
        return RefreshResult.invalid;
      }
      if (response.statusCode != 200) return RefreshResult.unavailable;
      final data = _decode(response)['data'];
      if (data is! Map ||
          data['accessToken'] is! String ||
          data['refreshToken'] is! String) {
        return RefreshResult.unavailable;
      }
      await StorageService.updateTokens(
        data['accessToken'],
        data['refreshToken'],
        generation: generation,
      );
      return generation == StorageService.sessionGeneration
          ? RefreshResult.refreshed
          : RefreshResult.invalid;
    } catch (_) {
      // Preserve credentials on timeout, offline, throttling or server failure.
      return RefreshResult.unavailable;
    }
  }
}
