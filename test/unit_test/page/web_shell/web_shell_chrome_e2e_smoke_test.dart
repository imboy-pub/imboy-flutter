/// Web Shell + ChatPanel Chrome 组件 smoke
///
/// 在真实 Chrome JS 引擎里集成 [WebShellPage] + 真实 [ChatPanel]，覆盖：
/// - 合成数据下的默认三栏布局
/// - 选中 [ChatSelection] 后右栏切到真实 ChatPanel（不是 fake builder）
/// - 调用方注入的只读输入区保持输入框和发送按钮禁用
/// - 关闭聊天 → 回欢迎屏
/// - 切 Tab → selection 清空
///
/// 与 [web_shell_page_test.dart] 的差异：
/// - 该文件用 fake `_chatBuilder`（仅断言 builder 被调到）
/// - 本文件用真实 ChatPanel，断言用户实际看到的占位 UI 状态
@TestOn('chrome')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/web_shell/web_shell.dart';

const _kMessageTab = Center(key: ValueKey('msg-tab'), child: Text('MSG_TAB'));
const _kContactTab = Center(
  key: ValueKey('contact-tab'),
  child: Text('CON_TAB'),
);
const _kChannelTab = Center(
  key: ValueKey('channel-tab'),
  child: Text('CH_TAB'),
);
const _kMineTab = Center(key: ValueKey('mine-tab'), child: Text('MINE_TAB'));

/// 只读合成输入区，用于验证 ChatPanel 保留调用方注入的禁用状态。
/// 生产 `_WebChatInput` 有真实发送回调，本 fixture 不覆盖其发送行为。
class _DisabledInputArea extends StatelessWidget {
  const _DisabledInputArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('disabled-input-area'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              key: ValueKey('disabled-text-field'),
              enabled: false,
              decoration: InputDecoration(hintText: 'Read-only message input'),
            ),
          ),
          IconButton(
            key: const ValueKey('disabled-send-btn'),
            icon: const Icon(Icons.send),
            tooltip: 'Read-only input',
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  Size size = const Size(1400, 800),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final container = ProviderContainer();
  addTearDown(container.dispose);
  // 保活订阅，避免 Riverpod 3 auto-dispose 测试陷阱（参考 channel_list_state_sync_test 修复经验）
  container.listen(webShellProvider, (_, _) {});

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        // 对齐 lib/run.dart：Cupertino 页面中的输入组件使用导航器上方的 Material。
        builder: (_, child) =>
            Material(type: MaterialType.transparency, child: child),
        home: WebShellPage(
          tabMessageLabel: 'Messages',
          tabContactLabel: 'Contacts',
          tabChannelLabel: 'Channels',
          tabMineLabel: 'Me',
          welcomeTitle: 'WelcomeTitle',
          welcomeSubtitle: 'WelcomeSub',
          messageTab: _kMessageTab,
          contactTab: _kContactTab,
          channelTab: _kChannelTab,
          mineTab: _kMineTab,
          chatBuilder: (sel) => ChatPanel(
            peerId: sel.peerId,
            chatType: sel.chatType,
            title: 'Peer ${sel.peerId}',
            closeTooltip: 'Close',
            onClose: () =>
                container.read(webShellProvider.notifier).clearSelection(),
            inputArea: const _DisabledInputArea(),
          ),
          contactBuilder: (sel) => Center(
            key: const ValueKey('contact-panel'),
            child: Text('CONT:${sel.uid}'),
          ),
          channelBuilder: (sel) => Center(
            key: const ValueKey('channel-panel'),
            child: Text('CHA:${sel.channelId}'),
          ),
          mineBuilder: (sel) => Center(
            key: const ValueKey('mine-panel'),
            child: Text('MINE:${sel.section ?? "ov"}'),
          ),
          mobileFallback: const Material(
            key: ValueKey('mobile-fallback'),
            child: Center(child: Text('MOBILE')),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return container;
}

void main() {
  group('Web Shell + 真实 ChatPanel — Chrome 组件 smoke', () {
    testWidgets('默认三栏 + welcome 屏', (tester) async {
      await _pumpShell(tester);
      expect(find.byType(WebNavRail), findsOneWidget);
      expect(find.byType(WebMiddlePanel), findsOneWidget);
      expect(find.byType(WebMainPanel), findsOneWidget);
      expect(find.text('WelcomeTitle'), findsOneWidget);
      expect(find.byType(ChatPanel), findsNothing);
    });

    testWidgets('selectItem(ChatSelection) → 右栏渲染真实 ChatPanel header', (
      tester,
    ) async {
      final container = await _pumpShell(tester);
      container
          .read(webShellProvider.notifier)
          .selectItem(const ChatSelection(peerId: 'u-001', chatType: 'C2C'));
      // WebMainPanel 的 300ms 交叉淡出结束后，旧 welcome 才移出树。
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      expect(find.byType(ChatPanel), findsOneWidget);
      expect(find.text('Peer u-001'), findsOneWidget);
      // 关闭按钮可见
      expect(find.byTooltip('Close'), findsOneWidget);
      // welcome 应消失
      expect(find.text('WelcomeTitle'), findsNothing);
    });

    testWidgets('注入只读输入区：输入框和发送按钮保持禁用', (tester) async {
      final container = await _pumpShell(tester);
      container
          .read(webShellProvider.notifier)
          .selectItem(const ChatSelection(peerId: 'u-002', chatType: 'C2C'));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('disabled-text-field')),
      );
      expect(
        textField.enabled,
        isFalse,
        reason: 'ChatPanel 应保留调用方注入的 TextField 禁用状态',
      );

      final sendBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('disabled-send-btn')),
      );
      expect(sendBtn.onPressed, isNull, reason: 'ChatPanel 应保留调用方注入的发送按钮禁用状态');
    });

    testWidgets('点击 ChatPanel close → clearSelection 回 welcome', (
      tester,
    ) async {
      final container = await _pumpShell(tester);
      container
          .read(webShellProvider.notifier)
          .selectItem(const ChatSelection(peerId: 'u-003', chatType: 'C2C'));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatPanel), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      expect(find.byType(ChatPanel), findsNothing);
      expect(find.text('WelcomeTitle'), findsOneWidget);
      expect(container.read(webShellProvider).selectedItem, isNull);
    });

    testWidgets('选中聊天后切 Tab 1 → selection 清空，回 welcome（跨 Tab 串扰防护）', (
      tester,
    ) async {
      final container = await _pumpShell(tester);
      container
          .read(webShellProvider.notifier)
          .selectItem(const ChatSelection(peerId: 'u-004', chatType: 'C2C'));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatPanel), findsOneWidget);

      // 切到联系人 Tab
      container.read(webShellProvider.notifier).switchTab(1);
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      expect(container.read(webShellProvider).currentTab, 1);
      expect(container.read(webShellProvider).selectedItem, isNull);
      expect(find.byType(ChatPanel), findsNothing);
      expect(find.text('WelcomeTitle'), findsOneWidget);
    });
  });
}
