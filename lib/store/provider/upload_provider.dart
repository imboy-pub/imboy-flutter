import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart' as Getx;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:imboy/helper/func.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:xid/xid.dart';

class UploadProvider {
  /// 上传图片
  Future<void> uploadImg(
    String prefix,
    Function callback,
    Function errorCallback,
    AssetEntity entity,
  ) async {
    var options = BaseOptions(
      baseUrl: UPLOAD_BASE_URL,
      contentType: 'application/x-www-form-urlencoded',
      connectTimeout: 30000,
      sendTimeout: 60000,
      receiveTimeout: 30000,
    );
    File? file = await entity.file;

    Dio _dio = Dio(options);
    String path = file!.path;
    String ext = path.substring(path.lastIndexOf(".") + 1, path.length);
    String name = "${Xid().toString()}.${ext}";
    int ts = DateTimeHelper.currentTimeMillis();
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);
    String savePath = "/${prefix}/${dt.year}${dt.month}/${dt.day}_${dt.hour}/";
    String v = (Random()).nextInt(999999).toString();
    String authToken = generateMD5(UP_AUTH_KEY + v).substring(8, 24);
    FormData formdata = FormData.fromMap({
      "file": await MultipartFile.fromFile(path, filename: name),
      "output": "json2",
      "path": savePath,
      "scene": UPLOAD_SENCE,
      "s": UPLOAD_SENCE,
      "v": v,
      "a": authToken,
    });

    await _dio
        .post(
      "${UPLOAD_BASE_URL}/upload",
      // "upload",
      data: formdata,
    )
        .then((response) {
      debugPrint(">>> on upload response ${response.toString()}");
      Map<String, dynamic> responseData = json.decode(response.data);

      String url = responseData["data"]["url"] +
          "?s=${UPLOAD_SENCE}&a=${authToken}&v=${v}";
      if (ext != "gif") {
        double w = Getx.Get.width * 2;
        url += "&width=${w.toInt()}";
      }
      callback(responseData, url);
    }).catchError((e) {
      debugPrint(">>> on upload err ${e.toString()}");
      errorCallback(e);
    });
  }
}
