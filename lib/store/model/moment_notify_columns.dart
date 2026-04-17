/// `moment_notify` 表列名常量（纯 Dart，不依赖任何数据库 / 平台插件）。
///
/// 设计目的：解耦 `MomentNotifyModel` ↔ `MomentNotifyRepo`，让 Model-only
/// 单测不被 `sqflite_sqlcipher` → `win32_*` 传递依赖污染（沿用
/// `group_member_columns.dart` 同款解耦策略）。
///
/// Slice A-1 对应迁移 v20（`assets/migrations/upgrade.sql`）。
class MomentNotifyColumns {
  MomentNotifyColumns._();

  static const String table = 'moment_notify';

  /// 自增主键（SQLite `INTEGER PRIMARY KEY AUTOINCREMENT`）。
  static const String id = 'id';

  /// 接收者 UID（当前登录用户的 TSID 字符串）。
  static const String userId = 'user_id';

  /// S2C action：`moment_like` 或 `moment_comment`。
  static const String action = 'action';

  /// 朋友圈帖子 ID（TSID 字符串）。
  static const String momentId = 'moment_id';

  /// 发起人 UID（点赞者 / 评论者）。
  static const String fromUid = 'from_uid';

  /// 评论 ID（仅 `moment_comment` 有值）。
  static const String commentId = 'comment_id';

  /// 已读标记（SQLite 无 bool，用 0/1 存）。
  static const String isRead = 'is_read';

  /// 创建时间（ms epoch）。
  static const String createdAt = 'created_at';
}
