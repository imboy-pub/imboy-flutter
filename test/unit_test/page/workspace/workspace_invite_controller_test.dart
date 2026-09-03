/// WP5 (T9) — 邀请向导「三条独立结果」控制器测试
///
/// 计划锚点（T9 VALIDATE）：widget/逻辑测试覆盖三种关系的独立状态与
/// 部分失败；证明「加入 Workspace（成为工作区成员）必须成功」「加入
/// General Group（成为群成员）」「邀请加入 Announcements Channel」三条动作
/// 分别执行、分别返回结果、失败可重试。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace/workspace_invite_page.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/page/workspace/workspace_invite_controller.dart';

class _RecordingChannelApi extends ChannelApi {
  String? channelId;
  String? inviteeUid;

  @override
  Future<Map<String, dynamic>?> createInvitation({
    required String channelId,
    required String inviteeUid,
  }) async {
    this.channelId = channelId;
    this.inviteeUid = inviteeUid;
    return {'id': 'invitation-1'};
  }
}

void main() {
  test('频道邀请传递目标成员 UID，而不是当前操作者订阅', () async {
    final api = _RecordingChannelApi();

    await sendWorkspaceChannelInvitation(
      api: api,
      channelId: 'channel-1',
      inviteeUid: 'target-user',
    );

    expect(api.channelId, 'channel-1');
    expect(api.inviteeUid, 'target-user');
  });

  group('WorkspaceInviteResultsController 三条独立结果', () {
    test('主关系成功 + 两条可选均成功 → 三条 success', () async {
      final c = WorkspaceInviteResultsController();
      addTearDown(c.dispose);

      await c.submit(
        invite: () async {},
        joinGroup: () async {},
        inviteChannel: () async {},
      );

      expect(c.state.workspace.phase, WorkspaceRelationPhase.success);
      expect(c.state.group.phase, WorkspaceRelationPhase.success);
      expect(c.state.channel.phase, WorkspaceRelationPhase.success);
    });

    test('主关系（加入工作区）失败 → 整单失败，可选两条不发起（idle）', () async {
      final c = WorkspaceInviteResultsController();
      addTearDown(c.dispose);
      var groupCalled = false;
      var channelCalled = false;

      await c.submit(
        invite: () async => throw Exception('403 仅 Owner 可邀请'),
        joinGroup: () async => groupCalled = true,
        inviteChannel: () async => channelCalled = true,
      );

      // 前置关系（工作区成员）不存在时，不写群成员/频道订阅关系
      expect(c.state.workspace.phase, WorkspaceRelationPhase.failed);
      expect(c.state.group.phase, WorkspaceRelationPhase.idle);
      expect(c.state.channel.phase, WorkspaceRelationPhase.idle);
      expect(groupCalled, isFalse, reason: '主关系失败不应触发入群');
      expect(channelCalled, isFalse, reason: '主关系失败不应触发订阅');
    });

    test('部分失败：入群失败不影响订阅成功（三条独立）', () async {
      final c = WorkspaceInviteResultsController();
      addTearDown(c.dispose);

      await c.submit(
        invite: () async {},
        joinGroup: () async => throw Exception('join failed'),
        inviteChannel: () async {},
      );

      expect(c.state.workspace.phase, WorkspaceRelationPhase.success);
      expect(c.state.group.phase, WorkspaceRelationPhase.failed);
      expect(c.state.group.message, contains('join failed'));
      expect(c.state.channel.phase, WorkspaceRelationPhase.success);
    });

    test('未勾选的可选关系保持 idle（取消任一选项不写对应关系表）', () async {
      final c = WorkspaceInviteResultsController();
      addTearDown(c.dispose);

      await c.submit(invite: () async {}, joinGroup: null, inviteChannel: null);

      expect(c.state.workspace.phase, WorkspaceRelationPhase.success);
      expect(c.state.group.phase, WorkspaceRelationPhase.idle);
      expect(c.state.channel.phase, WorkspaceRelationPhase.idle);
    });

    test('失败项可单独重试且互不影响（retryGroup）', () async {
      final c = WorkspaceInviteResultsController();
      addTearDown(c.dispose);

      await c.submit(
        invite: () async {},
        joinGroup: () async => throw Exception('first attempt failed'),
        inviteChannel: () async {},
      );

      // 重试入群成功：只改变 group 状态，channel 保持 success
      await c.retryGroup(() async {});

      expect(c.state.group.phase, WorkspaceRelationPhase.success);
      expect(c.state.channel.phase, WorkspaceRelationPhase.success);
      expect(c.state.workspace.phase, WorkspaceRelationPhase.success);
    });

    test('订阅重试仍失败：仅 channel 变 failed，group 不受影响', () async {
      final c = WorkspaceInviteResultsController();
      addTearDown(c.dispose);

      await c.submit(
        invite: () async {},
        joinGroup: () async {},
        inviteChannel: () async {},
      );

      await c.retryChannel(
        () async => throw Exception('980 workspace archived'),
      );

      expect(c.state.channel.phase, WorkspaceRelationPhase.failed);
      expect(c.state.channel.message, contains('980'));
      expect(c.state.group.phase, WorkspaceRelationPhase.success);
      expect(c.state.workspace.phase, WorkspaceRelationPhase.success);
    });

    test('reset 恢复初始 idle', () async {
      final c = WorkspaceInviteResultsController();
      addTearDown(c.dispose);

      await c.submit(invite: () async {});
      c.reset();

      expect(c.state.workspace.phase, WorkspaceRelationPhase.idle);
      expect(c.state.group.phase, WorkspaceRelationPhase.idle);
      expect(c.state.channel.phase, WorkspaceRelationPhase.idle);
    });
  });
}
