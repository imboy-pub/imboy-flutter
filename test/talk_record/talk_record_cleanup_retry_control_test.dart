import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_cleanup_retry_control.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/store/model/talk_record/talk_record_cleanup_retry_model.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';

class _Client implements TalkRecordCleanupRetryClient {
  final calls = <(String, String, int, String)>[];
  Future<void> Function()? send;
  @override
  Future<void> retry(
    String id,
    String etag,
    int generation,
    String key,
    void Function() guard,
  ) async {
    guard();
    calls.add((id, etag, generation, key));
    await send?.call();
  }
}

void main() {
  const eligible = TalkRecordCleanupRetryCapability(
    allowed: true,
    generation: 2,
    exhaustedResources: 1,
    reason: 'eligible',
  );
  final action = find.byKey(const ValueKey('cleanup-retry-action'));
  Future<void> mount(
    WidgetTester tester,
    _Client client, {
    TalkRecordCleanupRetryCapability? capability = eligible,
    Future<bool> Function()? refresh,
    Object? Function()? session,
    void Function(void Function())? subscribe,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          talkRecordCleanupRetryClientProvider.overrideWithValue(client),
          talkRecordCleanupSessionProvider.overrideWithValue(
            session ?? () => 'actor',
          ),
          talkRecordAuthSubscribeProvider.overrideWithValue((changed) {
            subscribe?.call(changed);
            return () {};
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TalkRecordCleanupRetryControl(
              recordId: '123',
              etag: '"3"',
              capability: capability,
              onRefresh: refresh ?? () async => true,
            ),
          ),
        ),
      ),
    );
  }

  test('capability fails closed and unknown protected count stays unknown', () {
    for (final raw in [
      null,
      <String, dynamic>{},
      {'allowed': 'true'},
      {'allowed': true, 'generation': -1, 'exhausted_resources': 1},
      {
        'allowed': true,
        'generation': 0,
        'exhausted_resources': 1,
        'reason': 'protected',
      },
    ]) {
      expect(TalkRecordCleanupRetryCapability.fromJson(raw).canRetry, false);
    }
    final cap = TalkRecordCleanupRetryCapability.fromJson({
      'allowed': true,
      'generation': 0,
      'exhausted_resources': 1,
      'reason': 'partial_protection',
    });
    expect(cap.canRetry, true);
    expect(cap.protectedResources, isNull);
  });

  test('cleanup counters reject unsafe Web integers', () {
    expect(
      TalkRecordCleanupRetryCapability.counter(9007199254740991),
      9007199254740991,
    );
    expect(
      TalkRecordCleanupRetryCapability.counter(9007199254740992),
      kIsWeb ? isNull : 9007199254740992,
    );
  });

  test('a read started before acceptance cannot unlock a new retry intent', () {
    final intents = TalkRecordCleanupRetryIntents();
    final oldRead = intents.beginRead();
    intents.obtain('actor', '123', '"3"', 2);
    intents.markAccepted('actor', '123', '"3"', 2);
    intents.reconcileRecord('actor', '123', oldRead);
    expect(intents.accepted('actor', '123', '"3"', 2), true);
    intents.reconcileRecord('actor', '123', intents.beginRead());
    expect(intents.accepted('actor', '123', '"3"', 2), false);
  });

  testWidgets('protected, waiting and denied capabilities never offer retry', (
    tester,
  ) async {
    for (final reason in [
      'protected',
      'not_exhausted',
      'permission_denied',
      'identity_unverified',
    ]) {
      await mount(
        tester,
        _Client(),
        capability: TalkRecordCleanupRetryCapability(
          allowed: false,
          generation: 2,
          exhaustedResources: 1,
          reason: reason,
        ),
      );
      expect(action, findsNothing);
    }
  });

  testWidgets(
    'double tap sends once and acceptance only requests real refresh',
    (tester) async {
      final pending = Completer<void>();
      final client = _Client()..send = () => pending.future;
      var refreshes = 0;
      await mount(
        tester,
        client,
        refresh: () async {
          refreshes++;
          return true;
        },
      );
      await tester.tap(action);
      await tester.tap(action);
      await tester.pump();
      expect(client.calls.length, 1);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(action, findsNothing);
      expect(client.calls.single.$2, '"3"');
      expect(client.calls.single.$3, 2);
    },
  );

  testWidgets(
    'unknown outcome explicit retry reuses key with no automatic retry',
    (tester) async {
      final client = _Client()
        ..send = () async => throw TimeoutException('unknown');
      await mount(tester, client);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(client.calls.length, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(client.calls.length, 1);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(client.calls.length, 2);
      expect(client.calls[0], client.calls[1]);
    },
  );

  testWidgets(
    'conflict refreshes capability without automatically resubmitting',
    (tester) async {
      final client = _Client()
        ..send = () async => throw const TalkRecordApiException(409, 'stale');
      var refreshes = 0;
      await mount(
        tester,
        client,
        refresh: () async {
          refreshes++;
          return true;
        },
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      expect(client.calls.length, 1);
    },
  );

  testWidgets('account fence drops late result and refresh', (tester) async {
    final pending = Completer<void>();
    final client = _Client()..send = () => pending.future;
    Object session = 'first';
    var refreshes = 0;
    await mount(
      tester,
      client,
      session: () => session,
      refresh: () async {
        refreshes++;
        return true;
      },
    );
    await tester.tap(action);
    await tester.pump();
    session = 'second';
    pending.complete();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    expect(action, findsNothing);
  });
  testWidgets(
    'unknown intent survives removal during refresh with the original key',
    (tester) async {
      final client = _Client()
        ..send = () async => throw TimeoutException('unknown');
      final container = ProviderContainer(
        overrides: [
          talkRecordCleanupRetryClientProvider.overrideWithValue(client),
          talkRecordCleanupSessionProvider.overrideWithValue(() => 'actor'),
          talkRecordAuthSubscribeProvider.overrideWithValue((changed) => () {}),
        ],
      );
      addTearDown(container.dispose);
      Widget page(bool visible) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: visible
                ? TalkRecordCleanupRetryControl(
                    recordId: '123',
                    etag: '"3"',
                    capability: eligible,
                    onRefresh: () async => true,
                  )
                : const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(false));
      await tester.pump();
      await tester.pumpWidget(page(true));
      await tester.pump();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(client.calls.length, 2);
      expect(client.calls.first, client.calls.last);
    },
  );

  testWidgets('accepted retry with failed refresh never offers a new POST', (
    tester,
  ) async {
    final client = _Client();
    await mount(tester, client, refresh: () async => false);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(client.calls.length, 1);
    expect(action, findsNothing);
    expect(find.byKey(const ValueKey('cleanup-retry-message')), findsOneWidget);
  });
}
