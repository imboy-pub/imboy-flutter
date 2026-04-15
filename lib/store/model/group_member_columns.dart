/// `group_member` 表列名常量（纯 Dart，不依赖任何数据库 / 平台插件）。
///
/// 设计目的：解耦 `GroupMemberModel` ↔ `GroupMemberRepo`。
/// - Model 以前通过 `GroupMemberRepo.xxx` 读取列名字符串，会把 Model 的传递
///   依赖拉到 `sqflite_sqlcipher` → `win32_*`（Windows 条件编译路径），导致
///   macOS 下单元测试编译时也要解析整条 Windows 插件链，在环境里 win32 5.x
///   与插件生态 6.x API 错配时测试无法启动。
/// - 抽出纯 Dart 常量后，Model 只依赖本文件，即可在无平台插件的环境中被
///   单元测试直接 import。
///
/// Repo 侧现有 `GroupMemberRepo.xxx` 静态字段保持不动，作为既有调用点的
/// 兼容层；后续可以让 Repo 直接引用这里的常量以消除重复定义。
class GroupMemberColumns {
  GroupMemberColumns._();

  static const String table = 'group_member';

  static const String id = 'id';
  static const String groupId = 'group_id';
  static const String userId = 'user_id';
  static const String nickname = 'nickname';
  static const String avatar = 'avatar';
  static const String sign = 'sign';
  static const String account = 'account';
  static const String inviteCode = 'invite_code';
  static const String alias = 'alias';
  static const String description = 'description';
  static const String role = 'role';
  static const String isJoin = 'is_join';
  static const String joinMode = 'join_mode';
  static const String status = 'status';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';

  /// 禁言解除时间戳（毫秒，epoch）。`null` 表示未禁言。
  /// 对齐后端迁移 `00000051_group_member_mute.sql` 的 `mute_until TIMESTAMPTZ NULL`。
  static const String muteUntil = 'mute_until';
}
