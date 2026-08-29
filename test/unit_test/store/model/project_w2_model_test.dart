/// W2 (ZC-06) — Project Member / Milestone / Channel / 聚合 领域模型测试
///
/// 计划锚点（TDD 用例 7）：EntityId 解析大 TSID 不丢精度；W2 各行模型
/// 对齐后端 handler SELECT 列（imboy project_member/milestone/channel
/// handler），字段缺失宽容（null → 空值默认）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show WorkspacePageResult, entityIdOf;

/// 2^53 + 1：JS Number.MAX_SAFE_INTEGER 之外的 TSID 量级（web 精度红线）。
const int _bigTsid = 9007199254740993;

void main() {
  group('EntityId 解析（大 TSID 不丢精度）', () {
    test('entityIdOf：num 入参保留全部有效位', () {
      expect(entityIdOf(_bigTsid), '9007199254740993');
      expect(entityIdOf(12345), '12345');
    });

    test('entityIdOf：String 入参透传、null → 空串', () {
      expect(entityIdOf('9007199254740993'), '9007199254740993');
      expect(entityIdOf(null), '');
    });

    test('ProjectMemberModel.fromJson：大 TSID user_id/project_id 以字符串持有', () {
      final json =
          jsonDecode(
                '{"workspace_id": $_bigTsid, "project_id": $_bigTsid, '
                '"user_id": $_bigTsid, "invited_by": 1001, '
                '"joined_at": "2026-01-01T00:00:00Z", "status": "active", '
                '"nickname": "李雷", "avatar": "", "account": "leilei"}',
              )
              as Map<String, dynamic>;
      final m = ProjectMemberModel.fromJson(json);
      expect(m.workspaceId, '9007199254740993');
      expect(m.projectId, '9007199254740993');
      expect(m.userId, '9007199254740993');
      expect(m.invitedBy, '1001');
      expect(m.status, 'active');
      expect(m.nickname, '李雷');
      expect(m.account, 'leilei');
    });

    test('ProjectChannelModel.fromJson：channel_id 大 TSID 不回转 int', () {
      final json =
          jsonDecode(
                '{"channel_id": $_bigTsid, "workspace_id": 7, "name": "Announcements", '
                '"avatar": "", "channel_status": "active", "linked_at": "2026-01-02"}',
              )
              as Map<String, dynamic>;
      final m = ProjectChannelModel.fromJson(json);
      expect(m.channelId, '9007199254740993');
      expect(m.workspaceId, '7');
      expect(m.name, 'Announcements');
      expect(m.channelStatus, 'active');
      expect(m.linkedAtText, '2026-01-02');
    });

    test(
      'AggPostModel.fromJson：pinned 行（含 author_name）与 related_posts 行（缺省）',
      () {
        final pinned = AggPostModel.fromJson(
          jsonDecode(
                '{"id": $_bigTsid, "channel_id": 8001, "author_id": 1001, '
                '"author_name": "李雷", "msg_type": "text", "created_at": "2026-01-03"}',
              )
              as Map<String, dynamic>,
        );
        expect(pinned.id, '9007199254740993');
        expect(pinned.channelId, '8001');
        expect(pinned.authorName, '李雷');
        expect(pinned.msgType, 'text');

        final post = AggPostModel.fromJson(
          jsonDecode(
                '{"id": 8002, "channel_id": 8001, "author_id": 1002, '
                '"msg_type": "image", "created_at": "2026-01-04"}',
              )
              as Map<String, dynamic>,
        );
        expect(post.authorName, '');
        expect(post.id, '8002');
      },
    );
  });

  group('MilestoneStatus / MilestoneModel', () {
    test('parse：planned/reached 正常；未知值降级 planned', () {
      expect(MilestoneStatus.parse('planned'), MilestoneStatus.planned);
      expect(MilestoneStatus.parse('reached'), MilestoneStatus.reached);
      expect(MilestoneStatus.parse('bogus'), MilestoneStatus.planned);
      expect(MilestoneStatus.parse(null), MilestoneStatus.planned);
    });

    test('单向状态机：reached 不可回退（无回退目标）', () {
      expect(MilestoneStatus.reached.canAdvance, isFalse);
      expect(MilestoneStatus.planned.canAdvance, isTrue);
    });

    test('MilestoneModel.fromJson：due_date 保留 YYYY-MM-DD、null → 空串', () {
      final planned = MilestoneModel.fromJson(
        jsonDecode(
              '{"id": 9001, "workspace_id": 7, "project_id": 5001, "name": "公测", '
              '"due_date": "2026-12-31", "status": "planned", "reached_at": null, '
              '"created_at": "2026-01-01", "updated_at": "2026-01-01"}',
            )
            as Map<String, dynamic>,
      );
      expect(planned.id, '9001');
      expect(planned.name, '公测');
      expect(planned.dueDateText, '2026-12-31');
      expect(planned.status, MilestoneStatus.planned);
      expect(planned.isReached, isFalse);

      final reached = MilestoneModel.fromJson(
        jsonDecode(
              '{"id": 9002, "project_id": 5001, "name": "上线", "due_date": null, '
              '"status": "reached", "reached_at": "2026-02-01"}',
            )
            as Map<String, dynamic>,
      );
      expect(reached.dueDateText, '');
      expect(reached.status, MilestoneStatus.reached);
      expect(reached.isReached, isTrue);
      expect(reached.reachedAtText, '2026-02-01');
    });
  });

  group('ProjectLinkModel / ActivityEventModel / 分页 envelope', () {
    test('ProjectLinkModel：name/url 宽容解析', () {
      final l = ProjectLinkModel.fromJson(
        jsonDecode('{"name": "官网", "url": "https://imboy.pub"}')
            as Map<String, dynamic>,
      );
      expect(l.name, '官网');
      expect(l.url, 'https://imboy.pub');
    });

    test('ActivityEventModel：payload 保留清洗后元数据键', () {
      final e = ActivityEventModel.fromJson(
        jsonDecode(
              '{"id": $_bigTsid, "event_type": "member_invited", "actor_id": 1001, '
              '"target_id": 1002, "payload": {"actor": 1001}, "created_at": "2026-01-05"}',
            )
            as Map<String, dynamic>,
      );
      expect(e.id, '9007199254740993');
      expect(e.eventType, 'member_invited');
      expect(e.actorId, '1001');
      expect(e.targetId, '1002');
      expect(e.payload['actor'], 1001);
      expect(e.createdAtText, '2026-01-05');
    });

    test('里程碑列表 envelope：后端仅 {list,page,size}（无 total/total_page）兜 0', () {
      final page = WorkspacePageResult<MilestoneModel>.fromJson(
        jsonDecode(
              '{"list": [{"id": 1, "name": "M1", "project_id": 5001}], '
              '"page": 2, "size": 10}',
            )
            as Map<String, dynamic>,
        MilestoneModel.fromJson,
      );
      expect(page.list, hasLength(1));
      expect(page.page, 2);
      expect(page.size, 10);
      expect(page.total, 0);
      expect(page.totalPage, 0);
    });
  });
}
