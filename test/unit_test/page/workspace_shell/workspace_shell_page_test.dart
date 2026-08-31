/// WP5 (T8) — WorkspaceShellPage widget 测试
///
/// 覆盖：五项导航渲染（移动端底部导航 / 桌面端侧栏）、T1 页面标题制顶栏
/// （头像菜单、切换器退出移动端顶栏）、会话目的地不叠加壳顶栏（头像经
/// ConversationPage extraActions 呈现）、archived 横幅（T9 归档规则）。
/// 数据 Provider 在无头测试环境下由 flutter_test_config 全局禁网 →
/// 各视图渲染错误/空态（Day-1 Bar 的可见状态设计本身就是断言对象）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/workspace_model.dart';

Future<ProviderContainer> _seededContainer({
  WorkspaceStatus status = WorkspaceStatus.active,
}) async {
  final container = ProviderContainer();
  container
      .read(workspaceShellProvider.notifier)
      .applyCreated(
        WorkspaceCreateResult(
          workspace: WorkspaceModel(
            id: '9001',
            name: '官网改版',
            ownerId: '1001',
            status: status,
          ),
          channelId: '9002',
          groupId: '9003',
          status: 'created',
        ),
      );
  return container;
}

Future<void> _pumpShell(
  WidgetTester tester,
  ProviderContainer container, {
  Size size = const Size(430, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkspaceShellPage()),
      ),
    ),
  );
  // 固定帧推进（页面异步加载在无头禁网环境会落错误/空态，不 pumpAndSettle）
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('移动端：底部导航五项 + 顶栏 [切换 chip | 标题 | 头像]', (tester) async {
    final container = await _seededContainer();
    addTearDown(container.dispose);

    await _pumpShell(tester, container);

    expect(
      find.byKey(const ValueKey('workspace-shell-bottom-nav')),
      findsOneWidget,
    );
    expect(find.text('消息'), findsWidgets);
    expect(find.text('概览'), findsWidgets);
    expect(find.text('频道'), findsWidgets);
    expect(find.text('群组'), findsWidgets);
    expect(find.text('项目'), findsWidgets);
    // Members 退出五项导航（入口收敛进 Overview 成员卡片）
    expect(find.text('成员'), findsNothing);
    // 切换 chip 恢复移动端常驻（壳顶栏 + ConversationPage leading 各一，
    // IndexedStack 保活两实例均在树中）
    expect(
      find.byKey(const ValueKey('workspace-shell-switcher')),
      findsWidgets,
    );
    // 头像：壳顶栏右侧 + ConversationPage trailingActions 各一
    expect(
      find.byKey(const ValueKey('workspace-shell-account-entry')),
      findsWidgets,
    );
    // DM/设置图标退出全局区（收进账户 Sheet）
    expect(
      find.byKey(const ValueKey('workspace-shell-dm-entry')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('workspace-shell-setting-entry')),
      findsNothing,
    );
  });

  testWidgets('会话目的地：自带导航栏 [chip | 消息 | 搜索+＋+头像]，壳顶栏隐藏', (tester) async {
    final container = await _seededContainer();
    addTearDown(container.dispose);

    await _pumpShell(tester, container);

    container
        .read(workspaceShellProvider.notifier)
        .selectDestination(WorkspaceShellDestination.conversations);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('workspace-shell-bottom-nav')),
      findsOneWidget,
    );
    // 会话页自带 chip 与头像（壳顶栏隐藏后两者依旧可达）
    expect(
      find.byKey(const ValueKey('workspace-shell-switcher')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('workspace-shell-account-entry')),
      findsWidgets,
    );
  });

  testWidgets('桌面端：NavigationRail 五项 + 顶部切换器 + 头像沉底', (tester) async {
    final container = await _seededContainer();
    addTearDown(container.dispose);

    await _pumpShell(tester, container, size: const Size(1440, 900));

    expect(find.byKey(const ValueKey('workspace-shell-rail')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-shell-bottom-nav')),
      findsNothing,
    );
    // 桌面惯例：rail 顶部保留工作区切换器（含 ConversationPage leading 实例）
    expect(
      find.byKey(const ValueKey('workspace-shell-switcher')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('workspace-shell-account-entry')),
      findsWidgets,
    );
    expect(find.text('消息'), findsWidgets);
    expect(find.text('项目'), findsWidgets);
    expect(find.text('成员'), findsNothing);
  });

  testWidgets('archived workspace：显示归档横幅（T9 归档规则）', (tester) async {
    final container = await _seededContainer(status: WorkspaceStatus.archived);
    addTearDown(container.dispose);

    await _pumpShell(tester, container);

    expect(
      find.byKey(const ValueKey('workspace-archived-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('已归档'), findsOneWidget);
  });

  testWidgets('active workspace：无归档横幅', (tester) async {
    final container = await _seededContainer();
    addTearDown(container.dispose);

    await _pumpShell(tester, container);

    expect(
      find.byKey(const ValueKey('workspace-archived-banner')),
      findsNothing,
    );
  });

  testWidgets('账户 Sheet：单工作区也常驻列表 + 创建/加入双入口（T1.1）', (tester) async {
    final container = await _seededContainer();
    addTearDown(container.dispose);

    await _pumpShell(tester, container);

    // 头像入口壳顶栏与会话页各一（IndexedStack 保活），点第一个即可
    await tester.tap(
      find.byKey(const ValueKey('workspace-shell-account-entry')).first,
    );
    // bottom sheet 过场动画：固定帧推进（无头禁网环境不 pumpAndSettle）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 单工作区列表常驻：自身 tile 渲染且带选中 check
    expect(
      find.byKey(const ValueKey('workspace-account-sheet-ws-9001')),
      findsOneWidget,
    );
    // 创建/加入双入口常驻（「创建更多 + 团队码加入」断头修复）
    expect(
      find.byKey(const ValueKey('workspace-account-sheet-create-entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-account-sheet-join-entry')),
      findsOneWidget,
    );
  });
}
