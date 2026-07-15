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
///
/// 注意：photo_manager 的 requestPermissionExtend 在部分定制 ROM（如华为
/// Android 9）上可能因 ActivityCompat.requestPermissions 回调链挂起而
/// 永不 resolve，导致整个方法静默卡死。此处先用 permission_handler 做
/// 预检（其权限链在定制 ROM 上更可靠），再对 photo_manager 的调用加超时
/// 兜底——超时不阻断，让后续 picker 自行处理。
Future<bool> requestPhotoPermission() async {
  if (kIsWeb) {
    throw UnsupportedError('requestPhotoPermission_stub 不应在 Web 平台调用');
  }
  if (Platform.isMacOS) {
    // macOS 沙盒 app：照片/文件访问由 entitlements 控制，picker 走 NSOpenPanel 不需运行时权限请求。
    // permission_handler 12 无 macOS 实现（仅 android/ios/web/windows），直接放行让后续 picker 处理。
    return true;
  }

  // Android：先用 permission_handler 预检存储权限（在定制 ROM 上更可靠）
  if (Platform.isAndroid) {
    try {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) {
        // 存储权限已通过 permission_handler 授予，直接放行。
        // 不再调 PhotoManager.requestPermissionExtend——它的原生回调链
        // 在部分 ROM 上会挂起，permission_handler 已足够保证权限就绪。
        return true;
      }
      // permission_handler 未授权，提示用户
      debugPrint(
        '[perm] storage permission denied by permission_handler: $storageStatus',
      );
      AppLoading.showInfo(t.common.noPermission);
      return false;
    } on Exception catch (e) {
      debugPrint('[perm] permission_handler storage request failed: $e');
      // 降级到 photo_manager 路径（见下方）
    }
  }

  try {
    // 对 photo_manager 的调用加超时，防止回调链挂起导致永久静默
    final PermissionState ps = await PhotoManager.requestPermissionExtend()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint(
              '[perm] PhotoManager.requestPermissionExtend timed out, '
              'allowing picker to proceed',
            );
            // 超时时不阻断——picker 自身会再做权限检查
            return PermissionState.authorized;
          },
        );
    if (ps == PermissionState.authorized || ps == PermissionState.limited) {
      return true;
    } else {
      // 权限被拒绝，提示用户
      AppLoading.showInfo(t.common.noPermission);
      return false;
    }
  } on Exception catch (e) {
    debugPrint('[perm] requestPhotoPermission exception: $e');
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
  if (Platform.isMacOS) {
    // macOS 相机访问由系统 TCC 控制，permission_handler 无 macOS 实现；
    // 桌面 pickCamera 已降级为 gallery（见 adapter），此处直接放行。
    return true;
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
