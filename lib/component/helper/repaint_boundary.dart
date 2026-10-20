import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dart:typed_data';
import 'dart:ui';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photo_manager/photo_manager.dart';

class RepaintBoundaryHelper {
  FutureOr<Uint8List?> image(BuildContext ctx, GlobalKey boundaryKey) async {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !ctx.mounted) return null;
    final image = await boundary.toImage(
      pixelRatio: View.of(ctx).devicePixelRatio,
    );
    try {
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// 新版 Android 通过 MediaStore 写入，不申请读取相册权限。
  /// iOS 的授权由 photo_manager 原生保存入口处理。
  Future<bool> _requestLegacyWritePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 29) return true;
    return (await Permission.storage.request()).isGranted;
  }

  /// for example:{"isSuccess":true, "filePath":String?}
  ///保存到相册
  ///
  /// 失败提示在**这里**弹，不交给调用方：user / group / channel 三个二维码页
  /// 都只写了 `if (isSuccess) showSuccess(...)`、没有 else，失败时用户点了保存
  /// 什么都不会发生（BUG#87）。收口到这一层，新增第四个调用点也不会再漏。
  FutureOr<dynamic> savePhoto(
    BuildContext ctx,
    GlobalKey boundaryKey,
    String name,
  ) async {
    final Uint8List? img;
    try {
      if (!await _requestLegacyWritePermission()) {
        AppLoading.showError(t.common.storagePermissionNotObtained);
        return {
          "isSuccess": false,
          "errorMessage": t.common.storagePermissionNotObtained,
        };
      }
      if (!ctx.mounted) return {"isSuccess": false};
      img = await image(ctx, boundaryKey);
    } on Exception catch (e) {
      // 截图阶段异常（低内存等）：与保存异常同款反馈，不向上穿透
      // （三个调用方均无 try-catch，穿透=未处理异常）。
      if (kDebugMode) debugPrint("savePhoto image error: ${e.runtimeType}");
      AppLoading.showError(t.common.saveFailedRetry);
      return {"isSuccess": false, "errorMessage": t.common.saveFailedRetry};
    }
    if (img == null) {
      AppLoading.showError(t.common.saveFailedRetry);
      return {"isSuccess": false, "errorMessage": t.common.saveFailedRetry};
    }

    try {
      // 使用 photo_manager 保存到相册
      final asset = await PhotoManager.editor.saveImage(img, filename: name);

      return {"isSuccess": true, "filePath": asset.id};
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("savePhoto error: ${e.runtimeType}");
      AppLoading.showError(t.common.saveFailedRetry);
      return {"isSuccess": false, "errorMessage": t.common.saveFailedRetry};
    }
  }
}
