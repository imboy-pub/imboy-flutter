@TestOn('chrome')
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test/test.dart' as test_api show registerException;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/widget/message_inbox_tile.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';

const _title = 'Synthetic conversation';
const _preview = 'Synthetic latest message';
const _action = 'Mark synthetic conversation read';

Future<void> _pumpInbox(
  WidgetTester tester,
  Brightness brightness,
  VoidCallback onTap,
  VoidCallback onCustomAction,
) => tester.pumpWidget(
  TranslationProvider(
    child: MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.getDarkThemeFromOption(FontSizeOption.normal)
          : AppTheme.getLightThemeFromOption(FontSizeOption.normal),
      home: Scaffold(
        body: Column(
          children: [
            MessageInboxTile(
              avatar: const SizedBox.square(dimension: AppSpacing.xxxLarge),
              title: const Text(_title),
              preview: const Text(_preview),
              unreadCount: 125,
              onTap: onTap,
              customSemanticsActions: {
                CustomSemanticsAction(label: _action): onCustomAction,
              },
            ),
            TextButton(onPressed: () {}, child: const Text('Next control')),
          ],
        ),
      ),
    ),
  ),
);

int _expectNamedFocus(WidgetTester tester, bool focused) {
  final data = tester.getSemantics(find.text(_title)).getSemanticsData();
  expect(data.label, contains(_title));
  expect(data.label, contains(_preview));
  expect(data.label, contains(t.common.unreadCount(count: '125')));
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.flagsCollection.isFocused.toBoolOrNull(), focused);
  expect(find.bySemanticsLabel(RegExp(r'99\+')), findsNothing);
  final actionIds = data.customSemanticsActionIds ?? const <int>[];
  expect(actionIds, isNotEmpty);
  return actionIds.singleWhere(
    (id) => CustomSemanticsAction.getAction(id)?.label == _action,
  );
}

void main() {
  final originalReporter = reportTestException;
  setUpAll(() {
    reportTestException = (details, description) {
      test_api.registerException(
        details.exception,
        details.stack ?? StackTrace.current,
      );
      originalReporter(details, description);
    };
  });
  tearDownAll(() => reportTestException = originalReporter);
  // Use the production default-font fallback, without preference/writer startup.
  setUp(ThemeManager.resetInstance);
  tearDown(ThemeManager.resetInstance);
  for (final brightness in Brightness.values) {
    testWidgets('Chrome inbox keyboard and named semantics: $brightness', (
      tester,
    ) async {
      expect(kIsWeb, isTrue);
      final semantics = tester.ensureSemantics();
      try {
        var taps = 0, customActions = 0;
        await _pumpInbox(
          tester,
          brightness,
          () => taps++,
          () => customActions++,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final actionId = _expectNamedFocus(tester, true);
        final row = tester.getSemantics(find.text(_title));
        row.owner!.performAction(
          row.id,
          SemanticsAction.customAction,
          actionId,
        );
        expect(customActions, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(taps, 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        _expectNamedFocus(tester, false);
        expect(
          Focus.of(tester.element(find.text('Next control'))).hasFocus,
          isTrue,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(_expectNamedFocus(tester, true), actionId);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(taps, 3);
        expect(customActions, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      } finally {
        semantics.dispose();
      }
    });
  }
}
