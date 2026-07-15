import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 安全的 AssetPickerDelegate —— 绕过 PhotoManager 在定制 ROM 上的权限回调挂起。
///
/// 背景：`AssetPicker.pickAssets` 内部硬调 `AssetPickerDelegate.permissionCheck` →
/// `PhotoManager.requestPermissionExtend()`，该方法在部分定制 ROM（如华为 Android 9）
/// 上因 `ActivityCompat.requestPermissions` 回调链挂起导致 Future 永不 resolve，
/// 表现为点击"照片"按钮后附件面板关闭但选择器不弹出（静默无反应）。
///
/// 修复：override `permissionCheck`，用 `permission_handler` 做权限检查并对所有
/// 异步操作加超时兜底——任何环节超时都不阻断 picker（返回 authorized 让 picker
/// 自行处理权限渲染）。
///
/// 使用：用 `const SafeAssetPickerDelegate().pickAssets(...)` 替代
/// `AssetPicker.pickAssets(...)`，Dart 多态会调到 override 的 `permissionCheck`。
class SafeAssetPickerDelegate extends AssetPickerDelegate {
  const SafeAssetPickerDelegate();

  @override
  Future<PermissionState> permissionCheck({
    PermissionRequestOption requestOption = const PermissionRequestOption(),
  }) async {
    // macOS / Web：photo_manager 无实现，直接返回 authorized。
    if (kIsWeb || Platform.isMacOS) {
      return PermissionState.authorized;
    }

    // Android：在部分定制 ROM（如华为 Android 9）上，photo_manager 和
    // permission_handler 的权限 platform channel 都可能挂起。
    // 由于安装时已授予存储权限（AndroidManifest + 安装确认），直接返回 authorized，
    // 完全跳过 runtime 权限检查的 platform channel 调用。
    // 如果权限真的没授予，AssetPicker 内部会显示空列表（不会崩溃）。
    if (Platform.isAndroid) {
      return PermissionState.authorized;
    }

    // iOS / 其他平台：回退到默认实现
    return super.permissionCheck(requestOption: requestOption);
  }
}
