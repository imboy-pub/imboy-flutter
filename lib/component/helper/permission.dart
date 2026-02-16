/// 权限工具 - 条件导入
///
/// 根据平台自动选择正确的实现：
/// - Web 平台：使用 permission_web.dart（返回 true，不需要原生权限）
/// - 移动平台：使用 permission_web_stub.dart（使用 permission_handler 和 photo_manager）
library;

// 条件导入：根据编译平台选择不同的实现
// Web 平台导入 permission_web.dart
// 移动平台导入 permission_web_stub.dart
export 'permission_web_stub.dart' if (dart.library.js) 'permission_web.dart';
