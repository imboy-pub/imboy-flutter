/// 群成员角色值对象 / Group role value object（T2.4）。
///
/// 底层为角色码 1..5，对齐后端 `imboy/src/logic/group_role.hrl` 权限矩阵：
///   1=普通成员 2=嘉宾 3=管理员 4=群主 5=副群主。
///
/// 权限矩阵（与后端 group_role.hrl 一致）：
///   | 角色      | 踢人 | 禁言 | 公告 | 解散 | 转让 |
///   | 群主(4)   | ✓   | ✓   | ✓   | ✓   | ✓   |
///   | 副群主(5) | ✓   | ✓   | ✓   | ✗   | ✗   |
///   | 管理员(3) | ✓   | ✓   | ✓   | ✗   | ✗   |
///   | 嘉宾(2)   | ✗   | ✗   | ✗   | ✗   | ✗   |
///   | 成员(1)   | ✗   | ✗   | ✗   | ✗   | ✗   |
///
/// 纯 Dart——禁止 import flutter/* 与 repository/*。
extension type const GroupRole(int code) {
  /// 构造并校验：落在 [member, viceOwner] 之外拒绝。
  factory GroupRole.parse(int raw) {
    if (raw < member || raw > viceOwner) {
      throw FormatException('invalid group role: $raw');
    }
    return GroupRole(raw);
  }

  static const int member = 1;
  static const int guest = 2;
  static const int admin = 3;
  static const int owner = 4;
  static const int viceOwner = 5;

  /// 群主。
  bool get isOwner => code == owner;

  /// 高级管理员（群主或副群主）—— 后端 IS_SENIOR_ADMIN_ROLE。
  bool get isSeniorAdmin => code == owner || code == viceOwner;

  /// 管理员级（管理员/群主/副群主）—— 后端 IS_ADMIN_ROLE。
  bool get isAdmin => code >= admin && code <= viceOwner;

  /// 可踢人（管理员级）。
  bool get canKick => isAdmin;

  /// 可禁言他人（管理员级）。
  bool get canMute => isAdmin;

  /// 可发布公告（管理员级）。
  bool get canAnnounce => isAdmin;

  /// 可解散群（仅群主）。
  bool get canDissolve => code == owner;

  /// 可转让群（仅群主）。
  bool get canTransfer => code == owner;
}
