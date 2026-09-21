/// 受限游标目录（成员/身份检索）的前端契约与不变式（FULL-05 / INT-16、INT-17）。
///
/// 逐条对齐后端 `enterprise_directory_logic`（FULL-02 真库套件已钉死）：
///
/// | 项 | 契约 |
/// |---|---|
/// | 分页上限 | `page_size ∈ [1, 100]`，缺省 50；**超限拒绝**（`invalid_request`），绝不静默截断 |
/// | 游标 | 不透明 base64url(`<族标签>:<keyset>`)；不可跨页族复用；只含键，不含 PII |
/// | 页响应 | `{items, page_size, has_more, next_cursor}` |
/// | mappings 项 | `{external_user_id, user_id}` |
/// | users 项 | `{user_id, external_user_id, member_role, member_status}`（**恰好 4 键**，无昵称/手机/邮箱） |
/// | 无界导出 | 不存在：只有分页入口，没有 OFFSET、没有无 LIMIT 读、没有 COUNT 导出 |
///
/// **UI 侧不得提供「全量导出」入口**（plan-full §3.1 硬边界）。本文件把这条
/// 从「约定」变成**结构事实**：
/// - 客户端只有 [EnterpriseDirectoryFamily] 两个分页取数入口；
/// - [kDirectoryForbiddenEntryPattern] 是导出面命名黑名单，测试以源码扫描 +
///   公开成员扫描双向断言模块内没有任何导出形态的入口；
/// - [EnterpriseDirectoryClientSurface] 的公开成员集合被测试逐条冻结，
///   新增成员即红（防止后人加一个 exportAll 形态的方法悄悄破坏边界）。
///
/// 纯 Dart（零 Flutter / 零 IO）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

export 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 目录页族（游标不可跨族复用，标签与后端 `?TAG_MAPPINGS`/`?TAG_USERS` 同源）。
enum EnterpriseDirectoryFamily {
  /// 外部身份映射（INT-16）。
  mappings('mappings'),

  /// 本 Org 成员身份（INT-17，可选 workspace 过滤）。
  users('users');

  /// 游标族标签（服务端以它在游标内自证页族）。
  final String tag;

  const EnterpriseDirectoryFamily(this.tag);
}

/// 分页硬上限（后端 `?MAX_PAGE`）。
const int kDirectoryMaxPageSize = 100;

/// 分页缺省值（后端 `?DEFAULT_PAGE`）。
const int kDirectoryDefaultPageSize = 50;

/// 目录项最小字段：mappings（恰好 2 键）。
class DirectoryMappingItem {
  const DirectoryMappingItem({
    required this.externalUserId,
    required this.userId,
  });

  final EntityId externalUserId;
  final EntityId userId;

  /// 原样字段（测试以键集合钉死「不夹带 PII」）。
  Map<String, Object?> get rawFields => <String, Object?>{
    'external_user_id': externalUserId,
    'user_id': userId,
  };

  factory DirectoryMappingItem.fromJson(Map<String, dynamic> json) {
    return DirectoryMappingItem(
      externalUserId: entityIdOf(json['external_user_id']),
      userId: entityIdOf(json['user_id']),
    );
  }
}

/// 目录项最小字段：users（恰好 4 键，无昵称/手机/邮箱）。
class DirectoryMemberItem {
  const DirectoryMemberItem({
    required this.userId,
    this.externalUserId = '',
    this.memberRole,
    this.memberStatus,
  });

  final EntityId userId;
  final EntityId externalUserId;

  /// `group_member` 不是本项语义源——此处是 org 成员角色（可缺省）。
  final int? memberRole;
  final int? memberStatus;

  Map<String, Object?> get rawFields => <String, Object?>{
    'user_id': userId,
    'external_user_id': externalUserId,
    'member_role': memberRole,
    'member_status': memberStatus,
  };

  factory DirectoryMemberItem.fromJson(Map<String, dynamic> json) {
    return DirectoryMemberItem(
      userId: entityIdOf(json['user_id']),
      externalUserId: entityIdOf(json['external_user_id']),
      memberRole: parseModelNullableInt(json['member_role']),
      memberStatus: parseModelNullableInt(json['member_status']),
    );
  }
}

/// 一页目录结果（泛型，两项共用）。
class EnterpriseDirectoryResult<T> {
  const EnterpriseDirectoryResult({
    required this.family,
    required this.items,
    required this.pageSize,
    required this.hasMore,
    this.nextCursor = '',
  });

  final EnterpriseDirectoryFamily family;
  final List<T> items;
  final int pageSize;
  final bool hasMore;

  /// 空串 = 无下一页。
  final String nextCursor;

  /// 末页判定（UI 显示「已到末页」而不是永远「加载更多」）。
  bool get isEnd => !hasMore || nextCursor.isEmpty;

  bool get isEmpty => items.isEmpty;
}

/// 请求校验结果。
class DirectoryQueryValidation {
  const DirectoryQueryValidation({this.reason, required this.pageSize});

  /// null = 通过。
  final String? reason;
  final int pageSize;

  bool get isValid => reason == null;
}

/// 归一 + 校验一次目录请求的 page_size。
///
/// 与后端同规则：非整数 / 0 / 负数 / 超过 [kDirectoryMaxPageSize] 一律**拒绝**
/// （不是截断）——截断会把「想要全量」变成一个永远成功的循环。
DirectoryQueryValidation validateDirectoryPageSize(dynamic raw) {
  if (raw == null) {
    return const DirectoryQueryValidation(pageSize: kDirectoryDefaultPageSize);
  }
  final int? v = raw is int ? raw : int.tryParse(raw.toString());
  if (v == null) {
    return const DirectoryQueryValidation(
      reason: 'page_size_not_integer',
      pageSize: 0,
    );
  }
  if (v < 1) {
    return const DirectoryQueryValidation(
      reason: 'page_size_below_min',
      pageSize: 0,
    );
  }
  if (v > kDirectoryMaxPageSize) {
    return const DirectoryQueryValidation(
      reason: 'page_size_over_cap',
      pageSize: 0,
    );
  }
  return DirectoryQueryValidation(pageSize: v);
}

/// 解析一页响应（mappings 族）。
EnterpriseDirectoryResult<DirectoryMappingItem> parseMappingsPage(
  dynamic body,
) {
  final _PageEnvelope env = _parseEnvelope(body);
  return EnterpriseDirectoryResult<DirectoryMappingItem>(
    family: EnterpriseDirectoryFamily.mappings,
    items: env.items
        .map((e) => DirectoryMappingItem.fromJson(e))
        .toList(growable: false),
    pageSize: env.pageSize,
    hasMore: env.hasMore,
    nextCursor: env.nextCursor,
  );
}

/// 解析一页响应（users 族）。
EnterpriseDirectoryResult<DirectoryMemberItem> parseUsersPage(dynamic body) {
  final _PageEnvelope env = _parseEnvelope(body);
  return EnterpriseDirectoryResult<DirectoryMemberItem>(
    family: EnterpriseDirectoryFamily.users,
    items: env.items
        .map((e) => DirectoryMemberItem.fromJson(e))
        .toList(growable: false),
    pageSize: env.pageSize,
    hasMore: env.hasMore,
    nextCursor: env.nextCursor,
  );
}

/// 客户端目录公开方法名冻结表（**新增即红**）。
///
/// 测试以 `dart:mirrors` 之外的机械方式（源码扫描）断言：目录能力对外只暴露
/// 这两个分页取数入口 + 纯校验/解析函数，**不存在**任何导出/全量形态入口。
const List<String> kDirectoryClientPagedReadMethods = <String>[
  'directoryMappingsPage',
  'directoryUsersPage',
];

/// 导出面命名黑名单（源码扫描用；命中即违反「无全量导出入口」硬边界）。
///
/// 覆盖常见导出形态命名：export / dump / downloadAll / fetchAll /
/// listEverything / allItems / fullList / bulk。
final RegExp kDirectoryForbiddenEntryPattern = RegExp(
  r'\b(?:export|dump|downloadAll|fetchAll|listEverything|allItems|fullList|'
  r'bulk[A-Z_]|exportAll|downloadEverything)\w*\s*\(',
);

/// 目录族 → 请求路径（与 manifest INT-16 / INT-17 逐字对齐）。
String directoryPathFor(EnterpriseDirectoryFamily family) {
  switch (family) {
    case EnterpriseDirectoryFamily.mappings:
      return '/api/internal/v1/identity-mappings/directory';
    case EnterpriseDirectoryFamily.users:
      return '/api/internal/v1/directory/users';
  }
}

class _PageEnvelope {
  const _PageEnvelope({
    required this.items,
    required this.pageSize,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<Map<String, dynamic>> items;
  final int pageSize;
  final bool hasMore;
  final String nextCursor;
}

_PageEnvelope _parseEnvelope(dynamic body) {
  final Map<String, dynamic> root = _asMap(body) ?? const <String, dynamic>{};
  final dynamic rawItems = root['items'];
  final List<Map<String, dynamic>> items = rawItems is List
      ? rawItems
            .map((dynamic e) => _asMap(e))
            .whereType<Map<String, dynamic>>()
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  return _PageEnvelope(
    items: items,
    pageSize: parseModelInt(root['page_size']),
    hasMore: parseModelBool(root['has_more']),
    nextCursor: parseModelString(root['next_cursor']),
  );
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return parseModelJsonMap(raw);
}
