/// WP5 (T8+T9+T12) — 壳层纯函数/Provider 测试
///
/// 覆盖：导航项（五项 IA + 术语）、断点、壳状态机（空态 → 创建 → 切换）、
/// Branding 主题解析（T12：解析失败回落默认）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace_shell/workspace_branding_theme.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_breakpoint.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/workspace_model.dart';

void main() {
  group('WorkspaceShellNavItems（§4.2 IA 唯一权威导航结构）', () {
    final items = buildWorkspaceShellNavItems(
      overviewLabel: '概览',
      projectsLabel: '项目',
      channelsLabel: '频道',
      groupsLabel: '群组',
      membersLabel: '成员',
    );

    test('五项导航：Overview/Projects/Channels/Groups/Members（固定顺序）', () {
      expect(items.length, kWorkspaceShellDestinationCount);
      expect(
        items.map((i) => i.destination).toList(),
        WorkspaceShellDestination.values,
      );
    });

    test('Members 导航术语：工作区成员（members），无 DM / Files 一级导航', () {
      // §4.2 收敛决策：Files 不做一级导航；DM 由壳全局区承载不进导航
      expect(items.last.destination, WorkspaceShellDestination.members);
      expect(items.last.label, '成员');
      final destinations = items.map((i) => i.destination).toSet();
      expect(destinations.length, 5);
      expect(destinations.contains(WorkspaceShellDestination.overview), isTrue);
    });

    test('每一项均有图标与文案', () {
      for (final item in items) {
        expect(item.label, isNotEmpty);
        expect(item.icon, isNotNull);
      }
    });
  });

  group('WorkspaceShellBreakpoint', () {
    test('< 900 → mobile；>= 900 → desktop（与 ChatShell 一致）', () {
      expect(resolveWorkspaceShellLayout(899.9), WorkspaceShellLayout.mobile);
      expect(resolveWorkspaceShellLayout(900), WorkspaceShellLayout.desktop);
      expect(resolveWorkspaceShellLayout(1920), WorkspaceShellLayout.desktop);
    });
  });

  group('WorkspaceShellNotifier 壳状态机（空态 → 创建 → 切换）', () {
    test('初始为空态（无工作区）→ 壳可空态运行', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(workspaceShellProvider);
      expect(state.hasWorkspace, isFalse);
      expect(state.current, isNull);
      expect(state.destination, WorkspaceShellDestination.overview);
    });

    test('applyCreated 回填 Template 结果并选中 Overview', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(workspaceShellProvider.notifier);
      notifier.selectDestination(WorkspaceShellDestination.members);
      notifier.applyCreated(
        WorkspaceCreateResult(
          workspace: const WorkspaceModel(
            id: '9001',
            name: '官网改版',
            ownerId: '1001',
          ),
          channelId: '9002',
          groupId: '9003',
          status: 'created',
        ),
      );

      final state = container.read(workspaceShellProvider);
      expect(state.workspaces.length, 1);
      expect(state.currentWorkspaceId, '9001');
      expect(state.destination, WorkspaceShellDestination.overview);
    });

    test('selectWorkspace 切换工作区并回到 Overview', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(workspaceShellProvider.notifier);
      notifier.applyCreated(
        WorkspaceCreateResult(
          workspace: const WorkspaceModel(
            id: '9001',
            name: 'A',
            ownerId: '1001',
          ),
          channelId: '',
          groupId: '',
          status: 'created',
        ),
      );
      notifier.applyCreated(
        WorkspaceCreateResult(
          workspace: const WorkspaceModel(
            id: '9004',
            name: 'B',
            ownerId: '1001',
          ),
          channelId: '',
          groupId: '',
          status: 'created',
        ),
      );
      notifier.selectDestination(WorkspaceShellDestination.channels);
      notifier.selectWorkspace('9001');

      final state = container.read(workspaceShellProvider);
      expect(state.currentWorkspaceId, '9001');
      expect(state.destination, WorkspaceShellDestination.overview);
      expect(state.workspaces.length, 2);
    });

    test('replaceWorkspace 轻量同步归档状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(workspaceShellProvider.notifier);
      notifier.applyCreated(
        WorkspaceCreateResult(
          workspace: const WorkspaceModel(
            id: '9001',
            name: 'A',
            ownerId: '1001',
          ),
          channelId: '',
          groupId: '',
          status: 'created',
        ),
      );
      notifier.replaceWorkspace(
        const WorkspaceModel(
          id: '9001',
          name: 'A',
          ownerId: '1001',
          status: WorkspaceStatus.archived,
        ),
      );

      final state = container.read(workspaceShellProvider);
      expect(state.current?.isArchived, isTrue);
    });
  });

  group('Branding 主色解析（T12）', () {
    test('#RRGGBB 解析成功', () {
      expect(parseBrandingPrimaryColor('#2474E5'), const Color(0xFF2474E5));
    });

    test('#AARRGGBB 与无 # 前缀均可解析', () {
      expect(parseBrandingPrimaryColor('#802474E5'), const Color(0x802474E5));
      expect(parseBrandingPrimaryColor('2474E5'), const Color(0xFF2474E5));
    });

    test('非法值返回 null（回落默认主题色，不吞成白/黑屏）', () {
      expect(parseBrandingPrimaryColor(''), isNull);
      expect(parseBrandingPrimaryColor('#XYZ'), isNull);
      expect(parseBrandingPrimaryColor('#12345'), isNull);
      expect(parseBrandingPrimaryColor('#1234567890'), isNull);
      expect(parseBrandingPrimaryColor('not-a-color'), isNull);
    });

    test('buildWorkspaceColorScheme：非法值原样返回 base（不覆盖）', () {
      const base = ColorScheme.light();
      expect(identical(buildWorkspaceColorScheme(base, 'oops'), base), isTrue);
    });
  });
}
