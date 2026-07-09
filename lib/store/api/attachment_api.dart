import 'dart:io';
import 'dart:typed_data';
import 'package:imboy/config/const.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:xid/xid.dart';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:mime/mime.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/i18n/strings.g.dart';

/// presign 请求注入 seam（默认走 [HttpClient]，测试可注入 fake）。
typedef PresignFn =
    Future<IMBoyHttpResponse> Function(String filename, String mime);

/// PUT 直传注入 seam（默认走 [AttachmentApi._putToGarage]，测试可注入 fake）。
typedef PutFn =
    Future<void> Function(
      String putUrl,
      Uint8List bytes,
      String mime,
      bool process,
    );

/// confirm 落库注入 seam（默认走 [HttpClient]，测试可注入 fake）。
typedef ConfirmFn =
    Future<IMBoyHttpResponse> Function(Map<String, dynamic> body);

/// 单次 PUT 注入 seam（默认 [AttachmentApi._rawDioPut]，测试可注入 fake 验证重试编排）。
typedef SinglePutFn =
    Future<void> Function(
      String putUrl,
      Uint8List bytes,
      String mime,
      bool process,
    );

/// 退避延时注入 seam（默认真实 [Future.delayed]，测试可注入零延时避免真实等待）。
typedef DelayFn = Future<void> Function(Duration d);

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
  /// 2. `GET /api/v1/attachment/presign` 取 {put_url, object_key}（JWT，走 HttpClient）；
  /// 3. 裸 Dio PUT 直传 Garage（不注 JWT；进度回调 + 指数退避重试 [_putMaxAttempts] 次）；
  /// 4. `POST /api/v1/attachment/confirm` 落 attachment 表（孤儿清理依赖此表）；
  /// 5. 返回 object_key（消息体 uri 字段语义改为存 object_key）。
  ///
  /// 注意：旧 go-fastdfs 上传方法已下线删除（resource-access-control.md §10.5）。
  static Future<String> uploadViaPresign(
    Uint8List bytes,
    String fileName,
    String mime, {
    bool process = true,
    // 资源访问控制（resource-access-control.md §7）：scope 决定上传桶与读鉴权，
    // scopeRef 绑定可见范围实体（c2c→"c2c:min:max"，group→group_id）。
    // 默认 private 保持既有非聊天面调用方行为（后端 presign/confirm 默认亦为 private）。
    String scope = 'private',
    String? scopeRef,
    // 以下三个为 @visibleForTesting 注入 seam：默认 null 走真实实现，
    // 调用方零改动；测试注入 fake 以脱离 HttpClient/Dio/网络验证编排逻辑。
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
  }) async {
    // 1. 前置校验（系统边界，快速失败）
    final String? validationError = validateUpload(bytes.length, mime);
    if (validationError != null) {
      throw Exception(validationError);
    }

    // 2. presign（JWT，走 HttpClient；可注入）
    final IMBoyHttpResponse presignResp = presignFn != null
        ? await presignFn(fileName, mime)
        : await HttpClient.client.get(
            API.attachmentPresign,
            queryParameters: <String, dynamic>{
              'filename': fileName,
              'mime_type': mime,
              'scope': scope,
              if (scopeRef != null && scopeRef.isNotEmpty)
                'scope_ref': scopeRef,
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

    // 3. PUT 直传 Garage（裸 Dio，不注 JWT；指数退避重试；可注入）
    if (putFn != null) {
      await putFn(putUrl, bytes, mime, process);
    } else {
      await _putToGarage(putUrl, bytes, mime, process: process);
    }

    // 4. confirm 落库（JWT，走 HttpClient；可注入）
    final String md5sum = md5.convert(bytes).toString();
    final Map<String, dynamic> confirmBody = <String, dynamic>{
      'object_key': objectKey,
      'md5': md5sum,
      'mime_type': mime,
      'size': bytes.length,
      'scope': scope,
      if (scopeRef != null && scopeRef.isNotEmpty) 'scope_ref': scopeRef,
    };
    final IMBoyHttpResponse confirmResp = confirmFn != null
        ? await confirmFn(confirmBody)
        : await HttpClient.client.post(
            API.attachmentConfirm,
            data: confirmBody,
          );
    if (!confirmResp.ok) {
      throw Exception(
        'confirm 失败: code=${confirmResp.code} msg=${confirmResp.msg}',
      );
    }

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
    String scope = 'private',
    String? scopeRef,
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
        scope: scope,
        scopeRef: scopeRef,
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
    String scope = 'private',
    String? scopeRef,
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
        scope: scope,
        scopeRef: scopeRef,
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
    String scope = 'private',
    String? scopeRef,
  }) async {
    final String objectKey = await uploadViaPresign(
      bytes,
      fileName,
      mime,
      process: process,
      scope: scope,
      scopeRef: scopeRef,
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
    String scope = 'private',
    String? scopeRef,
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
      scope: scope,
      scopeRef: scopeRef,
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
  /// 下游 handleVideoUpload 无需改。
  static Future<Map<String, dynamic>> uploadVideoViaPresign(
    AssetEntity entity, {
    String scope = 'private',
    String? scopeRef,
  }) async {
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
      scope: scope,
      scopeRef: scopeRef,
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
      scope: scope,
      scopeRef: scopeRef,
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

  /// File 版视频上传（压缩+缩略图+上传三件套），供频道发布等已持有 File
  /// 与元数据（时长/宽高）、无 AssetEntity 的场景使用。
  ///
  /// 与 [uploadVideoViaPresign]（AssetEntity 版）流程一致，差异：
  ///   - 直接接收 [file]（不经 entity.file 再取一次）；
  ///   - width/height/durationMs 由调用方传入，不再从 entity 反推；
  ///   - 返回扁平 `{video_uri, size, thumb_uri}`，失败返回 null（调用方
  ///     以 `result == null` 判失败，不抛异常）。
  static Future<Map<String, dynamic>?> uploadVideoFileViaPresign(
    File file, {
    required int durationMs,
    required int width,
    required int height,
    String scope = 'private',
    String? scopeRef,
  }) async {
    try {
      final String path = file.path;

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
        scope: scope,
        scopeRef: scopeRef,
      );

      // 2. 压缩视频 → presign
      final MediaInfo? info = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.Res640x480Quality,
        deleteOrigin: false,
      );
      if (info?.file == null) {
        await VideoCompress.deleteAllCache();
        return null;
      }
      final File videoFile = info!.file!;
      final Uint8List videoBytes = await videoFile.readAsBytes();
      final String videoName = '${Xid().toString()}.mp4';
      final String videoObjKey = await uploadViaPresign(
        videoBytes,
        videoName,
        'video/mp4',
        scope: scope,
        scopeRef: scopeRef,
      );

      await VideoCompress.deleteAllCache();
      return <String, dynamic>{
        'video_uri': videoObjKey,
        'thumb_uri': thumbMeta['object_key'] as String,
        'size': info.filesize ?? videoBytes.length,
        'duration': durationMs,
        'width': width,
        'height': height,
      };
    } on Object catch (e) {
      debugPrint('[attachment_api] uploadVideoFileViaPresign error: $e');
      await VideoCompress.deleteAllCache();
      return null;
    }
  }

  /// 裸 Dio PUT 直传到 Garage presigned URL（不经 HttpClient，不注 JWT；指数退避重试）。
  ///
  /// 签名仅含 host（Content-Type 为查询参数、payload 为 UNSIGNED-PAYLOAD），
  /// 故 PUT 原始字节即可；带 Content-Type 头让 Garage 存储正确类型。
  /// 重试编排委托 [putWithRetry]（默认单次 PUT 走 [_rawDioPut]）。
  static Future<void> _putToGarage(
    String putUrl,
    Uint8List bytes,
    String mime, {
    bool process = true,
  }) async {
    await putWithRetry(
      putUrl,
      bytes,
      mime,
      process: process,
      singlePut: _rawDioPut,
    );
  }

  /// 单次裸 Dio PUT（无重试）：生产默认的 [SinglePutFn]，含上传进度提示。
  static Future<void> _rawDioPut(
    String putUrl,
    Uint8List bytes,
    String mime,
    bool process,
  ) async {
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: 30000),
        sendTimeout: const Duration(milliseconds: 120000),
        receiveTimeout: const Duration(milliseconds: 30000),
      ),
    );
    await dio.put<dynamic>(
      putUrl,
      data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
      options: Options(
        contentType: mime,
        headers: <String, dynamic>{Headers.contentLengthHeader: bytes.length},
      ),
      onSendProgress: (int sent, int total) {
        if (process && total > 0) {
          AppLoading.showProgress(sent / total, status: t.common.uploading);
          if (sent == total) {
            Future<dynamic>.delayed(const Duration(milliseconds: 1500), () {
              AppLoading.dismiss();
            });
          }
        }
      },
    );
  }

  /// PUT 指数退避重试编排（[_putMaxAttempts] 次，退避 500/1000ms ...）。
  ///
  /// 单次 PUT 与退避延时均经注入 seam，便于在不触网、不真实等待的前提下
  /// 验证重试次数与退避序列。生产默认 singlePut=[_rawDioPut]、delay=真实 [Future.delayed]。
  @visibleForTesting
  static Future<void> putWithRetry(
    String putUrl,
    Uint8List bytes,
    String mime, {
    bool process = true,
    required SinglePutFn singlePut,
    DelayFn? delay,
  }) async {
    final DelayFn doDelay = delay ?? (Duration d) => Future<void>.delayed(d);
    Object? lastError;
    for (int attempt = 0; attempt < _putMaxAttempts; attempt++) {
      try {
        await singlePut(putUrl, bytes, mime, process);
        return;
      } on Object catch (e) {
        lastError = e;
        if (attempt < _putMaxAttempts - 1) {
          // 指数退避：500ms, 1000ms, 2000ms ...
          await doDelay(Duration(milliseconds: 500 * (1 << attempt)));
        }
      }
    }
    if (process) {
      AppLoading.dismiss();
    }
    throw Exception('PUT 直传 Garage 失败（已重试 $_putMaxAttempts 次）: $lastError');
  }
}
