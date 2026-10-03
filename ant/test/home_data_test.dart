import 'dart:async';
import 'package:ant/screens/home/home_data_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'empty treatment is successful, failed treatment is not empty',
    () async {
      var failed = false;
      final home = HomeDataController(
        fetch: (url) async => url.endsWith('profile')
            ? {
                'success': true,
                'data': {'fullName': 'Test', 'totalPoints': 8},
              }
            : {'success': !failed, 'data': null},
      );
      addTearDown(home.dispose);
      await home.refresh();
      expect(home.treatmentLoaded, isTrue);
      expect(home.treatmentError, isNull);
      failed = true;
      await home.refresh();
      expect(home.treatmentError, isNotNull);
      expect(home.profile?.totalPoints, 8);
    },
  );
  test(
    'offline refresh preserves previous treatment and valid profile',
    () async {
      var offline = false;
      final home = HomeDataController(
        fetch: (url) async {
          if (offline) throw Exception('offline');
          return {
            'success': true,
            'data': url.endsWith('profile')
                ? {'fullName': 'Test'}
                : {'id': 7, 'protocolName': 'My plan'},
          };
        },
      );
      addTearDown(home.dispose);
      await home.refresh();
      offline = true;
      await home.refresh();
      expect(home.protocol?.id, 7);
      expect(home.profile?.fullName, 'Test');
      expect(home.treatmentError, isNotNull);
      expect(home.profileError, isNotNull);
      expect(home.loading, isFalse);
    },
  );
  test(
    'expired session clears private data instead of displaying stale care',
    () async {
      var expired = false;
      final home = HomeDataController(
        fetch: (url) async => expired
            ? {'success': false, 'code': 'SESSION_EXPIRED'}
            : {
                'success': true,
                'data': url.endsWith('profile')
                    ? {'fullName': 'Test'}
                    : {'id': 7},
              },
      );
      addTearDown(home.dispose);
      await home.refresh();
      expired = true;
      await home.refresh();
      expect(home.sessionExpired, isTrue);
      expect(home.profile, isNull);
      expect(home.protocol, isNull);
      expect(home.treatmentLoaded, isFalse);
    },
  );
  test(
    'overlapping refreshes share requests and disposing ignores their results',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      final home = HomeDataController(
        fetch: (_) {
          calls++;
          return pending.future;
        },
      );
      final first = home.refresh();
      final second = home.refresh();
      expect(calls, 2);
      home.dispose();
      pending.complete({'success': true, 'data': null});
      await Future.wait([first, second]);
    },
  );
  test('malformed treatment produces a recoverable error', () async {
    final home = HomeDataController(
      fetch: (_) async => {'success': true, 'data': 'invalid'},
    );
    addTearDown(home.dispose);
    await home.refresh();
    expect(home.treatmentLoaded, isFalse);
    expect(home.treatmentError, isNotNull);
  });
}
