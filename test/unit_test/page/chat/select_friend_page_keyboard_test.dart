import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/select_friend.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _uid = '990042';
const _friendName = 'Alice keyboard friend';

Future<void> _pumpPage(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const SelectFriendPage(
            peer: {'nickname': '测试名片', 'title': '测试名片', 'avatar': ''},
            peerIsReceiver: true,
          ),
        ),
      ),
    ),
  );
  // The no-isolate SQLite fixture completes the real post-frame query on the
  // current isolate; it requires no real network or filesystem from the page.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  expect(find.text(_friendName), findsOneWidget);
}

void main() {
  late Database db;

  setUpAll(() async {
    await StorageService.to.setString(Keys.currentUid, _uid);
    databaseFactory = databaseFactoryFfiNoIsolate;
    db = await openFixtureDatabaseAtVersion(version: 32);
    await db.insert('contact', {
      'user_id': _uid,
      'peer_id': 8001,
      'nickname': _friendName,
      'avatar': '',
      'gender': 1,
      'account': '8001',
      'status': 1,
      'remark': '',
      'tag': '',
      'region': '',
      'sign': '',
      'source': 'test',
      'updated_at': 1790000000000,
      'is_friend': 1,
      'category_id': '',
      'is_from': 1,
      'account_type': 'normal',
    });
    SqliteService.setDbForTest(db);
    expect((await ContactRepo().findFriend()).single.title, _friendName);
  });

  tearDownAll(() async {
    SqliteService.setDbForTest(null);
    await db.close();
    await StorageService.to.remove(Keys.currentUid);
  });

  testWidgets('friend row keeps its name and keyboard activation in one node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpPage(tester);
      final friend = find.text(_friendName);
      Focus.of(tester.element(friend)).requestFocus();
      await tester.pump();
      final data = tester.getSemantics(friend).getSemanticsData();
      expect(data.label, contains(_friendName));
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isFocused.toBoolOrNull(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text(t.common.buttonSend), findsOneWidget);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(SelectFriendPage), findsOneWidget);

      Focus.of(tester.element(friend)).requestFocus();
      await tester.pump();
      expect(
        tester.getSemantics(friend).flagsCollection.isFocused.toBoolOrNull(),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('large text fits contact row, synchronized header and confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester, textScale: 2.5);

    final friendParagraph = tester.renderObject<RenderParagraph>(
      find.text(_friendName),
    );
    expect(
      friendParagraph.getMaxIntrinsicHeight(friendParagraph.size.width),
      lessThanOrEqualTo(friendParagraph.size.height + 0.01),
    );
    // Check the actual header paragraphs, excluding the plugin's separate
    // compact index bar. The page and AzListView must agree on header height.
    final list = tester.widget<AzListView>(find.byType(AzListView));
    expect(list.susItemHeight, greaterThan(32));
    final headers = find.byWidgetPredicate(
      (widget) => widget is Text &&
          widget.data == 'A' && widget.style?.fontWeight == FontWeight.w600,
    );
    expect(headers, findsWidgets);
    for (final element in headers.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width),
        lessThanOrEqualTo(paragraph.size.height + 0.01),
      );
      expect(paragraph.size.height, lessThanOrEqualTo(list.susItemHeight));
    }

    await tester.tap(find.text(_friendName));
    await tester.pumpAndSettle();
    expect(find.text('[${t.common.personalCard}]测试名片'), findsOneWidget);
    expect(find.text(t.common.buttonCancel), findsOneWidget);
    expect(find.text(t.common.buttonSend), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
  });
}
