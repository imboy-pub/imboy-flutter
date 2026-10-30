// integration_test/chat/j18c_revoke_window_test.dart
//
// plan-v2.2 §9 J18.c（本人消息：允许/过期撤回分别 → 时限真实，撤回失败
// 保留合法状态）真机旅程：登录 demo_alice → 打开与 demo_bob 的 C2C →
//   ① 发送 OLD marker（稍后在窗口外做过期撤回）
//   ② 发送 FRESH marker，等状态进入正向 sent → 长按 →「撤回」→ 断言 FRESH
//      原文消失、出现「撤回了一条消息」占位（允许分支）
//   ③ 从 OLD 气泡 widget 读真实 createdAt，按 kDefaultRevokeWindowMs 真实
//      等待到窗口外（不改时钟、不改常量）
//   ④ 长按 OLD → 菜单仍有「撤回」（入口门控只看作者）→ 点击 → 断言出现
//      「超过 2 分钟，无法撤回」，OLD 仍是文本气泡（过期分支）
//
// 时限两层一致：客户端 message_revoke_policy.dart kDefaultRevokeWindowMs=120s
// 在发网络前短路；后端 msg_c2c_logic.erl REVOKE_TIMEOUT_MS=120000。
//
// 前置（fixture 在测试外完成）：后端本地 daemon 绑定合成库；
// demo_alice/demo_bob 互为好友。
//
// 运行：
//   flutter test integration_test/chat/j18c_revoke_window_test.dart \
//     -d <real_device_id> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=demo_alice \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     --dart-define=TEST_EXPECTED_UID=<alice-uid> \
//     --dart-define=PEER_UID=<bob-uid> \
//     --dart-define=PEER_TITLE=演示用户Bob \
//     --dart-define=TEST_ALLOW_BUSINESS_WRITES=true

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/component/chat/message_revoked_builder.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/message_revoke_policy.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerUid = String.fromEnvironment('PEER_UID');
const _peerTitle = String.fromEnvironment('PEER_TITLE');

const _oldPrefix = '[J18C-OLD]';
const _freshPrefix = '[J18C-FRESH]';

/// 撤回占位文案（自己撤回 = messageWasWithdrawn，他人 = 带昵称前缀）。
const _revokedPlaceholder = '撤回了一条消息';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J18.c 本人消息：窗口内撤回成功，窗口外撤回被拒且原文保留', (tester) async {
    if (_expectedUid.isEmpty || _peerUid.isEmpty || _peerTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、PEER_UID、PEER_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    final chatPage = await openC2CWithPeer(
      tester,
      journey: 'J18.c',
      expectedUid: _expectedUid,
      peerUid: _peerUid,
      peerTitle: _peerTitle,
    );

    final nonce = DateTime.now().millisecondsSinceEpoch;
    final oldMarker = '$_oldPrefix $nonce';
    final freshMarker = '$_freshPrefix $nonce';

    // ① OLD：先发，记录其真实 createdAt（NTP 校时后的发送时刻）。
    await sendTextViaInput(tester, chatPage, oldMarker);
    final oldMsg = await waitSent(tester, oldMarker);
    if (oldMsg == null || oldMsg.createdAt == null) {
      fail('OLD 消息未进入列表或无 createdAt（status=${oldMsg?.status}）');
    }
    expect(settledStatuses, contains(oldMsg.status));
    expect(oldMsg.id, isNotEmpty);
    final oldCreatedMs = oldMsg.createdAt!.millisecondsSinceEpoch;
    debugPrint(
      'J18C old createdAtMs=$oldCreatedMs status=${oldMsg.status} '
      'ntpOffsetMs=${NtpHelper.offset} deviceNowMs=$nonce',
    );

    // ② FRESH：发送 → 等 sent → 长按 →「撤回」→ 允许分支。
    await sendTextViaInput(tester, chatPage, freshMarker);
    final freshMsg = await waitSent(tester, freshMarker);
    if (freshMsg == null) {
      fail('FRESH 消息未进入列表');
    }
    expect(freshMsg.id, isNotEmpty);
    expect(freshMsg.id, isNot(oldMsg.id));
    expect(
      settledStatuses.contains(freshMsg.status),
      isTrue,
      reason:
          '撤回前消息须已进入正向已发送态（域规则要求 status==sent），'
          '实际 status=${freshMsg.status}',
    );
    final freshRevoked = find.byWidgetPredicate(
      (widget) =>
          widget is RevokedMessageBuilder && widget.message.id == freshMsg.id,
    );

    await tester.longPress(
      find.textContaining(freshMarker, findRichText: true).first,
    );
    await settle(tester, maxSeconds: 2);
    final revokeAction = find.text('撤回');
    expect(revokeAction, findsWidgets, reason: '本人消息长按菜单应有「撤回」');
    // 直接 tap + 短 pump：toast（EasyLoading）仅存活约 2s，safeTap 自带的
    // settle 会在轮询开始前把它等没。
    await tester.tap(revokeAction.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    final successToastSeen = await pollText(tester, find.text('撤回成功'));
    debugPrint('J18C fresh revokeSuccessToastSeen=$successToastSeen');

    // 终态：原文消失、占位 +1（message_revoke_ack 回流后替换气泡）。
    var freshGone = false;
    for (var i = 0; i < 30 && !freshGone; i++) {
      await settle(tester, maxSeconds: 1);
      freshGone = !tester.any(
        find.textContaining(freshMarker, findRichText: true),
      );
    }
    await takeScreenshot(tester, 'j18c_01_fresh_revoked');
    expect(freshGone, isTrue, reason: '窗口内撤回后 FRESH 原文应于 30s 内从列表消失');
    // 占位由 FutureBuilder 异步补齐昵称后渲染，轮询而非单次采样。
    var placeholderShown = false;
    for (var i = 0; i < 10 && !placeholderShown; i++) {
      placeholderShown = tester.any(
        find.descendant(
          of: freshRevoked,
          matching: find.textContaining(
            _revokedPlaceholder,
            findRichText: true,
          ),
        ),
      );
      if (!placeholderShown) await settle(tester, maxSeconds: 1);
    }
    expect(
      placeholderShown,
      isTrue,
      reason: '窗口内撤回后应出现「$_revokedPlaceholder」占位',
    );

    // ③ 真实等待：以 OLD 的真实 createdAt 与设备本地时钟（revokeMessage 的
    // nowMs 同源）计算，超出 kDefaultRevokeWindowMs 再加 3s 裕量。
    final deadline = oldCreatedMs + kDefaultRevokeWindowMs + 3000;
    var now = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      'J18C waiting ${deadline - now}ms for OLD to leave revoke window',
    );
    while (now < deadline) {
      await settle(tester, maxSeconds: 5);
      now = DateTime.now().millisecondsSinceEpoch;
    }
    expect(
      canRevokeMessage(createdAtMs: oldCreatedMs, nowMs: now),
      isFalse,
      reason: '前置：OLD 必须已超出撤回窗口（age=${now - oldCreatedMs}ms）',
    );

    // ④ OLD：长按 → 菜单仍有「撤回」→ 点击 → 过期分支。
    final oldBubble = find.textContaining(oldMarker, findRichText: true);
    expect(oldBubble, findsWidgets, reason: '等待期间 OLD 原文应仍在列表');
    await tester.scrollUntilVisible(
      oldBubble.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, maxSeconds: 1);
    await tester.longPress(oldBubble.first);
    await settle(tester, maxSeconds: 2);
    final revokeActionOld = find.text('撤回');
    expect(
      revokeActionOld,
      findsWidgets,
      reason: '入口门控只看作者：过期本人消息的长按菜单仍应有「撤回」',
    );
    await tester.tap(revokeActionOld.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    final expiredToastSeen = await pollText(tester, find.text('超过 2 分钟，无法撤回'));
    await takeScreenshot(tester, 'j18c_02_old_expired_toast');
    expect(
      expiredToastSeen,
      isTrue,
      reason: '过期撤回应即时提示「超过 2 分钟，无法撤回」（客户端短路，不发网络）',
    );
    await settle(tester, maxSeconds: 3);
    expect(
      find.textContaining(oldMarker, findRichText: true),
      findsWidgets,
      reason: '过期撤回失败后 OLD 原文应保留（合法状态）',
    );
    // 合法状态 = OLD 仍是文本气泡，未被转成撤回占位（itemContaining 只匹配
    // TextMessage）。不用占位计数：懒加载列表滚动后视口外占位不再构建。
    expect(
      itemContaining(oldMarker),
      findsOneWidget,
      reason: '过期撤回不得把 OLD 转成撤回占位',
    );
    expect(
      tester.widget<ChatMessageItem>(itemContaining(oldMarker)).message.id,
      oldMsg.id,
    );
    await takeScreenshot(tester, 'j18c_03_old_retained');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
