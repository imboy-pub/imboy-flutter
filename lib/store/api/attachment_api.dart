import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:xid/xid.dart';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/i18n/strings.g.dart';

class AttachmentApi {
  static Future<void> _upload(
    String prefix,
    Map<String, dynamic> data,
    Function callback,
    Function errorCallback, {
    bool process = true,
  }) async {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    );
    String savePath = "/$prefix/${dt.year}${dt.month}/${dt.day}_${dt.hour}/";
    if (prefix == "avatar") {
      savePath = "/$prefix/";
    }

    Map<String, dynamic> authData = AssetsService.authData();
    // data = {'file':MultipartFile.fromFile(path, filename: name)};
    data['output'] = 'json2';
    data['path'] = savePath;
    data['scene'] = Env.uploadScene;

    data['v'] = authData['v'];
    data['a'] = authData['a'];
    data['s'] = authData['s'];
    // 安全日志：只输出文件名，不输出完整的认证参数
    debugPrint(
      "> on upload filename: ${(data['file'] as MultipartFile).filename}",
    );
    FormData formData = FormData.fromMap(data);
    String baseUrl = Env.uploadUrl;
    if (strEmpty(baseUrl)) {
      await AppInitializer.initConfig();
      baseUrl = StorageService.to.getString(Keys.uploadUrl);
    }
    if (strEmpty(baseUrl)) {
      debugPrint("上传失败: uploadUrl 未配置，请检查后端 initConfig 接口是否返回 upload_url");
      errorCallback(Exception('uploadUrl 未配置'));
      return;
    }
    debugPrint("> on upload URL configured");
    var options = BaseOptions(
      baseUrl: baseUrl,
      contentType: 'application/x-www-form-urlencoded',
      connectTimeout: const Duration(milliseconds: 30000),
      sendTimeout: const Duration(milliseconds: 60000),
      receiveTimeout: const Duration(milliseconds: 30000),
    );
    await Dio(options)
        .post<dynamic>(
          "$baseUrl/upload",
          data: formData,
          onSendProgress: (int sent, int total) {
            // debugPrint('> on upload $sent / $total');
            if (process) {
              EasyLoading.showProgress(sent / total, status: t.uploading);
              if (sent == total) {
                Future<dynamic>.delayed(const Duration(milliseconds: 2000), () {
                  EasyLoading.dismiss();
                });
              }
            }
          },
        )
        .then((response) {
          // 安全日志：不输出完整响应数据，可能包含敏感信息
          debugPrint(
            "> on upload completed with status ${response.statusCode}",
          );
          Map<String, dynamic> resp = json.decode(response.data as String) as Map<String, dynamic>;
          callback(resp, AssetsService.viewUrl(resp['data']['url'] as String).toString());
        })
        .catchError((Object e) {
          debugPrint("> on upload error ${e.toString()}");
          errorCallback(e);
        });
  }

  static Future<dynamic> preUpload(
    String prefix,
    Map<String, dynamic> data,
  ) async {
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    );
    String savePath = "/$prefix/${dt.year}${dt.month}/${dt.day}_${dt.hour}/";

    Map<String, dynamic> authData = AssetsService.authData();
    // data = {'file':MultipartFile.fromFile(path, filename: name)};
    data['md5'] = data['md5'];
    data['output'] = 'json2';
    data['path'] = savePath;
    data['scene'] = Env.uploadScene;
    data['s'] = authData['s'];
    data['v'] = authData['v'];
    data['a'] = authData['a'];
    var options = BaseOptions(
      baseUrl: Env.uploadUrl,
      contentType: 'application/x-www-form-urlencoded',
      connectTimeout: const Duration(milliseconds: 30000),
      sendTimeout: const Duration(milliseconds: 60000),
      receiveTimeout: const Duration(milliseconds: 30000),
    );
    return Dio(
      options,
    ).get<dynamic>("${Env.uploadUrl}/upload", queryParameters: data);
  }

  /// 上传视频
  static Future<void> uploadVideo(
    String prefix,
    AssetEntity entity,
    Function callback,
    Function errorCallback, {
    bool uploadOriginalImage = false,
  }) async {
    int quality = 68;
    int width = 800;
    int height = 0;
    if (entity.width < width) {
      width = entity.width;
      height = entity.height;
    } else {
      height = (entity.height / entity.width * width).toInt();
    }

    // Android 9 兼容性：获取文件路径，处理可能的 null 情况
    File? file = await entity.file;
    if (file == null) {
      debugPrint("❌ uploadVideo: 无法获取文件 entity.file is null");
      debugPrint("   AssetType: ${entity.type}, title: ${entity.title}");
      debugPrint("   尝试使用替代方法获取文件...");

      // 尝试使用 originBytes 作为替代方案
      try {
        if (entity.type == AssetType.image) {
          final Uint8List? bytes = await entity.originBytes;
          if (bytes != null) {
            // 创建临时文件
            final tempDir = await Directory.systemTemp.createTemp();
            final tempFile = File('${tempDir.path}/${Xid().toString()}.jpg');
            await tempFile.writeAsBytes(bytes);
            file = tempFile;
            debugPrint("✅ 使用 originBytes 创建临时文件成功: ${tempFile.path}");
          }
        }
      } catch (e) {
        debugPrint("❌ 替代方法失败: $e");
        errorCallback(Exception(t.attachmentGetFileFailed));
        return;
      }

      if (file == null) {
        errorCallback(Exception(t.attachmentGetFileFailedAndroid9));
        return;
      }
    }

    String path = file.path;

    String ext = path.substring(path.lastIndexOf(".") + 1, path.length);
    // bool uploadOriginalImage = false;
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
      var thumbName = thumbPath.substring(
        thumbPath.lastIndexOf("/") + 1,
        thumbPath.length,
      );

      String thumbMd5 = sha1
          .convert(thumbnailFile.readAsBytesSync())
          .toString();
      Map<String, dynamic> data = {
        'file': await MultipartFile.fromFile(thumbPath, filename: thumbName),
      };
      await _upload(
        prefix,
        data,
        (Map<String, dynamic> resp, String imgUrl) {
          thumbUri = imgUrl;
        },
        errorCallback,
        process: false,
      );
      // end 上传缩略图

      MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.Res640x480Quality,
        deleteOrigin: true,
      );
      File videoFile = mediaInfo!.file!;
      String videoMd5 = sha1.convert(videoFile.readAsBytesSync()).toString();
      Map<String, dynamic> preData = {'md5': videoMd5};
      await preUpload(prefix, preData)
          .then((response) async {
            Map<String, dynamic> responseData = json.decode(response.data as String) as Map<String, dynamic>;
            String status = responseData['status'] as String? ?? '';
            if (status == 'ok') {
              videoUri = AssetsService.viewUrl(
                responseData['data']['url'] as String,
              ).toString();
            } else {
              Map<String, dynamic> data = {
                'file': await MultipartFile.fromFile(
                  videoFile.path,
                  filename: name,
                ),
              };
              await _upload(prefix, data, (
                Map<String, dynamic> resp,
                String uri,
              ) {
                String status = resp['status'] as String? ?? '';
                if (status == 'ok') {
                  videoUri = uri;
                }
              }, errorCallback);
            }
          })
          .catchError((Object e) {
            errorCallback(e);
          });
      EntityImage thumb = EntityImage(
        md5: thumbMd5,
        name: thumbName,
        uri: thumbUri!,
        size: (await thumbnailFile.readAsBytes()).length,
        width: width,
        height: height,
      );
      EntityVideo video = EntityVideo(
        md5: videoMd5,
        name: name,
        uri: videoUri!,
        // unit Bytes
        size: mediaInfo.filesize,
        duration: mediaInfo.duration,
        author: mediaInfo.author,
        width: mediaInfo.width!,
        height: mediaInfo.height!,
      );

      await callback({'thumb': thumb, 'video': video}, '');
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
        ThumbnailSize(width, height),
        quality: quality,
      );

      // Android 9 兼容性：处理 thumbData 为 null 的情况
      if (thumbData == null || thumbData.isEmpty) {
        debugPrint("❌ uploadVideo: thumbnailDataWithSize 返回空数据");
        debugPrint("   尝试使用 originBytes 作为替代...");

        // 尝试使用 originBytes 作为替代
        final Uint8List? originData = await entity.originBytes;
        if (originData != null && originData.isNotEmpty) {
          Map<String, dynamic> preData = {'md5': sha1.convert(originData)};
          await preUpload(prefix, preData)
              .then((response) async {
                Map<String, dynamic> responseData = json.decode(response.data as String) as Map<String, dynamic>;
                String status = responseData['status'] as String? ?? '';
                if (status == 'ok') {
                  callback(
                    responseData,
                    AssetsService.viewUrl(
                      responseData['data']['url'] as String,
                    ).toString(),
                  );
                } else {
                  Map<String, dynamic> data = {
                    'file': MultipartFile.fromBytes(originData, filename: name),
                  };
                  await _upload(prefix, data, callback, errorCallback);
                }
              })
              .catchError((Object e) {
                debugPrint("> on preUpload catchError ${e.toString()}");
                errorCallback(e);
              });
        } else {
          errorCallback(Exception(t.attachmentGetImageDataFailed));
        }
        return;
      }

      Map<String, dynamic> preData = {'md5': sha1.convert(thumbData)};
      await preUpload(prefix, preData)
          .then((response) async {
            Map<String, dynamic> responseData = json.decode(response.data as String) as Map<String, dynamic>;
            String status = responseData['status'] as String? ?? '';
            if (status == 'ok') {
              callback(
                responseData,
                AssetsService.viewUrl(responseData['data']['url'] as String).toString(),
              );
            } else {
              Map<String, dynamic> data = {
                'file': MultipartFile.fromBytes(thumbData, filename: name),
              };

              await _upload(prefix, data, callback, errorCallback);
            }
          })
          .catchError((Object e) {
            debugPrint("> on preUpload catchError ${e.toString()}");
            errorCallback(e);
          });
    } else if (entity.type == AssetType.image && uploadOriginalImage == true) {
      // 不压缩上传
      final Uint8List? thumbData = await entity.originBytes;

      // Android 9 兼容性：处理 originBytes 为 null 的情况
      if (thumbData == null || thumbData.isEmpty) {
        debugPrint("❌ uploadVideo: originBytes 返回空数据");
        errorCallback(Exception(t.attachmentGetOriginalImageFailed));
        return;
      }

      Map<String, dynamic> preData = {'md5': sha1.convert(thumbData)};
      await preUpload(prefix, preData)
          .then((response) async {
            Map<String, dynamic> responseData = json.decode(response.data as String) as Map<String, dynamic>;
            String status = responseData['status'] as String? ?? '';
            if (status == 'ok') {
              callback(
                responseData,
                AssetsService.viewUrl(responseData['data']['url'] as String).toString(),
              );
            } else {
              Map<String, dynamic> data = {
                'file': await MultipartFile.fromFile(path, filename: name),
              };
              await _upload(prefix, data, callback, errorCallback);
            }
          })
          .catchError((Object e) {
            debugPrint("> on preUpload catchError ${e.toString()}");
            errorCallback(e);
          });
    }
  }

  static Future<void> uploadFile(
    String prefix,
    Object file,
    Function callback,
    Function errorCallback, {
    String name = "",
    bool process = true,
  }) async {
    String path = "";
    if (file is PlatformFile) {
      path = file.path!;
    } else if (file is File) {
      path = file.path;
    } else {
      throw Exception(t.unsupportedFileType);
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
    debugPrint(
      "> on uploadFile ${Env.uploadUrl}; path1 $path, name: $name, ext: $ext",
    );
    await _upload(prefix, data, callback, errorCallback, process: process);
  }

  static Future<void> uploadBytes(
    String prefix,
    Uint8List file,
    Function callback,
    Function errorCallback, {
    String path = "",
    bool process = true,
  }) async {
    String ext = path.substring(path.lastIndexOf(".") + 1, path.length);
    ext = ext.isEmpty ? '.png' : ext;
    String name = "${Xid().toString()}$ext";

    Map<String, dynamic> data = {
      'file': MultipartFile.fromBytes(file, filename: name),
    };
    // 安全日志：不输出完整数据，只输出文件信息
    debugPrint("> on uploadBytes name: $name, ext: $ext");
    await _upload(prefix, data, callback, errorCallback, process: process);
  }
}
