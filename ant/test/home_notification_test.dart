import 'package:ant/screens/home/widgets/notification_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'home_page_test.dart' show mountHome;

void main() {
  testWidgets('notification failure is not an empty inbox and retry recovers', (
    tester,
  ) async {
    var online = false;
    await mountHome(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showNotificationPanel(
              context,
              fetch: (url) async => online
                  ? {
                      'success': true,
                      'data': url.contains('unread-count')
                          ? {'unreadCount': 0}
                          : [],
                    }
                  : {'success': false},
            ),
            child: const Text('Open inbox'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load notifications'), findsWidgets);
    expect(find.text('All caught up'), findsNothing);
    online = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsWidgets);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'notification pagination exposes older notices without duplicates',
    (tester) async {
      final requests = <String>[];
      Map<String, dynamic> notice(int id) => {
        'id': id,
        'title': 'Notice $id',
        'message': 'Test',
        'isRead': true,
        'createdAt': '2026-09-30T10:00:00',
      };
      await mountHome(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showNotificationPanel(
                context,
                fetch: (url) async {
                  requests.add(url);
                  return {
                    'success': true,
                    'data': url.contains('unread-count')
                        ? {'unreadCount': 0}
                        : url.contains('page=1')
                        ? [notice(19), notice(20)]
                        : List.generate(20, notice),
                  };
                },
              ),
              child: const Text('Open inbox'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open inbox'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Load more'),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Notice 20'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Notice 20'), findsOneWidget);
      expect(find.text('Notice 19'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      expect(requests.where((u) => u.contains('page=1')).length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
