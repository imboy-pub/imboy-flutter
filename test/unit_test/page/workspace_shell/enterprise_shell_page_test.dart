import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_bootstrap.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/public.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_workbench_api.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
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
  Future<List<WorkspaceConversationModel>> conversations(
    EntityId workspaceId,
  ) async => [];
  @override
  Future<List<ChannelModel>> channels(
    EntityId workspaceId, {
    String? status,
  }) async => [];
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
  final pending = <String, Completer<List<EnterpriseOaRuntimeConfig>>>{};
  @override
  Future<List<EnterpriseOaRuntimeConfig>> entries(String organizationId) {
    calls.add(organizationId);
    return pending.putIfAbsent(organizationId, Completer.new).future;
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
    }, org);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _OaApi api, {
  Size size = const Size(430, 900),
  String? emptyMode,
  List<GroupModel> groups = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        UserModel(uid: '1', account: 'synthetic-account'),
      ),
      workspaceShellProvider.overrideWith(_Shell.new),
      workspaceApiProvider.overrideWithValue(_Api()),
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
  testWidgets('企业标签在重挂载后恢复，各企业的频道选择独立', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    api.pending['10']!.complete([]);
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
    api.pending['20']?.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(HumanDirectoryBrowserPage), findsNothing);
    await tester.tap(find.text('频道').last);
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
      channels: false,
    ));
    shell.forgetOrganization('10');
    await shell.selectOrganization('10', () async => '');
    expect(
      container.read(workspaceShellProvider).enterpriseNavigation.destination,
      EnterpriseShellDestination.messages,
    );
    shell.rememberEnterpriseNavigation((
      destination: EnterpriseShellDestination.mine,
      channels: true,
    ));
    container.read(_account.notifier).select('2');
    await container.pump();
    expect(container.read(workspaceShellProvider).enterpriseNavigation, (
      destination: EnterpriseShellDestination.messages,
      channels: false,
    ));
  });
  testWidgets('恢复工作台先重新校验配置，撤权后保留空工作台', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    api.pending['10']!.complete(_entries('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作台').last);
    await tester.pumpAndSettle();
    expect(find.text('合成办公 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    api.pending.remove('10');
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
    api.pending['10']!.complete([]);
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
      api.pending['10']?.complete([]);
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
      expect(
        find.byKey(const ValueKey('workspace-shell-switcher')),
        findsOneWidget,
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
    api.pending['10']!.complete([]);
    await tester.pump();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    expect(find.byType(WorkspaceConversationsPage), findsOneWidget);
    expect(find.byType(HumanDirectoryBrowserPage), findsNothing);
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    expect(find.text(t.workspace.navGroups), findsOneWidget);
    expect(find.text(t.channel.title), findsOneWidget);
    expect(find.text(t.chat.groupFile), findsOneWidget);
    await tester.tap(find.text('通讯录'));
    await tester.pumpAndSettle();
    expect(find.byType(HumanDirectoryBrowserPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-shell-switcher')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('无 OA 工作台群文件按当前工作区进入指定群', (tester) async {
    final api = _OaApi();
    await _pump(
      tester,
      api,
      groups: [
        GroupModel.fromJson({'id': 301, 'title': '合成资料群'}),
      ],
    );
    api.pending['10']!.complete([]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.chat.groupFile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workspace-group-tile-301')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GroupFilePage>(find.byType(GroupFilePage)).groupId,
      '301',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('授权 OA 出现工作台，但未选应用前不创建 SSO 页面', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    api.pending['10']!.complete(_entries('10'));
    await tester.pump();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    expect(find.byType(OaTabPage), findsNothing);
    await tester.tap(find.text('工作台'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('合成办公 10'), findsOneWidget);
    expect(find.byType(OaTabPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('企业切换销毁旧工作台，旧响应不能补回旧应用', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    (container.read(workspaceShellProvider.notifier) as _Shell).organization(
      '20',
    );
    await tester.pump();
    await tester.pump();
    api.pending['20']!.complete(_entries('20'));
    await tester.pump();
    api.pending['10']!.complete(_entries('10'));
    await tester.pump();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    await tester.tap(find.text('工作台'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('合成办公 20'), findsOneWidget);
    expect(find.text('合成办公 10'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('频道从消息内进入，不占企业底栏', (tester) async {
    final api = _OaApi();
    await _pump(tester, api);
    api.pending['10']!.complete([]);
    await tester.pump();
    await tester.tap(find.text('频道'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WorkspaceChannelsPage), findsOneWidget);
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    expect(tester.takeException(), isNull);
  });
  testWidgets('企业配置读取失败有重试入口，旧工作台立即撤下', (tester) async {
    final api = _OaApi();
    final container = await _pump(tester, api);
    api.pending['10']!.complete(_entries('10'));
    await tester.pump();
    await tester.tap(find.text('工作台'));
    await tester.pump();
    api.pending.remove('10');
    container.invalidate(
      oaWorkbenchEntriesProvider((accountKey: '1', organizationId: '10')),
    );
    await tester.pump();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    api.pending['10']!.completeError(StateError('synthetic denied'));
    await tester.pump();
    expect(find.text(t.enterpriseOa.actionRetry), findsOneWidget);
    expect(find.text('合成办公 10'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('桌面复用四项侧栏，不读取不支持的 OA', (tester) async {
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
    expect(api.calls, isEmpty);
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
    api.pending['10']!.complete([]);
    await tester.pumpAndSettle();
    expect(_labels(tester), ['消息', '通讯录', '工作台', '我']);
    await tester.tap(find.text('工作台'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workbench-official-website')),
      findsOneWidget,
    );
    expect(find.text('https://imboy.pub/'), findsOneWidget);
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
}
