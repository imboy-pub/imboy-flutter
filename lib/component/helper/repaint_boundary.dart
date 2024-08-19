import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class RepaintBoundaryHelper {
  FutureOr<Uint8List?> image(BuildContext ctx, GlobalKey boundaryKey) async {
    RenderRepaintBoundary? boundary = boundaryKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary?;

    final dpr = View.of(ctx).devicePixelRatio; // 获取当前设备的像素比
    final image = await boundary!.toImage(pixelRatio: dpr);
    // 将image转化成byte
    final byteData = await image.toByteData(format: ImageByteFormat.png);

    bool permission = true;
    if (Platform.isIOS || Platform.isAndroid) {
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
      BuildContext ctx, GlobalKey boundaryKey, String name) async {
    final img = await image(ctx, boundaryKey);
    return await ImageGallerySaver.saveImage(
      img!,
      quality: 72,
      name: name,
      isReturnImagePathOfIOS: true,
    );
  }
}
