import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

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
  FutureOr<dynamic> savePhoto(
    BuildContext ctx,
    GlobalKey boundaryKey,
    String name,
  ) async {
    final img = await image(ctx, boundaryKey);
    if (img == null) {
      return {"isSuccess": false, "errorMessage": "Failed to capture image"};
    }

    try {
      // 使用 photo_manager 保存到相册
      final asset = await PhotoManager.editor.saveImage(img, filename: name);

      return {"isSuccess": true, "filePath": asset.id};
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("savePhoto error: ${e.runtimeType}");
      return {"isSuccess": false, "errorMessage": t.common.saveFailedRetry};
    }
  }
}
