/// Refresh failures distinguish a revoked session from temporary connectivity.
enum RefreshResult { refreshed, invalid, unavailable }

/// One refresh per client session. Late 401s reuse a newer access token.
class SessionRefresh {
  SessionRefresh({required this.readAccessToken, required this.refresh});

  final Future<String?> Function() readAccessToken;
  final Future<RefreshResult> Function() refresh;
  Future<RefreshResult>? _pending;

  Future<RefreshResult> run({String? rejectedAccessToken}) async {
    if (_pending != null) return _pending!;
    if (rejectedAccessToken != null) {
      final current = await readAccessToken();
      if (current != null && current != rejectedAccessToken) {
        return RefreshResult.refreshed;
      }
    }
    // Another caller may have started while storage was being read.
    if (_pending != null) return _pending!;
    final work = refresh();
    _pending = work;
    try {
      return await work;
    } finally {
      if (identical(_pending, work)) _pending = null;
    }
  }
}
