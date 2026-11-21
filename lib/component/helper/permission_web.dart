/// 权限工具 - Web 平台实现
///
/// 仅在 Web 平台编译和使用
/// Web 平台不需要原生权限，所有权限检查返回 true
///
/// 返回值语义（P-01:LOCAL:01/02，按触发申请）：true 只表示
/// 「允许继续触发实际采集 API」，不是权限已授予的判定。真实授权/拒绝
/// 由浏览器在 Geolocation/MediaDevices 调用时当场询问并返回；浏览器
/// 层的拒绝（含用户此前永久拒绝）会在采集 API 处失败，调用方必须按
/// 失败处理，不得把本函数的 true 当作免责放行。
///
/// 注意：此文件中的 `kIsWeb` 检查属于防御性双重保护模式。
/// 主要的平台隔离由 `permission.dart` 中的条件导出
/// (`export ... if (dart.library.js) ...`) 在编译期完成。
/// 此处的运行时 `kIsWeb` 检查作为二次保障，防止条件导出被绕过
/// （例如通过直接 import 此文件），确保不会在错误平台上执行。
library;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 申请定位权限
/// Web 平台：定位通过浏览器 API 处理，返回 true
Future<bool> requestLocationPermission() async {
  if (!kIsWeb) {
    throw UnsupportedError('requestLocationPermission_web 只能在 Web 平台使用');
  }
  // Web 平台的定位权限通过浏览器 Geolocation API 处理
  // 这里返回 true，实际权限由浏览器在运行时请求
  return true;
}

/// 申请照片/存储权限
/// Web 平台：不需要原生权限，返回 true
Future<bool> requestPhotoPermission() async {
  if (!kIsWeb) {
    throw UnsupportedError('requestPhotoPermission_web 只能在 Web 平台使用');
  }
  // Web 平台不需要照片权限
  return true;
}

/// 申请相机权限
/// Web 平台：相机权限由浏览器在运行时处理，返回 true
Future<bool> requestCameraPermission() async {
  if (!kIsWeb) {
    throw UnsupportedError('requestCameraPermission_web 只能在 Web 平台使用');
  }
  // Web 平台的相机权限通过浏览器 MediaDevices API 处理
  // 这里返回 true，实际权限由浏览器在运行时请求
  return true;
}
