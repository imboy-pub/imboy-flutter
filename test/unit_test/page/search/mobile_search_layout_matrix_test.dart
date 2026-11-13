import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/search/message_search_page.dart';
import 'package:imboy/page/search/message_search_provider.dart';
import 'package:imboy/page/search/search_chat_page.dart';
import 'package:imboy/page/search/search_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ux_matrix/ux_harness.dart';

class _LayoutPages implements FtsApi {
  final pages = <int>[];
  bool failed = false;
  Future<MessageSearchResponse?> search(int page, int size) async {
    pages.add(page);
    if (page == 2 && !failed) {
      failed = true;
      return null;
    }
    final text = page == 1 ? 'layout first' : 'layout second';
    return MessageSearchResponse(
      items: [
        MessageSearchResult(
          id: text,
          content: text,
          fromId: '1001',
          toId: '1002',
          type: 'C2C',
          createdAt: 1,
          payload: {'text': text},
        ),
      ],
      total: size + 1,
      sourceItemCount: page == 1 ? size : 1,
    );
  }

  @override
  Future<MessageSearchResponse?> searchMessages({
    required String keyword,
    int page = 1,
    int size = 20,
    String type = 'all',
    int? startTime,
    int? endTime,
  }) => search(page, size);
  @override
  Future<MessageSearchResponse?> searchConversationMessages({
    required String keyword,
    required String conversationUk3,
    int page = 1,
    int size = 20,
    String? msgType,
  }) => search(page, size);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _showSearch(
  WidgetTester tester,
  bool chat,
  _LayoutPages api,
  UxCombo combo,
) async {
  final container = ProviderContainer(
    overrides: [ftsApiProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  final page = chat
      ? const SearchChatPage(
          conversationUk3: 'C2C_1001_1002',
          type: 'C2C',
          peerId: '1002',
          peerTitle: '',
          peerAvatar: '',
          peerSign: '',
        )
      : const MessageSearchPage();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: uxHost(
        Material(type: MaterialType.transparency, child: page),
        combo,
        theme: combo.brightness == Brightness.dark
            ? AppTheme.getDarkTheme()
            : AppTheme.getLightTheme(),
      ),
    ),
  );
  final scope = ProviderScope.containerOf(
    tester.element(find.byType(EditableText)),
  );
  for (final uid in ['1001', '1002']) {
    final contact = ContactModel(peerId: uid, nickname: 'sender');
    if (chat) {
      scope.read(searchProvider.notifier).cacheContact(uid, contact);
    } else {
      scope.read(messageSearchProvider.notifier).cacheContact(uid, contact);
    }
  }
  return scope;
}

Finder _action(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(CupertinoButton))
    .first;

void _touchTarget(WidgetTester tester, Finder target) {
  final size = tester.getSize(target);
  expect(
    size.width,
    greaterThanOrEqualTo(48),
    reason: 'Android48dp / iOS44pt width',
  );
  expect(
    size.height,
    greaterThanOrEqualTo(48),
    reason: 'Android48dp / iOS44pt height',
  );
}

Future<void> _retryPage(WidgetTester tester, _LayoutPages api) async {
  final previous = api.pages.takeWhile((page) => page == 1).toList();
  final footer = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        (w.data == t.common.loadMore || w.data == t.common.buttonRetry),
  );
  await tester.scrollUntilVisible(
    footer,
    100,
    scrollable: find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
    maxScrolls: 30,
  );
  await tester.pumpAndSettle();
  // Scrolling may change the lazy footer from More to Retry.
  if (api.pages.last == 1) {
    final more = _action(t.common.loadMore);
    _touchTarget(tester, more);
    expect(more.hitTestable(), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
  }
  expect(api.pages, [...previous, 2]);
  final retry = _action(t.common.buttonRetry);
  await tester.ensureVisible(retry);
  await tester.pumpAndSettle();
  _touchTarget(tester, retry);
  expect(retry.hitTestable(), findsOneWidget);
  await tester.tap(retry);
  await tester.pumpAndSettle();
  expect(api.pages, [...previous, 2, 2]);
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    SqliteService.setDbUnavailableForTest();
  });
  tearDown(() => SqliteService.setDbForTest(null));
  for (final chat in [false, true]) {
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            '${chat ? 'chat' : 'global'} layout $width $scale $brightness',
            (tester) async {
              tester.view.physicalSize = Size(width, 640);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.reset);
              final api = _LayoutPages();
              final scope = await _showSearch(
                tester,
                chat,
                api,
                UxCombo(
                  Size(width, 640),
                  textScale: scale,
                  brightness: brightness,
                ),
              );
              await tester.enterText(find.byType(EditableText), 'layout');
              await tester.testTextInput.receiveAction(
                chat ? TextInputAction.search : TextInputAction.done,
              );
              await tester.pumpAndSettle();
              expect(api.pages, [1]);
              final editable = tester
                  .state<EditableTextState>(find.byType(EditableText))
                  .renderEditable;
              expect(
                editable.size.height + 0.1,
                greaterThanOrEqualTo(editable.preferredLineHeight),
                reason: 'the entered line must not be vertically clipped',
              );
              _touchTarget(
                tester,
                chat
                    ? find.byType(CupertinoSearchTextField)
                    : find.byType(TextField),
              );
              final clear = chat
                  ? find
                        .ancestor(
                          of: find.byIcon(CupertinoIcons.xmark_circle_fill),
                          matching: find.byType(CupertinoButton),
                        )
                        .first
                  : find.widgetWithIcon(IconButton, CupertinoIcons.clear);
              _touchTarget(tester, clear);
              if (chat) {
                final glyph = tester.widget<RichText>(
                  find.descendant(
                    of: find.byIcon(CupertinoIcons.xmark_circle_fill),
                    matching: find.byType(RichText),
                  ),
                );
                expect(glyph.text.style?.fontSize, 20 * scale);
              }
              await tester.tapAt(tester.getTopLeft(clear) + const Offset(2, 2));
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<EditableText>(find.byType(EditableText))
                    .controller
                    .text,
                isEmpty,
              );
              expect(api.pages, [1]);
              await tester.enterText(find.byType(EditableText), 'layout');
              await tester.testTextInput.receiveAction(
                chat ? TextInputAction.search : TextInputAction.done,
              );
              await tester.pumpAndSettle();
              expect(api.pages, [1, 1]);
              _touchTarget(tester, _action(t.common.loadMore));
              expect(_action(t.common.loadMore).hitTestable(), findsOneWidget);
              tester.view.viewInsets = const FakeViewPadding(bottom: 240);
              await tester.pumpAndSettle();
              await _retryPage(tester, api);
              final result = find.byWidgetPredicate(
                (w) => w is TextHighlight && w.text == 'layout second',
              );
              await tester.ensureVisible(result);
              await tester.pumpAndSettle();
              expect(result.hitTestable(), findsOneWidget);
              expect(
                chat
                    ? scope.read(searchProvider).searchResults.length
                    : scope.read(messageSearchProvider).searchResults.length,
                2,
              );
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }
}
