/// W2 (ZC-06) — 协作页测试共享基建：可控 Fake API + pump 脚手架
///
/// 测试区禁网（flutter_test_config installSmokeHttpOverrides），页面数据
/// 一律经 ProviderScope.overrides 注入 Fake API（对齐 project_page_test
/// 既有模式；ProviderScope retry 置 null 以便 FakeAsync 推进）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart' as app_loading;
import 'package:imboy/config/const.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace/project/w2/project_w2_providers.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart'
    show workspaceApiProvider;
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/project_api.dart';
import 'package:imboy/store/api/project_channel_api.dart';
import 'package:imboy/store/api/project_member_api.dart';
import 'package:imboy/store/api/project_milestone_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

// ==================== 常量种子 ====================

const String testWsId = '9001';
const String testOwnerUid = '1001';
const String testGuestUid = '1003';
const String testMemberUid = '1002';
const String testProjectId = '5001';

WorkspaceModel testWs({WorkspaceStatus status = WorkspaceStatus.active}) =>
    WorkspaceModel(
      id: testWsId,
      name: '官网改版',
      ownerId: testOwnerUid,
      status: status,
    );

ProjectModel testProject({EntityId ownerId = testOwnerUid}) => ProjectModel(
  id: testProjectId,
  workspaceId: testWsId,
  name: '官网改版项目',
  ownerId: ownerId,
);

WorkspaceMemberModel wsMember({
  required EntityId uid,
  required WorkspaceMemberRole role,
}) => WorkspaceMemberModel(
  workspaceId: testWsId,
  userId: uid,
  role: role,
  nickname: '用户$uid',
  account: 'u$uid',
);

/// 工作区成员种子（Owner/Member/Guest 各一）。
List<WorkspaceMemberModel> wsMemberSeed() => [
  wsMember(uid: testOwnerUid, role: WorkspaceMemberRole.owner),
  wsMember(uid: testMemberUid, role: WorkspaceMemberRole.member),
  wsMember(uid: testGuestUid, role: WorkspaceMemberRole.guest),
];

ProjectMemberModel pmMember(EntityId uid) => ProjectMemberModel(
  workspaceId: testWsId,
  projectId: testProjectId,
  userId: uid,
  nickname: '用户$uid',
  account: 'u$uid',
);

MilestoneModel milestone({
  required EntityId id,
  String name = '公测',
  MilestoneStatus status = MilestoneStatus.planned,
  String dueDate = '',
}) => MilestoneModel(
  id: id,
  workspaceId: testWsId,
  projectId: testProjectId,
  name: name,
  dueDateText: dueDate,
  status: status,
);

ProjectChannelModel linkedChannel({required EntityId channelId}) =>
    ProjectChannelModel(
      channelId: channelId,
      workspaceId: testWsId,
      name: '频道$channelId',
    );

ChannelModel channelCandidate(int id, String name) => ChannelModel(
  id: id,
  name: name,
  creatorId: 0,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

// ==================== Fake API ====================

/// ProjectMemberApi 可控 Fake：记录调用 + 注入失败/延迟/幂等标记。
class FakeMemberApi extends ProjectMemberApi {
  final List<ProjectMemberModel> seed;
  final int totalPage;
  Object? listError;
  Object? inviteError;
  Object? removeError;
  String inviteFlag;
  String removeFlag;
  Completer<void>? inviteGate;
  final List<(EntityId projectId, EntityId userId)> inviteCalls = [];
  final List<(EntityId projectId, EntityId userId)> removeCalls = [];
  final List<(EntityId projectId, EntityId newOwnerUid)> transferCalls = [];
  final List<(EntityId projectId, int page, int size)> listCalls = [];

  FakeMemberApi({
    this.seed = const [],
    this.totalPage = 1,
    this.inviteFlag = 'created',
    this.removeFlag = 'removed',
  });

  @override
  Future<WorkspacePageResult<ProjectMemberModel>> list(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    listCalls.add((projectId, page, size));
    final err = listError;
    if (err != null) throw err;
    if (page > 1) {
      return WorkspacePageResult<ProjectMemberModel>(
        total: seed.length,
        totalPage: totalPage,
      );
    }
    return WorkspacePageResult<ProjectMemberModel>(
      list: seed,
      total: seed.length,
      totalPage: totalPage,
    );
  }

  @override
  Future<MemberWriteResult> invite({
    required EntityId projectId,
    required EntityId userId,
  }) async {
    inviteCalls.add((projectId, userId));
    final gate = inviteGate;
    if (gate != null) await gate.future;
    final err = inviteError;
    if (err != null) throw err;
    return MemberWriteResult(member: pmMember(userId), statusFlag: inviteFlag);
  }

  @override
  Future<MemberWriteResult> remove({
    required EntityId projectId,
    required EntityId userId,
  }) async {
    removeCalls.add((projectId, userId));
    final err = removeError;
    if (err != null) throw err;
    return MemberWriteResult(member: pmMember(userId), statusFlag: removeFlag);
  }

  @override
  Future<void> transferOwner({
    required EntityId projectId,
    required EntityId newOwnerUid,
  }) async {
    transferCalls.add((projectId, newOwnerUid));
  }
}

/// MilestoneApi 可控 Fake。
class FakeMilestoneApi extends MilestoneApi {
  final List<MilestoneModel> seed;
  Object? listError;
  Object? createError;
  String reachFlag;
  Completer<void>? reachGate;
  final List<(EntityId projectId, String status, int page)> listCalls = [];
  final List<(String name, String? dueDate)> createCalls = [];
  final List<EntityId> reachCalls = [];

  FakeMilestoneApi({this.seed = const [], this.reachFlag = 'reached'});

  @override
  Future<WorkspacePageResult<MilestoneModel>> list(
    EntityId projectId, {
    String status = 'all',
    int page = 1,
    int size = 10,
  }) async {
    listCalls.add((projectId, status, page));
    final err = listError;
    if (err != null) throw err;
    final filtered = status == 'all'
        ? seed
        : seed
              .where(
                (m) =>
                    m.status ==
                    (status == 'reached'
                        ? MilestoneStatus.reached
                        : MilestoneStatus.planned),
              )
              .toList();
    return WorkspacePageResult<MilestoneModel>(
      list: page == 1 ? filtered : const <MilestoneModel>[],
      total: filtered.length,
      totalPage: 1,
    );
  }

  @override
  Future<MilestoneModel> create({
    required EntityId projectId,
    required String name,
    String? dueDate,
  }) async {
    createCalls.add((name, dueDate));
    final err = createError;
    if (err != null) throw err;
    return milestone(id: '9100', name: name);
  }

  @override
  Future<MilestoneReachResult> reach(EntityId milestoneId) async {
    reachCalls.add(milestoneId);
    final gate = reachGate;
    if (gate != null) await gate.future;
    return MilestoneReachResult(
      milestone: milestone(id: milestoneId, status: MilestoneStatus.reached),
      statusFlag: reachFlag,
    );
  }
}

/// ProjectChannelApi 可控 Fake。
class FakeChannelApi extends ProjectChannelApi {
  final List<ProjectChannelModel> seed;
  Object? listError;
  String linkFlag;
  Completer<void>? linkGate;
  final List<(EntityId projectId, EntityId channelId)> linkCalls = [];
  final List<(EntityId projectId, EntityId channelId)> unlinkCalls = [];

  FakeChannelApi({this.seed = const [], this.linkFlag = 'created'});

  @override
  Future<WorkspacePageResult<ProjectChannelModel>> list(
    EntityId projectId, {
    int page = 1,
    int size = 10,
  }) async {
    final err = listError;
    if (err != null) throw err;
    return WorkspacePageResult<ProjectChannelModel>(
      list: page == 1 ? seed : const <ProjectChannelModel>[],
      total: seed.length,
      totalPage: 1,
    );
  }

  @override
  Future<String> link({
    required EntityId projectId,
    required EntityId channelId,
  }) async {
    linkCalls.add((projectId, channelId));
    final gate = linkGate;
    if (gate != null) await gate.future;
    return linkFlag;
  }

  @override
  Future<void> unlink({
    required EntityId projectId,
    required EntityId channelId,
  }) async {
    unlinkCalls.add((projectId, channelId));
  }
}

/// ProjectApi 最小 Fake（详情供 ownerId/工作区兜底）。
class FakeProjectDetailApi extends ProjectApi {
  final ProjectModel project;
  Object? detailError;

  FakeProjectDetailApi({ProjectModel? project, this.detailError})
    : project = project ?? testProject();

  @override
  Future<ProjectModel> detail(EntityId projectId) async {
    final err = detailError;
    if (err != null) throw err;
    return project;
  }
}

/// WorkspaceApi 最小 Fake（assigneeCandidates / 频道候选）。
class FakeWorkspaceApi extends WorkspaceApi {
  FakeWorkspaceApi({
    List<WorkspaceMemberModel>? memberSeed,
    List<ChannelModel>? channelSeed,
  }) : memberRows = memberSeed ?? wsMemberSeed(),
       channelRows = channelSeed ?? const <ChannelModel>[];

  final List<WorkspaceMemberModel> memberRows;
  final List<ChannelModel> channelRows;

  @override
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    return WorkspacePageResult<WorkspaceMemberModel>(
      list: memberRows,
      total: memberRows.length,
      totalPage: 1,
    );
  }

  @override
  Future<List<ChannelModel>> channels(EntityId workspaceId) async =>
      channelRows;
}

// ==================== pump 脚手架 ====================

GoRouter _router(Widget home) => GoRouter(
  initialLocation: '/x',
  routes: [
    GoRoute(path: '/x', builder: (c, s) => home),
    GoRoute(path: '/fallback', builder: (c, s) => const Text('popped')),
  ],
);

/// 泵 W2 页面（注入 fake 依赖；步进 pump 推进异步）。
Future<void> pumpW2Page(
  WidgetTester tester, {
  required Widget home,
  ProjectMemberApi? memberApi,
  MilestoneApi? milestoneApi,
  ProjectChannelApi? channelApi,
  ProjectApi? projectApi,
  WorkspaceApi? workspaceApi,
  WorkspaceModel? ws,
  EntityId currentUid = testOwnerUid,
  Size size = const Size(430, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await StorageService.to.setString(Keys.currentUid, currentUid);
  addTearDown(() => StorageService.to.remove(Keys.currentUid));

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          if (memberApi != null)
            projectMemberApiProvider.overrideWith((ref) => memberApi),
          if (milestoneApi != null)
            milestoneApiProvider.overrideWith((ref) => milestoneApi),
          if (channelApi != null)
            projectChannelApiProvider.overrideWith((ref) => channelApi),
          if (projectApi != null)
            projectApiProvider.overrideWith((ref) => projectApi),
          if (workspaceApi != null)
            workspaceApiProvider.overrideWith((ref) => workspaceApi),
          if (ws != null) currentWorkspaceProvider.overrideWithValue(ws),
        ],
        child: MaterialApp.router(
          routerConfig: _router(home),
          builder: app_loading.AppLoading.init(),
        ),
      ),
    ),
  );
  for (final ms in const [16, 60, 200, 400]) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// 步进 pump（写操作弹层/toast 后推进）。
Future<void> settleSteps(WidgetTester tester) async {
  for (final ms in const [16, 60, 200, 400]) {
    await tester.pump(Duration(milliseconds: ms));
  }
}
