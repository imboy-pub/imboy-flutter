// integration_test/two_client/mac_peer_c2c_ping_test.dart
//
// 双端测试 · macOS 对端侧：以 QA 对端账号登录，向 PEER_TITLE 会话发送
// 一条 C2C 文本 ping，供 Android 真机侧验收未读角标/消息到达。
// 两端均为自管 QA 账号，消息内容带 qa 标记，不构成第三方打扰。
//
// 运行（macOS 桌面）：
//   flutter test integration_test/two_client/mac_peer_c2c_ping_test.dart -d macos \
//     --dart-define=APP_ENV=pro \
//     --dart-define=API_BASE_URL=https://pro.imboy.pub \
//     --dart-define=TEST_PHONE=<对端账号> \
//     --dart-define=TEST_PASSWORD=<对端密码> \
//     --dart-define=PEER_TITLE=<Android真机账号昵称> \
//     --dart-define=TEST_ALLOW_C2C_PING=true

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _peerTitle = String.fromEnvironment('PEER_TITLE', defaultValue: '');

const _pingFlag = String.fromEnvironment(
  'TEST_ALLOW_C2C_PING',
  defaultValue: 'false',
);

final bool _allowPing = _pingFlag == 'true' || _pingFlag == 'True';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('双端 · macOS 对端发 C2C ping', () {
    testWidgets(
      '打开与 PEER_TITLE 的会话并发送 ping 文本',
      (tester) async {
        if (!_allowPing) {
          markTestSkipped('需显式 TEST_ALLOW_C2C_PING=true');
          return;
        }
        if (_peerTitle.isEmpty) {
          markTestSkipped('需显式 PEER_TITLE=<对端昵称>');
          return;
        }

        await ensureAppLaunched(tester, maxSeconds: 5);
        if (!await checkPreconditions(tester)) return;

        final loggedIn = await autoLoginOrSkip(tester);
        if (!loggedIn) return;
        if (!await waitForMainShell(tester)) {
          fail('对端登录成功但主 Shell 未挂载');
        }

        await _openConversationTab(tester);

        // 桌面端会话项不是 ListTile；直接轮询对方昵称文本，
        // 会话列表异步加载，给足等待窗口。
        var peerItem = find.textContaining(_peerTitle);
        for (var i = 0; i < 20 && !tester.any(peerItem); i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 300));
          peerItem = find.textContaining(_peerTitle);
        }
        await takeScreenshot(tester, 'mac_ping_01_conversations');
        if (!tester.any(peerItem)) {
          fail('会话列表中无 $_peerTitle 会话，无法发送 ping');
        }
        await safeTap(tester, peerItem.first);
        await settle(tester, maxSeconds: 3);
        await takeScreenshot(tester, 'mac_ping_02_chat_page');

        final input = find.byType(TextField);
        if (!tester.any(input)) {
          fail('聊天页无输入框');
        }
        final ping = 'qa-batch85-ping';
        await tester.enterText(input.first, ping);
        await settle(tester, maxSeconds: 1);

        // 桌面端发送按钮是 CupertinoIcons.arrow_up 蓝色药丸（Key=send_button），
        // 裸 Enter 不发送，快捷键为 Ctrl+Enter（chat_input.dart）。
        final sent = await tapAny(tester, [
          find.byKey(const ValueKey('send_button_inner')),
          find.byKey(const ValueKey('send_button')),
          find.byIcon(CupertinoIcons.arrow_up),
        ]);
        if (!sent) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        }
        await settle(tester, maxSeconds: 4);
        await takeScreenshot(tester, 'mac_ping_03_after_send');

        // 防假绿：textContaining 会匹配输入框残留；
        // 以「发送成功后输入框被清空」（chat_input.dart 契约）为真绿判据。
        final texts = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .map((w) => w.controller.text)
            .toList();
        if (texts.isEmpty) {
          fail('聊天页输入框消失');
        }
        if (texts.any((v) => v.contains(ping))) {
          fail('发送未生效：输入框仍残留 ping（发送按钮/快捷键未触发）');
        }
        flowLog('ping 已发送: $ping → $_peerTitle');
        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      // 逻辑 30s 内完成；binding teardown 因 WS timer 挂到超时，缩短空耗。
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

Future<bool> _openConversationTab(WidgetTester tester) async {
  final candidates = [
    find.byKey(const Key('tab_messages')),
    find.byIcon(Icons.chat_bubble_outline),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.message_outlined),
    find.text('消息'),
    find.text('Messages'),
  ];
  for (final candidate in candidates) {
    if (!await safeTap(tester, candidate)) continue;
    await settle(tester, maxSeconds: 2);
    if (tester.any(find.byType(ListTile)) ||
        tester.any(find.byKey(const Key('conversation_list_item')))) {
      return true;
    }
  }
  return false;
}
