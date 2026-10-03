import 'dart:async';
import 'dart:io';
// This check intentionally runs without Flutter/plugin packages.
// ignore: avoid_relative_lib_imports
import '../lib/services/session_refresh.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  var calls = 0;
  var current = 'old';
  var gate = Completer<RefreshResult>();
  final coordinator = SessionRefresh(
    readAccessToken: () async => current,
    refresh: () {
      calls++;
      return gate.future;
    },
  );
  final requests = List.generate(
    20,
    (_) => coordinator.run(rejectedAccessToken: 'old'),
  );
  await Future<void>.delayed(Duration.zero);
  check(calls == 1, 'Concurrent callers must share one refresh');
  current = 'new';
  gate.complete(RefreshResult.refreshed);
  check(
    (await Future.wait(requests)).every((r) => r == RefreshResult.refreshed),
    'All callers get refresh result',
  );
  check(
    await coordinator.run(rejectedAccessToken: 'old') ==
        RefreshResult.refreshed,
    'Late 401 reuses new token',
  );
  check(calls == 1, 'Late response must not rotate again');
  gate = Completer<RefreshResult>();
  final unavailable = coordinator.run(rejectedAccessToken: 'new');
  await Future<void>.delayed(Duration.zero);
  gate.complete(RefreshResult.unavailable);
  check(
    await unavailable == RefreshResult.unavailable,
    'Connectivity is distinct from invalid session',
  );
  gate = Completer<RefreshResult>();
  final retry = coordinator.run(rejectedAccessToken: 'new');
  await Future<void>.delayed(Duration.zero);
  gate.complete(RefreshResult.invalid);
  check(
    await retry == RefreshResult.invalid && calls == 3,
    'Completed failure allows a later attempt',
  );
  var failingCalls = 0;
  final failing = SessionRefresh(
    readAccessToken: () async => 'x',
    refresh: () async {
      failingCalls++;
      if (failingCalls == 1) throw StateError('synthetic storage failure');
      return RefreshResult.refreshed;
    },
  );
  try {
    await failing.run();
  } on StateError {
    /* expected */
  }
  check(
    await failing.run() == RefreshResult.refreshed,
    'Exception must release the in-flight future',
  );
  stdout.writeln(
    'PASS: concurrency, late 401, transient failure, invalid session and exception recovery',
  );
}
