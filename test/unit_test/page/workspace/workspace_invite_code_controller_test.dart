/// T2.6 (WP 团队码) — 邀请页「团队码」卡片控制器纯逻辑测试（无网）
///
/// 覆盖：生成成功（ready + 码/有效期）、空 payload 按失败、生成异常
/// （403/980 透传消息）、重新生成覆盖旧码 + copied 复位、复制成功/失败、
/// 无码复制 no-op、撤销成功回 idle 清码/失败留 ready/无码 no-op。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace/workspace_invite_code_controller.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

void main() {
  group('WorkspaceInviteCodeController.generate', () {
    test('初始 idle，无码不可复制', () {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      expect(c.state.phase, WorkspaceInviteCodePhase.idle);
      expect(c.hasCode, isFalse);
      expect(c.isGenerating, isFalse);
    });

    test('生成成功：ready + 码与有效期', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async => const WorkspaceInviteCode(
          code: 'AB12CD34',
          expiresAt: '2026-09-30 12:00:00',
        ),
      );

      expect(c.state.phase, WorkspaceInviteCodePhase.ready);
      expect(c.state.inviteCode.code, 'AB12CD34');
      expect(c.state.inviteCode.expiresAt, '2026-09-30 12:00:00');
      expect(c.hasCode, isTrue);
      expect(c.state.message, isEmpty);
    });

    test('空 payload（契约外）按失败处理，不伪装成功', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async => const WorkspaceInviteCode(),
      );

      expect(c.state.phase, WorkspaceInviteCodePhase.failed);
      expect(c.hasCode, isFalse);
      expect(c.state.message, isNotEmpty);
    });

    test('生成异常（403 越权 / 980 归档）：failed + 消息透传', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async =>
            throw const WorkspaceApiException(980, '工作区已归档，写操作被拒绝'),
      );

      expect(c.state.phase, WorkspaceInviteCodePhase.failed);
      expect(c.state.message, contains('980'));
    });

    test('重新生成覆盖旧码（一工作区一个 active 码）且 copied 复位', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async =>
            const WorkspaceInviteCode(code: 'AAAAAAAA', expiresAt: 't1'),
      );
      await c.copy(writeToClipboard: (_) async {});
      expect(c.state.copied, isTrue);

      await c.generate(
        createInviteCode: () async =>
            const WorkspaceInviteCode(code: 'BBBBBBBB', expiresAt: 't2'),
      );

      expect(c.state.phase, WorkspaceInviteCodePhase.ready);
      expect(c.state.inviteCode.code, 'BBBBBBBB');
      expect(c.state.copied, isFalse, reason: '新码生成后复制态须复位');
    });
  });

  group('WorkspaceInviteCodeController.copy', () {
    test('复制成功：copied=true + 收到完整码', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async =>
            const WorkspaceInviteCode(code: 'AB12CD34', expiresAt: 't'),
      );
      final copied = <String>[];
      await c.copy(writeToClipboard: (code) async => copied.add(code));

      expect(c.state.copied, isTrue);
      expect(copied, ['AB12CD34']);
    });

    test('复制失败（Clipboard 异常）：copied=false + 消息透传', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async =>
            const WorkspaceInviteCode(code: 'AB12CD34', expiresAt: 't'),
      );
      await c.copy(
        writeToClipboard: (_) async => throw Exception('clipboard denied'),
      );

      expect(c.state.copied, isFalse);
      expect(c.state.message, contains('clipboard denied'));
      // 码本身仍有效（复制失败不影响已生成的码）
      expect(c.state.phase, WorkspaceInviteCodePhase.ready);
    });

    test('无码复制 no-op（不抛异常、不改状态）', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      var called = false;
      await c.copy(writeToClipboard: (_) async => called = true);

      expect(called, isFalse);
      expect(c.state.copied, isFalse);
    });
  });

  group('WorkspaceInviteCodeController.revoke', () {
    test('撤销成功：回 idle 清码（输码即 981 的 UI 前置）', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async =>
            const WorkspaceInviteCode(code: 'AB12CD34', expiresAt: 't'),
      );
      var called = false;
      await c.revoke(
        revokeInviteCode: () async {
          called = true;
          return 1;
        },
      );

      expect(called, isTrue);
      expect(c.state.phase, WorkspaceInviteCodePhase.idle);
      expect(c.hasCode, isFalse);
      expect(c.state.message, isEmpty);
    });

    test('撤销失败（403 越权等）：留 ready + 消息透传', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      await c.generate(
        createInviteCode: () async =>
            const WorkspaceInviteCode(code: 'AB12CD34', expiresAt: 't'),
      );
      await c.revoke(
        revokeInviteCode: () async =>
            throw const WorkspaceApiException(403, '仅 Owner 可撤销'),
      );

      expect(c.state.phase, WorkspaceInviteCodePhase.ready);
      expect(c.state.inviteCode.code, 'AB12CD34');
      expect(c.state.message, contains('403'));
    });

    test('无码撤销 no-op（不触达 revoke 动作）', () async {
      final c = WorkspaceInviteCodeController();
      addTearDown(c.dispose);

      var called = false;
      await c.revoke(
        revokeInviteCode: () async {
          called = true;
          return 0;
        },
      );

      expect(called, isFalse);
      expect(c.state.phase, WorkspaceInviteCodePhase.idle);
    });
  });
}
