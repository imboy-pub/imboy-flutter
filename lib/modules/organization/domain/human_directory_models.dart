/// Human Directory DTO（计划 §14.2 / A4 冻结契约 2026-09-23）
///
/// 出站投影**逐字段镜像** A4 `RESULT.json` 的 `response_field_lists`：
/// - department: `{id, name, parent_id, member_count}`
/// - member: `{user_id, display_name, avatar, department_ids}`
/// - search item: department 投影 + `type:"department"`，或 member 投影 +
///   `type:"member"`（同 list 混排，departments 在前）
/// - /me payload: `{organization_id, list}`
/// - 分页 payload: `{list, cursor, has_more}`
///
/// TSID：后端以 JSON integer 传输 64-bit ID，本端一律经 [entityIdOf] 转
/// String（[EntityId]）持有，全程不回转 int。cursor 为服务端 opaque 字符串
/// （CURSOR-V2 签名票），客户端只透传、不解析。
///
/// 本文件保持纯 Dart（无 flutter import），可被单测直接驱动。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

export 'package:imboy/store/model/workspace_model.dart'
    show EntityId, entityIdOf;

/// Human Directory 分页信封：`payload:{list, cursor, has_more}`。
/// 末页 `cursor == null`（服务端 limit+1 判 has_more 后摘掉多取行）。
class HumanDirectoryPage<T> {
  final List<T> list;
  final String? cursor;
  final bool hasMore;

  const HumanDirectoryPage({
    required this.list,
    required this.cursor,
    required this.hasMore,
  });

  bool get isLastPage => cursor == null;
}

/// 部门行（`GET /directory/departments`、search department 项、/me 项共用）。
class HumanDirectoryDepartment {
  final EntityId id;
  final String name;

  /// 父部门 ID；`null`（服务端根级）→ 空串。
  final EntityId parentId;

  /// 本级 active 组织成员数（removed/suspended 排除；展示即事实）。
  final int memberCount;

  const HumanDirectoryDepartment({
    required this.id,
    required this.name,
    this.parentId = '',
    this.memberCount = 0,
  });

  factory HumanDirectoryDepartment.fromJson(Map<String, dynamic> json) {
    return HumanDirectoryDepartment(
      id: entityIdOf(json['id']),
      name: parseModelString(json['name']),
      parentId: entityIdOf(json['parent_id']),
      memberCount: parseModelInt(json['member_count']),
    );
  }

  bool get isRoot => parentId.isEmpty;
}

/// 成员行（`GET /directory/members`、search member 项共用）。
///
/// U-02：**没有职位字段**（服务端 UNKNOWN_DATA_SOURCE，本期不出站），
/// 本 DTO 也不得臆造。
class HumanDirectoryMember {
  final EntityId userId;

  /// 昵称空串回落 account 后的展示名（服务端口径）。
  final String displayName;
  final String avatar;

  /// 本人全部 active 部门（升序；根成员为空数组）。
  final List<EntityId> departmentIds;

  const HumanDirectoryMember({
    required this.userId,
    required this.displayName,
    this.avatar = '',
    this.departmentIds = const <EntityId>[],
  });

  factory HumanDirectoryMember.fromJson(Map<String, dynamic> json) {
    return HumanDirectoryMember(
      userId: entityIdOf(json['user_id']),
      displayName: parseModelString(json['display_name']),
      avatar: parseModelString(json['avatar']),
      departmentIds: _entityIdList(json['department_ids']),
    );
  }
}

/// search 混排行：departments 在前、组内 id ASC；同一 list 内两类混排，
/// 客户端保持服务端顺序，不重排、不与目录分页合并（§14.3）。
class HumanDirectorySearchItem {
  /// "department" | "member"（未知值原样保留，行按未知态降级渲染）。
  final String type;
  final HumanDirectoryDepartment? department;
  final HumanDirectoryMember? member;

  const HumanDirectorySearchItem({
    required this.type,
    this.department,
    this.member,
  });

  factory HumanDirectorySearchItem.fromJson(Map<String, dynamic> json) {
    final type = parseModelString(json['type']);
    return HumanDirectorySearchItem(
      type: type,
      department: type == 'department'
          ? HumanDirectoryDepartment.fromJson(json)
          : null,
      member: type == 'member' ? HumanDirectoryMember.fromJson(json) : null,
    );
  }

  bool get isDepartment => type == 'department';
  bool get isMember => type == 'member';

  /// 行去重键（部门与成员 ID 域不冲突：同为 TSID 但分型比较）。
  String get dedupeKey =>
      '$type:${isDepartment ? department?.id : member?.userId}';
}

/// `GET /directory/me` payload：`{organization_id, list, member_count}`
/// （我的 active 部门捷径；无部门返回空数组，不报错。member_count =
/// 组织 active 成员总数，APP-M02 通讯录页脚「共X人」；0 = 未提供/失败）。
class HumanDirectoryMe {
  final EntityId organizationId;
  final List<HumanDirectoryDepartment> list;
  final int memberCount;

  const HumanDirectoryMe({
    required this.organizationId,
    required this.list,
    this.memberCount = 0,
  });

  factory HumanDirectoryMe.fromJson(Map<String, dynamic> json) {
    return HumanDirectoryMe(
      organizationId: entityIdOf(json['organization_id']),
      list: _deptList(json['list']),
      memberCount: parseModelInt(json['member_count']),
    );
  }
}

List<EntityId> _entityIdList(dynamic raw) {
  if (raw is! List) return const <EntityId>[];
  return raw
      .map(entityIdOf)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}

List<HumanDirectoryDepartment> _deptList(dynamic raw) {
  if (raw is! List) return const <HumanDirectoryDepartment>[];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(HumanDirectoryDepartment.fromJson)
      .where((d) => d.id.isNotEmpty)
      .toList(growable: false);
}
