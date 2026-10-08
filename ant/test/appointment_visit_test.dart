import 'package:ant/screens/appointments/appointments_screen.dart';
import 'package:ant/screens/appointments/widgets/visit_guide.dart';
import 'package:ant/services/appointment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'home_page_test.dart' show mountHome;

AppointmentData booking({String status = 'PENDING', bool voucher = false}) =>
    AppointmentData(
      id: 7,
      appointmentDate: '2035-10-20',
      appointmentTime: '10:30:00',
      branch: 'MARINA',
      status: status,
      giftVoucherBooking: voucher,
    );

void main() {
  testWidgets('voucher visit guide, clinic contact and call fallback work', (
    tester,
  ) async {
    String? dialed;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          dialed = (call.arguments as Map)['url'] as String?;
          return false;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    var contacts = 0;
    await mountHome(
      tester,
      Scaffold(
        body: AppointmentsScreen(
          fetchReports: () async => [],
          fetch: () async => [booking(voucher: true)],
          onContactClinic: () => contacts++,
        ),
      ),
    );
    expect(find.text('Your AED 1,000 voucher is claimed'), findsOneWidget);
    expect(
      find.textContaining('Your request is with the clinic'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Call clinic'));
    await tester.tap(find.text('Call clinic'));
    await tester.pumpAndSettle();
    expect(dialed, 'tel:+919384609073');
    expect(find.text('Copy number'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Chat with our team'));
    await tester.tap(find.text('Chat with our team'));
    expect(contacts, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'normal booking has no voucher and confirmed status is accurate',
    (tester) async {
      await mountHome(
        tester,
        Scaffold(
          body: AppointmentsScreen(
            fetchReports: () async => [],
            fetch: () async => [booking(status: 'CONFIRMED')],
          ),
        ),
      );
      expect(find.text('Your AED 1,000 voucher is claimed'), findsNothing);
      expect(find.textContaining('Your visit is confirmed.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('guide fits large text on a narrow screen', (tester) async {
    await mountHome(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: VisitGuide(
            status: 'CHECKED_IN',
            voucherBooking: true,
            onContactClinic: () {},
          ),
        ),
      ),
      width: 320,
      scale: 2,
    );
    expect(find.textContaining('You’re checked in.'), findsOneWidget);
    await tester.ensureVisible(find.text('Chat with our team'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'load failure is not an empty appointment state and retry works',
    (tester) async {
      var online = false;
      await mountHome(
        tester,
        Scaffold(
          body: AppointmentsScreen(
            fetchReports: () async => [],
            fetch: () async {
              if (!online) throw StateError('offline');
              return [];
            },
          ),
        ),
      );
      expect(find.text('Plan your next visit'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      online = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Plan your next visit'), findsOneWidget);
      expect(find.byType(VisitGuide), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
