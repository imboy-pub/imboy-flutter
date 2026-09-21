/// 企业 OA 模块公开入口（barrel）。
///
/// 分析器边界约定：上层调用方只 import 本文件，不直接深入模块内部
/// 路径（对齐 enterprise / customer_service 模块的 public.dart 先例）。
///
/// W1 阶段模块为独立骨架（未接入共享导航/router）；W3 集成波次由
/// Flutter Integration Owner（A6）持 lease 统一接线。
library;

export 'domain/enterprise_oa_brand_config.dart';
export 'domain/oa_tab_state.dart';
export 'domain/oa_webview_policy.dart';
export 'presentation/oa_message_badge.dart';
export 'presentation/oa_tab_page.dart';
