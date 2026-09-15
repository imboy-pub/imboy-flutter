/// 企业模块公开入口（barrel）。
///
/// 分析器边界约定：上层调用方只 import 本文件，不直接深入模块内部路径
/// （对齐 identity / messaging 模块的 public.dart 先例）。
library;

export 'domain/enterprise_models.dart';
export 'infrastructure/enterprise_api.dart';
export 'infrastructure/enterprise_sqflite_store.dart';
export 'infrastructure/enterprise_store.dart';
export 'presentation/enterprise_conversation_page.dart';
export 'presentation/enterprise_home_page.dart';
export 'presentation/enterprise_routes.dart';
