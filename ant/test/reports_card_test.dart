import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:ant/screens/appointments/widgets/reports_card.dart';
import 'package:ant/screens/appointments/appointments_screen.dart';
import 'package:ant/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'home_page_test.dart' show mountHome;

final samples = [
  PatientReport(
    id: 1,
    title: 'Consultation summary',
    date: DateTime(2026, 10, 8),
    sizeBytes: 248000,
    branch: 'MARINA',
  ),
  PatientReport(
    id: 2,
    title: 'Blood test results',
    date: DateTime(2026, 10, 6),
    sizeBytes: 1258000,
    branch: 'MARINA',
  ),
];
void main() {
  testWidgets('empty report list occupies no space', (tester) async {
    await mountHome(tester, const Scaffold(body: ReportsCard(reports: [])));
    expect(find.text('Your reports'), findsNothing);
    expect(tester.getSize(find.byType(ReportsCard)), Size.zero);
  });
  testWidgets('download prevents duplicate taps, handles failure and retries', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await mountHome(
      tester,
      Scaffold(
        body: ReportsCard(
          reports: [samples.first],
          onDownload: (report, rect) async {
            expect(report.id, 1);
            expect(rect.width, greaterThan(0));
            calls++;
            if (calls == 1) await pending.future;
          },
        ),
      ),
    );
    await tester.tap(find.text('Download'));
    await tester.pump();
    expect(find.text('Preparing…'), findsOneWidget);
    await tester.tap(find.text('Preparing…'));
    expect(calls, 1);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Download'), findsOneWidget);
    expect(find.textContaining('Could not open'), findsNothing);
    await mountHome(tester, const Scaffold(body: ReportsCard(reports: [])));
    expect(find.text('Your reports'), findsNothing);
  });
  testWidgets('report card supports narrow screens and large text', (
    tester,
  ) async {
    await mountHome(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: ReportsCard(reports: samples, onDownload: (_, _) async {}),
        ),
      ),
      width: 320,
      scale: 2,
    );
    expect(find.text('Your reports'), findsOneWidget);
    await tester.ensureVisible(find.text('Download').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'appointment screen loads real reports even without active appointment',
    (tester) async {
      await mountHome(
        tester,
        Scaffold(
          body: AppointmentsScreen(
            fetch: () async => [],
            fetchReports: () async => samples,
          ),
        ),
      );
      expect(find.text('Your reports'), findsOneWidget);
      expect(find.text('Consultation summary'), findsOneWidget);
    },
  );
  testWidgets('sample design preview stays in tests only', (tester) async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/inter/Inter-Regular.ttf'));
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/inter/Inter-Regular.ttf'))).load();
    final key = GlobalKey();
    await mountHome(
      tester,
      RepaintBoundary(
        key: key,
        child: Theme(
          data: ThemeData(fontFamily: 'Inter'),
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F6FB),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    const Text(
                      'Appointments',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'DESIGN PREVIEW · SAMPLE REPORTS',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    ReportsCard(reports: samples, onDownload: (_, _) async {}),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('REPORT_PREVIEW')) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/bodyperfect-reports-preview.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
