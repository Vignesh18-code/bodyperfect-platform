import 'package:flutter/services.dart';

class ExternalLinkService {
  static const MethodChannel _channel = MethodChannel('bodyperfect/external_links');

  static Future<bool> openUrl(String url) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return opened == true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openDirections({
    required String branch,
    required String fallbackUrl,
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>('openDirections', {
        'branch': branch,
        'fallbackUrl': fallbackUrl,
      });
      return opened == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> copyUrl(String url) {
    return Clipboard.setData(ClipboardData(text: url));
  }
}
