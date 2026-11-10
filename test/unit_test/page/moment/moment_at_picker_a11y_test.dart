/// MomentAtPickerPage 多选行的无障碍与交互契约。
///
/// 覆盖朋友圈「提醒谁看」及可见性选人页与本轮整改相关的契约：
///   1. 行声明 selected 状态 —— 多选页里读屏用户光听到名字不知道选没选
///   2. 不用 Material Ripple（DESIGN.md §13.2 禁止用在 Cupertino 列表行）
///   3. 每个好友行一个键盘停靠点，Enter / Space 各切换一次
///   4. 矮窗口和大字下可滚动到最后一个可见性选项
///
/// 页面 initState 走 `ContactRepo().findFriend()` 直连 SQLite，
/// 用 SqliteService.setDbForTest 注入 ffi 内存库真跑（不是 mock）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/page/moment/moment_friend_picker/moment_friend_picker_page.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_friend_picker/moment_at_picker_page.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

const String _uid = '1001';

/// 与 baseline_schema.sql 等价的最小 contact 表（findFriend 用到的列）。
const String _contactDDL = '''
  CREATE TABLE contact (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    peer_id INTEGER NOT NULL,
    nickname TEXT NOT NULL DEFAULT '',
    avatar TEXT NOT NULL DEFAULT '',
    gender INTEGER NOT NULL DEFAULT 0,
    account TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    remark TEXT DEFAULT '',
    tag TEXT DEFAULT '',
    region TEXT DEFAULT '',
    sign TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    is_friend INTEGER NOT NULL DEFAULT 1,
    is_from TEXT NOT NULL DEFAULT '',
    category_id INTEGER NOT NULL DEFAULT 0,
    account_type INTEGER NOT NULL DEFAULT 0,
    -- upgrade.sql:1378 新增；findFriend 的 SELECT 列表含此列，
    -- 漏掉会让整条查询 "no such column" 直接失败（列表空）。
    last_seen_at INTEGER,
    updated_at INTEGER NOT NULL DEFAULT 0,
    UNIQUE (user_id, peer_id)
  )
''';

void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await StorageService.to.setString(Keys.currentUid, _uid);
  });

  tearDownAll(() async {
    await StorageService.to.remove(Keys.currentUid);
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(_contactDDL);
    await db.insert('contact', {
      'user_id': int.parse(_uid),
      'peer_id': 2002,
      'nickname': '张三',
      'account': 'zhangsan',
      'sign': '',
      'source': '',
      'status': '',
      'is_friend': 1,
      'updated_at': 0,
    });
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Widget page = const MomentAtPickerPage(),
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    // AzListView 内部是 Stack + 悬浮 IndexBar，给个真机尺寸的有界视口
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: page,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // _loadFriends 走 addPostFrameCallback + 真实 SQLite 异步查询，
    // 光 pump 追不上，必须让真异步跑完再 pump 出结果。
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('好友行不使用 Material Ripple（DESIGN.md 13.2）', (tester) async {
    await pumpPage(tester);

    expect(find.text('张三'), findsWidgets, reason: '好友未加载出来，后续断言无意义');

    // 只看承载好友行的那一层：Checkbox 内部自带 InkWell，不能一刀切断言
    // 全页无 InkWell（那会把第三方组件的实现细节也管进来）。
    expect(
      find.ancestor(of: find.text('张三'), matching: find.byType(InkWell)),
      findsNothing,
      reason: 'Cupertino 列表行禁止用 Material Ripple（DESIGN.md 13.2）',
    );
    // CellPressable 底层触摸手势仍可用。
    expect(
      find.ancestor(
        of: find.text('张三'),
        matching: find.byType(GestureDetector),
      ),
      findsWidgets,
    );
  });

  testWidgets('多选行声明 selected 状态，选中后翻转', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    await pumpPage(tester);

    final name = find.text('张三');
    expect(name, findsWidgets);

    // 初始未选中
    expect(
      tester
              .getSemantics(name.first)
              .flagsCollection
              .isSelected
              .toBoolOrNull() ==
          true,
      isFalse,
      reason: '未选中时不该声明 selected',
    );

    await tester.tap(name.first);
    await tester.pump();

    // 选中后语义翻转——多选页里这是读屏用户唯一能感知选中与否的途径
    expect(
      tester
              .getSemantics(name.first)
              .flagsCollection
              .isSelected
              .toBoolOrNull() ==
          true,
      isTrue,
      reason: '选中后未声明 selected，读屏用户不知道自己选没选',
    );
  });

  testWidgets('好友行只有一个键盘停靠点，Space 和 Enter 各切换一次', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    await pumpPage(tester);
    final name = find.text('张三').first;
    final row = find.ancestor(of: name, matching: find.byType(CellPressable)).first;
    expect(row, findsOneWidget);
    Focus.of(tester.element(name)).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      tester.getSemantics(name).flagsCollection.isSelected.toBoolOrNull(),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.getSemantics(name).flagsCollection.isSelected.toBoolOrNull(),
      isFalse,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final checkboxContext = tester.element(find.byType(Checkbox));
    expect(
      Focus.of(checkboxContext).hasFocus,
      isFalse,
      reason: '装饰复选框不应产生第二个键盘停靠点',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('可见性选项在矮窗口和大字下可滚动到最后一项', (tester) async {
    await pumpPage(
      tester,
      page: const MomentFriendPickerPage(),
      size: const Size(320, 280),
      textScale: 1.6,
    );
    expect(tester.takeException(), isNull);
    final lastOption = find.text(t.discovery.momentsVisibilityExclude);
    await tester.ensureVisible(lastOption);
    await tester.pump();
    expect(tester.getBottomRight(lastOption).dy, lessThanOrEqualTo(280));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
