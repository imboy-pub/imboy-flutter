/// WP5 (T8+T9+T12) — 壳层纯函数/Provider 测试
///
/// 覆盖：导航项（五项 IA + 术语）、断点、壳状态机（空态 → 创建 → 切换）、
/// Branding 主题解析（T12：解析失败回落默认）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_branding_theme.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_breakpoint.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// Fake：mine() 列表行不带 branding（复刻服务端 page_by_member 的 SELECT
/// 列：id/name/logo/owner_id/status/created_at，无 branding）；readBranding
/// 返回白名单视图并计数（验证补拉只发生在缺失 primaryColor 的行上）。
class _NoBrandingFakeApi extends WorkspaceApi {
  int readBrandingCalls = 0;

  // mine 列表行一律不带 branding（复刻服务端行为）
  static const seed = [
    WorkspaceModel(id: '9001', name: '甲区', ownerId: '1001'),
    WorkspaceModel(id: '9002', name: '乙区', ownerId: '1001'),
  ];

  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) async {
    return WorkspacePageResult<WorkspaceModel>(
      list: seed,
      total: seed.length,
      totalPage: 1,
    );
  }

  @override
  Future<WorkspaceBranding> readBranding(EntityId workspaceId) {
    readBrandingCalls++;
    return Future.value(
      workspaceId == '9001'
          ? const WorkspaceBranding(name: '甲区', primaryColor: '#00AAFF')
          : const WorkspaceBranding(name: '乙区', primaryColor: '#FF6600'),
    );
  }
}

void main() {
  group('WorkspaceShellNavItems（§4.2 IA + 频率分层收敛）', () {
    final items = buildWorkspaceShellNavItems(
      conversationsLabel: '全部消息',
      overviewLabel: '概览',
      projectsLabel: '项目',
      channelsLabel: '频道',
      groupsLabel: '群组',
    );

    test('五项导航：Conversations/Overview/Channels/Groups/Projects（固定顺序）', () {
      expect(items.length, kWorkspaceShellDestinationCount);
      expect(
        items.map((i) => i.destination).toList(),
        WorkspaceShellDestination.values,
      );
    });

    test('频率分层：会话（全局 DM）排第一；Members 退出一级导航', () {
      // 2026-08-31 UX 收敛：DM 进一级导航且排第一；Files 不做一级导航；
      // Members 退出（治理低频，入口收敛进 Overview 成员卡片）
      expect(items.first.destination, WorkspaceShellDestination.conversations);
      expect(items.first.label, '全部消息');
      expect(items.last.destination, WorkspaceShellDestination.projects);
      expect(items.map((i) => i.destination).toSet(), {
        WorkspaceShellDestination.conversations,
        WorkspaceShellDestination.overview,
        WorkspaceShellDestination.channels,
        WorkspaceShellDestination.groups,
        WorkspaceShellDestination.projects,
      });
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
      notifier.selectDestination(WorkspaceShellDestination.projects);
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

    test('applyJoined 新工作区：置顶 + 切当前 + destination=overview', () {
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
      notifier.selectDestination(WorkspaceShellDestination.projects);

      notifier.applyJoined(
        const WorkspaceModel(id: '9005', name: '团队码加入', ownerId: '1002'),
      );

      final state = container.read(workspaceShellProvider);
      expect(state.workspaces.length, 2);
      // 新加入置顶（回填顺序与服务端 created_at DESC 一致）
      expect(state.workspaces.first.id, '9005');
      expect(state.currentWorkspaceId, '9005');
      expect(state.destination, WorkspaceShellDestination.overview);
    });

    test('applyJoined 已存在的工作区 id 不重复插入（去重同 applyCreated）', () {
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
            id: '9002',
            name: 'B',
            ownerId: '1001',
          ),
          channelId: '',
          groupId: '',
          status: 'created',
        ),
      );

      // unchanged 幂等命中：重复 applyJoined 既有 id（服务端可能回带
      // joined_at 更新的行），不重复插入，只置顶 + 切当前
      notifier.applyJoined(
        const WorkspaceModel(id: '9001', name: 'A', ownerId: '1001'),
      );

      final state = container.read(workspaceShellProvider);
      expect(state.workspaces.length, 2);
      expect(
        state.workspaces.where((ws) => ws.id == '9001').length,
        1,
        reason: '同 id 不得重复插入',
      );
      expect(state.workspaces.first.id, '9001');
      expect(state.currentWorkspaceId, '9001');
      expect(state.destination, WorkspaceShellDestination.overview);
    });

    test('applyJoined 空 id（异常兜底）不产生任何状态变更', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(workspaceShellProvider.notifier);
      notifier.applyJoined(const WorkspaceModel(id: '', name: '', ownerId: ''));

      final state = container.read(workspaceShellProvider);
      expect(state.workspaces, isEmpty);
      expect(state.currentWorkspaceId, '');
    });
  });

  group('ensureCurrentBranding（mine 列表不带 branding 的补拉）', () {
    test('loadMine 后为当前工作区补拉 branding（冷启动路径）', () async {
      final api = _NoBrandingFakeApi();
      final container = ProviderContainer(
        overrides: [workspaceApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      await container.read(workspaceShellProvider.notifier).loadMine();
      // ensureCurrentBranding 是 loadMine 内的 fire-and-forget 补拉
      await Future<void>.delayed(Duration.zero);

      final current = container.read(workspaceShellProvider).current;
      expect(current?.id, '9001');
      expect(
        current?.branding.primaryColor,
        '#00AAFF',
        reason: 'mine 行不带 branding，壳主题依赖补拉结果（T12）',
      );
      expect(api.readBrandingCalls, 1);
    });

    test('切换工作区后为新当前工作区补拉（切换路径）', () async {
      final api = _NoBrandingFakeApi();
      final container = ProviderContainer(
        overrides: [workspaceApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workspaceShellProvider.notifier);
      await notifier.loadMine();
      notifier.selectWorkspace('9002');
      // selectWorkspace 内 fire-and-forget：跑完微任务队列
      await Future<void>.delayed(Duration.zero);

      final current = container.read(workspaceShellProvider).current;
      expect(current?.id, '9002');
      expect(current?.branding.primaryColor, '#FF6600');
      expect(api.readBrandingCalls, 2);
    });

    test('已配置 primaryColor 的行不重拉（编辑页本地回填已覆盖）', () async {
      final api = _NoBrandingFakeApi();
      final container = ProviderContainer(
        overrides: [workspaceApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(workspaceShellProvider.notifier);
      await notifier.loadMine();
      notifier.selectWorkspace('9002');
      await Future<void>.delayed(Duration.zero);
      final callsBefore = api.readBrandingCalls;

      // 直接调用 ensure：当前行（9002）已有 primaryColor → 不重拉
      await notifier.ensureCurrentBranding();
      expect(api.readBrandingCalls, callsBefore);
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
