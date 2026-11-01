/// WP5 (T9) — Workspace Channel 详情视图结构契约测试（I6 + W06/F12）
///
/// 计划锚点：Workspace 的 Channel 视图**不提供聊天式输入框**（无
/// ChatInput / 聊天 Composer），只有发帖/评论入口。
///
/// W06/F12 收敛（J12）：「去 General 群聊聊」常驻引导横幅与进个人会话
/// 列表的「私聊/全部消息」按钮已移除——讨论的唯一合法目的地是内容区内
/// 的真实绑定讨论入口（ChannelDiscussionEntry，经 embedded
/// ChannelDetailPage 提供）；不造 General、不自动加入。
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:dio/dio.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/page/workspace/widget/workspace_access_guard.dart';
import 'package:imboy/page/workspace/workspace_access_provider.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_group_create_page.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

// J12.a：讨论入口绑定向量需要开门（ChannelMicroCommunityPolicy 读
// manifest + registry 两个全局静态），沿 J27.f 先例在测试内替换并在
// tearDown 复原。
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart'
    show
        compiledProductFeatures,
        productFeatureManifestHash,
        productFeatureSchemaVersion;
import 'package:imboy/page/channel/widgets/channel_discussion_entry.dart';
import 'package:go_router/go_router.dart';

class _ChannelApi extends ChannelApi {
  @override
  Future<ChannelModel> getChannelChecked(String channelId) async {
    expect(channelId, '9002');
    return ChannelModel(
      id: 9002,
      scope: 'workspace',
      workspaceId: '100',
      name: 'Workspace channel',
      creatorId: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      visibility: 1,
      accessType: 0,
      joinPolicy: 1,
    );
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/channel/9002/messages');
    expect(queryParameters, {'limit': 1});
    return IMBoyHttpResponse.success({'list': <Map<String, dynamic>>[]});
  }
}

// J14.a：仅合成成功空集合，保留真实 provider、目录与导航链。
class _EmptyDirectoryApi extends WorkspaceApi {
  final groupWorkspaces = <EntityId>[];
  final allGroupWorkspaces = <EntityId>[];
  final channelWorkspaces = <EntityId>[];
  final memberWorkspaces = <EntityId>[];

  // 合成另一个工作区群：当前用户未加入，不应出现在成员群目录。
  final otherWorkspaceGroups = <GroupModel>[
    GroupModel.fromJson({'id': 2001, 'title': '其他成员的群'}),
  ];

  @override
  Future<List<GroupModel>> groups(EntityId workspaceId) async {
    allGroupWorkspaces.add(workspaceId);
    return otherWorkspaceGroups;
  }

  @override
  Future<List<GroupModel>> memberGroups(EntityId workspaceId) async {
    groupWorkspaces.add(workspaceId);
    return const [];
  }

  @override
  Future<List<ChannelModel>> channels(
    EntityId workspaceId, {
    String? status,
  }) async {
    channelWorkspaces.add(workspaceId);
    return const [];
  }

  @override
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    memberWorkspaces.add(workspaceId);
    return const WorkspacePageResult<WorkspaceMemberModel>();
  }
}

class _NoDirectoryWrites implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    throw StateError('J14.a 不允许目录导航发出 HTTP 请求');
  }

  @override
  void close({bool force = false}) {}
}

Future<_EmptyDirectoryApi> _pumpEmptyDirectory(
  WidgetTester tester,
  Widget directory,
) async {
  final adapter = _NoDirectoryWrites();
  HttpClient.adapterForTest = adapter;
  addTearDown(() {
    HttpClient.adapterForTest = null;
    expect(adapter.requests, isEmpty, reason: '目录不自动创建、加入或补资源');
  });
  // 必须在安装拦截器之后构造同一个 API 实例。
  final api = _EmptyDirectoryApi();
  expect(identical(api.dio.httpClientAdapter, adapter), isTrue);
  // 先校验同实例 POST 确实到达拦截器；identity 校验使探针绝不触网。
  await tester.runAsync(() async {
    await expectLater(
      api.dio.post<void>('https://j14.invalid/probe', data: {'probe': true}),
      throwsA(isA<DioException>()),
    );
  });
  expect(adapter.requests, hasLength(1));
  expect(adapter.requests.single.method, 'POST');
  expect(adapter.requests.single.uri.toString(), 'https://j14.invalid/probe');
  adapter.requests.clear(); // 探针不计入实际页面导航的零请求断言。
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceApiProvider.overrideWithValue(api),
        currentUserProvider.overrideWith(
          (ref) => UserModel.fromJson({'uid': '91001'}),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp(home: Scaffold(body: directory)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('J14.a 群目录成功空：本人已加入群为空，CTA 进入当前工作区建群页', (tester) async {
    final api = await _pumpEmptyDirectory(
      tester,
      const WorkspaceGroupsPage(workspaceId: '100'),
    );

    // 空的是本人已加入的群，不是整个工作区的群；绝不请求全体群或补资源。
    expect(api.otherWorkspaceGroups, hasLength(1));
    expect(api.groupWorkspaces, ['100']);
    expect(api.allGroupWorkspaces, isEmpty);
    expect(find.text('其他成员的群'), findsNothing);
    expect(api.memberWorkspaces, isEmpty);
    expect(t.workspace.groupsEmptyTitle, '你还没有加入工作区群组');
    expect(t.workspace.groupsEmptySubtitle, '群组是工作区里的实时讨论空间（聊天唯一入口）');
    expect(find.text(t.workspace.groupsEmptyTitle), findsOneWidget);
    expect(find.text(t.workspace.groupsEmptySubtitle), findsOneWidget);
    expect(find.byType(WorkspaceErrorView), findsNothing);
    expect(find.byType(WorkspaceLoadingView), findsNothing);
    expect(find.text(t.common.searchNoResults), findsNothing);
    expect(find.textContaining('General'), findsNothing);
    expect(find.byType(WorkspaceGroupCreatePage), findsNothing);
    final empty = tester.widget<WorkspaceEmptyView>(
      find.byType(WorkspaceEmptyView),
    );
    expect(empty.actions, hasLength(1));

    await tester.tap(find.text(t.organization.manage.createGroup));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceGroupCreatePage), findsOneWidget);
    expect(
      tester
          .widget<WorkspaceGroupCreatePage>(
            find.byType(WorkspaceGroupCreatePage),
          )
          .workspaceId,
      '100',
    );
    expect(api.memberWorkspaces, ['100']);
    expect(api.groupWorkspaces, ['100']);
    expect(api.allGroupWorkspaces, isEmpty);
    expect(api.channelWorkspaces, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('J14.a 频道目录成功空：无虚构创建 CTA，刷新是合法下一步', (tester) async {
    final api = await _pumpEmptyDirectory(
      tester,
      const WorkspaceChannelsPage(workspaceId: '100'),
    );

    expect(api.channelWorkspaces, ['100']);
    expect(find.text(t.workspace.channelsEmptyTitle), findsOneWidget);
    expect(find.text(t.workspace.channelsEmptySubtitle), findsOneWidget);
    expect(find.byType(WorkspaceErrorView), findsNothing);
    expect(find.byType(WorkspaceLoadingView), findsNothing);
    expect(find.text(t.channel.noResults), findsNothing);
    expect(find.textContaining('General'), findsNothing);
    expect(
      tester
          .widget<WorkspaceEmptyView>(find.byType(WorkspaceEmptyView))
          .actions,
      isEmpty,
    );
    expect(find.byType(CupertinoButton), findsNothing);
    expect(find.text(t.organization.manage.createGroup), findsNothing);
    final refresh = find.byKey(const ValueKey('workspace-channel-refresh'));
    expect(tester.widget<IconButton>(refresh).onPressed, isNotNull);

    await tester.tap(refresh);
    await tester.pumpAndSettle();

    expect(api.channelWorkspaces, ['100', '100']);
    expect(find.text(t.workspace.channelsEmptyTitle), findsOneWidget);
    expect(find.text(t.workspace.channelsEmptySubtitle), findsOneWidget);
    expect(find.byType(WorkspaceErrorView), findsNothing);
    expect(find.byType(WorkspaceGroupCreatePage), findsNothing);
    expect(api.groupWorkspaces, isEmpty);
    expect(api.memberWorkspaces, isEmpty);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpPage(WidgetTester tester, {Widget? detailEntry}) async {
    // WorkspaceChannelDetailPage 为 ConsumerWidget（外层顶栏 watch 频道
    // provider），必须置于 ProviderScope 内。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelApiProvider.overrideWithValue(_ChannelApi()),
          workspaceAccessNetworkProvider.overrideWith(
            (ref) => Stream.value(true),
          ),
          workspaceAccessContextReaderProvider.overrideWithValue(
            () => (
              origin: 'https://workspace.invalid',
              uid: '1',
              session: 1,
              featureScope: 'workspace:1',
              featureEpoch: 1,
              featureRevision: 1,
              channelEnabled: true,
            ),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            home: WorkspaceChannelDetailPage(
              channelId: '9002',
              workspaceId: '100',
              detailEntry: detailEntry ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('workspace-access-shield')), findsNothing);
  }

  testWidgets('频道详情视图无聊天式输入框（I6：不出现 ChatInput）', (tester) async {
    await pumpPage(tester);
    expect(find.byType(ChatInput), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('W06/J12：常驻讨论引导横幅已移除，页面无 General 文案', (tester) async {
    await pumpPage(tester);
    expect(
      find.byKey(const ValueKey('workspace-channel-discuss-guide')),
      findsNothing,
      reason: '跳群列表的常驻引导与真实绑定讨论入口并存属 F12 反模式',
    );
    expect(find.textContaining('General'), findsNothing);
  });

  testWidgets('W06/F12：无「全部消息/私聊」按钮（个人会话列表不是频道讨论目的地）', (tester) async {
    await pumpPage(tester);
    expect(
      find.byKey(const ValueKey('workspace-channel-detail-dm-entry')),
      findsNothing,
    );
  });

  testWidgets('内容区默认复用现有频道内容页（发帖/评论模型，非聊天页）', (tester) async {
    final entry = defaultWorkspaceChannelDetailEntry('9002');
    expect(entry, isA<ChannelDetailPage>());
    expect((entry as ChannelDetailPage).channelId, '9002');
  });

  testWidgets('注入内容区直接成为页面主体（无横幅占位）', (tester) async {
    await pumpPage(
      tester,
      detailEntry: const SizedBox(key: ValueKey('detail-entry-probe')),
    );
    expect(find.byKey(const ValueKey('detail-entry-probe')), findsOneWidget);
    // body 即内容区本身（W06 收敛后无 Column+横幅结构）。
    final bodyDy = tester
        .getTopLeft(find.byKey(const ValueKey('detail-entry-probe')))
        .dy;
    final appBarBottom = tester.getBottomRight(find.byType(AppBar)).dy;
    expect(bodyDy, greaterThanOrEqualTo(appBarBottom));
  });

  group('J12.a 讨论入口绑定（plan §9：有/无/变更绑定；未入群不自动加入）', () {
    void openChannelGate() {
      // bindScope 必须先于 replaceForTest：bindScope 换 scope 会触发
      // manifest 内存 _checkScope 清空，先定 scope 再写 manifest，
      // 否则组内首个用例 reads=0（J12.a「无绑定」）。
      AppFeatureRegistry.bindScope(
        endpoint: 'http://127.0.0.1:29922',
        uid: 'j12a-synthetic-account',
      );
      AppManifestService.replaceForTest({
        'manifest_hash': productFeatureManifestHash,
        'manifest_schema_version': productFeatureSchemaVersion,
        'compiled_features': compiledProductFeatures,
        'app_entries': ['channel_tab'],
        'features': {FeatureKeys.channel: true},
        'policy': {'profile': 'community'},
      });
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: true});
    }

    ChannelModel channel({
      bool subscribed = true,
      bool purchased = true,
      Object? discussionGroupId = '7001',
    }) => ChannelModel(
      id: 9002,
      scope: 'personal',
      name: 'J12.a channel',
      creatorId: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      visibility: 1,
      accessType: 0,
      joinPolicy: 1,
      isSubscribed: subscribed,
      hasPurchased: purchased,
      discussionGroupId: discussionGroupId,
    );

    Future<_DiscussionApi> pumpEntry(
      WidgetTester tester, {
      required List<String?> bindings,
      required ChannelModel channelModel,
    }) async {
      final api = _DiscussionApi(bindings);
      final router = GoRouter(
        initialLocation: '/j12a-entry',
        routes: [
          GoRoute(
            path: '/j12a-entry',
            builder: (_, _) =>
                Scaffold(body: ChannelDiscussionEntry(channel: channelModel)),
          ),
          // 唯一准确目的地的探针：push 成功后渲染 chat-dest:<gid>。
          GoRoute(
            path: '/chat/:gid',
            builder: (_, state) => Scaffold(
              body: Text('chat-dest:${state.pathParameters['gid']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelApiProvider.overrideWithValue(api)],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: EasyLoading.init(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    setUp(() {
      AppFeatureRegistry.replaceSnapshotForTest({});
    });

    tearDown(() async {
      await AppManifestService.clear();
      AppFeatureRegistry.replaceSnapshotForTest({});
    });

    testWidgets('C-channel 功能门关闭：入口 fail-closed 不渲染、不读绑定', (tester) async {
      // 合成部署 channel 功能未交付（§9.1 桶 7）；不开门即默认门关闭。
      final api = await pumpEntry(
        tester,
        bindings: ['7001'],
        channelModel: channel(),
      );
      expect(api.reads, 0, reason: '门关闭时不得发起绑定读');
      expect(find.byKey(const Key('mc_discussion_join')), findsNothing);
      expect(find.byKey(const Key('mc_discussion_retry')), findsNothing);
      expect(find.text(t.channel.joinDiscussion), findsNothing);
      expect(find.text(t.channel.discussionIneligible), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('无绑定：不渲染入口、不造讨论目的地', (tester) async {
      openChannelGate();
      final api = await pumpEntry(
        tester,
        bindings: [null],
        channelModel: channel(discussionGroupId: null),
      );
      expect(api.reads, 1, reason: '门开时读一次真实绑定');
      expect(find.byKey(const Key('mc_discussion_join')), findsNothing);
      expect(find.text(t.channel.discussionIneligible), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('有绑定无资格（未订阅）：明确说明且不自动加入', (tester) async {
      openChannelGate();
      final api = await pumpEntry(
        tester,
        bindings: ['7001'],
        channelModel: channel(subscribed: false),
      );
      expect(
        find.text(t.channel.discussionIneligible),
        findsOneWidget,
        reason: 'W06/J12.a：资格不足必须明确说明，不静默隐藏',
      );
      expect(
        find.byKey(const Key('mc_discussion_join')),
        findsNothing,
        reason: '无资格不得提供加入按钮',
      );
      expect(api.joinCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('未入群点击：取消不加入；确认进唯一绑定群不造 General', (tester) async {
      openChannelGate();
      final api = await pumpEntry(
        tester,
        bindings: ['7001'],
        channelModel: channel(),
      );
      final joinButton = find.byKey(const Key('mc_discussion_join'));
      expect(joinButton, findsOneWidget);

      // 显式确认前绝不加入：取消分支零 join 调用、零导航。
      await tester.tap(joinButton);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(api.joinCalls, 0, reason: '取消分支不得自动加入');
      expect(find.textContaining('chat-dest:'), findsNothing);

      // 确认分支：join 幂等回显同 gid → push 唯一绑定目的地 /chat/7001。
      await tester.tap(joinButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mc_join_confirm')));
      await tester.pumpAndSettle();
      expect(api.joinCalls, 1);
      expect(
        find.text('chat-dest:7001'),
        findsOneWidget,
        reason: '目的地只能是真实绑定 gid，不造 General',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('变更绑定：确认时绑定漂移拒绝入群、零 join 调用、不导航', (tester) async {
      openChannelGate();
      final api = await pumpEntry(
        tester,
        bindings: const ['7001', '7002'],
        channelModel: channel(),
      );
      await tester.tap(find.byKey(const Key('mc_discussion_join')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mc_join_confirm')));
      await tester.pumpAndSettle();
      expect(api.joinCalls, 0, reason: '二次读取绑定与首次不一致必须拒绝，不得把人加进漂移后的群');
      expect(find.textContaining('chat-dest:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('绑定读取失败：错误行加重试入口，不渲染加入按钮', (tester) async {
      openChannelGate();
      final failing = _FailingDiscussionApi();
      final router = GoRouter(
        initialLocation: '/j12a-entry',
        routes: [
          GoRoute(
            path: '/j12a-entry',
            builder: (_, _) =>
                Scaffold(body: ChannelDiscussionEntry(channel: channel())),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelApiProvider.overrideWithValue(failing)],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: EasyLoading.init(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(failing.reads, 1);
      expect(
        find.text(t.common.loadError),
        findsOneWidget,
        reason: '读取失败显示可行动错误行',
      );
      expect(find.byKey(const Key('mc_discussion_retry')), findsOneWidget);
      expect(find.byKey(const Key('mc_discussion_join')), findsNothing);
    });
  });
}

/// J12.a 绑定序列桩：getDiscussion 依调用序弹出；游标耗尽后重复返回最后一个值。
/// joinCalls 只统计 joinDiscussion POST；join 载荷缺省回显同 gid。
class _DiscussionApi extends ChannelApi {
  _DiscussionApi(this.bindingSequence);

  final List<String?> bindingSequence;
  int reads = 0;
  int joinCalls = 0;
  Map<String, dynamic>? joinPayload;
  int _cursor = 0;

  @override
  Future<String?> getDiscussion(String channelId) async {
    reads++;
    if (bindingSequence.isEmpty) return null;
    if (_cursor >= bindingSequence.length) {
      return bindingSequence.last;
    }
    final value = bindingSequence[_cursor];
    _cursor++;
    return value;
  }

  @override
  Future<Map<String, dynamic>> joinDiscussion(String channelId) async {
    joinCalls++;
    return joinPayload ??
        const {
          'discussion_group_id': '7001',
          'title': 'J12A Discussion',
          'avatar': '',
          'member_count': 3,
        };
  }
}

/// 绑定读取抛错的 API 桩（J12.a 错误态向量）。
class _FailingDiscussionApi extends ChannelApi {
  int reads = 0;

  @override
  Future<String?> getDiscussion(String channelId) async {
    reads++;
    throw StateError('synthetic binding read failure');
  }

  @override
  Future<Map<String, dynamic>> joinDiscussion(String channelId) async {
    throw StateError('join must not be reachable in J12.a error vector');
  }
}
