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
  testWidgets('移动端：底部导航五项 + 顶栏页面标题制（头像菜单，无切换器）', (tester) async {
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
    // T1：workspace 切换器退出移动端顶栏（收进账户 Sheet + 概览页卡片）
    expect(
      find.byKey(const ValueKey('workspace-shell-switcher')),
      findsNothing,
    );
    // 全局区收敛：DM/设置图标退出，收进头像菜单（顶栏 + ConversationPage
    // extraActions 各一，IndexedStack 保活两处均在树中）
    expect(
      find.byKey(const ValueKey('workspace-shell-dm-entry')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('workspace-shell-setting-entry')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('workspace-shell-account-entry')),
      findsWidgets,
    );
  });

  testWidgets('会话目的地：壳顶栏隐藏，头像经 extraActions 呈现', (tester) async {
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
    // ConversationPage 自带标题栏，壳顶栏不叠加（switcher 顶栏实例不存在）
    expect(
      find.byKey(const ValueKey('workspace-shell-switcher')),
      findsNothing,
    );
    // 头像经 ConversationPage extraActions 挂入其标题栏（T1：五页右上均可达账户区）
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
    // 桌面惯例：rail 顶部保留工作区切换器
    expect(
      find.byKey(const ValueKey('workspace-shell-switcher')),
      findsOneWidget,
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
}
