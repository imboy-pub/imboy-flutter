/// W2 (ZC-06) — 项目关联频道页视图/Provider 测试
///
/// TDD 用例映射：
/// 4. Channel 关联：link 选择器、unlink 确认、重复 link 幂等反馈；
/// 5. 防抖：link 进行中入口禁用；
/// 1. 非成员 403 → 明确无权限态。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/project/w2/project_channels_page.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;

import 'w2_test_helpers.dart';

void main() {
  testWidgets('列表渲染关联频道 + 关联入口（Project Owner）', (tester) async {
    final api = FakeChannelApi(
      seed: [
        linkedChannel(channelId: '8001'),
        linkedChannel(channelId: '8002'),
      ],
    );
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(
        channelSeed: [channelCandidate(8003, '新品频道')],
      ),
      ws: testWs(),
      currentUid: testOwnerUid,
    );

    expect(
      find.byKey(const ValueKey('project-channel-tile-8001')),
      findsOneWidget,
    );
    expect(find.text('频道8001'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('project-channel-link-entry')),
      findsOneWidget,
    );
  });

  testWidgets('link 选择器：候选来自工作区频道；created 成功反馈', (tester) async {
    final api = FakeChannelApi(seed: [linkedChannel(channelId: '8001')]);
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(
        channelSeed: [channelCandidate(8003, '新品频道')],
      ),
      ws: testWs(),
      currentUid: testOwnerUid,
    );

    await tester.tap(find.byKey(const ValueKey('project-channel-link-entry')));
    await tester.pumpAndSettle();
    // 候选选择器出现（工作区频道）
    await tester.tap(find.text('新品频道'));
    await settleSteps(tester);

    expect(api.linkCalls.single, (testProjectId, '8003'));
    expect(find.text(t.workspace.projectChannelLinkedToast), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('重复 link 幂等反馈：existing → 「该频道已关联」（TDD-4）', (tester) async {
    final api = FakeChannelApi(
      seed: [linkedChannel(channelId: '8001')],
      linkFlag: 'existing',
    );
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(
        channelSeed: [channelCandidate(8001, 'Announcements')],
      ),
      ws: testWs(),
      currentUid: testOwnerUid,
    );

    await tester.tap(find.byKey(const ValueKey('project-channel-link-entry')));
    await tester.pumpAndSettle();
    // 选择已关联频道 → 后端幂等返回 existing
    await tester.tap(find.text('Announcements'));
    await settleSteps(tester);

    expect(api.linkCalls.length, 1);
    expect(
      find.text(t.workspace.projectChannelLinkExistingToast),
      findsOneWidget,
      reason: '幂等命中给明确反馈而非错误',
    );
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('link 防抖：进行中入口禁用（TDD-5）', (tester) async {
    final api = FakeChannelApi(seed: const [])..linkGate = Completer<void>();
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(
        channelSeed: [channelCandidate(8003, '新品频道')],
      ),
      ws: testWs(),
      currentUid: testOwnerUid,
    );

    await tester.tap(find.byKey(const ValueKey('project-channel-link-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新品频道'));
    await tester.pump();

    final entry = tester.widget<FilledButton>(
      find.byKey(const ValueKey('project-channel-link-entry')),
    );
    expect(entry.onPressed, isNull, reason: 'link 进行中入口必须禁用');
    await tester.tap(
      find.byKey(const ValueKey('project-channel-link-entry')),
      warnIfMissed: false,
    );

    api.linkGate!.complete();
    await settleSteps(tester);
    expect(api.linkCalls.length, 1, reason: '进行中的重复点击不得重复提交');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('unlink 确认：确认后调用 unlink（TDD-4）', (tester) async {
    final api = FakeChannelApi(seed: [linkedChannel(channelId: '8001')]);
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(),
      ws: testWs(),
      currentUid: testOwnerUid,
    );

    await tester.tap(find.byKey(const ValueKey('project-channel-unlink-8001')));
    await tester.pumpAndSettle();
    // 确认弹层出现：先取消验证不调用，再确认
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(api.unlinkCalls, isEmpty, reason: '取消不得解除关联');

    await tester.tap(find.byKey(const ValueKey('project-channel-unlink-8001')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.workspace.projectChannelUnlinkSubmit));
    await settleSteps(tester);

    expect(api.unlinkCalls.single, (testProjectId, '8001'));
    expect(find.text(t.workspace.projectChannelUnlinkedToast), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Guest 只读：关联入口与解除按钮不渲染', (tester) async {
    final api = FakeChannelApi(seed: [linkedChannel(channelId: '8001')]);
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(),
      ws: testWs(),
      currentUid: testGuestUid,
    );

    expect(
      find.byKey(const ValueKey('project-channel-link-entry')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('project-channel-unlink-8001')),
      findsNothing,
    );
  });

  testWidgets('非成员 403：明确无权限态', (tester) async {
    final api = FakeChannelApi()
      ..listError = const WorkspaceApiException(403, 'forbidden');
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(),
      ws: testWs(),
      currentUid: testMemberUid,
    );

    expect(
      find.byKey(const ValueKey('project-w2-forbidden-retry')),
      findsOneWidget,
    );
    expect(
      find.textContaining(t.workspace.projectNoPermission),
      findsOneWidget,
    );
  });

  testWidgets('空态：无关联频道空视图', (tester) async {
    final api = FakeChannelApi();
    await pumpW2Page(
      tester,
      home: const ProjectChannelsPage(
        projectId: testProjectId,
        workspaceId: testWsId,
      ),
      channelApi: api,
      projectApi: FakeProjectDetailApi(),
      workspaceApi: FakeWorkspaceApi(),
      ws: testWs(),
      currentUid: testOwnerUid,
    );

    expect(find.text(t.workspace.projectChannelEmptyTitle), findsOneWidget);
  });
}
