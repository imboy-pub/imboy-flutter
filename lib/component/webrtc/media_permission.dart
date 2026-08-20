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
      // 显式 await：try 内隐式 return future 会让异常落入本地 catch 且
      // 触发 unawaited_return_in_try_block（语义上此处确实想就地消化）
      return await launchUrl(
        Uri.parse(
          'x-apple.systempreferences:com.apple.preference.security?$pane',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
    return await permission_handler.openAppSettings();
  } on Object {
    return false;
  }
}
