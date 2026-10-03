import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/treatment_service.dart';
import '../../services/user_service.dart';

typedef HomeFetch = Future<Map<String, dynamic>> Function(String url);

/// Home keeps successful data during a transient outage and never treats a
/// failed request as an empty treatment plan. Concurrent refreshes share work.
class HomeDataController extends ChangeNotifier {
  HomeDataController({HomeFetch? fetch})
    : _fetch = fetch ?? ApiService.secureGet;
  final HomeFetch _fetch;
  UserProfileData? profile;
  ProtocolData? protocol;
  bool loading = false;
  bool treatmentLoaded = false;
  bool sessionExpired = false;
  String? profileError;
  String? treatmentError;
  Future<void>? _pending;
  bool _disposed = false;

  Future<void> refresh() =>
      _pending ??= _load().whenComplete(() => _pending = null);

  Future<Map<String, dynamic>> _read(String url) async {
    try {
      return await _fetch(url);
    } catch (_) {
      return {'success': false};
    }
  }

  Future<void> _load() async {
    loading = true;
    notifyListeners();
    final results = await Future.wait([
      _read(ApiConfig.userProfile),
      _read(ApiConfig.treatmentActive),
    ]);
    if (_disposed) return;
    sessionExpired = results.any(
      (r) => r['code'] == 'SESSION_EXPIRED' || r['httpStatus'] == 401,
    );
    if (sessionExpired) {
      profile = null;
      protocol = null;
      treatmentLoaded = false;
      profileError = 'Please sign in again to load your account.';
      treatmentError = 'Please sign in again to load your treatment.';
    } else {
      profileError = null;
      treatmentError = null;
      try {
        if (results[0]['success'] != true ||
            results[0]['data'] is! Map<String, dynamic>) {
          throw const FormatException();
        }
        profile = UserProfileData.fromJson(results[0]['data']);
      } catch (_) {
        profileError = 'Your account details could not be refreshed.';
      }
      try {
        if (results[1]['success'] != true) throw const FormatException();
        final data = results[1]['data'];
        protocol = data == null
            ? null
            : ProtocolData.fromJson(data as Map<String, dynamic>);
        treatmentLoaded = true;
      } catch (_) {
        treatmentError = 'Your treatment information could not be refreshed.';
      }
    }
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
