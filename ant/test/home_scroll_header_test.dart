import 'package:ant/screens/home/widgets/home_header.dart';
import 'package:ant/screens/home/widgets/home_scroll_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

Widget preview(TextEditingController search) => ScreenUtilInit(
  designSize: const Size(375, 812),
  builder: (context, child) => MaterialApp(
    home: Scaffold(
      body: HomeScrollLayout(
        cornerOverlap: 28,
        headerBuilder: (visible) => HomeHeader(
          fullName: 'Vignesh',
          initials: 'V',
          totalPoints: 0,
          searchVisible: visible,
          searchController: search,
          onSearchChanged: (_) {},
        ),
        child: SingleChildScrollView(
          key: const Key('home-scroll'),
          padding: const EdgeInsets.only(top: 28),
          child: Column(
            children: [
              SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: List.generate(
                    8,
                    (i) => SizedBox(width: 200, child: Text('Card $i')),
                  ),
                ),
              ),
              const SizedBox(height: 2200),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('only search collapses on scrolling and returns on reversing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(preview(search));
    await tester.pumpAndSettle();
    final header = find.byType(HomeHeader);
    final expanded = tester.getSize(header).height;
    final scroll = find.byKey(const Key('home-scroll'));
    expect(tester.getTopLeft(scroll).dy, tester.getBottomLeft(header).dy - 28);
    expect(
      tester.getTopLeft(find.text('Card 0')).dy,
      tester.getBottomLeft(header).dy,
    );
    final profileY = tester.getTopLeft(find.text('Vignesh')).dy;
    await tester.drag(find.byType(ListView), const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, expanded);
    await tester.drag(
      find.byKey(const Key('home-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, lessThan(expanded - 40));
    expect(tester.getTopLeft(find.text('Vignesh')).dy, profileY);
    expect(tester.getTopLeft(scroll).dy, tester.getBottomLeft(header).dy - 28);
    expect(find.byType(TextField).hitTestable(), findsNothing);
    await tester.drag(
      find.byKey(const Key('home-scroll')),
      const Offset(0, 70),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(header).height, expanded);
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active search remains visible and preserves the query', (
    tester,
  ) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(preview(search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'appointment');
    final expanded = tester.getSize(find.byType(HomeHeader)).height;
    await tester.drag(
      find.byKey(const Key('home-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(HomeHeader)).height, expanded);
    expect(search.text, 'appointment');
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
