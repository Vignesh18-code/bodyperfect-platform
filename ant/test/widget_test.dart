import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ant/screens/auth/login_screen.dart';
import 'package:ant/screens/home/widgets/next_treatment_session.dart';
import 'package:ant/screens/treatment/widgets/protocol_instructions_card.dart';
import 'package:ant/services/treatment_service.dart';

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  double width = 375,
}) async {
  tester.view.physicalSize = Size(width, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: child is LoginScreen ? child : Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('Login identifies missing fields without submitting', (
    tester,
  ) async {
    await mount(tester, const LoginScreen());
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Login rejects malformed email', (tester) async {
    await mount(tester, const LoginScreen());
    await tester.enterText(find.byType(TextFormField).first, 'a@@b.com');
    await tester.enterText(find.byType(TextFormField).last, 'ExistingPassword');
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Unscheduled card never invents date, time or session number', (
    tester,
  ) async {
    await mount(
      tester,
      const NextTreatmentSession(
        protocolName: 'Test plan',
        status: 'ACTIVE',
        totalSessions: 6,
        completedSessions: 2,
      ),
    );
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('2 of 6 completed'), findsOneWidget);
    expect(find.text('10:30 AM'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'Scheduled card works at width $width and View Plan navigates',
      (tester) async {
        var opened = false;
        await mount(
          tester,
          NextTreatmentSession(
            protocolName: 'A longer treatment plan name for responsive testing',
            status: 'ACTIVE',
            totalSessions: 6,
            completedSessions: 2,
            onViewPlan: () => opened = true,
            nextSession: SessionData(
              id: 1,
              protocolId: 1,
              protocolName: 'Test plan',
              sessionNumber: 3,
              sessionName: 'Review',
              sessionDate: '2030-05-15',
              sessionTime: '10:30',
              durationMinutes: 30,
              status: 'SCHEDULED',
            ),
          ),
          width: width,
        );
        expect(find.text('15'), findsOneWidget);
        expect(find.text('10:30 AM'), findsOneWidget);
        expect(find.text('30 min'), findsOneWidget);
        await tester.tap(find.text('View Plan'));
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Care instructions retain the full clinic text', (tester) async {
    const instructions =
        'Before your visit\nBring your documents.\nAfter your visit\nFollow your clinic’s instructions.\nContact the team for clarification.';
    await mount(
      tester,
      const ProtocolInstructionsCard(instructions: instructions),
    );
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, instructions);
    expect(text.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });
}
