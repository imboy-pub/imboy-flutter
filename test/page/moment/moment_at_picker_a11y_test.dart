/// MomentAtPickerPage 多选行的无障碍与交互契约。
///
/// 这是朋友圈「提醒谁看」的选人页，之前零 widget 测试。本文件只钉两条与
/// 本轮整改直接相关的不变量：
///   1. 行声明 selected 状态 —— 多选页里读屏用户光听到名字不知道选没选
///   2. 不用 Material Ripple（DESIGN.md §13.2 禁止用在 Cupertino 列表行）
///
/// 页面 initState 走 `ContactRepo().findFriend()` 直连 SQLite，
/// 用 SqliteService.setDbForTest 注入 ffi 内存库真跑（不是 mock）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
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

  Future<void> pumpPage(WidgetTester tester) async {
    // AzListView 内部是 Stack + 悬浮 IndexBar，给个真机尺寸的有界视口
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const MaterialApp(home: MomentAtPickerPage()),
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
    // 行改用 GestureDetector 承接点击
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
    await pumpPage(tester);

    final name = find.text('张三');
    expect(name, findsWidgets);

    // 初始未选中
    expect(
      tester.getSemantics(name.first).hasFlag(SemanticsFlag.isSelected),
      isFalse,
      reason: '未选中时不该声明 selected',
    );

    await tester.tap(name.first);
    await tester.pump();

    // 选中后语义翻转——多选页里这是读屏用户唯一能感知选中与否的途径
    expect(
      tester.getSemantics(name.first).hasFlag(SemanticsFlag.isSelected),
      isTrue,
      reason: '选中后未声明 selected，读屏用户不知道自己选没选',
    );

    handle.dispose();
  });
}
