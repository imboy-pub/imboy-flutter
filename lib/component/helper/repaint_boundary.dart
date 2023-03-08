import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class RepaintBoundaryHelper {
  //保存到相册
  void savePhoto(GlobalKey boundaryKey, String filename) async {
    RenderRepaintBoundary? boundary = boundaryKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary?;

    double dpr = ui.window.devicePixelRatio; // 获取当前设备的像素比
    var image = await boundary!.toImage(pixelRatio: dpr);
    // 将image转化成byte
    ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);

    bool permition = await Permission.storage.isGranted;
    // debugPrint(">>> on storage permition $permition; filename $filename");
    if (permition) {
      Uint8List images = byteData!.buffer.asUint8List();
      await ImageGallerySaver.saveImage(
        images,
        quality: 72,
        name: filename,
      );
      EasyLoading.showSuccess("保存成功".tr);
      Get.back();
    } else {
      await openAppSettings();
    }
  }
}
