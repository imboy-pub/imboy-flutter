/// Organization 模块 barrel（对齐 enterprise/public.dart 模式）。
library;

export 'domain/organization_models.dart';
export 'infrastructure/organization_api.dart';
export 'infrastructure/organization_cache.dart';
export 'infrastructure/current_organization_store.dart';
export 'presentation/org_async_state.dart';
// ENT-APP-01：聚合页（/organization/:orgId）是模块对外的门面页，
// 导出以便测试/宿主经公共入口引用（module boundaries 零新增）。
export 'presentation/organization_detail_page.dart';
export 'presentation/organization_routes.dart';
// ENT-APP-04：成员治理面（治理列表 + §5.2 成员详情）同样经公共入口
// 供测试引用（module boundaries 零新增）。
export 'presentation/organization_member_detail_page.dart';
export 'presentation/organization_members_page.dart';
// ENT-APP-05：部门治理闭包（树 + 详情成员治理面）经公共入口供测试引用。
export 'presentation/organization_departments_page.dart';
export 'presentation/human_directory_page.dart';
