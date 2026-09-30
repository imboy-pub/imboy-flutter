/// 企业 OA 模块公开入口（barrel）。
///
/// 分析器边界约定：上层调用方只 import 本文件，不直接深入模块内部
/// 路径（对齐 enterprise / customer_service 模块的 public.dart 先例）。
///
/// W3 集成形态：SSO 链路（issue code → redirect URL → WebView）、真
/// WebView 容器、运行时配置（dart-define）已接线；主导航 Tab 注册由
/// A6 持 shared-navigation lease 落地（bottom_navigation_page.dart）。
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
