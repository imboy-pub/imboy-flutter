import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/group_member_columns.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 群组成员数据模型
/// 纯数据模型，不包含响应式状态
class GroupMemberModel {
  int? id; // 自增长ID 服务端
  int groupId; // 群组ID
  int userId; // 群组成员用户ID
  String nickname; // 群组成员用户信息
  String avatar; // 群组成员用户信息
  String sign; // 群组成员用户信息a
  String account; // 群组成员用户信息
  String inviteCode; // 入群邀请码
  String alias; // 群内别名
  String description; // 群内描述
  int role; // 角色: 1 成员  2 嘉宾  3  管理员 4 群主
  int isJoin; // 是否加入的群： 1 是 0 否 （0 是群创建者或者拥有者; 1 是 成员 嘉宾 管理员等）
  // 进群方式 :  invite_[uid]_[nickname] <a>leeyi</a>邀请进群  scan_qr_code 扫描二维码加入 face2face_join 面对面建群
  String joinMode; // 进群方式
  int status;
  int updatedAt;
  int createdAt;

  /// 禁言解除时间戳（毫秒，epoch）。
  /// `null` 表示未禁言 —— **不能**退化为 now，否则所有旧数据都会被误判为禁言中。
  /// 来源：后端 `group_member.mute_until TIMESTAMPTZ NULL`，下发形态有 3 种：
  /// null / int ms / RFC3339 字符串。
  int? muteUntilMs;

  // 如果需要选中状态，应在 UI 层使用 Set 或 State 管理
  // bool selected = false;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.sign,
    required this.account,
    this.inviteCode = '',
    required this.alias,
    this.description = '',
    this.role = 1,
    this.isJoin = 1,
    this.joinMode = '',
    this.status = 1, // '状态: -1 删除  0 禁用  1 启用
    this.updatedAt = 0,
    required this.createdAt,
    this.muteUntilMs,
  });

  /// 当前是否处于禁言状态。
  /// 语义：`muteUntilMs > nowMs` 才算禁言中；等于或小于都视为已解禁。
  /// [nowMs] 传入以支持测试；不传则使用当前墙钟。
  bool isMuted({int? nowMs}) {
    final until = muteUntilMs;
    if (until == null) return false;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return until > now;
  }

  /// 解析 `mute_until` 字段为毫秒时间戳。
  /// - null / 缺失 → null
  /// - int → 原样返回
  /// - String → `DateTime.tryParse`，失败返回 null（不抛异常）
  static int? _parseMuteUntil(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is String) {
      final dt = DateTime.tryParse(raw);
      return dt?.millisecondsSinceEpoch;
    }
    return null;
  }

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    // iPrint("GroupMemberModel.fromJson ${json.toString()}");
    return GroupMemberModel(
      id: parseModelInt(json[GroupMemberColumns.id]),
      groupId: parseModelInt(json[GroupMemberColumns.groupId]),
      userId: parseModelInt(json[GroupMemberColumns.userId]),
      nickname: parseModelString(json[GroupMemberColumns.nickname]),
      avatar: parseModelString(json[GroupMemberColumns.avatar]),
      sign: parseModelString(json[GroupMemberColumns.sign]),
      account: parseModelString(json[GroupMemberColumns.account]),
      inviteCode: parseModelString(json[GroupMemberColumns.inviteCode]),
      alias: parseModelString(json[GroupMemberColumns.alias]),
      description: parseModelString(json[GroupMemberColumns.description]),
      role: parseModelInt(json[GroupMemberColumns.role], defaultValue: 1),
      isJoin: parseModelInt(json[GroupMemberColumns.isJoin], defaultValue: 1),
      joinMode: parseModelString(json[GroupMemberColumns.joinMode]),
      status: parseModelInt(json[GroupMemberColumns.status], defaultValue: 1),
      updatedAt: DateTimeHelper.parseTimestamp(json[GroupMemberColumns.updatedAt]),
      createdAt: DateTimeHelper.parseTimestamp(json[GroupMemberColumns.createdAt]),
      muteUntilMs: _parseMuteUntil(json[GroupMemberColumns.muteUntil]),
    );
  }

  Map<String, dynamic> toJson() => {
    GroupMemberColumns.id: id,
    GroupMemberColumns.groupId: groupId,
    GroupMemberColumns.userId: userId,
    GroupMemberColumns.inviteCode: inviteCode,
    GroupMemberColumns.alias: alias,
    GroupMemberColumns.description: description,
    GroupMemberColumns.role: role,
    GroupMemberColumns.isJoin: isJoin,
    GroupMemberColumns.joinMode: joinMode,
    GroupMemberColumns.status: status,
    GroupMemberColumns.updatedAt: updatedAt,
    GroupMemberColumns.createdAt: createdAt,
    // 始终输出 mute_until（可为 null），便于上层以 containsKey 判断字段存在性。
    GroupMemberColumns.muteUntil: muteUntilMs,
  };
}
