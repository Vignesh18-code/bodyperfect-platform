import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ant/screens/home/widgets/quick_actions.dart';

void main() {
  testWidgets('carousel swipes and preserves all action destinations', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 375,
            child: QuickActions(
              onBookAppointment: () => calls.add('appointment'),
              onOpenTreatment: () => calls.add('treatment'),
              onGymMembership: () => calls.add('gym'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Book Appointment'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Treatment Plan'));
    await tester.tap(find.text('GYM Membership'));
    expect(calls, ['appointment', 'treatment', 'gym']);
    await tester.tap(find.byTooltip('Previous quick action'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Quick action group 1 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen supports large text and reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: QuickActions(onBookAppointment: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Next quick action'));
    await tester.pump();
    expect(find.bySemanticsLabel('Quick action group 2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
