import 'package:imboy/store/model/contact_model.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 联系人（用户）仓储端口 / Contact (user) repository port（T4.4a，务实 port 方向 A）。
///
/// **命名说明**：backlog T4.4 所述「User Repository」在本代码库的真身为
/// `ContactRepo`（社交图谱上下文的用户/好友数据仓储）；`UserRepoLocal` 是当前会话
/// 单例（非 CRUD 仓储），不在本端口范围。
///
/// **架构决策（2026-06-01，T4.4 方向 A）**：与 [MessageRepository]/[GroupRepository]
/// 一致，务实允许签名引用 `sqflite_sqlcipher.Transaction`，零行为变更让 `ContactRepo`
/// 原地 `implements`。`findByUid` 端口仅声明必需 `uid`；实现方追加 `{autoFetch, txn}`
/// 可选参（合法实现）。`search`/`findFriend`/`addTag` 等专用方法作为实现方扩展保留。
abstract interface class ContactRepository {
  /// 插入联系人（已存在则跳过）。
  Future<ContactModel> insert(ContactModel obj, {Transaction? txn});

  /// 按字段局部更新。
  Future<int> update(Map<String, dynamic> json, {Transaction? txn});

  /// 按 UID 删除（单条）。
  Future<int> delete(String uid);

  /// 按 UID 删除（from 或 to 关联）。
  Future<int> deleteByUid(String uid);

  /// 按 UID 查找。
  Future<ContactModel?> findByUid(String uid);

  /// 全量同步保存（存在则更新，不存在则插入）。
  Future<ContactModel?> save(Map<String, dynamic> json);
}
