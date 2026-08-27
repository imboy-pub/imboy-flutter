/// WP5 (T8/T9/T12) — workspace 壳/视图 barrel 与错误语义测试
///
/// 覆盖：
/// - barrel 导出完整（镜像 chat_shell_barrel_test 模式）
/// - WorkspaceApiException 透传 980（归档）/409（成员冲突）语义
/// - TSID EntityId 安全解析（int/num/String 均可入，绝不丢精度回转）
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace_shell/workspace_shell.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

void main() {
  group('workspace_shell barrel 导出（镜像 chat_shell barrel 模式）', () {
    test('barrel 导出 bootstrap/provider/nav/breakpoint/theme', () {
      // barrel 文件自身 import 成功即导出链可用；这里固化关键符号可解析
      expect(WorkspaceShellBootstrap, isNotNull);
      expect(workspaceShellProvider, isNotNull);
      expect(buildWorkspaceShellNavItems, isNotNull);
      expect(resolveWorkspaceShellLayout, isNotNull);
      expect(WorkspaceBrandingScope, isNotNull);
    });
  });

  group('WorkspaceApiException 错误语义透传', () {
    test('980 → isArchived（T7 归档写守卫稳定错误码）', () {
      const e = WorkspaceApiException(980, '工作区已归档，写操作被拒绝');
      expect(e.isArchived, isTrue);
      expect(e.isConflict, isFalse);
      expect(e.message, '工作区已归档，写操作被拒绝');
    });

    test('409 → isConflict（成员移除冲突清单）', () {
      const e = WorkspaceApiException(
        409,
        'membership_conflict：该用户有未完成任务（官网首页），须先改派或完成后再移除',
      );
      expect(e.isConflict, isTrue);
      expect(e.isArchived, isFalse);
      expect(e.message, contains('未完成任务'));
    });

    test('toString 携带 code 与消息（日志可读）', () {
      const e = WorkspaceApiException(403, '仅工作区 Owner 可操作');
      expect(e.toString(), contains('403'));
      expect(e.toString(), contains('仅工作区 Owner 可操作'));
    });
  });

  group('TSID EntityId 安全解析（workspace 层）', () {
    test('int / num / String 入参均可转 EntityId 字符串', () {
      // 64-bit TSID 以 Dart int 传输不丢精度（dart:convert JSON integer
      // → int）；超大值亦然。
      expect(entityIdOf(12345678901234567), '12345678901234567');
      expect(entityIdOf('12345678901234567'), '12345678901234567');
      expect(entityIdOf(' 9001 '), '9001');
    });

    test('fromJson 整条链路：int TSID 全精度（绝不经 double 回转）', () {
      final ws = WorkspaceModel.fromJson({
        'id': 9223372036854775807,
        'name': 'max',
        'owner_id': 1001,
      });
      expect(ws.id, '9223372036854775807');
    });

    test('缺失 / null / 空 → 空串（调用方以 isEmpty 判无效）', () {
      expect(entityIdOf(null), '');
      expect(entityIdOf(''), '');
      expect(entityIdOf('   '), '');
    });

    test('workspace/member/overview JSON 反序列化（integer TSID → EntityId）', () {
      final ws = WorkspaceModel.fromJson({
        'id': 9001,
        'name': '官网改版',
        'owner_id': 1001,
        'status': 'archived',
        'branding': {'primaryColor': '#FF5733'},
      });
      expect(ws.id, '9001');
      expect(ws.ownerId, '1001');
      expect(ws.isArchived, isTrue);
      expect(ws.branding.primaryColor, '#FF5733');

      final member = WorkspaceMemberModel.fromJson({
        'workspace_id': 9001,
        'user_id': 1002,
        'role': 'owner',
        'nickname': '李雷',
        'account': 'leilei',
      });
      expect(member.userId, '1002');
      expect(member.role, WorkspaceMemberRole.owner);

      final overview = WorkspaceOverview.fromJson({
        'project_count': 3,
        'group_count': 2,
        'channel_count': 1,
        'member_preview': [
          {'user_id': 1001, 'role': 'owner', 'nickname': '李雷'},
        ],
      });
      expect(overview.projectCount, 3);
      expect(overview.memberPreview.single.role, WorkspaceMemberRole.owner);
    });
  });
}
