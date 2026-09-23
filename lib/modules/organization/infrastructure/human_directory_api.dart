/// Human Directory 数据源接口（计划 §14.2 / §14.3）
///
/// 4 个只读端点的客户端抽象：
/// - `GET /api/v1/organizations/{org_id}/directory/departments?parent_id=&cursor=&limit=`
/// - `GET /api/v1/organizations/{org_id}/directory/members?department_id=&cursor=&limit=`
/// - `GET /api/v1/organizations/{org_id}/directory/me`
/// - `GET /api/v1/organizations/{org_id}/directory/search?q=&cursor=&limit=`
///
/// 抽象目的：[HumanDirectoryController]（状态机）依赖本接口而非具体
/// [OrganizationApi]，widget/mock 测试可注入可控延迟的 fake transport
/// （§14.3 Flutter Oracle 口径）。生产实现见 `OrganizationApi implements
/// HumanDirectoryDataSource`（复用既有 HttpClient/Token，不建第二套）。
///
/// 错误语义：任何失败以 [OrganizationApiException] 抛出——Human Directory
/// 的错误信封 `{"error":{"code","message"}}` 携带真实 HTTP 状态
/// （400 invalid_request / 403 insufficient_scope·organization_disabled /
/// 404 resource_not_found / 503 security_gate_closed），经
/// [OrganizationApiException.code] 一比一透传，调用方按状态分型：
/// - 400 + cursor 请求 → 游标失效（客户端清空对应分页从首页重试一次）
/// - 403/404 → 权限/不存在终态
/// - 503 → 安全门关闭
library;

import 'package:imboy/modules/organization/domain/human_directory_models.dart';

abstract interface class HumanDirectoryDataSource {
  /// 直接子部门（direct active children；parent_id 缺省 = 根级）。
  Future<HumanDirectoryPage<HumanDirectoryDepartment>> directoryDepartments({
    required EntityId organizationId,
    EntityId? parentId,
    String? cursor,
    int? limit,
  });

  /// 本级成员（department_id 缺省 = 未挂任何 active 部门的根成员）。
  Future<HumanDirectoryPage<HumanDirectoryMember>> directoryMembers({
    required EntityId organizationId,
    EntityId? departmentId,
    String? cursor,
    int? limit,
  });

  /// 当前用户在本 Org 的 active 部门（「我的部门」捷径；空数组非错误）。
  Future<HumanDirectoryMe> directoryMe({required EntityId organizationId});

  /// 三列 ILIKE 混排搜索（name/nickname/account；U-02：不搜职位/手机/邮箱）。
  Future<HumanDirectoryPage<HumanDirectorySearchItem>> directorySearch({
    required EntityId organizationId,
    required String q,
    String? cursor,
    int? limit,
  });
}
