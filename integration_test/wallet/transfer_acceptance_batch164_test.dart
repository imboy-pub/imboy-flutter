// integration_test/wallet/transfer_acceptance_batch164_test.dart
//
// chat_page「发送红包与转账」行解锁（批次164，automation 第三十七轮）。
// 原阻塞理由「允许写生产资金流水」已被批次144/159 本地资金配方推翻：
// topup 仅打本地 9801 + imboy_v1（4323），无生产写。
//
//   AT-TR-PAGE  单聊附加面板→转账入口→发起转账页（余额提示条非0）
//   AT-TR-CONF  二次确认弹窗展示金额与收款人
//   AT-TR-SEND  确认后 WalletApi.sendTransfer 成功并回聊天页
//   wire 断言：transfer_order 新行（pending/500分/默认备注）+
//   wallet 余额精确减 500 + msg_c2c msg_type=transfer 新鲜行 +
//   聊天气泡转账卡片渲染
//
// 链路：extra_panel 转账项（仅 C2C）→ /transfer_send（extra {to}）→
// 金额+确认 → transfer_logic:send → transfer_order 落库 + wallet 扣款 →
// pop 携 {transfer_id} → handleTransferSelection 投递 CustomMessage。
// 金额取 ¥5.00（> 任一端下限 0.01 元；「转账金额下限不一致」待拍板 bug
// 的边界值不在本批触碰范围）。
//
// 运行（define 与批次162 同配方）：
//   flutter test integration_test/wallet/transfer_acceptance_batch164_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/wallet/transfer_send_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';
import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _aliceUid = '1000000051';
const _topupFen = 500;
const _transferFen = 500;

final _client = FlowApiClient(baseUrl: 'http://127.0.0.1:9801', deviceId: 'tr-batch164');

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

/// topup 必须先于 app 登录：FlowApiClient 再登一次 bob 会把 app 会话踢
/// 下线（device_kicked 4000）触发 quitLogin 连带删本地库（批次159 铁律）
Future<void> _topup(int fen) async {
  final login = await _client.login(
    account: FlowConfig.testPhone,
    password: FlowConfig.testPassword,
    type: 'account',
  );
  expect(login['code'], 0, reason: '前置登录失败: ${login['msg']}');
  final topup = await _client.post('/api/v1/wallet/topup', data: {'amount': fen});
  expect(topup['code'], 0, reason: '本地 mock topup 失败: ${topup['msg']}');
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
  await _pump(tester, seconds: 5);
  return true;
}

/// 打开与 alice 的单聊 → 附加面板 → 转账入口（批次159 同配方）
Future<void> _openTransferPage(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  var onChat = false;
  for (var attempt = 0; attempt < 3 && !onChat; attempt++) {
    // /chat/:peerId 默认 type=C2C（群聊才需显式 type=C2G，批次159 run5）
    router.go('/chat/$_aliceUid');
    onChat = await _waitFor(
      tester,
      () => tester.any(find.byKey(const Key('chat_message_input'))),
      seconds: 12,
    );
    if (!onChat) {
      router.go('/bottom_navigation');
      await _pump(tester, seconds: 4);
    }
  }
  expect(onChat, isTrue, reason: '前置：与 alice 的会话页可达');

  final extraBtn = find.byKey(const ValueKey('extra_button'));
  await tester.ensureVisible(extraBtn);
  await _pump(tester, seconds: 1);
  await tester.tap(extraBtn, warnIfMissed: false);
  final panelShown = await _waitFor(
    tester,
    () => tester.any(find.text('照片')),
    seconds: 8,
  );
  expect(panelShown, isTrue, reason: '前置：附加面板应打开（首页「照片」）');

  final transferItem = find.text('转账');
  if (!tester.any(transferItem)) {
    final carousel = find.byType(CarouselSlider);
    for (var p = 0; p < 3 && !tester.any(transferItem); p++) {
      await tester.drag(carousel.first, const Offset(-500, 0));
      await _pump(tester, seconds: 2);
    }
  }
  expect(tester.any(transferItem), isTrue, reason: '前置：应见转账入口（仅 C2C）');
  await tester.ensureVisible(transferItem);
  await _pump(tester, seconds: 1);
  await tester.tap(transferItem, warnIfMissed: false);
  final onTr = await _waitFor(
    tester,
    () => tester.any(find.text('发起转账')),
    seconds: 10,
  );
  expect(onTr, isTrue, reason: 'AT-TR-PAGE：发起转账页应可达');
}

/// 等余额提示条刷新为非 0（QA#25 守卫：未拉到余额会被误判余额不足）
Future<void> _waitBalanceLoaded(WidgetTester tester) async {
  final ready = await _waitFor(tester, () {
    final hints = tester.widgetList<Text>(find.textContaining('余额'));
    return hints.isNotEmpty &&
        !hints.any((w) => (w.data ?? '').contains('￥0.00'));
  }, seconds: 12);
  expect(ready, isTrue, reason: '前置：余额提示条应刷新为非 0（mock topup 后）');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次164：AT-TR 单聊转账全链', (tester) async {
    await _topup(_topupFen);
    if (!await _boot(tester)) return;
    // 扣款基线：topup 之后的真实余额
    final balBefore = await TestPg.scalar(
      'SELECT balance FROM wallet WHERE user_id = @_u',
      {'_u': int.parse(_uid)},
    );
    expect(balBefore, isNotNull, reason: 'wire：bob 钱包行应存在');

    await _openTransferPage(tester);
    await _waitBalanceLoaded(tester);

    // 金额框：WalletAmountField 渲染为独立 Text 标签 + hintText '0.00'
    // 的 TextFormField（无 labelText，run1 实证 label 谓词落空）
    final amountField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText == '0.00'),
    );
    expect(amountField.evaluate().isNotEmpty, isTrue, reason: '前置：金额输入框');
    await tester.enterText(amountField.first, '5.00');
    await _pump(tester, seconds: 1);

    // 页面按钮（弹窗未开时唯一「确认转账」）
    await tester.ensureVisible(find.text('确认转账'));
    await _pump(tester, seconds: 1);
    await tester.tap(find.text('确认转账'), warnIfMissed: false);

    // 二次确认弹窗：金额摘要 + 收款人（联系人备注 Alice 优先于 uid）
    final dialog = await _waitFor(
      tester,
      () => tester.any(find.text('取消')),
      seconds: 8,
    );
    expect(dialog, isTrue, reason: 'AT-TR-CONF：应弹二次确认');
    expect(
      tester.any(find.textContaining('5.00')),
      isTrue,
      reason: 'AT-TR-CONF：确认框应展示金额摘要',
    );
    final receiverShown = await _waitFor(
      tester,
      () => tester.any(find.textContaining('Alice')),
      seconds: 6,
    );
    expect(receiverShown, isTrue, reason: 'AT-TR-CONF：确认框应展示收款人显示名');
    // 弹窗动作键：CupertinoDialogAction 的「确认转账」（标题同文案，限定动作）
    final confirmAction = find.widgetWithText(CupertinoDialogAction, '确认转账');
    expect(confirmAction.evaluate().isNotEmpty, isTrue, reason: '前置：确认动作键');
    await tester.tap(confirmAction.first, warnIfMissed: false);

    // 发送完成：转账页关闭（AppLoading→sendTransfer→pop 回聊天页）
    final back = await _waitFor(
      tester,
      () => tester.any(find.byType(TransferSendPage)) == false &&
          tester.any(find.byKey(const Key('chat_message_input'))),
      seconds: 15,
    );
    expect(back, isTrue, reason: 'AT-TR-SEND：转账成功应返回聊天页');

    // wire①：transfer_order 新行（pending / 500分 / 默认备注）
    Map<String, dynamic>? order;
    for (var i = 0; i < 16 && order == null; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final row = await TestPg.scalar(
        "SELECT status || ',' || amount || ',' || remark FROM transfer_order "
        'WHERE sender_uid = @_s AND receiver_uid = @_r '
        "AND created_at > now() - interval '90 seconds' "
        'ORDER BY created_at DESC LIMIT 1',
        {'_s': int.parse(_uid), '_r': int.parse(_aliceUid)},
      );
      if (row != null) {
        final parts = '$row'.split(',');
        order = {
          'status': parts[0],
          'amount': parts[1],
          'remark': parts.sublist(2).join(','),
        };
      }
    }
    expect(order, isNotNull, reason: 'wire：转账应落 transfer_order');
    expect(order!['status'], 'pending', reason: 'wire：新转账应处待领取态');
    expect(order['amount'], '$_transferFen', reason: 'wire：金额应精确为 500 分');
    expect(order['remark'], '转账给好友', reason: 'wire：空备注应回填默认');

    // wire②：wallet 余额精确减 500
    final balAfter = await TestPg.scalar(
      'SELECT balance FROM wallet WHERE user_id = @_u',
      {'_u': int.parse(_uid)},
    );
    expect(
      int.parse('$balAfter'),
      int.parse('$balBefore') - _transferFen,
      reason: 'wire：余额应精确减少 500 分（$balBefore → $balAfter）',
    );

    // wire③：msg_c2c msg_type=transfer 新鲜行（C2C 出站落 msg_c2c，run11 实证）
    String? msgId;
    for (var i = 0; i < 16 && msgId == null; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final row = await TestPg.scalar(
        'SELECT msg_id FROM msg_c2c '
        'WHERE from_id = @_f AND to_id = @_t AND msg_type = @_mt '
        "AND created_at > now() - interval '90 seconds' "
        'ORDER BY created_at DESC LIMIT 1',
        {'_f': int.parse(_uid), '_t': int.parse(_aliceUid), '_mt': 'transfer'},
      );
      msgId = row == null ? null : '$row';
    }
    expect(msgId, isNotNull, reason: 'wire：transfer 消息应经 WS 投递落库');

    // UX：聊天页转账卡片渲染（备注或金额标记）
    final bubble = await _waitFor(
      tester,
      () =>
          tester.any(find.textContaining('转账给好友')) ||
          tester.any(find.textContaining('¥5.00')) ||
          tester.any(find.textContaining('￥5.00')),
      seconds: 10,
    );
    expect(bubble, isTrue, reason: 'UX：聊天页应渲染转账卡片');
    flowLog('[AT-TR] PASS：转账全链（页面/确认/落库/扣款/投递/气泡）');
  });
}
