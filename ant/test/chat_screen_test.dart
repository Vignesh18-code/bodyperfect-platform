import 'package:ant/screens/chat/chat_screen.dart';
import 'package:ant/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeChatService extends ChatService {
  bool available = true, failSend = false, memory = true;
  String note = '';
  final sent = <Map<String, dynamic>>[];
  final gets = <String>[];
  int deletes = 0;
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic> ok(dynamic data) => {'success': true, 'data': data};
  @override
  Future<Map<String, dynamic>> get(String url) async {
    gets.add(url);
    if (url.endsWith('/assistant')) {
      return ok({
        'available': available,
        'knowledgePages': 70,
        'displayName': 'Elena Testclient',
      });
    }
    if (url.contains('/assistant/history')) return ok(history);
    if (url.endsWith('/preferences')) {
      return ok({'memoryEnabled': memory, 'note': note});
    }
    if (url.endsWith('/branches')) return ok(['BURJUMAN', 'MARINA']);
    return ok({'items': [], 'hasEarlier': false});
  }

  @override
  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    if (url.contains('/threads?')) return ok({'id': 1});
    sent.add(Map.of(body));
    if (failSend) {
      return {
        'success': false,
        'message': 'Connection interrupted. Please retry.',
      };
    }
    if (url.endsWith('/messages')) {
      return ok({'id': 1, 'body': body['body'], 'senderRole': 'PATIENT'});
    }
    return ok({
      'id': 1,
      'clientId': body['clientId'],
      'question': body['question'],
      'state': 'COMPLETED',
      'answer': 'You can request a consultation with the clinic.',
      'sources': [
        {
          'id': 'S1',
          'title': 'Clinic services',
          'url': 'https://www.bodyperfect.ae/services/',
        },
      ],
      'actions': ['BOOK_APPOINTMENT', 'VIEW_TREATMENT', 'CLINIC_TEAM'],
      'followUps': ['Will I need blood tests?'],
    });
  }

  @override
  Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    memory = body['memoryEnabled'];
    note = body['note'];
    return ok(body);
  }

  @override
  Future<Map<String, dynamic>> delete(String url) async {
    deletes++;
    history = [];
    note = '';
    return ok({});
  }
}

Future<void> mountChat(
  WidgetTester tester,
  FakeChatService api, {
  double width = 390,
  double scale = 1,
  double keyboard = 0,
  VoidCallback? book,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: ChatScreen(
          service: api,
          onBookAppointment: () async {
            book?.call();
          },
          onOpenTreatment: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> send(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField).first, question);
  await tester.pump();
  await tester.tap(find.byTooltip('Send message'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('consent gates AI; sources and booking remain explicit actions', (
    tester,
  ) async {
    final api = FakeChatService();
    int bookings = 0;
    await mountChat(tester, api, book: () => bookings++);
    await send(tester, 'Can I book a consultation?');
    expect(api.sent, isEmpty);
    expect(find.text('Meet your AI care assistant'), findsOneWidget);
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(api.sent.single['consent'], true);
    expect(find.text('Clinic services'), findsOneWidget);
    expect(
      find.bySemanticsLabel('You can request a consultation with the clinic.'),
      findsOneWidget,
    );
    expect(bookings, 0);
    await tester.ensureVisible(find.text('Book a visit'));
    await tester.tap(find.text('Book a visit'));
    expect(bookings, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('connection retry preserves draft and idempotency key', (
    tester,
  ) async {
    final api = FakeChatService()..failSend = true;
    await mountChat(tester, api);
    await send(tester, 'My next appointment');
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expect(find.text('My next appointment'), findsOneWidget);
    api.failSend = false;
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(api.sent.length, 2);
    expect(api.sent[0]['clientId'], api.sent[1]['clientId']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('staff support works while AI unavailable', (tester) async {
    final api = FakeChatService()..available = false;
    await mountChat(tester, api);
    await tester.tap(find.text('Clinic team'));
    await tester.pumpAndSettle();
    await send(tester, 'Please help with my booking');
    expect(api.sent.single['body'], 'Please help with my booking');
    expect(api.sent.single.containsKey('consent'), false);
    expect(find.text('Meet your AI care assistant'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'memory can be disabled, saved and history cleared with confirmation',
    (tester) async {
      final api = FakeChatService();
      await mountChat(tester, api);
      await tester.tap(find.byTooltip('Memory and privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.enterText(
        find.widgetWithText(TextField, 'Preferences to remember'),
        'Simple English',
      );
      await tester.tap(find.text('Save preferences'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.memory, false);
      expect(api.note, 'Simple English');
      await tester.tap(find.byTooltip('Memory and privacy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear AI history'));
      await tester.pumpAndSettle();
      expect(api.deletes, 0);
      await tester.tap(find.text('Clear AI history').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.deletes, 1);
      expect(api.note, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small screen with large text and keyboard has no overflow', (
    tester,
  ) async {
    final api = FakeChatService();
    await mountChat(tester, api, width: 320, scale: 1.5, keyboard: 290);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Clinic team'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('personal greeting and follow-up chips continue the chat', (
    tester,
  ) async {
    final api = FakeChatService();
    await mountChat(tester, api);
    expect(find.text('Hello, Elena.'), findsOneWidget);
    await tester.tap(find.text('Start a diet plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Will I need blood tests?'));
    await tester.tap(find.text('Will I need blood tests?'));
    await tester.pumpAndSettle();
    expect(api.sent.length, 2);
    expect(api.sent.last['question'], 'Will I need blood tests?');
    expect(tester.takeException(), isNull);
  });
  testWidgets('reopening chat reloads earlier messages without duplication', (
    tester,
  ) async {
    final api = FakeChatService()
      ..history = [
        {
          'id': 8,
          'question': 'I want a diet consultation',
          'answer': 'We can discuss a consultation.',
          'state': 'COMPLETED',
          'createdAt': DateTime.now()
              .subtract(const Duration(minutes: 6))
              .toIso8601String(),
          'sources': <dynamic>[],
          'actions': <String>[],
          'followUps': <String>[],
        },
      ];
    await mountChat(tester, api);
    expect(find.text('I want a diet consultation'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await mountChat(tester, api);
    expect(find.text('I want a diet consultation'), findsOneWidget);
    expect(find.text('We can discuss a consultation.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
