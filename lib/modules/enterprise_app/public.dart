/// 企业应用模块公开入口（barrel）。
///
/// 分析器边界约定：上层调用方只 import 本文件，不直接深入模块内部路径
/// （对齐 enterprise / enterprise_oa / customer_service 模块的 public.dart 先例）。
///
/// 模块职责（FULL-05 / plan-full §3.3）：Application 消息来源事实、企业群治理、
/// 受限游标目录、附件留存治理、企业接口错误与空态。
/// 复用广州期 `enterprise_oa` 的 OA Tab/WebView/SSO/品牌配置与代发徽标组件，
/// **不重建**。
library;

export 'domain/asset_retention_governance.dart';
export 'domain/enterprise_app_error.dart';
export 'domain/enterprise_directory.dart';
export 'domain/enterprise_group_admin.dart';
export 'domain/enterprise_message_origin.dart';
export 'infrastructure/enterprise_app_api.dart';
export 'presentation/asset_retention_panel.dart';
export 'presentation/enterprise_directory_page.dart';
export 'presentation/enterprise_error_view.dart';
export 'presentation/enterprise_group_page.dart';
export 'presentation/hosted_message_facts.dart';
