/// 钉住 S2C `group_member_mute` 通知的 payload 解析契约 —— 驱动 GREEN-6。
///
/// 后端 `group_member_logic:mute_notice/4` 广播的 payload 形状：
///   {
///     "gid": int,
///     "mute_until": int (ms),
///     "remaining_seconds": int,
///     "duration_text": String,
///     "admin_nickname": String
///   }
///
/// ⚠️ **已知后端契约缺口**：`mute_notice/4` 的第三个参数 `_UserId` 被忽略，
/// 因此 payload 中不包含被禁言的 `user_id`。slice-1 的客户端处理只能做「广播
/// 通知」（toast + 事件总线），无法直接更新 `group_member.mute_until` 行。
/// 修复责任在后端（TODO：`imboy/src/logic/group_member_logic.erl:260-266`
/// 的 Payload 需补 `<<"user_id">> => UserId`）。
///
/// 契约：
///   1. payload 正常 → `GroupMemberMutePayload(...)` 带全字段
///   2. gid 缺失或 <=0 → `GroupMemberMuteParseError('invalid_gid')`
///   3. mute_until 缺失或 <=0 → `GroupMemberMuteParseError('invalid_mute_until')`
///   4. 可选字段缺失（remaining_seconds / duration_text / admin_nickname）→
///      填默认值（0 / '' / ''），不视为错误
///   5. 结果是 sealed，switch 必须穷尽
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_member_mute_s2c.dart';

void main() {
  group('parseGroupMemberMutePayload — sealed GroupMemberMuteParseResult', () {
    test('完整 payload → GroupMemberMutePayload，字段逐一映射', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'mute_until': 1_900_000_000_000,
        'remaining_seconds': 600,
        'duration_text': '10分钟',
        'admin_nickname': 'Alice',
      });

      expect(result, isA<GroupMemberMutePayload>());
      final p = result as GroupMemberMutePayload;
      expect(p.gid, 10086);
      expect(p.muteUntilMs, 1_900_000_000_000);
      expect(p.remainingSeconds, 600);
      expect(p.durationText, '10分钟');
      expect(p.adminNickname, 'Alice');
    });

    test('gid 为 String 数字 → 解析为 int', () {
      final result = parseGroupMemberMutePayload({
        'gid': '10086',
        'mute_until': 1_900_000_000_000,
      });

      expect(result, isA<GroupMemberMutePayload>());
      expect((result as GroupMemberMutePayload).gid, 10086);
    });

    test('gid 缺失 → invalid_gid', () {
      final result = parseGroupMemberMutePayload({
        'mute_until': 1_900_000_000_000,
      });

      expect(result, isA<GroupMemberMuteParseError>());
      expect(
        (result as GroupMemberMuteParseError).reason,
        'invalid_gid',
      );
    });

    test('gid = 0 → invalid_gid（防止污染全局默认行）', () {
      final result = parseGroupMemberMutePayload({
        'gid': 0,
        'mute_until': 1_900_000_000_000,
      });

      expect(result, isA<GroupMemberMuteParseError>());
      expect(
        (result as GroupMemberMuteParseError).reason,
        'invalid_gid',
      );
    });

    test('mute_until 缺失 → invalid_mute_until', () {
      final result = parseGroupMemberMutePayload({'gid': 10086});

      expect(result, isA<GroupMemberMuteParseError>());
      expect(
        (result as GroupMemberMuteParseError).reason,
        'invalid_mute_until',
      );
    });

    test('mute_until <= 0 → invalid_mute_until', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'mute_until': 0,
      });

      expect(result, isA<GroupMemberMuteParseError>());
      expect(
        (result as GroupMemberMuteParseError).reason,
        'invalid_mute_until',
      );
    });

    test('可选字段缺失 → 填默认值，不算错误', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'mute_until': 1_900_000_000_000,
      });

      expect(result, isA<GroupMemberMutePayload>());
      final p = result as GroupMemberMutePayload;
      expect(p.remainingSeconds, 0);
      expect(p.durationText, '');
      expect(p.adminNickname, '');
    });

    test('sealed —— switch 必须穷尽', () {
      String describe(GroupMemberMuteParseResult r) {
        return switch (r) {
          GroupMemberMutePayload(:final gid) => 'ok:$gid',
          GroupMemberMuteParseError(:final reason) => 'err:$reason',
        };
      }

      expect(
        describe(const GroupMemberMutePayload(
          gid: 1,
          muteUntilMs: 2,
          remainingSeconds: 3,
          durationText: 't',
          adminNickname: 'a',
        )),
        'ok:1',
      );
      expect(
        describe(const GroupMemberMuteParseError('invalid_gid')),
        'err:invalid_gid',
      );
    });
  });
}
