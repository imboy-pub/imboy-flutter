/// 面聊记录（talk_record）入口上下文（T10 UI 层）。
///
/// 契约源：docs/design/2026-10-20-face-to-face-notes/UI-SPEC.md §2
/// 「个人入口 / 企业入口 / 列表」+ DESIGN.md §9 ——
/// - 个人入口（我→个人工具）带个人上下文进入列表，不默认企业；
/// - 企业入口（工作台→协作工具）带当前企业；不带未知工作区、
///   不暗示全员可读；
/// - 列表上下文由入口决定，V1 不在列表内切换归属；开始前的归属
///   更正走准备页「保存到」（保存位置页）。
///
/// 本对象只承载「入口给出的展示级上下文」，不是权限凭证：真正的
/// 可创建集合以 GET /creation-contexts（T08 数据层）为准。
library;

import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 面聊记录入口上下文。
class TalkRecordEntryContext {
  /// personal=个人入口；organization=企业入口（工作台）。
  final TalkRecordScope scope;

  /// 企业 ID（仅 organization 上下文非空）。
  final EntityId organizationId;

  /// 企业展示名（可空：入口未提供时 UI 显示通用文案，不猜测）。
  final String organizationName;

  /// 工作区 ID（可空：企业入口不默认携带未知工作区）。
  final EntityId workspaceId;

  /// 工作区展示名（可空）。
  final String workspaceName;

  const TalkRecordEntryContext({
    this.scope = TalkRecordScope.personal,
    this.organizationId = '',
    this.organizationName = '',
    this.workspaceId = '',
    this.workspaceName = '',
  });

  const TalkRecordEntryContext.personal()
    : this(scope: TalkRecordScope.personal);

  bool get isOrganization => scope == TalkRecordScope.organization;

  /// 是否携带工作区（企业上下文下用于决定是否展示工作区行）。
  bool get hasWorkspace =>
      isOrganization && workspaceId.isNotEmpty && workspaceName.isNotEmpty;

  /// 路由 query 序列化（入口 → 列表/准备页传参）。
  Map<String, String> toQuery() => {
    'scope': isOrganization
        ? TalkRecordScope.organization.wireName
        : TalkRecordScope.personal.wireName,
    if (organizationId.isNotEmpty) 'organization_id': organizationId,
    if (organizationId.isNotEmpty && organizationName.isNotEmpty)
      'organization_name': organizationName,
    if (workspaceId.isNotEmpty) 'workspace_id': workspaceId,
    if (workspaceId.isNotEmpty && workspaceName.isNotEmpty)
      'workspace_name': workspaceName,
  };

  /// 路由 query 反序列化（缺省/未知值降级 personal，不猜企业）。
  factory TalkRecordEntryContext.fromQuery(Map<String, String> query) {
    final scope = TalkRecordScope.parse(query['scope']);
    final orgId = (query['organization_id'] ?? '').trim();
    return TalkRecordEntryContext(
      scope: scope == TalkRecordScope.organization
          ? TalkRecordScope.organization
          : TalkRecordScope.personal,
      organizationId: orgId,
      organizationName: (query['organization_name'] ?? '').trim(),
      workspaceId: (query['workspace_id'] ?? '').trim(),
      workspaceName: (query['workspace_name'] ?? '').trim(),
    );
  }

  /// 与创建上下文（creation-contexts 元素）对齐的有效归属。
  bool matchesContext({
    required TalkRecordScope scope,
    EntityId organizationId = '',
    EntityId workspaceId = '',
  }) {
    return this.scope == scope &&
        this.organizationId == organizationId &&
        this.workspaceId == workspaceId;
  }

  @override
  bool operator ==(Object other) =>
      other is TalkRecordEntryContext &&
      other.scope == scope &&
      other.organizationId == organizationId &&
      other.workspaceId == workspaceId;

  @override
  int get hashCode => Object.hash(scope, organizationId, workspaceId);

  @override
  String toString() =>
      'TalkRecordEntryContext(${scope.wireName}, org=$organizationId, ws=$workspaceId)';
}
