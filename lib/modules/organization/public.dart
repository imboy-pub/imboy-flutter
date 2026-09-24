/// Organization 模块 barrel（对齐 enterprise/public.dart 模式）。
library;

export 'domain/organization_models.dart';
export 'infrastructure/organization_api.dart';
export 'infrastructure/organization_cache.dart';
export 'presentation/org_async_state.dart';
// ENT-APP-01：聚合页（/organization/:orgId）是模块对外的门面页，
// 导出以便测试/宿主经公共入口引用（module boundaries 零新增）。
export 'presentation/organization_detail_page.dart';
export 'presentation/organization_routes.dart';
