import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_bootstrap.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/public.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_workbench_api.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_group_agenda_views.dart';
import 'package:imboy/page/workspace_shell/workspace_message_filter.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/modules/attachments/workspace_attachments_page.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_conversation_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Shell extends WorkspaceShellNotifier {
  @override
  Future<void> initialize() async {}
  void empty(String mode) => state = WorkspaceShellState(
    organizationId: '10',
    isLoading: mode == 'loading',
    error: mode == 'error' ? 'synthetic workspace failure' : null,
  );
  @override
  WorkspaceShellState build() => const WorkspaceShellState(
    organizationId: '10',
    currentWorkspaceId: '100',
    workspaces: [
      WorkspaceModel(
        id: '100',
        name: '合成企业',
        ownerId: '1',
        organizationId: '10',
      ),
    ],
  );
  void organization(String id, {String? workspaceId}) => state = state.copyWith(
    organizationId: id,
    currentWorkspaceId: workspaceId ?? '${id}0',
    workspaces: [
      WorkspaceModel(
        id: workspaceId ?? '${id}0',
        name: '合成企业 $id',
        ownerId: '1',
        organizationId: id,
      ),
    ],
  );
}

class _Api extends WorkspaceApi {
  @override
  Future<List<GroupModel>> memberGroups(EntityId workspaceId) async => [];
  @override
  Future<Map<String, dynamic>> attachments(
    EntityId workspaceId,
    Map<String, dynamic> filters,
  ) async => {
    'workspace_id': workspaceId,
    'next_cursor': null,
    'items': [
      {
        'id': 991,
        'name': 'enterprise-report.pdf',
        'size': 100,
        'scope': 'group',
        'scope_ref': '200',
        'source_name': 'test group',
        'creator_name': 'test uploader',
        'created_at': '2026-10-08T03:00:00Z',
      },
    ],
  };
  @override
  Future<List<WorkspaceConversationModel>> conversations(
    EntityId workspaceId,
  ) async => [];
  @override
  Future<List<ChannelModel>> channels(
    EntityId workspaceId, {
    String? status,
  }) async => [];
}

class _OrgApi extends OrganizationApi {
  _OrgApi(this.role);
  final String role;
  @override
  Future<Organization> detail(EntityId orgId) async {
    if (role == 'error') throw StateError('synthetic role failure');
    return Organization(id: orgId, name: '合成企业资料', memberRole: role);
  }
}

class _DirectoryTransport implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final path = options.uri.path;
    final departments = path.endsWith('/directory/departments');
    final payload = <String, dynamic>{
      'organization_id': 10,
      'list': departments
          ? [
              {'id': 21, 'name': '合成研发部', 'member_count': 0},
            ]
          : <Map<String, dynamic>>[],
      'cursor': null,
      'has_more': false,
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'msg': 'success', 'payload': payload}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _OaApi extends OaWorkbenchApi {
  final calls = <String>[];
  // initState watch + postFrame invalidate 会双触发请求：按队列缓存
  // completer，completeFirst 消费最早一个（键控单 completer 会被二次
  // complete 打爆）。
  final pending = <String, List<Completer<List<EnterpriseOaRuntimeConfig>>>>{};
  @override
  Future<List<EnterpriseOaRuntimeConfig>> entries() {
    calls.add('entries');
    final c = Completer<List<EnterpriseOaRuntimeConfig>>();
    pending.putIfAbsent('entries', () => []).add(c);
    return c.future;
  }

  void completeFirst(List<EnterpriseOaRuntimeConfig> value) {
    pending['entries']!.removeAt(0).complete(value);
  }

  void failFirst(Object error) {
    pending['entries']!.removeAt(0).completeError(error);
  }

  void resetPending() {
    pending['entries'] = [];
  }
}

List<EnterpriseOaRuntimeConfig> _entries(String org) =>
    parseOaWorkbenchEntries({
      'entries': [
        {
          'kind': 'oa',
          'organization_id': int.parse(org),
          'application_key': 'synthetic-oa-key',
          'label': '合成办公 $org',
          'redirect_uri': 'https://oa.example.com/$org',
        },
      ],
    });

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _OaApi api, {
  Size size = const Size(430, 900),
  String? emptyMode,
  List<GroupModel> groups = const [],
  String orgRole = 'member',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        UserModel(uid: '1', account: 'synthetic-account', nickname: '合成员工'),
      ),
      workspaceShellProvider.overrideWith(_Shell.new),
      workspaceApiProvider.overrideWithValue(_Api()),
      organizationApiProvider.overrideWithValue(_OrgApi(orgRole)),
      workspaceGroupsProvider('100').overrideWith((ref) async => groups),
      oaWorkbenchApiProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  if (emptyMode != null) {
    (container.read(workspaceShellProvider.notifier) as _Shell).empty(
      emptyMode,
    );
  }
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: emptyMode == null
              ? const WorkspaceShellPage()
              : const WorkspaceShellBootstrap(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

List<String> _labels(WidgetTester tester) => tester
    .widget<NavigationBar>(
      find.byKey(const ValueKey('enterprise-shell-bottom-nav')),
    )
    .destinations
    .cast<NavigationDestination>()
    .map((item) => item.label)
    .toList();

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel(uid: '1', account: 'synthetic-account');
  void select(String uid) => state = uid.isEmpty
      ? null
      : UserModel(uid: uid, account: 'synthetic-account');
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _DelayedChannelsApi extends WorkspaceApi {
  final pending = <Completer<List<ChannelModel>>>[];
  @override
  Future<List<ChannelModel>> channels(EntityId workspaceId, {String? status}) {
    final reply = Completer<List<ChannelModel>>();
    pending.add(reply);
    return reply.future;
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    HttpClient.adapterForTest = _DirectoryTransport();
  });
  tearDown(() => HttpClient.adapterForTest = null);
  for (final role in ['member', 'admin']) {
    testWidgets('企业抽屉承载身份与快捷入口，角色 $role', (tester) async {
      final api = _OaApi();
      await _pump(tester, api, orgRole: role, size: const Size(320, 640));
      // 底栏回四栏：消息/通讯录/工作台/我。
      expect(find.text('我'), findsOneWidget);
      // 左上汉堡按钮唤起深蓝抽屉：身份 + 名片/高级功能/创建加入企业/设置
      // + 切换到个人/退出登录。
      await tester.tap(
        find.byKey(const ValueKey('enterprise-shell-menu-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成员工'), findsOneWidget);
      // 企业名两处：身份行次级文本 + 企业带主名。
      expect(find.text('合成企业'), findsWidgets);
      expect(find.text('我的名片'), findsOneWidget);
      expect(find.text('高级功能'), findsOneWidget);
      expect(find.text('创建 / 加入企业'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('切换到个人'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
      expect(find.byType(MinePage), findsNothing);
      expect(
        find.byKey(const ValueKey('workspace-shell-account-entry')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('顶栏显示企业·工作区两级上下文（T06 spec D1）', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    // org detail(合成企业资料) + currentWorkspace(合成企业) 组成两级
    // 副行；消息 tab 标题仍为 tab 名，汉堡与加号按钮原样保留。
    expect(find.text('合成企业资料 · 合成企业'), findsOneWidget);
    expect(find.text('消息'), findsWidgets);
    expect(
      find.byKey(const ValueKey('enterprise-shell-menu-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    // 切到通讯录 tab：上下文副行仍在（0005：非消息 tab 无抽屉，但
    // 上下文不得消失），邀请同事按钮照常。
    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.text('合成企业资料 · 合成企业'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('enterprise-topbar-invite-colleagues')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('无工作区上下文时顶栏降级为单段（不产生孤立分隔符）', (tester) async {
    final api = _OaApi();
    await _pump(tester, api, emptyMode: 'ok');
    await tester.pumpAndSettle();
    // empty('ok') 起步时工作区列表为空 → 副行只剩 org 名单段，无 ' · '。
    final joined = tester
        .widgetList<Text>(find.byType(Text))
        .where((node) => (node.data ?? '').contains(' · '))
        .toList();
    expect(joined, isEmpty);
    expect(find.text('合成企业资料'), findsOneWidget);
  });
  testWidgets('仅消息页显示左上抽屉入口，切回消息恢复入口', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    api.completeFirst([]);
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('enterprise-shell-menu-button'));
    final navigation = find.byKey(
      const ValueKey('enterprise-shell-bottom-nav'),
    );
    expect(menu, findsOneWidget);
    for (final label in ['通讯录', '工作台', '我', '消息']) {
      await tester.tap(
        find.descendant(of: navigation, matching: find.text(label)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(menu, label == '消息' ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(menu);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('我的名片'), findsOneWidget);
  });
  testWidgets('消息页挂筛选 tab 与右上角加号按钮', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    expect(find.text('日程'), findsOneWidget);
    expect(find.text('待办'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-message-filter-tab')),
      findsOneWidget,
    );
    // 点筛选 chip 弹出「视图 + 筛选」统一菜单。
    await tester.tap(
      find.byKey(const ValueKey('workspace-message-filter-tab')),
    );
    await tester.pumpAndSettle();
    // 视图段：日程/待办与顶栏 tab 同文案，各出现两处（tab + 菜单项）。
    expect(find.text('日程'), findsWidgets);
    expect(find.text('待办'), findsWidgets);
    // 筛选段：全部/未读/群聊/频道（真实可用项）。
    expect(find.text('未读'), findsOneWidget);
    expect(find.text('群聊'), findsOneWidget);
    expect(find.text('频道'), findsOneWidget);
    // 「功能开发中」项不展示：@我/单聊/内部聊天/外部聊天/标记/编辑
    // （TODO 广州第一期交付后实现）。
    for (final hidden in ['@我', '单聊', '内部聊天', '外部聊天', '标记', '编辑']) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    // 选中「未读」：下拉收起，chip 同步切「未读」，空态单独措辞。
    await tester.tap(find.text('未读'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsNothing);
    expect(find.text('暂无未读会话'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('弹窗可切日程/待办视图并同步顶栏 chip', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    api.completeFirst([]);
    await tester.pumpAndSettle();
    // 从弹窗进入日程视图（顶栏 tab 与菜单项同文案，取菜单项后者）。
    await tester.tap(
      find.byKey(const ValueKey('workspace-message-filter-tab')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('日程').last);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceGroupAgendaView), findsOneWidget);
    // chip 跟随当前视图显示「日程」。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workspace-message-filter-tab')),
        matching: find.text('日程'),
      ),
      findsOneWidget,
    );
    // 再从弹窗切回「全部」→ 消息视图回归。
    await tester.tap(
      find.byKey(const ValueKey('workspace-message-filter-tab')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部').last);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceConversationsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('企业标签在重挂载后恢复，各企业的频道选择独立', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    api.completeFirst([]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('通讯录').last);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WorkspaceShellPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    final shell = container.read(workspaceShellProvider.notifier) as _Shell;
    shell.organization('10', workspaceId: '101');
    await tester.pumpAndSettle();
    expect(find.byType(HumanDirectoryBrowserPage), findsNothing);
    shell.organization('10');
    await tester.pumpAndSettle();
    expect(find.byType(HumanDirectoryBrowserPage), findsOneWidget);
    shell.organization('20');
    await tester.pump();
    api.completeFirst([]);
    await tester.pumpAndSettle();
    expect(find.byType(HumanDirectoryBrowserPage), findsNothing);
    // 频道改为筛选下拉内的一档：选择后消息 tab 切到频道列表。
    await tester.tap(
      find.byKey(const ValueKey('workspace-message-filter-tab')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();
    shell.organization('10');
    await tester.pumpAndSettle();
    expect(find.byType(HumanDirectoryBrowserPage), findsOneWidget);
    shell.organization('20');
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceChannelsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('退出企业或换账号清除对应导航记录', () async {
    final container = ProviderContainer.test(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        workspaceApiProvider.overrideWithValue(_Api()),
      ],
    );
    final shell = container.read(workspaceShellProvider.notifier);
    await shell.selectOrganization('10', () async => '');
    shell.rememberEnterpriseNavigation((
      destination: EnterpriseShellDestination.contacts,
      filter: WorkspaceMessageFilter.all,
    ));
    shell.forgetOrganization('10');
    await shell.selectOrganization('10', () async => '');
    expect(
      container.read(workspaceShellProvider).enterpriseNavigation.destination,
      EnterpriseShellDestination.messages,
    );
    shell.rememberEnterpriseNavigation((
      destination: EnterpriseShellDestination.workbench,
      filter: WorkspaceMessageFilter.channel,
    ));
    container.read(_account.notifier).select('2');
    await container.pump();
    expect(container.read(workspaceShellProvider).enterpriseNavigation, (
      destination: EnterpriseShellDestination.messages,
      filter: WorkspaceMessageFilter.all,
    ));
  });
  testWidgets('恢复工作台先重新校验配置，撤权后保留空工作台', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    api.completeFirst(_entries('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作台').last);
    await tester.pumpAndSettle();
    expect(find.text('合成办公 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    api.resetPending();
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WorkspaceShellPage()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('合成办公 10'), findsNothing);
    expect(find.byType(OaTabPage), findsNothing);
    api.completeFirst([]);
    await tester.pumpAndSettle();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    expect(find.byType(EnterpriseWorkbenchPage), findsOneWidget);
    expect(find.byType(OaTabPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final mode in ['normal', 'loading', 'error']) {
    testWidgets('无工作区企业 $mode 仍可从首页进入组织架构', (tester) async {
      final api = _OaApi();
      await _pump(tester, api, emptyMode: mode);
      api.completeFirst([]);
      await tester.pump();
      expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
      expect(
        find.byKey(const ValueKey('workspace-empty-create-entry')),
        findsNothing,
      );
      if (mode == 'error') {
        expect(find.text('synthetic workspace failure'), findsOneWidget);
      }
      if (mode == 'loading') {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
      await tester.tap(find.text('通讯录').last);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('合成研发部').evaluate().isNotEmpty) break;
      }
      expect(find.text('合成研发部'), findsOneWidget);
      // 左上汉堡只在「消息」页展示；通讯录/工作台/我不挂。
      expect(
        find.byKey(const ValueKey('enterprise-shell-menu-button')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  test('退出账号后工作区资源立即清空，不发鉴权外请求', () async {
    final container = ProviderContainer.test(
      overrides: [currentUserProvider.overrideWithValue(null)],
    );
    expect(
      (await container.read(workspaceOverviewProvider('100').future))
          .memberPreview,
      isEmpty,
    );
    expect(
      (await container.read(workspaceMembersProvider('100').future)).list,
      isEmpty,
    );
    expect(
      await container.read(workspaceProjectsProvider('100').future),
      isEmpty,
    );
    expect(
      await container.read(workspaceChannelsProvider('100').future),
      isEmpty,
    );
  });

  test('同一工作区换账号：重拉频道，旧请求不得覆盖新账号', () async {
    final api = _DelayedChannelsApi();
    final container = ProviderContainer.test(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        workspaceApiProvider.overrideWithValue(api),
      ],
    );
    final provider = workspaceChannelsProvider('100');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    container.read(provider.future);
    container.read(_account.notifier).select('2');
    final fresh = container.read(provider.future);
    expect(api.pending, hasLength(2));
    api.pending.last.complete([
      ChannelModel.fromJson({'id': '2', 'name': 'new account'}),
    ]);
    expect((await fresh).single.name, 'new account');
    api.pending.first.complete([
      ChannelModel.fromJson({'id': '1', 'name': 'old account'}),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(provider).requireValue.single.name, 'new account');
    container.read(_account.notifier).select('');
    expect(await container.read(provider.future), isEmpty);
    expect(api.pending, hasLength(2));
  });

  testWidgets('无 OA：四项导航默认消息，通讯录按需加载', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    api.completeFirst([]);
    await tester.pump();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    expect(find.byType(WorkspaceConversationsPage), findsOneWidget);
    expect(find.byType(HumanDirectoryBrowserPage), findsNothing);
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    expect(find.text(t.workspace.navGroups), findsOneWidget);
    expect(find.text(t.channel.title), findsOneWidget);
    expect(find.text(t.attachmentManager.title), findsOneWidget);
    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.byType(HumanDirectoryBrowserPage), findsOneWidget);
    // 左上汉堡只在「消息」页展示；通讯录/工作台/我不挂。
    expect(
      find.byKey(const ValueKey('enterprise-shell-menu-button')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('无 OA 工作台附件入口进入企业统一检索中心', (tester) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
    final api = _OaApi();
    await _pump(
      tester,
      api,
      groups: [
        GroupModel.fromJson({'id': 301, 'title': '合成资料群'}),
      ],
    );
    api.completeFirst([]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.attachmentManager.title));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceAttachmentsPage), findsOneWidget);
    expect(find.text('enterprise-report.pdf'), findsOneWidget);
    expect(find.text(t.attachmentManager.personSearch), findsOneWidget);
    // 页面不再自带 AppBar（否则与资源入口外壳叠出双层标题——附件/企业附件
    // 双 back 回归钉）：入口外壳的「附件」标题栏是唯一 AppBar。
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text(t.attachmentManager.enterpriseTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('授权 OA 出现工作台，但未选应用前不创建 SSO 页面', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    api.completeFirst(_entries('10'));
    await tester.pump();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    expect(find.byType(OaTabPage), findsNothing);
    await tester.tap(find.text('工作台'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('合成办公 10'), findsOneWidget);
    expect(find.byType(OaTabPage), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('企业切换重建 shell 后配置仍是账号级结果，无按企业分叉的旧缓存（定位修订）', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    api.completeFirst(_entries('10'));
    await tester.pump();
    await tester.pump();
    (container.read(workspaceShellProvider.notifier) as _Shell).organization(
      '20',
    );
    await tester.pump();
    await tester.pump();
    // 切企业会重建 shell（保持各企业导航的既有机制），initState 的
    // postFrame invalidate 重新拉取——发现键只绑 accountKey（组织是
    // 业务对象不参与），不存在 (account, org) 分叉缓存，重建后由最新
    // 请求结果驱动 UI。
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    api.completeFirst(_entries('10'));
    await tester.pump();
    await tester.tap(find.text('工作台'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('合成办公 10'), findsOneWidget);
    expect(find.text('合成办公 20'), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('频道经筛选下拉进入，不占企业底栏', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    api.completeFirst([]);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('workspace-message-filter-tab')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('频道'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceChannelsPage), findsOneWidget);
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('企业配置读取失败有重试入口，旧工作台立即撤下', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    api.completeFirst(_entries('10'));
    await tester.pump();
    await tester.tap(find.text('工作台'));
    await tester.pump();
    api.resetPending();
    container.invalidate(oaWorkbenchEntriesProvider('1'));
    await tester.pump();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    api.failFirst(StateError('synthetic denied'));
    await tester.pump();
    expect(find.text(t.enterpriseOa.actionRetry), findsOneWidget);
    expect(find.text('合成办公 10'), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('桌面复用四项侧栏，同样读取 OA entries（macOS 平台门已放开）', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final api = _OaApi();
    await _pump(tester, api, size: const Size(1440, 900));
    final rail = tester.widget<NavigationRail>(
      find.byKey(const ValueKey('enterprise-shell-rail')),
    );
    expect(rail.destinations.map((item) => (item.label as Text).data), [
      '消息',
      '通讯录',
      '工作台',
      '我',
    ]);
    expect(api.calls, isNotEmpty); // macOS 桥齐备，须照常拉取
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('广州裁剪保留企业四栏、无OA官网及个人频道入口', (tester) async {
    final previousFlags = Map<String, dynamic>.from(
      AppFeatureRegistry.snapshot,
    );
    final previousManifest = AppManifestService.manifest?.toMap();
    AppFeatureRegistry.replaceSnapshotForTest({
      FeatureKeys.project: false,
      FeatureKeys.channelDiscover: false,
      FeatureKeys.location: false,
      FeatureKeys.channel: true,
      FeatureKeys.moment: true,
    });
    AppManifestService.replaceForTest({
      'app_entries': [
        'channel_tab',
        'moment_tab',
        'channel_discover_page',
        'people_nearby_page',
      ],
    });
    addTearDown(() async {
      AppFeatureRegistry.replaceSnapshotForTest(previousFlags);
      if (previousManifest == null) {
        await AppManifestService.clear();
      } else {
        AppManifestService.replaceForTest(previousManifest);
      }
    });
    final api = _OaApi();
    await _pump(tester, api);
    api.completeFirst([]);
    await tester.pumpAndSettle();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
    expect(find.text('https://imboy.pub/test_oa.html'), findsOneWidget);
    for (final (path, reason) in [
      ('/workspace/100/projects/200', RouteBlockReason.featureFlag),
      ('/channel/discover', RouteBlockReason.featureFlag),
      ('/contact/people_nearby', RouteBlockReason.featureFlag),
    ]) {
      final blocked = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: path,
      );
      expect(blocked?.reason, reason, reason: path);
      expect(blocked?.redirect, '/bottom_navigation', reason: path);
    }
    // Actual personal route guards; full personal widget mounting is separate.
    for (final path in ['/channel', '/moment/feed']) {
      expect(
        RouteFeatureGuard.checkBlocked(isLoggedIn: true, currentPath: path),
        isNull,
        reason: path,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mounted enterprise workbench reacts to validated project flags',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
      await StorageService.init();
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.project: false});
      final api = _OaApi();
      await _pump(tester, api);
      api.completeFirst([]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('工作台'));
      await tester.pumpAndSettle();
      expect(find.text(t.workspace.navProjects), findsNothing);
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.project: true});
      await tester.pumpAndSettle();
      expect(
        find.text(t.workspace.navProjects),
        compiledProductFeatures.contains(FeatureKeys.project)
            ? findsOneWidget
            : findsNothing,
      );
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.project: false});
      await tester.pumpAndSettle();
      expect(find.text(t.workspace.navProjects), findsNothing);
      expect(find.text('工作台'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'remote project flag respects compiled lock in workbench and deep link',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
      await StorageService.init();
      final previousFlags = Map<String, dynamic>.from(
        AppFeatureRegistry.snapshot,
      );
      addTearDown(
        () => AppFeatureRegistry.replaceSnapshotForTest(previousFlags),
      );
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.project: true});
      final projectCompiled = compiledProductFeatures.contains(
        FeatureKeys.project,
      );
      // Phase1 rejects remote enablement; full-selected retains the positive.
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.project),
        projectCompiled,
      );
      final api = _OaApi();
      await _pump(tester, api);
      api.completeFirst([]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('工作台'));
      await tester.pumpAndSettle();
      expect(
        find.text(t.workspace.navProjects),
        projectCompiled ? findsOneWidget : findsNothing,
      );
      final blocked = RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/workspace/100/projects/200',
      );
      if (projectCompiled) {
        expect(blocked, isNull);
      } else {
        expect(blocked?.reason, RouteBlockReason.featureFlag);
        expect(blocked?.redirect, '/bottom_navigation');
      }
      expect(find.text('工作台'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
