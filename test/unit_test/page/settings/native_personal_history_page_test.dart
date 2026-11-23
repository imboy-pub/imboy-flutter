import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/native_personal_history_page.dart';
import 'package:imboy/service/native_personal_history_sync.dart';

const _passphrase = ValueKey('native-personal-history-passphrase');
const _restore = ValueKey('native-personal-history-restore');
const _status = ValueKey('native-personal-history-status');
const _restored = ValueKey('native-personal-history-restored-text');

typedef _Fixture = ({
  ValueNotifier<bool> current,
  Future<void> Function(String) submit,
});

Future<_Fixture> _open(
  WidgetTester tester,
  NativeHistoryRestorer restore,
) async {
  final current = ValueNotifier(true);
  addTearDown(current.dispose);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: NativePersonalHistoryPage(
          authentication: current,
          isCurrent: () => current.value,
          restore: restore,
        ),
      ),
    ),
  );
  Future<void> submit(String text) async {
    await tester.enterText(find.byKey(_passphrase), text);
    await tester.pump();
    await tester.tap(find.byKey(_restore));
    await tester.pump();
  }

  return (current: current, submit: submit);
}

void main() {
  testWidgets('wrong passphrase leaves history hidden and allows retry', (
    tester,
  ) async {
    final fixture = await _open(tester, (phrase, _, _, _) async {
      return phrase == 'synthetic-correct'
          ? const NativeHistoryRestoreResult(
              NativeHistoryRestoreKind.restored,
              texts: ['history marker'],
            )
          : const NativeHistoryRestoreResult(
              NativeHistoryRestoreKind.wrongPassphrase,
            );
    });
    await fixture.submit('synthetic-wrong');
    await tester.pumpAndSettle();
    expect(find.byKey(_status), findsOneWidget);
    expect(find.text('The recovery passphrase is incorrect.'), findsOneWidget);
    expect(find.byKey(_restored), findsNothing);
    expect(find.text('synthetic-wrong'), findsNothing);

    await fixture.submit('synthetic-correct');
    await tester.pumpAndSettle();
    expect(find.byKey(_restored), findsOneWidget);
    expect(find.text('history marker'), findsOneWidget);

    fixture.current.value = false;
    await tester.pump();
    expect(find.text('history marker'), findsNothing);
    expect(find.byKey(_passphrase), findsNothing);
  });

  testWidgets('account change suppresses an in-flight recovery', (
    tester,
  ) async {
    final completed = Completer<NativeHistoryRestoreResult>();
    bool Function()? isCurrent;
    final fixture = await _open(tester, (_, _, _, guard) {
      isCurrent = guard;
      return completed.future;
    });
    await fixture.submit('synthetic-correct');
    expect(isCurrent?.call(), isTrue);
    fixture.current.value = false;
    await tester.pump();
    expect(isCurrent?.call(), isFalse);
    completed.complete(
      const NativeHistoryRestoreResult(
        NativeHistoryRestoreKind.restored,
        texts: ['late old account row'],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('late old account row'), findsNothing);
    expect(find.byKey(_passphrase), findsNothing);
  });

  testWidgets('an empty page retains both continuation controls', (
    tester,
  ) async {
    const next = (
      owner: 'synthetic-owner',
      domain: 'qa',
      generation: 1,
      after: (mergedAt: 10, messageId: 'm', conversationId: 'c2c:1:2'),
    );
    final fixture = await _open(tester, (phrase, page, _, _) async {
      if (page == null) {
        expect(phrase, 'synthetic-correct');
        return const NativeHistoryRestoreResult(
          NativeHistoryRestoreKind.restored,
          nextPage: next,
          moreToSync: true,
        );
      }
      expect(phrase, isNull);
      expect(page, next);
      return const NativeHistoryRestoreResult(
        NativeHistoryRestoreKind.restored,
        texts: ['older verified body'],
      );
    });
    await fixture.submit('synthetic-correct');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'More cloud history remains. Enter your passphrase to continue.',
      ),
      findsOneWidget,
    );
    final nextButton = find.byKey(
      const ValueKey('native-personal-history-next-page'),
    );
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();
    expect(find.text('older verified body'), findsOneWidget);
    expect(nextButton, findsNothing);
  });

  testWidgets('enabling history requires a matching, explicit confirmation', (
    tester,
  ) async {
    var requests = 0;
    await _open(tester, (phrase, page, enable, guard) async {
      expect(enable, isTrue);
      expect(phrase, 'qa-recovery');
      expect(page, isNull);
      expect(guard(), isTrue);
      requests++;
      return const NativeHistoryRestoreResult(NativeHistoryRestoreKind.enabled);
    });
    final mode = find.byKey(
      const ValueKey('native-personal-history-enable-mode'),
    );
    await tester.tap(mode);
    await tester.pumpAndSettle();
    final confirm = find.byKey(
      const ValueKey('native-personal-history-confirm-passphrase'),
    );
    await tester.enterText(find.byKey(_passphrase), 'qa-recovery');
    await tester.enterText(confirm, 'not-the-same');
    await tester.pump();
    expect(find.byKey(_restore), findsOneWidget);
    await tester.tap(find.byKey(_restore));
    await tester.pump();
    expect(requests, 0);
    await tester.enterText(confirm, 'qa-recovery');
    await tester.pump();
    await tester.tap(find.byKey(_restore));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Personal cloud history is enabled.'), findsOneWidget);
    expect(confirm, findsNothing);
  });

  testWidgets('rescan status keeps prior output without implying completion', (
    tester,
  ) async {
    final fixture = await _open(tester, (phrase, page, enable, guard) async {
      expect(phrase, 'qa-recovery');
      expect(page, isNull);
      expect(guard(), isTrue);
      return const NativeHistoryRestoreResult(
        NativeHistoryRestoreKind.rescanRequired,
        texts: ['previously verified body'],
      );
    });
    await fixture.submit('qa-recovery');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The server requires a history rescan. Previously verified copies are still available.',
      ),
      findsOneWidget,
    );
    expect(find.text('previously verified body'), findsOneWidget);
  });
}
