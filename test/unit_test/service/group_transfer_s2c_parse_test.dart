/// 钉住 `parseGroupTransferPayload` 的解析契约 —— Q05/AC10。
///
/// 服务端 payload 键为 binary（#{gid, from_owner_uid, to_owner_uid}），
/// 经 JSON 到达 Dart 侧为 String 键；TSID 按 JSON integer 下发，也须
/// 容忍数字串（对齐 _handleGroupMemberLeave 的 W2R6 类型漂移教训）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_transfer_s2c.dart';

void main() {
  group('parseGroupTransferPayload — 解析契约', () {
    test('完整 payload（TSID integer）→ 全字段解析', () {
      final result = parseGroupTransferPayload({
        'gid': 77,
        'from_owner_uid': 1001,
        'to_owner_uid': 2002,
      });

      expect(result, isA<GroupTransferPayload>());
      final p = result as GroupTransferPayload;
      expect(p.gid, '77');
      expect(p.fromOwnerUid, '1001');
      expect(p.toOwnerUid, '2002');
    });

    test('数字串形态（TSID 以字符串下发）→ 同样归一为 int', () {
      final result = parseGroupTransferPayload({
        'gid': '77',
        'from_owner_uid': '1001',
        'to_owner_uid': '2002',
      });

      final p = result as GroupTransferPayload;
      expect(p.gid, '77');
      expect(p.fromOwnerUid, '1001');
      expect(p.toOwnerUid, '2002');
    });

    test('缺 gid → invalid_gid（不抛异常）', () {
      final result = parseGroupTransferPayload({
        'from_owner_uid': 1001,
        'to_owner_uid': 2002,
      });
      expect(result, isA<GroupTransferParseError>());
      expect((result as GroupTransferParseError).reason, 'invalid_gid');
    });

    test('gid 为 0 / 负数 / 非数字串 → invalid_gid', () {
      for (final gid in [0, -1, 'abc', null, '']) {
        final result = parseGroupTransferPayload({
          'gid': gid,
          'from_owner_uid': 1001,
          'to_owner_uid': 2002,
        });
        expect(result, isA<GroupTransferParseError>(), reason: 'gid=$gid');
        expect((result as GroupTransferParseError).reason, 'invalid_gid');
      }
    });

    test('缺 from/to_owner_uid → 容忍为 0（老后端兼容，跳过角色写）', () {
      final result = parseGroupTransferPayload({'gid': 77});
      final p = result as GroupTransferPayload;
      expect(p.gid, '77');
      expect(p.fromOwnerUid, '');
      expect(p.toOwnerUid, '');
    });

    test('空 payload → invalid_gid（防御：不抛异常）', () {
      final result = parseGroupTransferPayload(<String, dynamic>{});
      expect(result, isA<GroupTransferParseError>());
    });

    test('类型漂移 → 明确拒绝而非截断身份', () {
      // 小数类型不能作为身份标识。
      final dbl = parseGroupTransferPayload({
        'gid': 77.0,
        'from_owner_uid': 1,
        'to_owner_uid': 2,
      });
      expect(dbl, isA<GroupTransferParseError>());

      // bool / List 无法归一 → invalid_gid，不抛异常
      for (final gid in [true, <dynamic>[]]) {
        final result = parseGroupTransferPayload({
          'gid': gid,
          'from_owner_uid': 1,
          'to_owner_uid': 2,
        });
        expect(result, isA<GroupTransferParseError>(), reason: 'gid=$gid');
      }
    });
  });
}
