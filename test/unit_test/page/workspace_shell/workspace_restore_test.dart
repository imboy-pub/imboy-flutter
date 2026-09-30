import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_bootstrap.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

const _a = WorkspaceModel(
  id: 'a',
  name: '甲',
  ownerId: '1',
  organizationId: 'org-a',
);
const _b = WorkspaceModel(
  id: 'b',
  name: '乙',
  ownerId: '1',
  organizationId: 'org-b',
);
const _b2 = WorkspaceModel(
  id: 'b2',
  name: '乙项目',
  ownerId: '1',
  organizationId: 'org-b',
);

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel.fromJson({'uid': 'restore-user-a'});
  void select(String uid) =>
      state = uid.isEmpty ? null : UserModel.fromJson({'uid': uid});
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _PagedApi extends WorkspaceApi {
  _PagedApi(this.read);
  final Future<WorkspacePageResult<WorkspaceModel>> Function(int) read;
  final List<int> pages = [];
  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) {
    pages.add(page);
    return read(page);
  }

  @override
  Future<WorkspaceBranding> readBranding(EntityId workspaceId) async =>
      const WorkspaceBranding(primaryColor: '#2474E5');
}

class _OrgApi extends OrganizationApi {
  int calls = 0;
  @override
  Future<DefaultWorkspaceRef> defaultWorkspace(EntityId orgId) async {
    calls++;
    return DefaultWorkspaceRef(organizationId: orgId, defaultWorkspaceId: 'b2');
  }
}

void main() {
  late ProviderContainer container;
  late _OrgApi orgApi;
  setUp(() async {
    await CurrentOrganizationStore.forAccount('restore-user-a')
        .set(const Organization(id: 'org-b', name: '乙'));
    await CurrentOrganizationStore.forAccount('restore-user-b')
        .set(const Organization(id: 'org-b', name: '乙'));
    orgApi = _OrgApi();
  });
  tearDown(() {
    container.dispose();
    CurrentOrganizationStore.disposeAccount('restore-user-a');
    CurrentOrganizationStore.disposeAccount('restore-user-b');
  });
  void create(_PagedApi api) {
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        workspaceApiProvider.overrideWithValue(api),
        organizationApiProvider.overrideWithValue(orgApi),
      ],
    );
  }

  test('冷启动先恢复企业范围，再读完分页并选中已加入的默认工作区', () async {
    final api = _PagedApi(
      (page) async => WorkspacePageResult(
        list: page == 1 ? [_a] : [_b, _b2],
        page: page,
        totalPage: 2,
      ),
    );
    create(api);
    final notifier = container.read(workspaceShellProvider.notifier);
    expect(container.read(workspaceShellProvider).organizationId, 'org-b');
    await notifier.initialize();
    expect(api.pages, [1, 2]);
    expect(
      container.read(workspaceShellProvider).workspaces.map((ws) => ws.id),
      ['b', 'b2'],
    );
    expect(container.read(workspaceShellProvider).current?.id, 'b2');
    notifier.selectWorkspace('b');
    await notifier.initialize();
    expect(container.read(workspaceShellProvider).current?.id, 'b');
    expect(orgApi.calls, 1, reason: '重进壳不能把手动选择改回默认');
  });

  test('分页中途失败不提交半份成员列表，保留既有状态供重试', () async {
    var fail = false;
    final api = _PagedApi((page) async {
      if (fail && page == 2) throw WorkspaceApiException(503, '第二页失败');
      return WorkspacePageResult(list: page == 1 ? [_b] : [_b2], totalPage: 2);
    });
    create(api);
    final notifier = container.read(workspaceShellProvider.notifier);
    await notifier.loadMine();
    fail = true;
    await notifier.loadMine();
    expect(container.read(workspaceShellProvider).workspaces, hasLength(2));
    expect(container.read(workspaceShellProvider).error, '第二页失败');
  });

  test('切换账号后旧请求不能回写，即使两个账号属于同一家企业', () async {
    final pending = Completer<WorkspacePageResult<WorkspaceModel>>();
    create(_PagedApi((_) => pending.future));
    final loading = container.read(workspaceShellProvider.notifier).loadMine();
    container.read(_account.notifier).select('restore-user-b');
    pending.complete(const WorkspacePageResult(list: [_b], totalPage: 1));
    await loading;
    expect(container.read(workspaceShellProvider).workspaces, isEmpty);
    expect(container.read(workspaceShellProvider).error, isNull);
    expect(container.read(workspaceShellProvider).organizationId, 'org-b');
  });

  test('登出同步清空工作区和企业范围', () async {
    create(
      _PagedApi(
        (_) async => const WorkspacePageResult(list: [_b], totalPage: 1),
      ),
    );
    await container.read(workspaceShellProvider.notifier).loadMine();
    container.read(_account.notifier).select('');
    expect(container.read(workspaceShellProvider).workspaces, isEmpty);
    expect(container.read(workspaceShellProvider).organizationId, isEmpty);
  });

  test('并发刷新以最新结果为准，不接受迟到的旧列表', () async {
    final old = Completer<WorkspacePageResult<WorkspaceModel>>();
    var calls = 0;
    create(
      _PagedApi((_) {
        return ++calls == 1
            ? old.future
            : Future.value(
                const WorkspacePageResult(list: [_b2], totalPage: 1),
              );
      }),
    );
    final notifier = container.read(workspaceShellProvider.notifier);
    final first = notifier.loadMine();
    await notifier.loadMine();
    old.complete(const WorkspacePageResult(list: [_b], totalPage: 1));
    await first;
    expect(container.read(workspaceShellProvider).current?.id, 'b2');
  });

  testWidgets('壳保持挂载时，换账号会重新加载工作区', (tester) async {
    final api = _PagedApi((_) async => const WorkspacePageResult());
    create(api);
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WorkspaceShellBootstrap()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.pages, [1]);
    container.read(_account.notifier).select('restore-user-b');
    await tester.pumpAndSettle();
    expect(api.pages, [1, 1]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
