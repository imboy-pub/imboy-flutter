import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/feature_refresh_loop.dart';

void main() {
  testWidgets('same connected network recovers without restarting the app', (
    tester,
  ) async {
    var available = false;
    var calls = 0;
    final loop = FeatureRefreshLoop(
      refresh: () async {
        calls++;
        return available;
      },
    );
    expect(await loop.request(), isFalse);
    available = true;
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 2, reason: 'a successful refresh cancels the retry timer');
    loop.dispose();
  });

  testWidgets('concurrent triggers share the request and dispose stops retry', (
    tester,
  ) async {
    final release = Completer<bool>();
    var calls = 0;
    final loop = FeatureRefreshLoop(
      refresh: () {
        calls++;
        return release.future;
      },
    );
    final first = loop.request();
    final second = loop.request();
    expect(calls, 1);
    loop.dispose();
    release.complete(false);
    expect(await first, isFalse);
    expect(await second, isFalse);
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 1);
  });

  testWidgets('retry delay is bounded and manual recovery is immediate', (
    tester,
  ) async {
    var calls = 0;
    var available = false;
    final loop = FeatureRefreshLoop(
      refresh: () async {
        calls++;
        return available;
      },
    );
    await loop.request();
    for (final seconds in [2, 4, 8, 16, 32, 60, 60]) {
      await tester.pump(Duration(seconds: seconds));
    }
    expect(calls, 8);
    available = true;
    expect(await loop.request(), isTrue);
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 9);
    loop.dispose();
  });
  testWidgets('revocation during policy wait gets one bounded trailing fetch', (
    tester,
  ) async {
    final policy = Completer<void>();
    var calls = 0;
    var remote = true;
    var visible = false;
    final loop = FeatureRefreshLoop(
      refresh: () async {
        calls++;
        final fetched = remote;
        if (calls == 1) await policy.future;
        visible = fetched;
        return true;
      },
    );
    final first = loop.request();
    remote = false;
    for (var i = 0; i < 100; i++) {
      loop.request();
    }
    policy.complete();
    await first;
    await tester.pump();
    expect(visible, isFalse);
    expect(calls, 2);
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 2);
    loop.dispose();
  });
  testWidgets(
    'events during trailing fetch stay bounded and old epoch cancels',
    (tester) async {
      final first = Completer<bool>();
      final second = Completer<bool>();
      var calls = 0;
      final loop = FeatureRefreshLoop(
        refresh: () {
          calls++;
          return calls == 1 ? first.future : second.future;
        },
      );
      final pending = loop.request();
      loop.request();
      first.complete(true);
      await tester.pump();
      expect(calls, 2);
      for (var i = 0; i < 100; i++) {
        loop.request();
      }
      second.complete(true);
      await pending;
      expect(calls, 2);
      loop.dispose();
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 2, reason: 'scope disposal cancels pending trailing retry');
    },
  );
  testWidgets('trailing exception retries without a new external event', (
    tester,
  ) async {
    final first = Completer<bool>();
    var calls = 0;
    final loop = FeatureRefreshLoop(
      refresh: () {
        calls++;
        if (calls == 1) return first.future;
        if (calls == 2) throw StateError('synthetic transient failure');
        return Future.value(true);
      },
    );
    final pending = loop.request();
    loop.request();
    first.complete(true);
    expect(await pending, isFalse);
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 3);
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 3);
    loop.dispose();
  });
}
