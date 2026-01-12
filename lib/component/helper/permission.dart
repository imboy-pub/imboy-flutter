import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 申请定位权限
/// 授予定位权限返回true， 否则返回false
Future<bool> requestLocationPermission() async {
  if (Platform.isMacOS) {
    return false;
  }
  bool isEnabled = await Permission.location.serviceStatus.isEnabled;
  bool isEnabled2 = await Permission.locationWhenInUse.serviceStatus.isEnabled;
  debugPrint("getLocation location.serviceStatus $isEnabled");
  if (isEnabled == false && isEnabled2 == false) {
    // "您还没有打开位置信息服务"
    EasyLoading.showInfo(t.notTurnedLocationService);
    // openAppSettings();
    return false;
  }
  //获取当前的权限
  var status = await Permission.location.status;
  if (status == PermissionStatus.granted) {
    //已经授权
    return true;
  } else {
    //未授权则发起一次申请
    status = await Permission.location.request();
    if (status == PermissionStatus.granted) {
      return true;
    } else {
      return false;
    }
  }
}

/// 申请照片/存储权限
/// 授予权限返回true, 否则返回false
Future<bool> requestPhotoPermission() async {
  if (Platform.isMacOS) {
    // macOS 用 permission_handler
    final status = await Permission.photos.request();
    if (status.isGranted) {
      return true;
    } else {
      EasyLoading.showInfo(t.noPermission);
      return false;
    }
  }
  // else {
  //   try {
  //     final PermissionState ps = await PhotoManager.requestPermissionExtend();
  //     if (ps == PermissionState.authorized || ps == PermissionState.limited) {
  //       return true;
  //     } else {
  //       EasyLoading.showInfo(t.noPermission);
  //       return false;
  //     }
  //   } catch (e, s) {
  //     debugPrint("requestPhotoPermission error: $e, stack: $s");
  //     EasyLoading.showInfo(t.permissionAcquisitionFailed);
  //     return false;
  //   }
  // }
  try {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps == PermissionState.authorized || ps == PermissionState.limited) {
      return true;
    } else {
      // 权限被拒绝，提示用户
      EasyLoading.showInfo(t.noPermission);
      return false;
    }
  } catch (e, s) {
    debugPrint("requestPhotoPermission error: $e, stack: $s");
    EasyLoading.showInfo(t.permissionAcquisitionFailed);
    return false;
  }
}

/// 申请相机权限
/// 授予权限返回true, 否则返回false
Future<bool> requestCameraPermission() async {
  try {
    var status = await Permission.camera.status;
    if (status == PermissionStatus.granted) {
      return true;
    } else {
      status = await Permission.camera.request();
      if (status == PermissionStatus.granted) {
        return true;
      } else {
        EasyLoading.showInfo(t.noPermission);
        return false;
      }
    }
  } catch (e) {
    debugPrint("requestCameraPermission error: $e");
    EasyLoading.showInfo(t.permissionAcquisitionFailed);
    return false;
  }
}