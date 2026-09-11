// integration_test/chat/group_chat_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';
import '../flows/api_test_client.dart';
import '../flows/test_utils.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';

bool _groupFixtureDone = false;

/// 自带 fixture：B 经裸 WS 向既有的 A/B 双人群发一条密文结构消息，
/// 投递给 A 的真机连接后 app 即建立 C2G 会话。
///
/// 实证过的三条弯路（勿再走）：
/// ① group/add 建群事件不投递给发起者自身端，A 的 app 无会话出现；
/// ② group/add 对 member_uids 的邀请失败被 `_ = join_group(...)` 静默
///    吞掉（疑 workspace 成员门），code=0 但 B 不在群里（403 Not a
///    group member）；
/// ③ 群消息投递排除发送者——A 自己发的消息不回投 A 的端。
/// 因此：用库里 A/B 双成员 is_join=true 的既有群（默认
/// 110206708118456320），B 发、A 收。全局 required 门拒明文，
/// 故按 DF-08-2 前例构造结构化测试信封（非真实密钥协商产物）。
Future<void> _ensureGroupFixture() async {
  if (_groupFixtureDone) return;
  _groupFixtureDone = true;
  final base = FlowApiConfig.apiBaseUrl.isNotEmpty
      ? FlowApiConfig.apiBaseUrl
      : 'http://127.0.0.1:9800';
  final gid = const String.fromEnvironment(
    'TEST_GROUP_ID',
    defaultValue: '110206708118456320',
  );
  final peer = FlowApiClient(baseUrl: base, deviceId: 'group-fixture-peer');
  final loginPeer = await peer.login(
    account: const String.fromEnvironment(
      'C2C_PEER_ACCOUNT',
      defaultValue: 'at20260830210132b@at.local',
    ),
    password: 'admin888',
    type: 'email',
    plainPassword: true,
  );
  if (loginPeer['code'] != 0) {
    flowLog('群 fixture：对端登录失败 ${loginPeer['msg']}');
    return;
  }
  final uidB = int.tryParse(peer.currentUid ?? '');
  if (uidB == null) return;
  if (peer.accessToken == null || peer.accessToken!.isEmpty) return;

  // 等待旧 WS 连接完全释放（服务端同设备在线策略会踢新连接，DF-08 前例）。
  await Future<void>.delayed(const Duration(seconds: 3));
  // WS 的 did 必须与 peer 登录的 did 一致：单设备在线策略按 did 识别
  // 「同设备的连接」，did 不一致会被当作新设备踢掉旧连接（发送静默丢弃）。
  final wsUrl =
      '${base.replaceFirst('http', 'ws')}/api/v1/ws'
      '?token=${peer.accessToken}&did=group-fixture-peer&cos=android';
  final ws = await WebSocket.connect(
    wsUrl,
    headers: {'Sec-WebSocket-Protocol': 'imboy.v2'},
  );
  final now = DateTime.now().millisecondsSinceEpoch;
  final msgId = 'groupfixture$now';
  // 决定性诊断：先挂收帧监听再发送，服务端的任何回帧（错误/限流/ACK）
  // 都会打出来，定位消息未落库的原因。
  final inbound = <String>[];
  late final StreamSubscription<dynamic> sub;
  sub = ws.listen(
    (data) {
      inbound.add('$data');
      flowLog('群 fixture：WS 入站帧 $data');
    },
    onError: (Object e) => flowLog('群 fixture：WS 错误 $e'),
    onDone: () => flowLog('群 fixture：WS 关闭'),
  );
  ws.add(
    jsonEncode({
      'id': msgId,
      'type': 'C2G',
      'msg_type': 'text',
      'from': '$uidB',
      'to': gid,
      'created_at': now,
      'e2ee': {
        'e2ee': true,
        'e2ee_ver': 1,
        'e2ee_suite': 'TEST-PIPELINE-ONLY',
        'nonce': base64.encode(utf8.encode('$msgId-nonce')),
      },
      'payload': base64.encode(utf8.encode('group-fixture-$now')),
    }),
  );
  await Future<void>.delayed(const Duration(seconds: 4));
  flowLog('群 fixture：入站帧共 ${inbound.length} 帧');
  await sub.cancel();
  await ws.close();
  flowLog('群 fixture：WS 密文结构群消息已发送（B→群）gid=$gid msgId=$msgId');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group(
    '群聊',
    () {
      testWidgets(
        '进入已有群聊页面可访问',
        (tester) async {
          await ensureAppLaunched(tester, maxSeconds: 10);
          if (!await checkPreconditions(tester)) return;
          await _ensureGroupFixture();
          await settle(tester, maxSeconds: 2);
          await _dismissRecoveryGuideIfVisible(tester);

          if (!await _openConversationTab(tester)) {
            markTestSkipped('无法进入会话列表');
            return;
          }
          await settle(tester, maxSeconds: 2);
          await _dismissRecoveryGuideIfVisible(tester);
          await takeScreenshot(tester, 'group_readonly_01_conv_list');

          // 不能用标题文本猜测群聊：群名可能为空、包含任意语言，且 C2C
          // 会话标题也可能包含“群”字。直接读取现有会话模型的 C2G 类型。
          final groupItem = await _waitForExistingGroupItem(tester);
          if (groupItem == null) {
            markTestSkipped('当前测试账号没有可识别的已有群聊会话');
            return;
          }

          await safeTap(tester, groupItem.first);
          await settle(tester, maxSeconds: 3);
          await takeScreenshot(tester, 'group_readonly_02_chat_page');

          expect(
            find.byType(ChatPage),
            findsOneWidget,
            reason: '已有 C2G 会话应能进入群聊页面',
          );
          drainKnownFrameworkExceptions(tester);
        },
        semanticsEnabled: false,
        timeout: const Timeout(Duration(minutes: 5)),
      );

      testWidgets('进入已有群聊并发送文本消息', (tester) async {
        if (!requireBusinessWriteAuthorization()) return;
        await ensureAppLaunched(tester, maxSeconds: 3);
        if (!await checkPreconditions(tester)) return;
        await _ensureGroupFixture();
        await settle(tester, maxSeconds: 2);

        if (!await _openConversationTab(tester)) {
          markTestSkipped('无法进入会话列表');
          return;
        }
        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'group_01_conv_list');

        // 优先找群聊标识，回退第一个会话
        final groupFinder = _anyText(['群', 'Group', '群聊']);
        final listTile = find.byType(ListTile);
        final target = tester.any(groupFinder)
            ? groupFinder.first
            : tester.any(listTile)
            ? listTile.first
            : null;

        if (target == null) {
          markTestSkipped('未找到群聊会话');
          return;
        }

        await safeTap(tester, target);
        await settle(tester, maxSeconds: 2);
        await takeScreenshot(tester, 'group_02_chat_page');

        final inputField = find.byType(TextField);
        if (!tester.any(inputField)) {
          markTestSkipped('聊天页无输入框（可能被禁言）');
          return;
        }

        final msg = '[GROUP-E2E] ${DateTime.now().millisecondsSinceEpoch}';
        await tester.enterText(inputField.first, msg);

        final sent = await tapAny(tester, [
          find.byIcon(Icons.send),
          find.text('发送'),
          find.text('Send'),
        ]);
        if (!sent) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await settle(tester, maxSeconds: 2);
        }

        await settle(tester, maxSeconds: 3);
        await takeScreenshot(tester, 'group_03_after_send');

        expect(
          find.textContaining('[GROUP-E2E]'),
          findsWidgets,
          reason: '发送后消息应出现在聊天列表中',
        );
        drainKnownFrameworkExceptions(tester);
      }, timeout: const Timeout(Duration(minutes: 5)));

      testWidgets(
        '从已有群聊进入群详情页可访问',
        (tester) async {
          await ensureAppLaunched(tester, maxSeconds: 10);
          if (!await checkPreconditions(tester)) return;
          await _ensureGroupFixture();
          await settle(tester, maxSeconds: 2);
          await _dismissRecoveryGuideIfVisible(tester);

          if (!await _openConversationTab(tester)) {
            markTestSkipped('无法进入会话列表');
            return;
          }
          await settle(tester, maxSeconds: 2);
          await _dismissRecoveryGuideIfVisible(tester);

          final groupItem = await _waitForExistingGroupItem(tester);
          if (groupItem == null) {
            markTestSkipped('当前测试账号没有可识别的已有群聊会话');
            return;
          }

          await safeTap(tester, groupItem.first);
          await settle(tester, maxSeconds: 3);
          if (!tester.any(find.byType(ChatPage))) {
            markTestSkipped('已有群聊会话未进入聊天页面');
            return;
          }
          await _dismissRecoveryGuideIfVisible(tester);

          final settingsButton = find.byIcon(Icons.more_horiz);
          if (!tester.any(settingsButton)) {
            markTestSkipped('群聊页面未找到群详情入口');
            return;
          }
          await safeTap(tester, settingsButton.first);
          await settle(tester, maxSeconds: 4);

          expect(
            find.byType(GroupDetailPage),
            findsOneWidget,
            reason: '已有群聊应能打开群详情页',
          );
          drainKnownFrameworkExceptions(tester);
        },
        semanticsEnabled: false,
        timeout: const Timeout(Duration(minutes: 5)),
      );
    },
    skip:
        '阻塞：本 fixture 用伪信封（非真实密钥协商产物）故入站必解密失败。'
        '批次179 定性：出站侧已完整——后端三件套在位（group_member_keys/'
        'e2ee_room_key 不透明中继/set_e2ee_mode）+ S15 e2ee_group_outbound_frame '
        'macOS 实测绿；真实缺口=双客户端回环的入站解密（需第二真实客户端/真机'
        '跑真 Megolm 会话）。勿再以伪信封攻击入站链。',
  );
}

bool _isOnConvList(WidgetTester t) =>
    t.any(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ConversationPage',
      ),
    ) ||
    (t.any(find.byIcon(Icons.search)) &&
        t.any(find.byIcon(Icons.add_circle_outline)));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  await tapAny(t, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Chats'),
  ]);
  for (int i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (_isOnConvList(t)) return true;
  }
  return false;
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});

Future<Finder?> _waitForExistingGroupItem(WidgetTester tester) async {
  for (int i = 0; i < 60; i++) {
    final groupItem = find.byWidgetPredicate(
      (widget) => widget is ConversationItem && widget.model.type == 'C2G',
    );
    if (tester.any(groupItem)) return groupItem;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return null;
}

Future<void> _dismissRecoveryGuideIfVisible(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    final later = _anyText(['稍后', 'Later']);
    if (tester.any(later)) {
      await safeTap(tester, later.first);
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
