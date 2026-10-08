import 'package:ant/screens/home/home_screen.dart';
import 'package:ant/screens/home/widgets/gift_voucher_card.dart';
import 'package:ant/screens/home/widgets/promo_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mountHome(
  WidgetTester tester,
  Widget child, {
  double width = 375,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, childWidget) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> homeResponse(String url) => {
  'success': true,
  'data': url.endsWith('profile')
      ? {
          'id': 1,
          'fullName': 'Home test',
          'totalPoints': 12,
          'unreadNotifications': 2,
        }
      : {
          'id': 1,
          'protocolName': 'Test treatment',
          'status': 'ACTIVE',
          'totalSessions': 5,
          'completedSessions': 2,
          'nextSession': {
            'sessionNumber': 3,
            'sessionDate': '2030-10-20',
            'sessionTime': '10:30:00',
            'durationMinutes': 30,
          },
        },
};

void main() {
  testWidgets('claimed voucher stays hidden when home is recreated', (
    tester,
  ) async {
    for (var i = 0; i < 2; i++) {
      await mountHome(
        tester,
        HomeScreen(
          fetch: (url) async {
            final response = homeResponse(url);
            if (url.endsWith('profile')) {
              (response['data'] as Map<String, dynamic>)['giftVoucherClaimed'] =
                  true;
            }
            return response;
          },
        ),
      );
      expect(find.byType(GiftVoucherCard), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
    await mountHome(
      tester,
      HomeScreen(fetch: (url) async => homeResponse(url)),
    );
    expect(find.byType(GiftVoucherCard), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('home loads only its data and promo opens matching service', (
    tester,
  ) async {
    final requests = <String>[];
    await mountHome(
      tester,
      HomeScreen(
        fetch: (url) async {
          requests.add(url);
          return homeResponse(url);
        },
      ),
    );
    expect(requests.length, 2);
    expect(find.text('Home test'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    await tester.tap(find.text('Explore').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close program details'), findsOneWidget);
    expect(find.text('IV Therapy'), findsWidgets);
    await tester.tap(find.byTooltip('Close program details'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('home distinguishes offline from empty and retry recovers', (
    tester,
  ) async {
    var online = false;
    await mountHome(
      tester,
      HomeScreen(
        fetch: (url) async => online ? homeResponse(url) : {'success': false},
      ),
    );
    expect(find.text('No active treatment protocol'), findsNothing);
    expect(
      find.textContaining('Treatment information is unavailable'),
      findsOneWidget,
    );
    online = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Home test'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'home fits narrow screen with large text and scrolls to voucher',
    (tester) async {
      await mountHome(
        tester,
        HomeScreen(fetch: (url) async => homeResponse(url)),
        width: 320,
        scale: 1.5,
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -850),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('promo respects reduced motion and all promotions navigate', (
    tester,
  ) async {
    final opened = <int>[];
    await mountHome(
      tester,
      Scaffold(body: PromoSlider(onOpenService: opened.add)),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('IV THERAPY & PEPTIDES'), findsOneWidget);
    await tester.tap(find.text('Explore'));
    for (final pair in [(2, 'Book Now'), (3, 'Start Now')]) {
      await tester.tap(find.bySemanticsLabel('Show promotion ${pair.$1} of 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pair.$2));
    }
    expect(opened, [6, 1, 0]);
    await tester.pumpWidget(const SizedBox());
  });
}
