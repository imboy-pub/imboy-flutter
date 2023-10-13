import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:xid/xid.dart';

class AttachmentProvider {
  static Future<void> _upload(
    String prefix,
    Map<String, dynamic> data,
    Function callback,
    Function errorCallback, {
    bool process = true,
  }) async {
    int ts = DateTimeHelper.currentTimeMillis();
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);
    String savePath = "/$prefix/${dt.year}${dt.month}/${dt.day}_${dt.hour}/";
    if (prefix == "avatar") {
      savePath = "/$prefix/";
    }

    Map<String, dynamic> authData = AssetsService.authData();
    // data = {'file':MultipartFile.fromFile(path, filename: name)};
    data['output'] = 'json2';
    data['path'] = savePath;
    data['scene'] = UPLOAD_SENCE;

    data['v'] = authData['v'];
    data['a'] = authData['a'];
    data['s'] = authData['s'];
    // debugPrint("> on upload param ${data.toString()}");
    // debugPrint("> on upload param ${(data['file'] as MultipartFile).filename}");
    FormData formData = FormData.fromMap(data);

    debugPrint("> on upload UPLOAD_BASE_URL $UPLOAD_BASE_URL");
    var options = BaseOptions(
      baseUrl: UPLOAD_BASE_URL,
      contentType: 'application/x-www-form-urlencoded',
      connectTimeout: const Duration(milliseconds: 30000),
      sendTimeout: const Duration(milliseconds: 60000),
      receiveTimeout: const Duration(milliseconds: 30000),
    );
    await Dio(options).post(
      "$UPLOAD_BASE_URL/upload",
      data: formData,
      onSendProgress: (int sent, int total) {
        // debugPrint('> on upload $sent / $total');
        if (process) {
          EasyLoading.showProgress(
            sent / total,
            status: 'uploading'.tr,
          );
          if (sent == total) {
            Future.delayed(const Duration(milliseconds: 2000), () {
              EasyLoading.dismiss();
            });
          }
        }
      },
    ).then((response) {
      debugPrint("> on upload response ${response.toString()}");
      Map<String, dynamic> resp = json.decode(response.data);
      callback(resp, AssetsService.viewUrl(resp['data']['url']).toString());
    }).catchError((e) {
      debugPrint("> on upload err ${e.toString()}");
      errorCallback(e);
    });
  }

  static Future<dynamic> preUpload(
      String prefix, Map<String, dynamic> data) async {
    int ts = DateTimeHelper.currentTimeMillis();
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);
    String savePath = "/$prefix/${dt.year}${dt.month}/${dt.day}_${dt.hour}/";

    Map<String, dynamic> authData = AssetsService.authData();
    // data = {'file':MultipartFile.fromFile(path, filename: name)};
    data['md5'] = data['md5'];
    data['output'] = 'json2';
    data['path'] = savePath;
    data['scene'] = UPLOAD_SENCE;
    data['s'] = authData['s'];
    data['v'] = authData['v'];
    data['a'] = authData['a'];
    var options = BaseOptions(
      baseUrl: UPLOAD_BASE_URL,
      contentType: 'application/x-www-form-urlencoded',
      connectTimeout: const Duration(milliseconds: 30000),
      sendTimeout: const Duration(milliseconds: 60000),
      receiveTimeout: const Duration(milliseconds: 30000),
    );
    return Dio(options).get(
      "$UPLOAD_BASE_URL/upload",
      queryParameters: data,
    );
  }

  /// 上传视频
  static Future<void> uploadVideo(
    String prefix,
    AssetEntity entity,
    Function callback,
    Function errorCallback,
  ) async {
    int quality = 68;
    int width = 800;
    int height = 0;
    if (entity.width < width) {
      width = entity.width;
      height = entity.height;
    } else {
      height = (entity.height / entity.width * width).toInt();
    }
    File? file = await entity.file;
    String path = file!.path;

    String ext = path.substring(path.lastIndexOf(".") + 1, path.length);
    bool uploadOriginalImage = false;
    // debugPrint("> on uploadOriginalImage: $uploadOriginalImage");
    String name = "${Xid().toString()}.$ext";
    if (entity.type == AssetType.video) {
      String? thumbUri;
      String? videoUri;
      // 上传缩略图
      File thumbnailFile = await VideoCompress.getFileThumbnail(
        path,
        quality: quality, // default(100)
        position: -1, // default(-1)
      );
      // debugPrint("> on upload video ${thumbnailFile.path}");
      String thumbPath = thumbnailFile.path;
      var thumbName =
          thumbPath.substring(thumbPath.lastIndexOf("/") + 1, thumbPath.length);
      Map<String, dynamic> data = {
        'file': await MultipartFile.fromFile(thumbPath, filename: thumbName),
      };
      await _upload(prefix, data, (Map<String, dynamic> resp, String imgUrl) {
        thumbUri = imgUrl;
      }, errorCallback, process: false);
      // end 上传缩略图

      MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.Res640x480Quality,
        deleteOrigin: true,
      );
      File videoFile = mediaInfo!.file!;
      String md5 = sha1.convert(videoFile.readAsBytesSync()).toString();
      Map<String, dynamic> preData = {
        'md5': md5,
      };
      await preUpload(prefix, preData).then((response) async {
        Map<String, dynamic> responseData = json.decode(response.data);
        String status = responseData['status'] ?? '';
        if (status == 'ok') {
          videoUri =
              AssetsService.viewUrl(responseData['data']['url']).toString();
        } else {
          Map<String, dynamic> data = {
            'file':
                await MultipartFile.fromFile(videoFile.path, filename: name),
          };
          await _upload(prefix, data, (
            Map<String, dynamic> resp,
            String uri,
          ) {
            String status = resp['status'] ?? '';
            if (status == 'ok') {
              videoUri = uri;
            }
          }, errorCallback);
        }
      }).catchError((e) {
        errorCallback(e);
      });
      EntityImage thumb = EntityImage(
        md5: md5,
        name: thumbName,
        uri: thumbUri!,
        size: (await thumbnailFile.readAsBytes()).length,
        width: width,
        height: height,
      );
      EntityVideo video = EntityVideo(
        md5: md5,
        name: name,
        uri: videoUri!,
        // unit Bytes
        filesize: mediaInfo.filesize,
        duration: mediaInfo.duration,
        author: mediaInfo.author,
        width: mediaInfo.width!,
        height: mediaInfo.height!,
      );

      await callback({
        'thumb': thumb,
        'video': video,
      }, '');
      await VideoCompress.deleteAllCache();

      // EntityImage thumb = EntityImage(
      //   name: name,
      //   uri: thumbUri,
      //   size: await thumbnailFile.length(),
      //   width: thumbnailFile.
      // );
    } else if (entity.type == AssetType.image && uploadOriginalImage == false) {
      // 压缩上传图片
      final Uint8List? thumbData = await entity.thumbnailDataWithSize(
        ThumbnailSize(
          width,
          height,
        ),
        quality: quality,
      );
      Map<String, dynamic> preData = {
        'md5': sha1.convert(thumbData!),
      };
      await preUpload(prefix, preData).then((response) async {
        Map<String, dynamic> responseData = json.decode(response.data);
        String status = responseData['status'] ?? '';
        if (status == 'ok') {
          callback(responseData,
              AssetsService.viewUrl(responseData['data']['url']).toString());
        } else {
          Map<String, dynamic> data = {
            'file': MultipartFile.fromBytes(thumbData, filename: name),
          };

          await _upload(prefix, data, callback, errorCallback);
        }
      }).catchError((e) {
        debugPrint("> on preUpload catchError ${e.toString()}");
        errorCallback(e);
      });
    } else if (entity.type == AssetType.image && uploadOriginalImage == true) {
      // 不压缩上传
      final Uint8List? thumbData = await entity.originBytes;
      Map<String, dynamic> preData = {
        'md5': sha1.convert(thumbData!),
      };
      await preUpload(prefix, preData).then((response) async {
        Map<String, dynamic> responseData = json.decode(response.data);
        String status = responseData['status'] ?? '';
        if (status == 'ok') {
          callback(responseData,
              AssetsService.viewUrl(responseData['data']['url']).toString());
        } else {
          Map<String, dynamic> data = {
            'file': await MultipartFile.fromFile(path, filename: name),
          };
          await _upload(prefix, data, callback, errorCallback);
        }
      }).catchError((e) {
        debugPrint("> on preUpload catchError ${e.toString()}");
        errorCallback(e);
      });
    }
  }

  static Future<void> uploadFile(
      String prefix, var file, Function callback, Function errorCallback,
      {String name = "", bool process = true}) async {
    String path = "";
    if (file is PlatformFile) {
      path = file.path!;
    } else if (file is File) {
      path = file.path;
    } else {
      throw Exception("不支持的文件文件类型".tr);
    }
    String ext = path.substring(path.lastIndexOf(".") + 1, path.length);
    if (name == "") {
      name = "${Xid().toString()}.$ext";
    } else {
      name = "$name.$ext";
    }

    Map<String, dynamic> data = {
      'file': await MultipartFile.fromFile(path, filename: name),
    };
    // debugPrint("> on uploadFile path $path, name: $name, ext: $ext");
    await _upload(prefix, data, callback, errorCallback, process: process);
  }
}
