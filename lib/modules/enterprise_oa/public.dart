/// 企业 OA 模块公开入口（barrel）。
///
/// 分析器边界约定：上层调用方只 import 本文件，不直接深入模块内部
/// 路径（对齐 enterprise / customer_service 模块的 public.dart 先例）。
///
/// SSO、WebView 与服务器工作台发现复用同一模块。企业壳承载工作台；
/// 个人导航不注册 OA，选择应用后才启动 SSO。
library;

export 'domain/enterprise_oa_brand_config.dart';
export 'domain/oa_sso_issue.dart';
export 'domain/oa_tab_state.dart';
export 'domain/oa_webview_policy.dart';
export 'enterprise_oa_runtime_config.dart';
export 'oa_workbench_provider.dart';
export 'presentation/oa_message_badge.dart';
export 'presentation/oa_tab_page.dart';
export 'presentation/oa_webview_container.dart';
export 'presentation/enterprise_workbench_page.dart';
