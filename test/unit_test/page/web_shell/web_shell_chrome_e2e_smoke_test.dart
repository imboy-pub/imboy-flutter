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

import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
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

Widget _buildShell(ProviderContainer container) {
  return UncontrolledProviderScope(
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
        navigationLeading: const Text('SPACE', key: ValueKey('space-entry')),
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
  );
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

  await tester.pumpWidget(_buildShell(container));
  expect(tester.takeException(), isNull);
  return container;
}

void main() {
  group('Web Shell + 真实 ChatPanel — Chrome 组件 smoke', () {
    for (final width in [899.0, 900.0, 901.0, 1199.0, 1200.0, 1201.0]) {
      testWidgets('Chrome actual panels and return at $width', (tester) async {
        final container = await _pumpShell(tester, size: Size(width, 800));
        if (width < 900) {
          expect(find.byKey(const ValueKey('mobile-fallback')), findsOneWidget);
          return;
        }
        final list = tester.element(find.byKey(const ValueKey('msg-tab')));
        expect(
          find.byType(WebMainPanel),
          width < 1200 ? findsNothing : findsOneWidget,
        );
        container
            .read(webShellProvider.notifier)
            .selectItem(
              const ChatSelection(peerId: 'u-layout', chatType: 'C2C'),
            );
        await tester.pumpAndSettle(const Duration(milliseconds: 350));
        expect(find.byType(ChatPanel), findsOneWidget);
        expect(
          find.byType(WebMiddlePanel),
          width < 1200 ? findsNothing : findsOneWidget,
        );
        expect(find.byKey(const ValueKey('space-entry')), findsOneWidget);
        if (width < 1200) {
          await tester.tap(find.byType(CupertinoNavigationBarBackButton));
        } else {
          await tester.tap(find.byTooltip('Close'));
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 350));
        expect(
          tester.element(find.byKey(const ValueKey('msg-tab'))),
          same(list),
        );
        expect(container.read(webShellProvider).selectedItem, isNull);
        expect(tester.takeException(), isNull);
      });
    }

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

    testWidgets('选中聊天后切 Tab 1 → selection 清空，显示完整联系人列表（跨 Tab 串扰防护）', (
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
      expect(find.byKey(const ValueKey('contact-tab')), findsOneWidget);
      expect(find.byType(WebMainPanel), findsNothing);
      expect(find.text('WelcomeTitle'), findsNothing);
      expect(
        tester.getSize(find.byType(WebMiddlePanel)).width,
        closeTo(
          tester.getSize(find.byKey(const ValueKey('web-shell-content'))).width,
          1,
        ),
      );

      container.read(webShellProvider.notifier).switchTab(0);
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(container.read(webShellProvider).selectedItem, isNull);
      expect(find.byType(ChatPanel), findsNothing);
      expect(find.text('WelcomeTitle'), findsOneWidget);
    });

    // ----------------------------------------------------------
    // FL-16:LOCAL:01 原生/Web 密集接收、分页及恢复（Web 面）
    // ----------------------------------------------------------
    testWidgets(
      'FL-16:LOCAL:01 密集会话切换下 selection 一致、chatBuilder 不串号、列表 element 稳定',
      (tester) async {
        final container = await _pumpShell(tester);
        final listBefore = tester.element(
          find.byKey(const ValueKey('msg-tab')),
        );

        // 密集事件：12 次连续 selectItem，帧间隔内不 settle，
        // 模拟 Web 端密集 S2C/用户操作交错到达的负载形态。
        const burst = 12;
        for (var i = 0; i < burst; i++) {
          container
              .read(webShellProvider.notifier)
              .selectItem(
                ChatSelection(
                  peerId: 'u-burst-${i.toString().padLeft(2, '0')}',
                  chatType: i.isEven ? 'C2C' : 'C2G',
                ),
              );
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);

        // 业务状态一致：selection 是最后一次更新，没有丢更新/串号。
        final selected = container.read(webShellProvider).selectedItem;
        expect(selected, isA<ChatSelection>());
        final chat = selected as ChatSelection;
        expect(chat.peerId, 'u-burst-11');
        expect(chat.chatType, 'C2G');

        // chatBuilder 收到当前 selection：标题即最后 peer，无 stale 残留。
        expect(find.byType(ChatPanel), findsOneWidget);
        expect(find.text('Peer u-burst-11'), findsOneWidget);
        expect(find.text('Peer u-burst-00'), findsNothing);

        // 列表稳定：左栏 element 在整段密集负载前后是同一实例。
        expect(
          tester.element(find.byKey(const ValueKey('msg-tab'))),
          same(listBefore),
        );
      },
    );

    // ----------------------------------------------------------
    // FL-16:LOCAL:02 浏览器刷新（容器重建）后无跨容器残留
    // ----------------------------------------------------------
    testWidgets('FL-16:LOCAL:02 容器重建=浏览器刷新等价：selection 不残留、恢复范围明确', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 刷新前：容器 A 选中一个会话。
      final containerA = ProviderContainer();
      addTearDown(containerA.dispose);
      containerA.listen(webShellProvider, (_, _) {});
      await tester.pumpWidget(_buildShell(containerA));
      containerA
          .read(webShellProvider.notifier)
          .selectItem(
            const ChatSelection(peerId: 'u-refresh-old', chatType: 'C2C'),
          );
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatPanel), findsOneWidget);
      expect(find.text('Peer u-refresh-old'), findsOneWidget);

      // 浏览器刷新等价：整树以全新 ProviderContainer 冷启动，
      // 内存态清零（webShellProvider 回初始态）。
      final containerB = ProviderContainer();
      addTearDown(containerB.dispose);
      containerB.listen(webShellProvider, (_, _) {});
      await tester.pumpWidget(_buildShell(containerB));
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      // 恢复范围明确：刷新回到欢迎屏，选中态不跨容器残留（无假成功）。
      expect(containerB.read(webShellProvider).selectedItem, isNull);
      expect(find.text('WelcomeTitle'), findsOneWidget);
      expect(find.byType(ChatPanel), findsNothing);
      // 旧容器状态不被新容器清掉（容器间隔离，无跨账号式污染）。
      final oldSelection = containerA.read(webShellProvider).selectedItem;
      expect(oldSelection, isA<ChatSelection>());
      expect((oldSelection as ChatSelection).peerId, 'u-refresh-old');

      // 刷新后功能可用：新会话正常选中，旧会话不复活。
      containerB
          .read(webShellProvider.notifier)
          .selectItem(
            const ChatSelection(peerId: 'u-refresh-new', chatType: 'C2C'),
          );
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(find.text('Peer u-refresh-new'), findsOneWidget);
      expect(find.text('Peer u-refresh-old'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
