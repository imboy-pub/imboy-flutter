import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

const _workspaces = [
  WorkspaceModel(id: 'a', name: '甲', ownerId: '1', organizationId: 'org-a'),
  WorkspaceModel(id: 'b', name: '乙', ownerId: '1', organizationId: 'org-b'),
  WorkspaceModel(id: 'b2', name: '乙项目', ownerId: '1', organizationId: 'org-b'),
  WorkspaceModel(id: 'personal', name: '个人', ownerId: '1'),
];

class _WorkspaceApi extends WorkspaceApi {
  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) async => const WorkspacePageResult(list: _workspaces);

  @override
  Future<WorkspaceBranding> readBranding(EntityId workspaceId) async =>
      const WorkspaceBranding(primaryColor: '#2474E5');
}

class _DelayedWorkspaceApi extends _WorkspaceApi {
  final pending = Completer<WorkspacePageResult<WorkspaceModel>>();
  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) => pending.future;
}

void main() {
  late ProviderContainer container;
  late WorkspaceShellNotifier notifier;

  setUp(() async {
    container = ProviderContainer(
      overrides: [workspaceApiProvider.overrideWithValue(_WorkspaceApi())],
    );
    notifier = container.read(workspaceShellProvider.notifier);
    await notifier.loadMine();
  });
  tearDown(() => container.dispose());

  test('切企业即显示消息，默认工作区读取失败不回概览', () async {
    notifier.selectDestination(WorkspaceShellDestination.overview);
    final pending = Completer<EntityId>();
    final switching = notifier.selectOrganization(
      'org-b',
      () => pending.future,
    );
    expect(
      container.read(workspaceShellProvider).destination,
      WorkspaceShellDestination.conversations,
    );
    pending.completeError(WorkspaceApiException(503, '暂不可用'));
    await switching;
    expect(
      container.read(workspaceShellProvider).destination,
      WorkspaceShellDestination.conversations,
    );
  });

  test('显式页面选择保留，同工作区或无效工作区选择不改变页面', () async {
    await notifier.selectOrganization('org-a', () async => 'a');
    notifier.selectDestination(WorkspaceShellDestination.overview);
    notifier.selectWorkspace('a');
    notifier.selectWorkspace('unknown');
    await notifier.loadMine();
    expect(
      container.read(workspaceShellProvider).destination,
      WorkspaceShellDestination.overview,
    );
  });

  test('另一企业加入回填不改变当前企业页面', () async {
    await notifier.selectOrganization('org-a', () async => 'a');
    notifier.selectDestination(WorkspaceShellDestination.overview);
    notifier.applyJoined(_workspaces[1]);
    final state = container.read(workspaceShellProvider);
    expect(state.organizationId, 'org-a');
    expect(state.currentWorkspaceId, 'a');
    expect(state.destination, WorkspaceShellDestination.overview);
  });

  test('退出前发出的 mine 响应不能重新写回已退出工作区', () async {
    final api = _DelayedWorkspaceApi();
    final delayed = ProviderContainer(
      overrides: [workspaceApiProvider.overrideWithValue(api)],
    );
    addTearDown(delayed.dispose);
    final n = delayed.read(workspaceShellProvider.notifier);
    n.applyJoined(_workspaces[0]);
    n.applyJoined(_workspaces[1]);
    final loading = n.loadMine();
    n.forgetOrganization('org-b');
    api.pending.complete(const WorkspacePageResult(list: _workspaces));
    await loading;
    expect(delayed.read(workspaceShellProvider).workspaces.map((ws) => ws.id), [
      'a',
    ]);
  });

  test('退出目标企业后清除其工作区，并拒绝迟到的默认工作区响应', () async {
    final pending = Completer<EntityId>();
    final switching = notifier.selectOrganization(
      'org-b',
      () => pending.future,
    );
    notifier.forgetOrganization('org-b');
    pending.complete('b2');
    await switching;
    final state = container.read(workspaceShellProvider);
    expect(state.organizationId, isEmpty);
    expect(state.currentWorkspaceId, isEmpty);
    expect(state.workspaces.map((ws) => ws.id), ['a', 'personal']);
  });

  test('退出另一企业不改变当前企业和工作区', () async {
    await notifier.selectOrganization('org-a', () async => 'a');
    notifier.forgetOrganization('org-b');
    expect(container.read(workspaceShellProvider).organizationId, 'org-a');
    expect(container.read(workspaceShellProvider).current?.id, 'a');
    expect(
      container.read(workspaceShellProvider).workspaces.map((ws) => ws.id),
      ['a'],
    );
  });

  test('默认工作区读取失败也立即离开上一企业，回退到目标企业工作区', () async {
    final pending = Completer<EntityId>();
    final switching = notifier.selectOrganization(
      'org-b',
      () => pending.future,
    );
    expect(container.read(workspaceShellProvider).current?.id, 'b');
    expect(
      container.read(workspaceShellProvider).workspaces.map((ws) => ws.id),
      ['b', 'b2'],
    );
    pending.completeError(WorkspaceApiException(503, '暂不可用'));
    await switching;
    expect(container.read(workspaceShellProvider).current?.id, 'b');
  });

  test('未配置、未加入及归属错误的默认工作区均不能跨企业落位', () async {
    for (final id in ['', 'unknown', 'a', 'personal']) {
      await notifier.selectOrganization('org-b', () async => id);
      expect(container.read(workspaceShellProvider).current?.id, 'b');
    }
    await notifier.selectOrganization('org-b', () async => 'b2');
    expect(container.read(workspaceShellProvider).current?.id, 'b2');
  });

  test('目标企业无工作区时显示空态，刷新也不选回其他企业', () async {
    await notifier.selectOrganization('org-empty', () async => 'a');
    expect(container.read(workspaceShellProvider).current, isNull);
    expect(container.read(workspaceShellProvider).hasWorkspace, isFalse);
    await notifier.loadMine();
    expect(container.read(workspaceShellProvider).currentWorkspaceId, isEmpty);
    expect(container.read(workspaceShellProvider).hasWorkspace, isFalse);
    expect(container.read(workspaceShellProvider).workspaces, isEmpty);
    await notifier.selectOrganization('org-a', () async => 'a');
    expect(container.read(workspaceShellProvider).current?.id, 'a');
  });

  test('A 到 B 再到 A：上一轮同企业响应不能覆盖最新选择', () async {
    final old = Completer<EntityId>();
    final first = notifier.selectOrganization('org-b', () => old.future);
    await notifier.selectOrganization('org-a', () async => 'a');
    await notifier.selectOrganization('org-b', () async => 'b');
    old.complete('b2');
    await first;
    expect(container.read(workspaceShellProvider).current?.id, 'b');
  });

  test('用户手动选择后，迟到的默认响应不能覆盖该选择', () async {
    final pending = Completer<EntityId>();
    final switching = notifier.selectOrganization(
      'org-b',
      () => pending.future,
    );
    notifier.selectWorkspace('b2');
    pending.complete('b');
    await switching;
    expect(container.read(workspaceShellProvider).current?.id, 'b2');
    notifier.selectWorkspace('a');
    notifier.selectWorkspace('unknown');
    expect(container.read(workspaceShellProvider).current?.id, 'b2');
  });
}
