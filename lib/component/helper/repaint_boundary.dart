import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class RepaintBoundaryHelper {
  FutureOr<Uint8List?> image(BuildContext ctx, GlobalKey boundaryKey) async {
    RenderRepaintBoundary? boundary =
        boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary?;

    final dpr = View.of(ctx).devicePixelRatio; // 获取当前设备的像素比
    final image = await boundary!.toImage(pixelRatio: dpr);
    // 将image转化成byte
    final byteData = await image.toByteData(format: ImageByteFormat.png);

    bool permission = true;
    // Web 平台不需要存储权限
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      permission = await Permission.storage.isGranted;
    }
    if (permission) {
      return byteData!.buffer.asUint8List();
    } else {
      await openAppSettings();
      return null;
    }
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
      img = await image(ctx, boundaryKey);
    } on Exception catch (e) {
      // 截图阶段异常（低内存等）：与保存异常同款反馈，不向上穿透
      // （三个调用方均无 try-catch，穿透=未处理异常）。
      if (kDebugMode) debugPrint("savePhoto image error: ${e.runtimeType}");
      AppLoading.showError(t.common.saveFailedRetry);
      return {"isSuccess": false, "errorMessage": t.common.saveFailedRetry};
    }
    if (img == null) {
      // image() 返回 null 只有一种情况：相册权限未授予，且已跳去系统设置。
      // 不再弹 toast —— 用户此刻已经在设置页，弹了也看不见。
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
