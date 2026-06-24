/// 权限工具 - Web 平台存根
///
/// 用于非 Web 平台（iOS、Android、macOS 等）
/// 避免导入 Web 特定的依赖导致编译错误
///
/// 注意：此文件中的 `kIsWeb` 检查属于防御性双重保护模式。
/// 主要的平台隔离由 `permission.dart` 中的条件导出
/// (`export ... if (dart.library.js) ...`) 在编译期完成。
/// 此处的运行时 `kIsWeb` 检查作为二次保障，防止条件导出被绕过
/// （例如通过直接 import 此文件），确保不会在错误平台上执行。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 申请定位权限
/// 授予定位权限返回true， 否则返回false
Future<bool> requestLocationPermission() async {
  if (kIsWeb) {
    throw UnsupportedError('requestLocationPermission_stub 不应在 Web 平台调用');
  }
  if (Platform.isMacOS) {
    return false;
  }

  // 【修复 Android 9 位置服务检测问题】
  // 先检查权限，再检查服务状态
  // 获取当前的权限
  var status = await Permission.location.status;
  if (kDebugMode) {}

  if (status == PermissionStatus.granted) {
    // 已经授权，检查位置服务是否开启
    bool isEnabled = await Permission.location.serviceStatus.isEnabled;
    if (kDebugMode) {}

    if (!isEnabled) {
      // 权限已授予，但位置服务未开启
      AppLoading.showInfo(t.common.notTurnedLocationService);
      // 引导用户开启位置服务
      // openAppSettings(); // 可选：打开设置页面
      return false;
    }
    return true;
  } else {
    // 未授权则发起一次申请
    if (kDebugMode) {}
    status = await Permission.location.request();
    if (kDebugMode) {}

    if (status == PermissionStatus.granted) {
      // 权限授予成功，检查位置服务
      bool isEnabled = await Permission.location.serviceStatus.isEnabled;
      if (kDebugMode) {}

      if (!isEnabled) {
        AppLoading.showInfo(t.common.notTurnedLocationService);
        return false;
      }
      return true;
    } else if (status == PermissionStatus.permanentlyDenied) {
      // 用户永久拒绝，提示去设置
      AppLoading.showInfo(t.common.noPermission);
      // openAppSettings(); // 可选：引导用户打开设置
      return false;
    } else {
      // 用户拒绝
      AppLoading.showInfo(t.common.noPermission);
      return false;
    }
  }
}

/// 申请照片/存储权限
/// 授予权限返回true, 否则返回false
Future<bool> requestPhotoPermission() async {
  if (kIsWeb) {
    throw UnsupportedError('requestPhotoPermission_stub 不应在 Web 平台调用');
  }
  if (Platform.isMacOS) {
    // macOS 用 permission_handler
    final status = await Permission.photos.request();
    if (status.isGranted) {
      return true;
    } else {
      AppLoading.showInfo(t.common.noPermission);
      return false;
    }
  }
  try {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps == PermissionState.authorized || ps == PermissionState.limited) {
      return true;
    } else {
      // 权限被拒绝，提示用户
      AppLoading.showInfo(t.common.noPermission);
      return false;
    }
  } on Exception {
    if (kDebugMode) {}
    AppLoading.showInfo(t.common.permissionAcquisitionFailed);
    return false;
  }
}

/// 申请相机权限
/// 授予权限返回true, 否则返回false
Future<bool> requestCameraPermission() async {
  if (kIsWeb) {
    throw UnsupportedError('requestCameraPermission_stub 不应在 Web 平台调用');
  }
  try {
    var status = await Permission.camera.status;
    if (status == PermissionStatus.granted) {
      return true;
    } else {
      status = await Permission.camera.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        AppLoading.showInfo(t.common.noPermission);
        return false;
      }
    }
  } on Exception {
    if (kDebugMode) {}
    AppLoading.showInfo(t.common.permissionAcquisitionFailed);
    return false;
  }
}
