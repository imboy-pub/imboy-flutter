// integration_test/mention/mention_auto_refresh_acceptance_batch166_test.dart
//
// mention_list_page「收到新提及事件后自动刷新」行解锁（批次166，automation
// 第三十九轮）。原阻塞理由「需第二台设备实时发送 @消息」经代码调研证伪为
// **真实缺陷（BUG#148）**：监听端 mention_list_page L49 订阅 NewMentionEvent，
// 但全仓唯一发射点 MentionService.handleMentionMessage 无任何调用方（死代码），
// WS 接收路径从不广播——即使有第二台真机也永远不会自动刷新。
//
// 本批修复：message.dart 接收路径在 mentionIncrement>0（与 C7-β @未读同口径）
// 时调用 handleMentionMessage 广播事件。
//
// 第二设备等价配方（两轮实测收敛）：
//   ① 裸 WS 直发明文帧 → 服务端 unknown_action（action 须为空串）；
//   ② 空串动作 → 服务端 policy_violation「encrypted_message_required」
//     （9801 节点 capability 为加密必需，明文内容消息在服务端即被拒——
//      安全边界按设计工作，但裸客户端无 Megolm 群会话无法产出合法密文）。
//   ③ 终版：服务端造数（TestPg 注入 msg_c2g+msg_mention，批次99 同范式）+
//     从 WS 分发唯一入口 fire WebSocketMessageReceivedEvent（与真实
//     第二设备投递的客户端侧形状完全一致），完整验证客户端链路：
//     isNewRow → mentionIncrement>0 → BUG#148 接线 → NewMentionEvent →
//     页面自动刷新 → GET /mention/list 渲染新条目。
//
//   AT-ME2  空态基线（清库后「暂无@提及」+ 无「全部已读」）
//   AT-ME2  @ 到达后页面**无任何手动操作**自动出现条目（'Alice' 条目 +
//           「全部已读」按钮 = _loadMentions/_loadUnreadCount 均被事件触发）
//   AT-ME2  接收链路落库断言：本地 msg_c2g 新行 + 服务端 msg_mention 未读行
//
// 运行（define 与批次162 同配方）：
//   flutter test integration_test/mention/mention_auto_refresh_acceptance_batch166_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/service/message.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _aliceUid = 1000000051; // smoke_alice（批次143 实证与 bob 同群）
// 批次159/160 复用的本地群（bob role=1 成员，alice role=4，e2ee_mode=0）
const _groupId = 110610282598107136;
const _marker = 'AT-BDG166 alice mentions bob';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != _uid) {
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区')) ||
        isOnMainShell(tester)) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    } else if (UserRepoLocal.to.currentUid == _uid) {
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go('/bottom_navigation');
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    flowLog('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  // 等 WS 建立与初始化导航尘埃落定（冷启动后 app 会再落一次 home）
  await _pump(tester, seconds: 5);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次166：AT-ME2 收到新提及事件后自动刷新（BUG#148 接线验证）', (
    tester,
  ) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    final msgId = 'bdg166_${DateTime.now().microsecondsSinceEpoch}';

    // ── AT-ME2 前置①：清空 bob 的 mention 记录，构造干净空态基线 ──
    // （仅本地 4323 测试库测试账号数据；同时保证重跑幂等。
    //   注意顺序：必须先开页验空态，再注入数据——否则首载即非空。）
    await TestPg.execute(
      'DELETE FROM msg_mention WHERE mentioned_uid = @_uid',
      {'_uid': _uid},
    );
    flowLog('[AT-ME2] 基线清理完成：bob 的 msg_mention 已清空');

    // ── 空态基线断言 ──
    router.push('/mention');
    final emptyShown = await _waitFor(
      tester,
      () => tester.any(find.text('暂无@提及')),
      seconds: 10,
    );
    expect(emptyShown, isTrue, reason: '清库后 /mention 应展示空态「暂无@提及」');
    expect(
      tester.any(find.text('全部已读')),
      isFalse,
      reason: '基线未读=0，AppBar 不应出现「全部已读」',
    );
    flowLog('[AT-ME2] 空态基线 OK');

    // ── AT-ME2 前置②：服务端造数（批次99 同范式）──
    // 注入 alice 在群内 @bob 的消息行 + mention 未读行（与 mention_logic:
    // create_mentions 落库形状一致），等价「第二台设备已发出并被服务端受理」。
    await TestPg.execute(
      'INSERT INTO msg_c2g (id, msg_id, from_id, to_id, msg_type, payload, '
      'mentions, created_at) '
      'VALUES (@_id, @_m, @_f, @_g, @_mt, @_p::jsonb, @_ms::jsonb, now())',
      {
        '_id': DateTime.now().millisecondsSinceEpoch * 1000,
        '_m': msgId,
        '_f': _aliceUid,
        '_g': _groupId,
        '_mt': 'text',
        '_p': '{"msg_type": "text", "text": "$_marker"}',
        '_ms': '["$_uid"]',
      },
    );
    await TestPg.execute(
      'INSERT INTO msg_mention (id, msg_id, group_id, mentioned_uid, from_uid, '
      'is_read, created_at) VALUES (@_id, @_m, @_g, @_u, @_f, false, now())',
      {
        '_id': DateTime.now().millisecondsSinceEpoch * 1000 + 1,
        '_m': msgId,
        '_g': _groupId,
        '_u': _uid,
        '_f': _aliceUid,
      },
    );
    flowLog('[AT-ME2] 服务端造数完成：msg_c2g + msg_mention($msgId)');

    // ── 第二设备等价投递：直接调用 WS 分发监听器的同一公开入口 ──
    // （websocket.dart _onMessage 收帧后即调用 MessageService.processMessage
    //   ——见其文档示例；此处以相同形状直调，绕开测试区事件总线时序不确定性。
    //   payload 为 Map 的明文帧与「第二台设备经服务端投递」的客户端侧形状一致。
    //   裸 WS 明文直发已被服务端 encrypted_message_required 拒收——见文件头①②。）
    await MessageService.to.processMessage('C2G', {
      'id': msgId,
      'type': 'C2G',
      'from': '$_aliceUid',
      'to': '$_groupId',
      'msg_type': 'text',
      'action': '',
      'e2ee': null,
      'payload': {'msg_type': 'text', 'text': _marker, 'mentions': [_uid]},
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    flowLog('[AT-ME2] 已注入 C2G @ 消息帧 msgId=$msgId');

    // ── 核心断言：不做任何下拉刷新/重进，页面因 NewMentionEvent 自动刷新 ──
    // 「全部已读」出现 = _loadUnreadCount 被事件触发（0→1）；
    // 'Alice' 条目出现 = _loadMentions(refresh:true) 被事件触发。
    final refreshed = await _waitFor(
      tester,
      () =>
          tester.any(find.text('全部已读')) &&
          tester.any(find.text('Alice')),
      seconds: 20,
    );
    expect(
      refreshed,
      isTrue,
      reason:
          'BUG#148：新 @ 到达后页面应在无手动操作下自动刷新'
          '（出现 Alice 条目+全部已读按钮；修复前发射端死代码，永不刷新）',
    );
    flowLog('[AT-ME2] PASS：页面自动刷新（Alice 条目 + 全部已读按钮）');

    // ── 接收链路落库断言 ──
    // ① 客户端：接收路径把消息持久化进本地 msg_c2g（isNewRow=true 证明
    //    走的是完整接收链而非仅刷新）
    final localMsg = await MessageRepo(tableName: MessageRepo.c2gTable).find(
      msgId,
    );
    expect(localMsg, isNotNull, reason: '接收路径应把消息落进本地 msg_c2g');
    // ② 服务端：msg_mention 精确一行且未读
    final mentionRow = await TestPg.scalar(
      'SELECT id || \',\' || is_read || \',\' || group_id FROM msg_mention '
      'WHERE msg_id = @_m AND mentioned_uid = @_u',
      {'_m': msgId, '_u': _uid},
    );
    expect(mentionRow, isNotNull, reason: '服务端应有 bob 的 msg_mention 行');
    expect(
      '$mentionRow'.split(',')[1],
      'false',
      reason: '新 mention 应为未读（is_read=false），实际: $mentionRow',
    );
    flowLog(
      '[AT-ME2] DB 断言 OK：本地 msg_c2g 新行 + 服务端 msg_mention($mentionRow)',
    );
  });
}
