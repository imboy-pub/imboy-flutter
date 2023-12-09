import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_crop/image_crop.dart';
import 'package:imboy/store/provider/attachment_provider.dart';

// ignore: must_be_immutable
class CropImageRoute extends StatefulWidget {
  CropImageRoute(
    this.image,
    this.prefix, {
    super.key,
    this.imageScale = 1.0,
    this.filename = "",
  });

  String prefix;
  String filename;
  File image; //原始图片路径

  //图片缩放比例
  double imageScale = 1.0;

  @override
  // ignore: library_private_types_in_public_api
  _CropImageRouteState createState() => _CropImageRouteState();
}

class _CropImageRouteState extends State<CropImageRoute> {
  final cropKey = GlobalKey<CropState>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      height: Get.height,
      width: Get.width,
      color: Colors.black,
      child: Column(
        children: <Widget>[
          Expanded(
            child: SizedBox(
              height: Get.height * 0.8,
              child: Crop.file(
                widget.image,
                key: cropKey,
                aspectRatio: 1.0,
                alwaysShowGrid: true,
              ),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  Get.back();
                },
                child: Text(
                  'button_cancel'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              const Expanded(
                child: SizedBox.shrink(), // 中间用Expanded控件
              ),
              TextButton(
                onPressed: () {
                  _crop(widget.image);
                },
                child: Text(
                  'button_accomplish'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ));
  }

  Future<void> _crop(File originalFile) async {
    final crop = cropKey.currentState;
    final area = crop!.area;
    if (area == null) {
      //裁剪结果为空
    }

    final scale = cropKey.currentState?.scale;

    await ImageCrop.requestPermissions().then((value) async {
      if (value) {
        File sample = await ImageCrop.sampleImage(
          file: originalFile,
          preferredSize: (880 / scale!).round(),
        );
        File croppedFile = await ImageCrop.cropImage(
          file: sample,
          area: crop.area!,
          scale: widget.imageScale,
        );
        // var opt1 = await ImageCrop.getImageOptions(file: sample);
        // debugPrint("> on _crop opt1 ${opt1}");
        // var opt2 = await ImageCrop.getImageOptions(file: croppedFile);
        // debugPrint("> on _crop opt2 ${opt2}");
        upload(croppedFile);
        Future.delayed(const Duration(milliseconds: 200)).then((value) {
          sample.delete();
          croppedFile.delete();
        });
      } else {
        upload(originalFile);
      }
    });
  }

  ///上传头像
  Future<void> upload(File file) async {
    await AttachmentProvider.uploadFile(widget.prefix, file, (
      Map<String, dynamic> resp,
      String uri,
    ) async {
      // debugPrint("> on upload resp ${resp.toString()}");
      Navigator.pop(context, uri); //这里的url在上一页调用的result可以拿到
    }, (Error error) {
      debugPrint("> on upload ${error.toString()}");
    }, name: widget.filename);
  }
}
