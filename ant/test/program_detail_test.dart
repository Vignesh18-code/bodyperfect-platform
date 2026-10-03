import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ant/screens/home/widgets/longevity_program.dart';
import 'package:ant/screens/home/widgets/longevity_programs.dart';
import 'package:ant/screens/home/widgets/program_detail_sheet.dart';
import 'package:ant/screens/appointments/widgets/book_appointment_sheet.dart';

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Program card opens details and booking keeps program context', (
    tester,
  ) async {
    String? selected;
    await mount(
      tester,
      LongevityPrograms(
        onBookAppointment: (program) async {
          selected = program;
        },
      ),
    );
    await tester.tap(find.bySemanticsLabel('Weightloss & Slimming'));
    await tester.pumpAndSettle();
    expect(
      find.text(LongevityProgram.catalog.first.description),
      findsOneWidget,
    );
    expect(find.byTooltip('Close program details'), findsOneWidget);
    expect(find.text('Call clinic'), findsOneWidget);
    final image = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image && widget.semanticLabel == 'Weightloss & Slimming',
      ),
    );
    expect(
      ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
      'assets/images/services/weightloss-slimming.jpg',
    );
    await tester.tap(find.text('Book appointment'));
    await tester.pumpAndSettle();
    expect(selected, 'Weightloss & Slimming');
    expect(find.byTooltip('Close program details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('View All opens a selected program; close does not book', (
    tester,
  ) async {
    var booked = false;
    await mount(
      tester,
      LongevityPrograms(
        onBookAppointment: (_) async {
          booked = true;
        },
      ),
    );
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Beauty & Aesthetics').last);
    await tester.pumpAndSettle();
    expect(find.text(LongevityProgram.catalog[1].description), findsOneWidget);
    await tester.tap(find.byTooltip('Close program details'));
    await tester.pumpAndSettle();
    expect(booked, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final setting in [(320.0, 1.0), (390.0, 2.0)]) {
    testWidgets(
      'Details fit width ${setting.$1} with text scale ${setting.$2}',
      (tester) async {
        await mount(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showProgramDetailSheet(
                context,
                LongevityProgram.catalog.last,
              ),
              child: const Text('Open'),
            ),
          ),
          width: setting.$1,
          scale: setting.$2,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Book appointment'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Call uses the supplied clinic number and handles unavailable dialer',
    (tester) async {
      String? dialed;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async {
              dialed = (call.arguments as Map)['url'] as String?;
              return false;
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/url_launcher'),
              null,
            ),
      );
      await mount(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showProgramDetailSheet(context, LongevityProgram.catalog[2]),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call clinic'));
      await tester.pumpAndSettle();
      expect(dialed, 'tel:+919384609073');
      expect(find.textContaining('cannot open the phone app'), findsOneWidget);
      expect(find.text('+919384609073'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all 12 website services are reachable and last service books its full name',
    (tester) async {
      String? selected;
      await mount(
        tester,
        LongevityPrograms(
          onBookAppointment: (name) async {
            selected = name;
          },
        ),
      );
      expect(LongevityProgram.catalog.length, 12);
      for (final service in LongevityProgram.catalog) {
        expect(
          (await rootBundle.load(service.imagePath)).lengthInBytes,
          greaterThan(0),
        );
      }
      await tester.dragUntilVisible(
        find.text('20 KGs in 60 Days'),
        find.byType(ListView),
        const Offset(-280, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel(LongevityProgram.catalog.last.title),
      );
      await tester.pumpAndSettle();
      expect(find.text(LongevityProgram.catalog.last.title), findsOneWidget);
      await tester.tap(find.text('Book appointment'));
      await tester.pumpAndSettle();
      expect(selected, LongevityProgram.catalog.last.title);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Appointment form prefills an editable program note', (
    tester,
  ) async {
    await mount(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showBookAppointmentSheet(
            context,
            initialNote: 'Interested in IV Therapy consultation.',
          ),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    expect(
      tester.widget<TextField>(input).controller!.text,
      'Interested in IV Therapy consultation.',
    );
    await tester.enterText(input, 'My question about this program');
    expect(
      tester.widget<TextField>(input).controller!.text,
      'My question about this program',
    );
    expect(tester.takeException(), isNull);
  });
}
