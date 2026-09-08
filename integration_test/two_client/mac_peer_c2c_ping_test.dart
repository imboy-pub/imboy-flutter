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
//     --dart-define=TEST_EXPECTED_UID=<macOS账号uid> \
//     --dart-define=PEER_UID=<Android真机账号uid> \
//     --dart-define=PEER_TITLE=<Android真机账号昵称> \
//     --dart-define=TEST_ALLOW_C2C_PING=true

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _peerTitle = String.fromEnvironment('PEER_TITLE', defaultValue: '');
const _peerUid = String.fromEnvironment('PEER_UID', defaultValue: '');
const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '',
);

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
        if (_peerTitle.isEmpty || _peerUid.isEmpty || _expectedUid.isEmpty) {
          markTestSkipped('需显式 TEST_EXPECTED_UID、PEER_UID 和 PEER_TITLE');
          return;
        }

        await ensureAppLaunched(tester, maxSeconds: 5);
        if (!await checkPreconditions(tester)) return;

        final loggedIn = await autoLoginOrSkip(tester);
        if (!loggedIn) return;
        final actualUid = UserRepoLocal.to.currentUid;
        if (actualUid != _expectedUid || actualUid == _peerUid) {
          fail('登录账号 UID=$actualUid 与授权发送方 $_expectedUid 不一致，或目标为自己');
        }
        await _selectChatExperience(tester);
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
        var enteredViaContact = false;
        if (!tester.any(peerItem)) {
          // E2EE 多设备语义：新 macOS 设备解不开旧 C2C 密文 history，
          // 重登不会重建对端会话行（09-03 实测两次）。回退走联系人
          // 路径进入聊天页；发送本身即建立本地会话行，不降低后续断言。
          flowLog('会话列表无 $_peerTitle，走联系人路径发起会话');
          if (!await _openContactAndChat(tester)) {
            fail('会话列表无 $_peerTitle 会话，且联系人路径无法进入与该好友的聊天面板');
          }
          enteredViaContact = true;
        }
        if (!enteredViaContact) {
          await safeTap(tester, peerItem.first);
          await settle(tester, maxSeconds: 3);
        }
        await takeScreenshot(tester, 'mac_ping_02_chat_page');
        // 桌面 web shell（≥900px ChatShellPage desktopEntry）聊天区是
        // _WebChatPanel（chatBuilder ValueKey('<type>:<peerId>')）而非
        // ChatPage；两分支都要求命中并校验目标 peerId。
        final chatPage = find.byType(ChatPage);
        final webChatPanel = find.byKey(ValueKey('C2C:$_peerUid'));
        if (tester.any(chatPage)) {
          expect(
            tester.widget<ChatPage>(chatPage).peerId,
            _peerUid,
            reason: '昵称匹配后的真实会话 UID 必须等于显式授权目标',
          );
        } else {
          expect(
            webChatPanel,
            findsOneWidget,
            reason: '桌面 web shell 应打开与 $_peerUid 的 C2C 聊天面板',
          );
        }

        final input =
            find.byKey(const Key('chat_message_input')).evaluate().isNotEmpty
            ? find.byKey(const Key('chat_message_input'))
            : find.byKey(const ValueKey('web-chat-input-field'));
        if (!tester.any(input)) {
          fail('聊天页无输入框');
        }
        final ping = 'qa-batch85-ping';
        await tester.enterText(input.first, ping);
        await settle(tester, maxSeconds: 1);

        // 移动端发送按钮是 CupertinoIcons.arrow_up 蓝色药丸（Key=send_button），
        // 桌面 web shell 是 web-chat-input-send-btn；裸 Enter 不发送，
        // 移动端快捷键为 Ctrl+Enter（chat_input.dart），web 端回车即发送。
        final sent = await tapAny(tester, [
          find.byKey(const ValueKey('web-chat-input-send-btn')),
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
      // 真实链路含冷启动（initConfig/E2EE 自愈/离线拉取）+登录+主 Shell
      // 等待，低配真机/桌面端冷启动单段即可 20s+，2 分钟不够（09-04 实测
      // 两轮均在 App 已就绪、等待循环未完时被测试级 timeout 截断）。
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}

Future<void> _selectChatExperience(WidgetTester tester) async {
  final shell = find.byType(ChatShellBootstrap);
  if (!tester.any(shell)) fail('ChatShellBootstrap 未挂载，无法切换到个人聊天体验');
  final container = ProviderScope.containerOf(tester.element(shell));
  await container
      .read(productExperienceProvider.notifier)
      .select(ProductExperience.chat);
  await settle(tester, maxSeconds: 2);
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

/// 会话列表不存在对端会话时的回退路径：联系人 Tab → 对端资料页 →
/// 「发消息」图标（people_info_page.dart 的 chat_bubble_fill，路由
/// /chat/:peerId）进入聊天页。
/// 会话列表不存在对端会话时的回退路径。macOS 桌面端是 web shell 三栏
/// （WebNavRail + 中栏 IndexedStack + 右栏面板）：左栏联系人 tab
/// （person_2）→ 中栏 ContactPage 点对端 → 右栏详情面板「发消息」
/// （web-contact-send-msg-btn，未同步容错版 unsynced）派发 ChatSelection
/// 打开 _WebChatPanel（以 chatBuilder 的 `ValueKey('C2C:<peerId>')` 判定）。
/// 移动布局下则为 tab_contacts → 资料页 chat_bubble_fill → /chat/:id。
Future<bool> _openContactAndChat(WidgetTester tester) async {
  // 桌面测试窗口（800px）落在 BottomNavigationPage 的 tablet NavigationRail
  // 或 web shell WebNavRail。树上有多个 person_2（「我的」页等），裸 icon
  // finder 会 tap 到 rail 之外——必须用 descendant 限定在 rail 内。
  final railContact = find.descendant(
    of: find.byType(NavigationRail),
    matching: find.byIcon(CupertinoIcons.person_2),
  );
  var contactTabTapped = false;
  if (tester.any(railContact)) {
    await safeTap(tester, railContact.first);
    contactTabTapped = true;
  } else {
    contactTabTapped = await tapAny(tester, [
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(CupertinoIcons.person_2_fill),
      ),
      find.byKey(const Key('tab_contacts')),
      find.byIcon(CupertinoIcons.person_2),
    ]);
  }
  if (!contactTabTapped) {
    flowLog('联系人路径失败：未找到联系人入口（rail/底栏）');
    return false;
  }
  await settle(tester, maxSeconds: 3);
  await settle(tester, maxSeconds: 3);
  var peerRow = find.textContaining(_peerTitle);
  for (var i = 0; i < 20 && !tester.any(peerRow); i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    peerRow = find.textContaining(_peerTitle);
  }
  if (!tester.any(peerRow)) {
    flowLog('联系人路径失败：联系人列表无 $_peerTitle');
    return false;
  }
  flowLog('联系人路径：找到 $_peerTitle，打开聊天');
  await safeTap(tester, peerRow.first);
  await settle(tester, maxSeconds: 3);
  // web shell：点击后右栏是联系人详情面板，需再点「发消息」派发 ChatSelection
  final opened = await tapAny(tester, [
    find.byKey(const ValueKey('web-contact-send-msg-btn')),
    find.byKey(const ValueKey('web-contact-unsynced-send-msg-btn')),
    find.byIcon(CupertinoIcons.chat_bubble_fill),
  ]);
  await settle(tester, maxSeconds: 3);
  final onChatPage = tester.any(find.byType(ChatPage));
  final onWebPanel = tester.any(find.byKey(ValueKey('C2C:$_peerUid')));
  flowLog('联系人路径：ChatPage=$onChatPage webPanel=$onWebPanel opened=$opened');
  return onChatPage || onWebPanel;
}
