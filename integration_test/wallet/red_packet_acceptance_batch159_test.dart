// integration_test/wallet/red_packet_acceptance_batch159_test.dart
//
// 红包发送页验收（批次159）：解锁 red_packet_send_page.md 5 行阻塞——
// 全部卡在「二次确认弹窗不可达（余额 0 被余额不足拦截）」。本地解法
// （批次144 定口径）：POST /api/v1/wallet/topup 仅本地后端可用的 mock
// 入账（demo_flow/red_packet_flow_test.dart DF-18 先例），零生产资金。
//   AT-RP1  单聊二次确认展示收款人昵称（含收款人显示名加载 L9/L15）
//   AT-RP2  群聊二次确认展示红包个数（L16）
//   AT-RP3  提交红包携带会话上下文 + 回传聊天页投递（L17/L18，真发送）
//
// 链路：/chat/:peerId 深链 → Key('extra_button') 开附加面板 → 红包 item
// → /red_packet_send（extra 传 type/to）→ 金额/个数/祝福语 →
// 「放入钱包发送」→ CupertinoAlertDialog 断言 → 确认/取消。
// L17 断言 red_packet.scope_type/scope_id（会话上下文落库）；L18 断言
// msg_c2c msg_type=redPacket 新鲜行（payload E2EE 密文，不打内容）。
//
// 红线：仅本地 9801/4323；mock topup 假币；不触生产资金授权域。
//
// 运行（define 与批次157 同配方，载体 smoke_bob）：
//   flutter test integration_test/wallet/red_packet_acceptance_batch159_test.dart \
//     -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';
import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _aliceUid = '1000000051'; // SmokeAlice（bob 的 C2C 对端/收款人）
// 批次143 实证本地群（双 smoke 账号同群）
const _groupId = '110610282598107136';
const _greetingMarker = 'AT-RP159';

final _baseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:9801',
);

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
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
    if (i == 6) {
      // 卡点诊断：打印此刻可见文本，定位 boot 停在哪一屏（run6/run7 停滞）
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      flowLog('[DIAG] boot 第6轮可见文本: $texts');
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
  // 等初始化导航尘埃落定：冷启动登录后 app 会再落一次 home，
  // 立刻深链会被覆盖（RP1 run1 教训）
  await _pump(tester, seconds: 5);
  return true;
}

/// mock topup（仅本地后端可用；DF-18 同契约）
Future<int> _topup(int fen) async {
  final client = FlowApiClient(baseUrl: _baseUrl, deviceId: 'rp-batch159');
  final login = await client.login(
    account: FlowConfig.testPhone,
    password: FlowConfig.testPassword,
    type: 'account',
  );
  expect(login['code'], 0, reason: '前置登录失败: ${login['msg']}');
  final topup = await client.post(
    '/api/v1/wallet/topup',
    data: {'amount': fen},
  );
  expect(topup['code'], 0, reason: '本地 mock topup 失败: ${topup['msg']}');
  return fen;
}

/// 打开与 peerId 的会话并经附加面板进入红包发送页
Future<void> _openRedPacketPage(
  WidgetTester tester,
  String peerId, {
  String type = 'C2C',
}) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  var onChat = false;
  for (var attempt = 1; attempt <= 3 && !onChat; attempt++) {
    // 群聊必须显式 type=C2G：路由默认 C2C，缺失会静默按单聊打开（run5）
    router.go('/chat/$peerId?type=$type');
    onChat = await _waitFor(
      tester,
      () => tester.any(find.byKey(const Key('chat_message_input'))),
      seconds: 12,
    );
    if (!onChat) {
      flowLog('[诊断] /chat/$peerId 第 $attempt 次未达，回锚主 Shell 重试');
      router.go('/bottom_navigation');
      await _pump(tester, seconds: 4);
    }
  }
  expect(onChat, isTrue, reason: '前置：会话页可达（peer=$peerId）');

  final extraBtn = find.byKey(const ValueKey('extra_button'));
  await tester.ensureVisible(extraBtn);
  await _pump(tester, seconds: 1);
  await tester.tap(extraBtn, warnIfMissed: false);
  // 面板已开标记：首页首个 item「照片」（红包在 fundItems，perPage=8
  // 分页下位于第 2 页——批次80「翻页」实证）
  final panelShown = await _waitFor(
    tester,
    () => tester.any(find.text('照片')),
    seconds: 8,
  );
  expect(panelShown, isTrue, reason: '前置：附加面板应打开（首页「照片」）');

  final redPacketItem = find.text('红包');
  if (!tester.any(redPacketItem)) {
    final carousel = find.byType(CarouselSlider);
    for (var p = 0; p < 3 && !tester.any(redPacketItem); p++) {
      await tester.drag(carousel.first, const Offset(-500, 0));
      await _pump(tester, seconds: 2);
    }
  }
  expect(tester.any(redPacketItem), isTrue, reason: '前置：翻页后应见红包入口');
  await tester.ensureVisible(redPacketItem);
  await _pump(tester, seconds: 1);
  await tester.tap(redPacketItem, warnIfMissed: false);
  final onRp = await _waitFor(
    tester,
    () => tester.any(find.text('放入钱包发送')),
    seconds: 10,
  );
  expect(onRp, isTrue, reason: '前置：红包发送页可达');
}

/// 等余额提示条刷新为非 0：进页 loadBalance 是异步，未完成时点发送会被
/// 「余额不足」拦截（run4 实证，「发红包」弹窗根本不开）
Future<void> _waitBalanceLoaded(WidgetTester tester) async {
  final ready = await _waitFor(tester, () {
    final hints = tester.widgetList<Text>(find.textContaining('钱包余额'));
    return hints.isNotEmpty &&
        !hints.any((w) => (w.data ?? '').contains('￥0.00'));
  }, seconds: 12);
  expect(ready, isTrue, reason: '前置：余额提示条应刷新为非 0（mock topup 后）');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-RP1 单聊二次确认展示收款人昵称', (tester) async {
    // topup 必须先于 app 登录：FlowApiClient 再登一次 bob 会把 app 会话
    // 踢下线（device_kicked 4000）触发 quitLogin 连带删本地库，会话页
    // 从此打不开（run2 实证）。先 API 后 app，app 成为唯一活跃会话。
    await _topup(200);
    if (!await _boot(tester)) return;

    await _openRedPacketPage(tester, _aliceUid);

    // 金额是第 1 个 TextFormField（之后是祝福语）
    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '1.00');
    await _pump(tester, seconds: 1);

    await _waitBalanceLoaded(tester);
    await tester.ensureVisible(find.text('放入钱包发送'));
    await _pump(tester, seconds: 1);
    await tester.tap(find.text('放入钱包发送'), warnIfMissed: false);

    // 二次确认弹窗：金额摘要 + 收款人（显示名加载 L9 / 昵称展示 L15）。
    // 弹窗标记用「取消」按钮——「发红包」与 AppBar 标题同文案会假匹配
    final dialog = await _waitFor(
      tester,
      () => tester.any(find.text('取消')),
      seconds: 8,
    );
    expect(dialog, isTrue, reason: '余额充足时点发送应弹二次确认');
    expect(
      tester.any(find.textContaining('￥1.00')),
      isTrue,
      reason: '确认框应展示金额摘要',
    );
    final contact = await ContactRepo().findByUid(_aliceUid);
    final expectName = (contact != null && contact.title.isNotEmpty)
        ? contact.title
        : _aliceUid;
    flowLog('[诊断] 收款人显示名=「$expectName」（本地联系人查得）');
    expect(
      tester.any(find.textContaining('用户：$expectName')),
      isTrue,
      reason: '确认框应展示收款人「$expectName」（非裸 TSID 回退即证明显示名已加载）',
    );

    // 取消：不发送，停留红包页
    await tester.tap(find.text('取消'), warnIfMissed: false);
    await _pump(tester, seconds: 1);
    expect(tester.any(find.text('放入钱包发送')), isTrue, reason: '取消后应停留红包页');
    flowLog('[AT-RP1] PASS：单聊确认框收款人昵称');
  });

  testWidgets('AT-RP2 群聊二次确认展示红包个数', (tester) async {
    if (!await _boot(tester)) return;

    await _openRedPacketPage(tester, _groupId, type: 'C2G');

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '1.00'); // 金额
    await tester.enterText(fields.at(1), '2'); // 红包个数
    await _pump(tester, seconds: 1);

    await _waitBalanceLoaded(tester);
    await tester.ensureVisible(find.text('放入钱包发送'));
    await _pump(tester, seconds: 1);
    await tester.tap(find.text('放入钱包发送'), warnIfMissed: false);

    final dialog = await _waitFor(
      tester,
      () => tester.any(find.text('取消')),
      seconds: 8,
    );
    expect(dialog, isTrue, reason: '前置：群聊二次确认弹窗');
    expect(
      tester.any(find.textContaining('￥1.00')),
      isTrue,
      reason: '确认框应展示金额摘要',
    );
    expect(
      tester.any(find.text('红包个数：2个')),
      isTrue,
      reason: '群聊确认框应展示红包个数 2 个',
    );

    await tester.tap(find.text('取消'), warnIfMissed: false);
    await _pump(tester, seconds: 1);
    flowLog('[AT-RP2] PASS：群聊确认框红包个数');
  });

  testWidgets('AT-RP3 提交红包携带会话上下文且回传聊天页投递', (tester) async {
    if (!await _boot(tester)) return;

    await _openRedPacketPage(tester, _aliceUid);

    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '0.50');
    // 祝福语 = 最后一个字段，写入标记供气泡定位
    await tester.enterText(find.byType(TextFormField).last, _greetingMarker);
    await _pump(tester, seconds: 1);

    await _waitBalanceLoaded(tester);
    await tester.ensureVisible(find.text('放入钱包发送'));
    await _pump(tester, seconds: 1);
    await tester.tap(find.text('放入钱包发送'), warnIfMissed: false);
    final dialog = await _waitFor(
      tester,
      () => tester.any(find.text('取消')),
      seconds: 8,
    );
    expect(dialog, isTrue, reason: '前置：二次确认弹窗');
    await tester.tap(find.text('确认'), warnIfMissed: false);

    // 成功后 Navigator.pop 回聊天页（L18 回传起点）
    final backToChat = await _waitFor(
      tester,
      () =>
          tester.any(find.byKey(const Key('chat_message_input'))) &&
          !tester.any(find.text('放入钱包发送')),
      seconds: 12,
    );
    expect(backToChat, isTrue, reason: '发送成功应回传并返回聊天页');

    // L17：会话上下文落库（scope_type/scope_id = C2C/alice）
    Map<String, dynamic>? packet;
    for (var i = 0; i < 16 && packet == null; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final row = await TestPg.scalar(
        'SELECT scope_type || \':\' || COALESCE(scope_id::text, \'\') '
        'FROM red_packet WHERE sender_uid = @_s AND amount = @_a '
        "AND greeting = @_g AND created_at > now() - interval '90 seconds' "
        'ORDER BY created_at DESC LIMIT 1',
        {'_s': int.parse(_uid), '_a': 50, '_g': _greetingMarker},
      );
      packet = row == null ? null : <String, dynamic>{'scope': '$row'};
    }
    expect(packet, isNotNull, reason: '红包应落库（amount=50分 greeting 标记）');
    expect(
      packet!['scope'],
      'C2C:$_aliceUid',
      reason: 'L17：scope_type/scope_id 应携带会话上下文（B-11）',
    );

    // L18：聊天页经 handleRedPacketSelection 投递 redPacket 消息
    // （payload 为 E2EE 密文不打内容，只断 msg_type + 双方 + 新鲜度；
    // C2C 出站消息落 msg_c2c——msg_c2s 恒空，run11 实证改表）
    String? msgId;
    for (var i = 0; i < 16 && msgId == null; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final row = await TestPg.scalar(
        'SELECT msg_id FROM msg_c2c '
        'WHERE from_id = @_f AND to_id = @_t AND msg_type = @_mt '
        "AND created_at > now() - interval '90 seconds' "
        'ORDER BY created_at DESC LIMIT 1',
        {'_f': int.parse(_uid), '_t': int.parse(_aliceUid), '_mt': 'redPacket'},
      );
      msgId = row == null ? null : '$row';
    }
    expect(msgId, isNotNull, reason: 'L18：redPacket 消息应经 WS 投递落库');

    // 聊天气泡：红包卡片渲染祝福语标记
    final bubble = await _waitFor(
      tester,
      () => tester.any(find.textContaining(_greetingMarker)),
      seconds: 10,
    );
    expect(bubble, isTrue, reason: '聊天页应渲染红包卡片（含祝福语）');
    flowLog('[AT-RP3] PASS：提交+上下文落库+回传投递');
  });
}
