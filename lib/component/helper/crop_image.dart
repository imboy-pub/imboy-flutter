import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_crop/image_crop.dart';
import 'package:imboy/store/provider/attachment_provider.dart';

class CropImageRoute extends StatefulWidget {
  CropImageRoute(
    this.image,
    this.prefix, {
    this.preferredSize = 400,
    this.filename = "",
  });
  String prefix;
  String filename;
  File image; //原始图片路径
  int preferredSize = 400;

  @override
  _CropImageRouteState createState() => new _CropImageRouteState();
}

class _CropImageRouteState extends State<CropImageRoute> {
  late double baseLeft; //图片左上角的x坐标
  late double baseTop; //图片左上角的y坐标
  late double imageWidth; //图片宽度，缩放后会变化
  late double imageScale = 1; //图片缩放比例
  late Image imageView;

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
            child: Container(
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: SizedBox.shrink(), // 中间用Expanded控件
              ),
              TextButton(
                onPressed: () {
                  _crop(widget.image);
                },
                child: Text(
                  'button_accomplish'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
      print('裁剪不成功');
    }

    await ImageCrop.requestPermissions().then((value) async {
      if (value) {
        final sample = await ImageCrop.sampleImage(
          file: originalFile,
          preferredSize: widget.preferredSize,
        );
        final croppedFile = await ImageCrop.cropImage(
          file: sample,
          area: crop.area!,
        );

        upload(croppedFile);
        Future.delayed(Duration(milliseconds: 200)).then((value) {
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
      debugPrint(">>> on upload uri ${uri}");
      // debugPrint(">>> on upload resp ${resp.toString()}");
      Navigator.pop(context, uri); //这里的url在上一页调用的result可以拿到
    }, (DioError error) {
      debugPrint(">>> on upload ${error.toString()}");
    }, name: widget.filename);
  }
}
