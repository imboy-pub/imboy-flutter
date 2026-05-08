/// 权限工具 - Web 平台实现
///
/// 仅在 Web 平台编译和使用
/// Web 平台不需要原生权限，所有权限检查返回 true
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
