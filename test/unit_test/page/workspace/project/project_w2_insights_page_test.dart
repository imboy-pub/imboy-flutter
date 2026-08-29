/// W2 (ZC-06) — 四聚合页视图测试（Pinned/Resources/Activity/Related Posts）
///
/// TDD 用例映射：
/// 3. 四聚合空态/加载态/错误态三态齐全（逐 Tab 验证；403 → 明确无权限态）；
/// 6. pinned 分页 size 10 + 加载更多。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/project/w2/project_insights_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show WorkspaceLoadingView;
import 'package:imboy/store/api/project_channel_api.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'w2_test_helpers.dart';

/// Pinned / Activity 可控 Fake（直出 page envelope）。
class FakeAggApi extends ProjectChannelApi {
  final List<AggPostModel> pinnedSeed;
  final List<ActivityEventModel> activitySeed;
  final List<ProjectLinkModel> resourceSeed;
  final List<AggPostModel> postsSeed;
  Object? pinnedError;
  Object? activityError;
  Object? resourcesError;
  Object? postsError;
  int pinnedTotalPage = 1;
  Completer<void>? pinnedGate;
  final List<(EntityId projectId, int page, int size)> pinnedCalls = [];

  FakeAggApi({
    this.pinnedSeed = const [],
    this.activitySeed = const [],
    this.resourceSeed = const [],
    this.postsSeed = const [],
  });

  @override
  Future<WorkspacePageResult<AggPostModel>> pinned(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    pinnedCalls.add((projectId, page, size));
    final gate = pinnedGate;
    if (gate != null) await gate.future;
    final err = pinnedError;
    if (err != null) throw err;
    return WorkspacePageResult<AggPostModel>(
      list: page == 1 ? pinnedSeed : const <AggPostModel>[],
      total: pinnedSeed.length,
      totalPage: pinnedTotalPage,
    );
  }

  @override
  Future<WorkspacePageResult<ProjectLinkModel>> resources(
    EntityId projectId,
  ) async {
    final err = resourcesError;
    if (err != null) throw err;
    return WorkspacePageResult<ProjectLinkModel>(
      list: resourceSeed,
      total: resourceSeed.length,
      totalPage: 1,
    );
  }

  @override
  Future<WorkspacePageResult<ActivityEventModel>> activity(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    final err = activityError;
    if (err != null) throw err;
    return WorkspacePageResult<ActivityEventModel>(
      list: page == 1 ? activitySeed : const <ActivityEventModel>[],
      total: activitySeed.length,
      totalPage: 1,
    );
  }

  @override
  Future<WorkspacePageResult<AggPostModel>> relatedPosts(
    EntityId projectId,
  ) async {
    final err = postsError;
    if (err != null) throw err;
    return WorkspacePageResult<AggPostModel>(
      list: postsSeed,
      total: postsSeed.length,
      totalPage: 1,
    );
  }
}

void main() {
  Future<void> pumpInsights(
    WidgetTester tester, {
    required FakeAggApi channelApi,
    EntityId currentUid = testOwnerUid,
  }) async {
    await pumpW2Page(
      tester,
      home: const ProjectInsightsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: channelApi,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(),
      ws: testWs(),
      currentUid: currentUid,
    );
  }

  group('Pinned Tab（默认激活）', () {
    testWidgets('空态', (tester) async {
      await pumpInsights(tester, channelApi: FakeAggApi());
      expect(find.text(t.workspace.projectInsightsPinnedEmpty), findsOneWidget);
    });

    testWidgets('加载态可见（pinned 请求未完成时）', (tester) async {
      // gate 阻塞首屏 pinned 请求：加载态必须渲染而非空白
      final api = FakeAggApi()..pinnedGate = Completer<void>();
      await pumpInsights(tester, channelApi: api);
      expect(find.byType(WorkspaceLoadingView), findsOneWidget);
      api.pinnedGate!.complete();
      await settleSteps(tester);
      expect(find.byType(WorkspaceLoadingView), findsNothing);
    });

    testWidgets('数据态：置顶摘要行渲染（作者 + 时间）', (tester) async {
      final api = FakeAggApi(
        pinnedSeed: [
          AggPostModel(
            id: '9501',
            channelId: '8001',
            authorId: testOwnerUid,
            authorName: '李雷',
            msgType: 'text',
            createdAtText: '2026-01-03',
          ),
        ],
      );
      await pumpInsights(tester, channelApi: api);
      expect(
        find.text(t.workspace.projectInsightsPostAuthor(name: '李雷')),
        findsOneWidget,
      );
      expect(find.text('2026-01-03'), findsOneWidget);
      // 首页请求固定 size 10
      expect(api.pinnedCalls.single.$3, 10);
    });

    testWidgets('403：明确无权限态', (tester) async {
      final api = FakeAggApi()
        ..pinnedError = const WorkspaceApiException(403, 'forbidden');
      await pumpInsights(tester, channelApi: api);
      expect(
        find.textContaining(t.workspace.projectNoPermission),
        findsOneWidget,
      );
    });

    testWidgets('500：错误态透传服务端消息', (tester) async {
      final api = FakeAggApi()
        ..pinnedError = const WorkspaceApiException(500, '查询失败');
      await pumpInsights(tester, channelApi: api);
      expect(find.textContaining('查询失败'), findsOneWidget);
    });

    testWidgets('分页：totalPage>1 出现加载更多，翻到 page=2', (tester) async {
      final api = FakeAggApi(
        pinnedSeed: [
          for (var i = 1; i <= 10; i++)
            AggPostModel(
              id: '96${i.toString().padLeft(2, '0')}',
              channelId: '8001',
              authorId: testOwnerUid,
            ),
        ],
      )..pinnedTotalPage = 2;
      await pumpInsights(tester, channelApi: api);

      await tester.tap(find.byKey(const ValueKey('project-w2-load-more')));
      await settleSteps(tester);

      expect(
        api.pinnedCalls.any((c) => c.$2 == 2 && c.$3 == 10),
        isTrue,
        reason: '加载更多应以 page=2, size=10 请求',
      );
    });
  });

  group('Resources Tab', () {
    testWidgets('数据态：链接行渲染', (tester) async {
      final api = FakeAggApi(
        resourceSeed: [
          const ProjectLinkModel(name: '官网', url: 'https://imboy.pub'),
        ],
      );
      await pumpInsights(tester, channelApi: api);
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-resources')),
      );
      await settleSteps(tester);

      expect(find.text('官网'), findsOneWidget);
      expect(find.text('https://imboy.pub'), findsOneWidget);
    });

    testWidgets('空态', (tester) async {
      await pumpInsights(tester, channelApi: FakeAggApi());
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-resources')),
      );
      await settleSteps(tester);
      expect(
        find.text(t.workspace.projectInsightsResourcesEmpty),
        findsOneWidget,
      );
    });

    testWidgets('403：明确无权限态', (tester) async {
      final api = FakeAggApi()
        ..resourcesError = const WorkspaceApiException(403, 'forbidden');
      await pumpInsights(tester, channelApi: api);
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-resources')),
      );
      await settleSteps(tester);
      expect(
        find.textContaining(t.workspace.projectNoPermission),
        findsOneWidget,
      );
    });
  });

  group('Activity Tab', () {
    testWidgets('数据态：事件行渲染；空态齐全', (tester) async {
      final api = FakeAggApi(
        activitySeed: [
          ActivityEventModel(
            id: '9701',
            eventType: 'member_invited',
            actorId: testOwnerUid,
            createdAtText: '2026-01-05',
          ),
        ],
      );
      await pumpInsights(tester, channelApi: api);
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-activity')),
      );
      await settleSteps(tester);

      expect(find.text('member_invited'), findsOneWidget);
      expect(find.text('2026-01-05'), findsOneWidget);
    });

    testWidgets('空态', (tester) async {
      await pumpInsights(tester, channelApi: FakeAggApi());
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-activity')),
      );
      await settleSteps(tester);
      expect(
        find.text(t.workspace.projectInsightsActivityEmpty),
        findsOneWidget,
      );
    });

    testWidgets('403：明确无权限态', (tester) async {
      final api = FakeAggApi()
        ..activityError = const WorkspaceApiException(403, 'forbidden');
      await pumpInsights(tester, channelApi: api);
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-activity')),
      );
      await settleSteps(tester);
      expect(
        find.textContaining(t.workspace.projectNoPermission),
        findsOneWidget,
      );
    });
  });

  group('Related Posts Tab', () {
    testWidgets('数据态：帖子摘要行渲染', (tester) async {
      final api = FakeAggApi(
        postsSeed: [
          AggPostModel(
            id: '9801',
            channelId: '8001',
            authorId: testMemberUid,
            msgType: 'text',
            createdAtText: '2026-01-06',
          ),
        ],
      );
      await pumpInsights(tester, channelApi: api);
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-posts')),
      );
      await settleSteps(tester);

      // related_posts 行无 author_name → 展示 msg_type
      expect(find.text('text'), findsOneWidget);
      expect(find.text('2026-01-06'), findsOneWidget);
    });

    testWidgets('空态', (tester) async {
      await pumpInsights(tester, channelApi: FakeAggApi());
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-posts')),
      );
      await settleSteps(tester);
      expect(find.text(t.workspace.projectInsightsPostsEmpty), findsOneWidget);
    });

    testWidgets('403：明确无权限态', (tester) async {
      final api = FakeAggApi()
        ..postsError = const WorkspaceApiException(403, 'forbidden');
      await pumpInsights(tester, channelApi: api);
      await tester.tap(
        find.byKey(const ValueKey('project-insights-tab-posts')),
      );
      await settleSteps(tester);
      expect(
        find.textContaining(t.workspace.projectNoPermission),
        findsOneWidget,
      );
    });
  });
}
