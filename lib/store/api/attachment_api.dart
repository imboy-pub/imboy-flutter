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
import 'package:mime/mime.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/i18n/strings.g.dart';

class AttachmentApi {
  /// 单文件直传上限：100MB。
  static const int maxUploadBytes = 100 * 1024 * 1024;

  /// PUT 直传重试上限。
  static const int _putMaxAttempts = 3;

  /// 允许直传的 MIME 前缀白名单（image/video/audio/部分文档）。
  static const List<String> _allowedMimePrefixes = <String>[
    'image/',
    'video/',
    'audio/',
    'text/plain',
    'application/pdf',
    'application/zip',
    'application/msword',
    'application/vnd.openxmlformats-officedocument', // docx/xlsx/pptx
    'application/vnd.ms-excel',
    'application/vnd.ms-powerpoint',
    'application/octet-stream',
  ];

  static bool _isAllowedMime(String mime) {
    final String m = mime.toLowerCase();
    for (final String p in _allowedMimePrefixes) {
      if (m.startsWith(p)) return true;
    }
    return false;
  }

  /// 上传前置校验（纯函数，系统边界）。返回错误消息，校验通过返回 null。
  @visibleForTesting
  static String? validateUpload(int size, String mime) {
    if (size <= 0) {
      return 'uploadViaPresign: 文件内容为空';
    }
    if (size > maxUploadBytes) {
      return 'uploadViaPresign: 文件超过上限 '
          '${(size / 1024 / 1024).toStringAsFixed(1)}MB > 100MB';
    }
    if (!_isAllowedMime(mime)) {
      return 'uploadViaPresign: 不支持的文件类型 $mime';
    }
    return null;
  }

  /// Garage S3 presign 直传：presign → PUT 直传 → confirm 落库，返回 object_key。
  ///
  /// 链路：
  /// 1. 前置校验文件大小（≤[maxUploadBytes]）与 MIME 白名单，不符立即抛错；
  /// 2. `GET /v1/attachment/presign` 取 {put_url, object_key}（JWT，走 HttpClient）；
  /// 3. 裸 Dio PUT 直传 Garage（不注 JWT；进度回调 + 指数退避重试 [_putMaxAttempts] 次）；
  /// 4. `POST /v1/attachment/confirm` 落 attachment 表（孤儿清理依赖此表）；
  /// 5. 返回 object_key（消息体 uri 字段语义改为存 object_key）。
  ///
  /// 注意：旧 [_upload]（go-fastdfs）保留不删，调用点逐类切换。
  static Future<String> uploadViaPresign(
    Uint8List bytes,
    String fileName,
    String mime, {
    bool process = true,
  }) async {
    // 1. 前置校验（系统边界，快速失败）
    final String? validationError = validateUpload(bytes.length, mime);
    if (validationError != null) {
      throw Exception(validationError);
    }

    // 2. presign（JWT，走 HttpClient）
    final presignResp = await HttpClient.client.get(
      API.attachmentPresign,
      queryParameters: <String, dynamic>{
        'filename': fileName,
        'mime_type': mime,
      },
    );
    if (!presignResp.ok) {
      throw Exception(
        'presign 失败: code=${presignResp.code} msg=${presignResp.msg}',
      );
    }
    final dynamic pp = presignResp.payload;
    final String? putUrl = (pp is Map ? pp['put_url'] : null) as String?;
    final String? objectKey = (pp is Map ? pp['object_key'] : null) as String?;
    if (putUrl == null ||
        putUrl.isEmpty ||
        objectKey == null ||
        objectKey.isEmpty) {
      throw Exception('presign 响应缺少 put_url/object_key');
    }

    // 3. PUT 直传 Garage（裸 Dio，不注 JWT；指数退避重试）
    await _putToGarage(putUrl, bytes, mime, process: process);

    // 4. confirm 落库（JWT，走 HttpClient）
    final String md5sum = md5.convert(bytes).toString();
    final confirmResp = await HttpClient.client.post(
      API.attachmentConfirm,
      data: <String, dynamic>{
        'object_key': objectKey,
        'md5': md5sum,
        'mime_type': mime,
        'size': bytes.length,
      },
    );
    if (!confirmResp.ok) {
      throw Exception(
        'confirm 失败: code=${confirmResp.code} msg=${confirmResp.msg}',
      );
    }

    debugPrint(
      '> uploadViaPresign ok object_key=$objectKey size=${bytes.length}',
    );
    return objectKey;
  }

  /// presign 兼容版上传（drop-in 替换旧 [uploadFile]，签名一致）。
  ///
  /// S6 非聊天面（头像/channel/feedback/moment 等）用：回调 resp 形态兼容旧
  /// go-fastdfs（`{status:'ok', data:{url,size,md5}}`），但 `url` 与第二参 uri
  /// 均为 **object_key**（消息/资源字段语义改为存 object_key）。
  static Future<void> uploadFileViaPresignCompat(
    String prefix,
    Object file,
    Function callback,
    Function errorCallback, {
    String name = "",
    bool process = true,
  }) async {
    try {
      final String path = file is PlatformFile
          ? (file.path ?? "")
          : (file as File).path;
      if (path.isEmpty) {
        throw Exception('uploadFileViaPresignCompat: 文件路径为空');
      }
      final Uint8List bytes = await File(path).readAsBytes();
      final String mime = lookupMimeType(path) ?? 'application/octet-stream';
      final String ext = path.contains('.')
          ? path.substring(path.lastIndexOf('.') + 1)
          : 'bin';
      final String fileName = name.isEmpty
          ? '${Xid().toString()}.$ext'
          : '$name.$ext';
      final meta = await uploadBytesViaPresignMeta(
        bytes,
        fileName,
        mime,
        process: process,
      );
      await callback(compatResp(meta), meta['object_key'] as String);
    } on Object catch (e) {
      errorCallback(e);
    }
  }

  /// presign 兼容版字节上传（drop-in 替换旧 [uploadBytes]，签名一致）。
  static Future<void> uploadBytesViaPresignCompat(
    String prefix,
    Uint8List file,
    Function callback,
    Function errorCallback, {
    String path = "",
    bool process = true,
  }) async {
    try {
      String ext = path.contains('.')
          ? path.substring(path.lastIndexOf('.') + 1)
          : 'png';
      if (ext.isEmpty) ext = 'png';
      final String fileName = '${Xid().toString()}.$ext';
      final String mime =
          lookupMimeType(fileName) ?? 'application/octet-stream';
      final meta = await uploadBytesViaPresignMeta(
        file,
        fileName,
        mime,
        process: process,
      );
      await callback(compatResp(meta), meta['object_key'] as String);
    } on Object catch (e) {
      errorCallback(e);
    }
  }

  /// 构造兼容旧 go-fastdfs 回调的 resp（data.url 存 object_key）。
  @visibleForTesting
  static Map<String, dynamic> compatResp(Map<String, dynamic> meta) {
    return <String, dynamic>{
      'status': 'ok',
      'data': <String, dynamic>{
        'url': meta['object_key'],
        'size': meta['size'],
        'md5': meta['md5'],
      },
    };
  }

  /// 原始字节经 presign 直传，返回 `{object_key, size, md5}`（voice/file 复用）。
  static Future<Map<String, dynamic>> uploadBytesViaPresignMeta(
    Uint8List bytes,
    String fileName,
    String mime, {
    bool process = true,
  }) async {
    final String objectKey = await uploadViaPresign(
      bytes,
      fileName,
      mime,
      process: process,
    );
    return <String, dynamic>{
      'object_key': objectKey,
      'size': bytes.length,
      'md5': md5.convert(bytes).toString(),
    };
  }

  /// 图片 AssetEntity 经 presign 直传，返回渲染/消息所需元数据。
  ///
  /// 仅用于聊天图片（S3）：取原图字节 → uploadViaPresign → 返回 object_key 等。
  /// 返回 `{object_key, size, md5, width, height}`。失败抛异常由调用方处理。
  static Future<Map<String, dynamic>> uploadImageEntityViaPresign(
    AssetEntity entity, {
    bool process = true,
  }) async {
    final Uint8List? bytes = await entity.originBytes;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('uploadImageEntityViaPresign: 无法获取图片原始数据');
    }
    final String mime = await entity.mimeTypeAsync ?? 'image/jpeg';
    final String title = await entity.titleAsync;
    final String ext = title.contains('.')
        ? title.substring(title.lastIndexOf('.') + 1)
        : 'jpg';
    final String name = '${Xid().toString()}.$ext';

    final String objectKey = await uploadViaPresign(
      bytes,
      name,
      mime,
      process: process,
    );
    return <String, dynamic>{
      'object_key': objectKey,
      'size': bytes.length,
      'md5': md5.convert(bytes).toString(),
      'width': entity.width,
      'height': entity.height,
    };
  }

  /// 视频 AssetEntity 经 presign 直传（缩略图 + 压缩视频双 object_key）。
  ///
  /// 仅用于聊天视频（S5）：缩略图与视频分别 presign 直传，返回
  /// `{thumb: EntityImage, video: EntityVideo}`（uri 均为 object_key），
  /// 形态与旧 [uploadVideo] 回调一致，下游 handleVideoUpload 无需改。
  static Future<Map<String, dynamic>> uploadVideoViaPresign(
    AssetEntity entity,
  ) async {
    final File? file = await entity.file;
    if (file == null) {
      throw Exception('uploadVideoViaPresign: 无法获取视频文件');
    }
    final String path = file.path;

    // 缩略图尺寸（沿用旧 uploadVideo 逻辑）
    int width = 800;
    int height = 0;
    if (entity.width < width) {
      width = entity.width;
      height = entity.height;
    } else {
      height = (entity.height / entity.width * width).toInt();
    }

    // 1. 缩略图 → presign
    final File thumbnailFile = await VideoCompress.getFileThumbnail(
      path,
      quality: 68,
      position: -1,
    );
    final Uint8List thumbBytes = await thumbnailFile.readAsBytes();
    final String thumbName = '${Xid().toString()}.jpg';
    final thumbMeta = await uploadBytesViaPresignMeta(
      thumbBytes,
      thumbName,
      'image/jpeg',
      process: false,
    );

    // 2. 压缩视频 → presign
    final MediaInfo? info = await VideoCompress.compressVideo(
      path,
      quality: VideoQuality.Res640x480Quality,
      deleteOrigin: true,
    );
    if (info?.file == null) {
      throw Exception('uploadVideoViaPresign: 视频压缩失败');
    }
    final File videoFile = info!.file!;
    final Uint8List videoBytes = await videoFile.readAsBytes();
    final String videoName = '${Xid().toString()}.mp4';
    final String videoObjKey = await uploadViaPresign(
      videoBytes,
      videoName,
      'video/mp4',
    );

    final EntityImage thumb = EntityImage(
      md5: thumbMeta['md5'] as String,
      name: thumbName,
      uri: thumbMeta['object_key'] as String,
      size: thumbMeta['size'] as int,
      width: width,
      height: height,
    );
    final EntityVideo video = EntityVideo(
      md5: md5.convert(videoBytes).toString(),
      name: videoName,
      uri: videoObjKey,
      size: info.filesize,
      duration: info.duration,
      author: info.author,
      width: info.width!,
      height: info.height!,
    );
    await VideoCompress.deleteAllCache();
    return <String, dynamic>{'thumb': thumb, 'video': video};
  }

  /// 裸 Dio PUT 直传到 Garage presigned URL（不经 HttpClient，不注 JWT）。
  ///
  /// 签名仅含 host（Content-Type 为查询参数、payload 为 UNSIGNED-PAYLOAD），
  /// 故 PUT 原始字节即可；带 Content-Type 头让 Garage 存储正确类型。
  static Future<void> _putToGarage(
    String putUrl,
    Uint8List bytes,
    String mime, {
    bool process = true,
  }) async {
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 30000),
        sendTimeout: const Duration(milliseconds: 120000),
        receiveTimeout: const Duration(milliseconds: 30000),
      ),
    );
    Object? lastError;
    for (int attempt = 0; attempt < _putMaxAttempts; attempt++) {
      try {
        await dio.put<dynamic>(
          putUrl,
          data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
          options: Options(
            contentType: mime,
            headers: <String, dynamic>{
              Headers.contentLengthHeader: bytes.length,
            },
          ),
          onSendProgress: (int sent, int total) {
            if (process && total > 0) {
              EasyLoading.showProgress(
                sent / total,
                status: t.common.uploading,
              );
              if (sent == total) {
                Future<dynamic>.delayed(const Duration(milliseconds: 1500), () {
                  EasyLoading.dismiss();
                });
              }
            }
          },
        );
        return;
      } on Object catch (e) {
        lastError = e;
        debugPrint('> PUT 直传失败 (尝试 ${attempt + 1}/$_putMaxAttempts): $e');
        if (attempt < _putMaxAttempts - 1) {
          // 指数退避：500ms, 1000ms, 2000ms ...
          await Future<dynamic>.delayed(
            Duration(milliseconds: 500 * (1 << attempt)),
          );
        }
      }
    }
    if (process) {
      EasyLoading.dismiss();
    }
    throw Exception('PUT 直传 Garage 失败（已重试 $_putMaxAttempts 次）: $lastError');
  }

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
              EasyLoading.showProgress(
                sent / total,
                status: t.common.uploading,
              );
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
          Map<String, dynamic> resp =
              json.decode(response.data as String) as Map<String, dynamic>;
          callback(
            resp,
            AssetsService.viewUrl(resp['data']['url'] as String).toString(),
          );
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
        errorCallback(Exception(t.common.attachmentGetFileFailed));
        return;
      }

      if (file == null) {
        errorCallback(Exception(t.common.attachmentGetFileFailedAndroid9));
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
            Map<String, dynamic> responseData =
                json.decode(response.data as String) as Map<String, dynamic>;
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
                Map<String, dynamic> responseData =
                    json.decode(response.data as String)
                        as Map<String, dynamic>;
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
          errorCallback(Exception(t.common.attachmentGetImageDataFailed));
        }
        return;
      }

      Map<String, dynamic> preData = {'md5': sha1.convert(thumbData)};
      await preUpload(prefix, preData)
          .then((response) async {
            Map<String, dynamic> responseData =
                json.decode(response.data as String) as Map<String, dynamic>;
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
        errorCallback(Exception(t.common.attachmentGetOriginalImageFailed));
        return;
      }

      Map<String, dynamic> preData = {'md5': sha1.convert(thumbData)};
      await preUpload(prefix, preData)
          .then((response) async {
            Map<String, dynamic> responseData =
                json.decode(response.data as String) as Map<String, dynamic>;
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
      throw Exception(t.chat.unsupportedFileType);
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
