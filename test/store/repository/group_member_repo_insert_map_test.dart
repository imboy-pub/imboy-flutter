/// 钉住 `GroupMemberRepo` 写入数据库时的 insert map 形状 —— 驱动 GREEN-3。
///
/// 背景：Repo 的 `insert()` 直接调用 `_db.insert(tableName, map)`，整段单例依赖
/// 让在内存 SQLite 上直接测 `insert()` 成本过高。折中方案：把 map 构建抽成
/// 纯静态方法 `toInsertMap()`，测试钉住其输出。
///
/// 契约：
///   - 输出 map 必须包含 `mute_until` key（禁言功能落地标志）
///   - muteUntilMs=null → map['mute_until'] == null
///   - muteUntilMs=非空 → map['mute_until'] == 原值（int ms）
///   - 其它既有字段保持不变（回归安全）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/group_member_columns.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';

GroupMemberModel _buildMember({int? muteUntilMs}) {
  return GroupMemberModel(
    id: 42,
    groupId: 10,
    userId: 100,
    nickname: 'n',
    avatar: 'a',
    sign: 's',
    account: 'ac',
    alias: 'al',
    createdAt: 1700000000000,
    muteUntilMs: muteUntilMs,
  );
}

void main() {
  group('GroupMemberRepo.toInsertMap', () {
    test('muteUntilMs=null → map 含 mute_until 且为 null', () {
      final map = GroupMemberRepo.toInsertMap(_buildMember());

      expect(map.containsKey(GroupMemberColumns.muteUntil), isTrue,
          reason: 'insert map 必须显式声明 mute_until 列，否则 Repo 永远写不进新字段');
      expect(map[GroupMemberColumns.muteUntil], isNull);
    });

    test('muteUntilMs=非空 → map[mute_until] 为同值 int ms', () {
      final map = GroupMemberRepo.toInsertMap(
        _buildMember(muteUntilMs: 1_900_000_000_000),
      );

      expect(map[GroupMemberColumns.muteUntil], 1_900_000_000_000);
    });

    test('既有字段不丢失（回归）', () {
      final map = GroupMemberRepo.toInsertMap(_buildMember());

      expect(map[GroupMemberColumns.id], 42);
      expect(map[GroupMemberColumns.groupId], 10);
      expect(map[GroupMemberColumns.userId], 100);
      expect(map[GroupMemberColumns.nickname], 'n');
      expect(map[GroupMemberColumns.createdAt], 1700000000000);
    });
  });
}
