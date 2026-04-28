/// Phase 2.1.c — Web Shell + ChatPanel Chrome 端到端 smoke
///
/// 在真实 Chrome JS 引擎里集成 [WebShellPage] + 真实 [ChatPanel]，覆盖：
/// - 用户登录后看到三栏布局
/// - 选中 [ChatSelection] 后右栏切到真实 ChatPanel（不是 fake builder）
/// - 当前阶段输入框 + 发送按钮均禁用（钉死 Phase 2.1.c TODO 真相）
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

const _kMessageTab = Center(
  key: ValueKey('msg-tab'),
  child: Text('MSG_TAB'),
);
const _kContactTab = Center(
  key: ValueKey('contact-tab'),
  child: Text('CON_TAB'),
);
const _kChannelTab = Center(
  key: ValueKey('channel-tab'),
  child: Text('CH_TAB'),
);
const _kMineTab = Center(
  key: ValueKey('mine-tab'),
  child: Text('MINE_TAB'),
);

/// 模拟 web_shell_bootstrap.dart `_SimpleWebInput`：禁用 TextField + 禁用发送按钮。
/// 与生产代码完全等价（只是 ValueKey 标识便于断言）。
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
              decoration: InputDecoration(
                hintText: 'Send message (TODO Phase 2.1.c real ChatInput)',
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('disabled-send-btn'),
            icon: const Icon(Icons.send),
            tooltip: 'Disabled (Phase 2.1.c TODO)',
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
          contactBuilder: (sel) =>
              Center(key: const ValueKey('contact-panel'), child: Text('CONT:${sel.uid}')),
          channelBuilder: (sel) => Center(
              key: const ValueKey('channel-panel'),
              child: Text('CHA:${sel.channelId}')),
          mineBuilder: (sel) => Center(
              key: const ValueKey('mine-panel'),
              child: Text('MINE:${sel.section ?? "ov"}')),
          mobileFallback: const Material(
            key: ValueKey('mobile-fallback'),
            child: Center(child: Text('MOBILE')),
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  group('Web Shell + 真实 ChatPanel — Chrome 端到端 smoke', () {
    testWidgets('登录后默认三栏 + welcome 屏', (tester) async {
      await _pumpShell(tester);
      expect(find.byType(WebNavRail), findsOneWidget);
      expect(find.byType(WebMiddlePanel), findsOneWidget);
      expect(find.byType(WebMainPanel), findsOneWidget);
      expect(find.text('WelcomeTitle'), findsOneWidget);
      expect(find.byType(ChatPanel), findsNothing);
    });

    testWidgets('selectItem(ChatSelection) → 右栏渲染真实 ChatPanel header',
        (tester) async {
      final container = await _pumpShell(tester);
      container.read(webShellProvider.notifier).selectItem(
            const ChatSelection(peerId: 'u-001', chatType: 'C2C'),
          );
      await tester.pump();

      expect(find.byType(ChatPanel), findsOneWidget);
      expect(find.text('Peer u-001'), findsOneWidget);
      // 关闭按钮可见
      expect(find.byTooltip('Close'), findsOneWidget);
      // welcome 应消失
      expect(find.text('WelcomeTitle'), findsNothing);
    });

    testWidgets('ChatPanel 当前阶段：输入框禁用 + 发送按钮禁用（钉死 Phase 2.1.c TODO）',
        (tester) async {
      final container = await _pumpShell(tester);
      container.read(webShellProvider.notifier).selectItem(
            const ChatSelection(peerId: 'u-002', chatType: 'C2C'),
          );
      await tester.pump();

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('disabled-text-field')),
      );
      expect(textField.enabled, isFalse, reason: 'TextField 必须禁用，等 Phase 2.1.c 接 ChatInput');

      final sendBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('disabled-send-btn')),
      );
      expect(sendBtn.onPressed, isNull, reason: '发送按钮必须禁用，等 Phase 2.1.c 接 ChatInput');
    });

    testWidgets('点击 ChatPanel close → clearSelection 回 welcome', (tester) async {
      final container = await _pumpShell(tester);
      container.read(webShellProvider.notifier).selectItem(
            const ChatSelection(peerId: 'u-003', chatType: 'C2C'),
          );
      await tester.pump();
      expect(find.byType(ChatPanel), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pump();

      expect(find.byType(ChatPanel), findsNothing);
      expect(find.text('WelcomeTitle'), findsOneWidget);
      expect(container.read(webShellProvider).selectedItem, isNull);
    });

    testWidgets('选中聊天后切 Tab 1 → selection 清空，回 welcome（跨 Tab 串扰防护）',
        (tester) async {
      final container = await _pumpShell(tester);
      container.read(webShellProvider.notifier).selectItem(
            const ChatSelection(peerId: 'u-004', chatType: 'C2C'),
          );
      await tester.pump();
      expect(find.byType(ChatPanel), findsOneWidget);

      // 切到联系人 Tab
      container.read(webShellProvider.notifier).switchTab(1);
      await tester.pump();

      expect(container.read(webShellProvider).currentTab, 1);
      expect(container.read(webShellProvider).selectedItem, isNull);
      expect(find.byType(ChatPanel), findsNothing);
      expect(find.text('WelcomeTitle'), findsOneWidget);
    });
  });
}
