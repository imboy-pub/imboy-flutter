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

    test('mute_until 缺失 → invalid_mute_until', () {
      // slice-9b 后：mute_until==0 改为解禁信号；仅"缺失 / 负数 / 非法格式"才报错
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
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

    // ----------------------------------------------------------------------
    // slice-1-finalize：后端补 user_id 字段后的客户端解析契约
    // 对应后端补丁：imboy/src/logic/group_member_logic.erl `mute_notice/4`
    // Payload 新增 `<<"user_id">> => UserId`
    // 向后兼容：老版本后端不带 user_id 时，userId 默认 ''（不报错，但调用方
    // 应据此跳过 Repo 写入，仅做群级 toast）
    // ----------------------------------------------------------------------

    test('payload 含 user_id（数字）→ 解析为 String', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'user_id': 1838294017982465,
        'mute_until': 1_900_000_000_000,
      });

      expect(result, isA<GroupMemberMutePayload>());
      expect((result as GroupMemberMutePayload).userId, '1838294017982465');
    });

    test('payload 含 user_id（字符串 TSID）→ 原样保留', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'user_id': '1838294017982465',
        'mute_until': 1_900_000_000_000,
      });

      expect(result, isA<GroupMemberMutePayload>());
      expect((result as GroupMemberMutePayload).userId, '1838294017982465');
    });

    test('payload 不含 user_id → userId 默认空串（向后兼容老后端）', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'mute_until': 1_900_000_000_000,
      });

      expect(result, isA<GroupMemberMutePayload>());
      expect((result as GroupMemberMutePayload).userId, '');
    });

    test('user_id = 0 / 空串 / 空白 → 归一化为空串', () {
      for (final raw in <Object?>[0, '0', '', '   ']) {
        final result = parseGroupMemberMutePayload({
          'gid': 10086,
          'user_id': raw,
          'mute_until': 1_900_000_000_000,
        });
        expect(result, isA<GroupMemberMutePayload>());
        expect(
          (result as GroupMemberMutePayload).userId,
          '',
          reason: 'raw=$raw 应归一化为空',
        );
      }
    });

    // ----------------------------------------------------------------------
    // slice-9b：后端解禁复用同一 action，payload mute_until=0 作为解禁信号
    // 对应后端（待落地）：group_member_logic:unmute/3 通过复用 mute_notice/4
    // 下发 `<<"mute_until">> => 0`，客户端据此切到 Unmute 分支
    // ----------------------------------------------------------------------

    test('mute_until=0 → GroupMemberUnmutePayload（解禁信号）', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'user_id': '1838294017982465',
        'mute_until': 0,
        'admin_nickname': 'Alice',
      });

      expect(result, isA<GroupMemberUnmutePayload>());
      final p = result as GroupMemberUnmutePayload;
      expect(p.gid, 10086);
      expect(p.userId, '1838294017982465');
      expect(p.adminNickname, 'Alice');
    });

    test('mute_until=0 + 无 user_id → Unmute 但 userId 空（向后兼容）', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'mute_until': 0,
      });

      expect(result, isA<GroupMemberUnmutePayload>());
      expect((result as GroupMemberUnmutePayload).userId, '');
      expect(result.adminNickname, '');
    });

    test('mute_until=0 但 gid 非法 → invalid_gid 优先', () {
      final result = parseGroupMemberMutePayload({
        'gid': 0,
        'mute_until': 0,
        'user_id': 'u1',
      });

      expect(result, isA<GroupMemberMuteParseError>());
      expect(
        (result as GroupMemberMuteParseError).reason,
        'invalid_gid',
      );
    });

    test('mute_until < 0 → invalid_mute_until（异常值，不视为解禁）', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'mute_until': -1,
      });

      expect(result, isA<GroupMemberMuteParseError>());
      expect(
        (result as GroupMemberMuteParseError).reason,
        'invalid_mute_until',
      );
    });

    test('mute_until 字符串 "0" → GroupMemberUnmutePayload', () {
      final result = parseGroupMemberMutePayload({
        'gid': 10086,
        'mute_until': '0',
      });

      expect(result, isA<GroupMemberUnmutePayload>());
    });

    test('sealed —— switch 必须穷尽（含 Unmute 分支）', () {
      String describe(GroupMemberMuteParseResult r) {
        return switch (r) {
          GroupMemberMutePayload(:final gid) => 'mute:$gid',
          GroupMemberUnmutePayload(:final gid) => 'unmute:$gid',
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
        'mute:1',
      );
      expect(
        describe(const GroupMemberUnmutePayload(gid: 9, userId: 'u', adminNickname: 'a')),
        'unmute:9',
      );
      expect(
        describe(const GroupMemberMuteParseError('invalid_gid')),
        'err:invalid_gid',
      );
    });
  });
}
