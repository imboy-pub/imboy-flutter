import 'package:imboy/store/model/group_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 群组仓储端口 / Group repository port（T4.4a，务实 port 方向 A）。
///
/// **架构决策（2026-06-01，T4.4 方向 A）**：与 [MessageRepository] 一致，本端口
/// 务实地允许签名引用 `sqflite_sqlcipher.Transaction`，零行为变更让 `GroupRepo`
/// 原地 `implements`。端口仅声明核心 CRUD + 主查询契约；`pageByAttr`/`pageActive`/
/// `search` 等专用查询作为实现方扩展保留，不进契约。
///
/// **Architecture decision (Direction A — pragmatic port)**: mirrors
/// `MessageRepository`; references the persistence `Transaction` type so the
/// existing `GroupRepo` implements it with zero behavior change.
abstract interface class GroupRepository {
  /// 插入群组（已存在则跳过）。
  Future<GroupModel> insert(GroupModel obj, {Transaction? txn});

  /// 按群组 ID 删除。
  Future<int> delete(String gid);

  /// 按群组 ID 局部更新。
  Future<int> update(String gid, Map<String, dynamic> json, {Transaction? txn});

  /// 全量同步保存（存在则更新，不存在则插入）。
  Future<GroupModel> save(String gid, Map<String, dynamic> json);

  /// 按群组 ID 查找。
  Future<GroupModel?> findById(String gid, {Transaction? txn});
}
