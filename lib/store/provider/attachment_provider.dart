import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
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
    Function errorCallback,
  ) async {
    int ts = DateTimeHelper.currentTimeMillis();
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);
    String savePath = "/${prefix}/${dt.year}${dt.month}/${dt.day}_${dt.hour}/";
    String v = (Random()).nextInt(999999).toString();
    String authToken = generateMD5(UP_AUTH_KEY + v).substring(8, 24);

    // data = {'file':MultipartFile.fromFile(path, filename: name)};
    data['output'] = 'json2';
    data['path'] = savePath;
    data['scene'] = UPLOAD_SENCE;
    data['s'] = UPLOAD_SENCE;
    data['v'] = v;
    data['a'] = authToken;
    FormData formdata = FormData.fromMap(data);

    var options = BaseOptions(
      baseUrl: UPLOAD_BASE_URL,
      contentType: 'application/x-www-form-urlencoded',
      connectTimeout: 30000,
      sendTimeout: 60000,
      receiveTimeout: 30000,
    );
    await Dio(options).post(
      "${UPLOAD_BASE_URL}/upload",
      data: formdata,
      onSendProgress: (int sent, int total) {
        debugPrint('>>> on upload $sent / $total');
      },
    ).then((response) {
      debugPrint(">>> on upload response ${response.toString()}");
      Map<String, dynamic> responseData = json.decode(response.data);

      String url = responseData["data"]["url"] +
          "?s=${UPLOAD_SENCE}&a=${authToken}&v=${v}";
      callback(responseData, url);
    }).catchError((e) {
      debugPrint(">>> on upload err ${e.toString()}");
      errorCallback(e);
    });
  }

  static Future<dynamic> preUpload(
      String prefix, Map<String, dynamic> data) async {
    int ts = DateTimeHelper.currentTimeMillis();
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);
    String savePath = "/${prefix}/${dt.year}${dt.month}/${dt.day}_${dt.hour}/";
    String v = (Random()).nextInt(999999).toString();
    String authToken = generateMD5(UP_AUTH_KEY + v).substring(8, 24);

    // data = {'file':MultipartFile.fromFile(path, filename: name)};
    data['md5'] = data['md5'];
    data['output'] = 'json2';
    data['path'] = savePath;
    data['scene'] = UPLOAD_SENCE;
    data['s'] = UPLOAD_SENCE;
    data['v'] = v;
    data['a'] = authToken;
    // FormData formdata = FormData.fromMap(data);

    debugPrint(">>> on preUpload request ${data.toString()}");
    var options = BaseOptions(
      baseUrl: UPLOAD_BASE_URL,
      contentType: 'application/x-www-form-urlencoded',
      connectTimeout: 30000,
      sendTimeout: 60000,
      receiveTimeout: 30000,
    );
    return Dio(options).get(
      "${UPLOAD_BASE_URL}/upload",
      queryParameters: data,
    );
  }

  /// 上传图片
  static Future<void> uploadImg(
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
    debugPrint(">>> on uploadOriginalImage: ${uploadOriginalImage}");
    String name = "${Xid().toString()}.${ext}";
    if (entity.type == AssetType.video) {
      String? thumbUri;
      String? videoUri;
      // 上传缩略图
      File thumbnailFile = await VideoCompress.getFileThumbnail(
        path,
        quality: quality, // default(100)
        position: -1, // default(-1)
      );
      debugPrint(">>> on upload video ${thumbnailFile.path}");
      String thumbPath = thumbnailFile.path;
      var thumbName =
          thumbPath.substring(thumbPath.lastIndexOf("/") + 1, thumbPath.length);
      Map<String, dynamic> data = {
        'file': await MultipartFile.fromFile(thumbPath, filename: thumbName),
      };
      await _upload(prefix, data, (Map<String, dynamic> _resp, String imgUrl) {
        thumbUri = imgUrl;
      }, errorCallback);
      // end 上传缩略图

      MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: true,
      );
      File videoFile = mediaInfo!.file!;
      Map<String, dynamic> predata = {
        'md5': sha1.convert(await videoFile.readAsBytesSync()),
      };
      await preUpload(prefix, predata).then((response) async {
        Map<String, dynamic> responseData = json.decode(response.data);
        String status = responseData['status'] ?? '';
        if (status == 'ok') {
          String v = (Random()).nextInt(999999).toString();
          String authToken = generateMD5(UP_AUTH_KEY + v).substring(8, 24);
          videoUri = responseData["data"]["url"] +
              "?s=${UPLOAD_SENCE}&a=${authToken}&v=${v}";
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
        name: thumbName,
        uri: thumbUri!,
        size: (await thumbnailFile.readAsBytes()).length,
        width: width,
        height: height,
      );
      EntityVideo video = EntityVideo(
        name: name,
        uri: videoUri!,
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

      // EntityImage thumb = new EntityImage(
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
      Map<String, dynamic> predata = {
        'md5': sha1.convert(thumbData!),
      };
      await preUpload(prefix, predata).then((response) async {
        Map<String, dynamic> responseData = json.decode(response.data);
        String status = responseData['status'] ?? '';
        if (status == 'ok') {
          String v = (Random()).nextInt(999999).toString();
          String authToken = generateMD5(UP_AUTH_KEY + v).substring(8, 24);
          String url = responseData["data"]["url"] +
              "?s=${UPLOAD_SENCE}&a=${authToken}&v=${v}";
          callback(responseData, url);
        } else {
          Map<String, dynamic> data = {
            'file': await MultipartFile.fromBytes(thumbData, filename: name),
          };

          await _upload(prefix, data, callback, errorCallback);
        }
      }).catchError((e) {
        debugPrint(">>> on preUpload catchError ${e.toString()}");
        errorCallback(e);
      });
    } else if (entity.type == AssetType.image && uploadOriginalImage == true) {
      // 不压缩上传
      final Uint8List? thumbData = await entity.originBytes;
      Map<String, dynamic> predata = {
        'md5': sha1.convert(thumbData!),
      };
      await preUpload(prefix, predata).then((response) async {
        Map<String, dynamic> responseData = json.decode(response.data);
        String status = responseData['status'] ?? '';
        debugPrint(">>> on preUpload response ${response.toString()}");
        if (status == 'ok') {
          String v = (Random()).nextInt(999999).toString();
          String authToken = generateMD5(UP_AUTH_KEY + v).substring(8, 24);
          String url = responseData["data"]["url"] +
              "?s=${UPLOAD_SENCE}&a=${authToken}&v=${v}";
          callback(responseData, url);
        } else {
          Map<String, dynamic> data = {
            'file': await MultipartFile.fromFile(path, filename: name),
          };
          await _upload(prefix, data, callback, errorCallback);
        }
      }).catchError((e) {
        debugPrint(">>> on preUpload catchError ${e.toString()}");
        errorCallback(e);
      });
    }
  }

  static Future<void> uploadFile(
    String prefix,
    PlatformFile file,
    Function callback,
    Function errorCallback,
  ) async {
    String path = file.path!;
    String ext = path.substring(path.lastIndexOf(".") + 1, path.length);
    String name = "${Xid().toString()}.${ext}";

    Map<String, dynamic> data = {
      'file': await MultipartFile.fromFile(path, filename: name),
    };
    await _upload(prefix, data, callback, errorCallback);
  }
}
