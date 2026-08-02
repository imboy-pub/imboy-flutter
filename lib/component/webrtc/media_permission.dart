import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:url_launcher/url_launcher.dart';

/// 需要用户在系统设置中恢复的媒体权限。
enum MediaPermissionTarget { microphone, camera }

/// 打开当前平台对应的媒体权限设置。
///
/// permission_handler 没有 macOS TCC 实现，因此 macOS 直接跳转到系统
/// “隐私与安全性”对应面板；iOS/Android 使用应用详情设置页。
Future<bool> openMediaPermissionSettings(MediaPermissionTarget target) async {
  try {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final pane = target == MediaPermissionTarget.camera
          ? 'Privacy_Camera'
          : 'Privacy_Microphone';
      return launchUrl(
        Uri.parse(
          'x-apple.systempreferences:com.apple.preference.security?$pane',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
    return permission_handler.openAppSettings();
  } on Object {
    return false;
  }
}
