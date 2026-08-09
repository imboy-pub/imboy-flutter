/// BUG#122 复现与闭环：聊天设置页「阅后即焚销毁时长」滚轮选择不生效。
///
/// 症状（真机）：滚轮滚动正常，点「确认」后列表副标题仍显示旧值，
/// 重开弹层初始值也是旧值。
///
/// 本测试带真实 SQLite（sqflite ffi in-memory）：
///   1. 预置会话 payload burn_enabled=true / burn_after_ms=30000
///   2. 打开「销毁时间」滚轮弹层
///   3. 拖动 CupertinoPicker 到新档位
///   4. 点「确认」
///   5. 断言列表副标题已更新 + payload 已持久化
///
/// 注意：AppLoading（flutter_easyloading）宿主挂载后自带常驻动画，
/// pumpAndSettle 永不结束——本测试一律用固定步进 pump 推进动画。
library;

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

const String _conversationDDL = '''
  CREATE TABLE conversation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    mention_unread INTEGER DEFAULT 0,
    is_muted INTEGER DEFAULT 0,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT
  )
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
    // BUG#122 测试复盘：必须用 noIsolate 工厂（databaseFactoryFfi 默认 isolate
    // 模式，DB 操作走真实后台 isolate，fake-async 无法确定性推进，SqliteService
    // 的 .timeout() fake timer 悬空导致测试挂死/竞态）。noIsolate 为同步 ffi、
    // 微任务级完成，pump 的 flushMicrotasks 即可驱动 _persistBurnSetting 链。
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await db.execute(_conversationDDL);
    await db.insert('conversation', {
      'user_id': 'tsid_uid_001',
      'peer_id': 'peer_1',
      'type': 'C2C',
      'is_show': 1,
      'last_time': 1,
      'payload': '{"burn_enabled":true,"burn_after_ms":30000}',
    });
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            // 与 run.dart 一致的宿主挂载：确认后 AppLoading.showToast 需要
            // EasyLoading.init 的 overlay，否则断言异常。
            builder: AppLoading.init(),
            home: ChatSettingPage('peer_1', type: 'C2C'),
          ),
        ),
      ),
    );
    // testWidgets 的 fake-async 收不到 sqflite_ffi 的真实 IO，须用 runAsync
    // 让 initState 的 _loadBurnSetting 的 Future 落地，再 pump 让 setState 生效。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  Future<Map<String, dynamic>> readPayload() async {
    final rows = await db.query(
      'conversation',
      columns: ['payload'],
      where: 'peer_id = ?',
      whereArgs: ['peer_1'],
    );
    return jsonDecode(rows.single['payload'] as String) as Map<String, dynamic>;
  }

  testWidgets('滚轮选新档位点确认后，副标题与 payload 同步更新', (tester) async {
    await pumpPage(tester);
    // 初始 30 秒（subtitle + trailing 各一处）
    expect(find.text('30秒'), findsNWidgets(2));

    // 打开「销毁时间」滚轮弹层
    await tester.tap(find.text('销毁时间'));
    // 弹层入场动画约 250ms
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CupertinoPicker), findsOneWidget);

    // 向上拖 3 档（itemExtent=40）：30000 → 更高档位
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -120));
    // 惯性滚动 + snap 到档位
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // 点「确认」
    await tester.tap(find.text('确认'));
    // onPressed：setState 同步生效，pop 开始
    await tester.pump();
    // sqflite_ffi 查询是同步 SQL + microtask，pump 的 flushMicrotasks 即驱动
    // onPressed 里 _persistBurnSetting 的 DB 链路完成（不用 runAsync——
    // flutter_test 的 runAsync 在后续真实 DB IO 排队时会挂起测试收尾）。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // BUG#122：确认后 UI 必须不再显示旧值 30 秒
    expect(
      find.text('30秒'),
      findsNothing,
      reason: 'BUG#122：确认后副标题仍显示旧值 30秒，选择未生效',
    );
    // payload 已持久化为新档位
    final payload = await readPayload();
    expect(payload['burn_enabled'], true);
    expect(
      payload['burn_after_ms'],
      isNot(30000),
      reason: 'BUG#122：确认后 payload.burn_after_ms 仍是旧值',
    );

    // 推进 toast 的 dismiss timer（2s）并完成 dismiss 动画，避免
    // testWidgets 收尾的 pending-timer 检查失败
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
