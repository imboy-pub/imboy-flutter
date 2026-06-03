/// 聊天页面附件处理器
///
/// 负责处理所有附件相关的上传、选择和消息创建逻辑
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image/image.dart' as img;
import 'package:xid/xid.dart';
import 'package:mime/mime.dart';

import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/voice_record/voice_widget.dart' show AudioFile;
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

/// 附件上传回调
typedef AttachmentUploadedCallback = Future<bool> Function(Message message);

/// 附件处理器
///
/// 封装所有附件相关的上传和选择逻辑
class ChatAttachmentHandler {
  /// 构造函数
  const ChatAttachmentHandler({
    required this.peerId,
    required this.conversationUk3,
    required this.onMessageCreated,
    this.burnEnabled = false,
    this.burnAfterMs = 0,
  });

  /// 对方 ID
  final String peerId;

  /// 会话唯一标识
  final String conversationUk3;

  /// 消息创建回调
  final AttachmentUploadedCallback onMessageCreated;

  /// 是否启用阅后即焚
  final bool burnEnabled;

  /// 阅后即焚时长（毫秒）
  final int burnAfterMs;

  /// 获取当前用户
  User get _currentUser => User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );

  /// 添加阅后即焚元数据
  Map<String, dynamic> _withBurnMetadata(Map<String, dynamic> base) {
    if (!burnEnabled) return base;
    return <String, dynamic>{
      ...base,
      'burn': true,
      'burn_after_ms': burnAfterMs,
    };
  }

  /// 处理文件选择
  Future<void> handleFileSelection(BuildContext context) async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;
    await uploadFile(context, result.files.single);
  }

  /// 上传文件
  ///
  /// S6：聊天文件走 Garage presign 直传（source 存 object_key，
  /// 下载经 IMBoyCacheManager.getSingleFile 异步解析）。
  Future<void> uploadFile(BuildContext context, PlatformFile file) async {
    final String? path = file.path;
    if (path == null) {
      debugPrint("uploadFile: file.path 为空，取消上传");
      return;
    }
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      final String mime = lookupMimeType(path) ?? 'application/octet-stream';
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        file.name,
        mime,
      );
      final message = FileMessage(
        id: Xid().toString(),
        authorId: _currentUser.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
        mimeType: mime,
        name: file.name,
        size: file.size,
        source: meta['object_key'] as String,
        status: MessageStatus.sending,
        metadata: _withBurnMetadata({
          'peer_id': peerId,
          'md5': meta['md5'].toString(),
        }),
      );
      await onMessageCreated(message);
    } on Object catch (e) {
      debugPrint("File presign upload error: $e");
    }
  }

  /// 处理相机选择
  Future<void> handlePickerSelection(BuildContext context) async {
    if (!context.mounted) return;
    // Phase 2.2: Web 平台不支持原生 camera picker (wechat_camera_picker 是
    // 移动端专用)。提示用户改用 + 号选文件（file_picker 已在 Web 工作）。
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera not supported on Web. Use file picker instead.',
            ),
          ),
        );
      }
      return;
    }
    try {
      bool hasPermission = await requestCameraPermission();
      if (!hasPermission || !context.mounted) return;

      final AssetEntity? entity = await CameraPicker.pickFromCamera(
        context,
        pickerConfig: const CameraPickerConfig(
          enableRecording: true,
          onlyEnableRecording: false,
          enableTapRecording: true,
          maximumRecordingDuration: Duration(seconds: 24),
        ),
      );

      if (!context.mounted || entity == null) return;
      await uploadCameraAsset(context, entity);
    } catch (e) {
      debugPrint("Camera picker error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.common.cameraShootFailed}: $e')),
        );
      }
    }
  }

  /// 上传拍摄的资源
  Future<void> uploadCameraAsset(
    BuildContext context,
    AssetEntity entity,
  ) async {
    // S3：图片走 Garage presign 直传（消息 source 存 object_key）；
    // 视频仍走旧 go-fastdfs 链路（待 S5 切换）。
    if (entity.type == AssetType.image) {
      try {
        final meta = await AttachmentApi.uploadImageEntityViaPresign(entity);
        await handleImageUploadPresign(meta, entity);
      } on Object catch (e) {
        debugPrint("Camera image presign upload error: $e");
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final resp = await AttachmentApi.uploadVideoViaPresign(entity);
        await handleVideoUpload(resp);
      } on Object catch (e) {
        debugPrint("Camera video presign upload error: $e");
      }
    }
    // 上传后删除临时文件
    (await entity.file)?.deleteSync();
  }

  /// 处理图片上传（S3 presign：source 存 object_key，渲染经 cachedImageProvider 异步解析）
  Future<void> handleImageUploadPresign(
    Map<String, dynamic> meta,
    AssetEntity entity,
  ) async {
    final message = ImageMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: meta['size'] as int?,
      // Garage 不支持 nginx 式 width 缩放，source 直接存 object_key（不拼 &width）
      source: meta['object_key'] as String,
      metadata: _withBurnMetadata({
        'peer_id': peerId,
        'md5': meta['md5'].toString(),
      }),
    );
    await onMessageCreated(message);
  }

  /// 处理视频上传
  Future<void> handleVideoUpload(Map<String, dynamic> resp) async {
    final thumb = (resp['thumb'] as EntityImage).toJson();
    final video = resp['video'] as EntityVideo;

    final message = VideoMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      source: video.uri,
      text: video.name,
      name: video.name,
      size: video.size ?? 0,
      width: video.width.toDouble(),
      height: video.height.toDouble(),
      metadata: _withBurnMetadata({
        'peer_id': peerId,
        'md5': video.md5,
        'thumb': thumb,
        if (video.duration != null)
          'duration_ms': (video.duration! * 1000).round(),
      }),
    );
    await onMessageCreated(message);
  }

  /// 处理图片选择
  Future<void> handleImageSelection(
    BuildContext context,
    Future<List<AssetEntity>?> Function() onSelect,
  ) async {
    bool hasPermission = await requestPhotoPermission();
    if (!hasPermission) return;

    final result = await onSelect();
    if (result != null) {
      for (var entity in result) {
        await uploadSelectedAsset(context, entity);
      }
    }
  }

  /// 上传选择的资源
  Future<void> uploadSelectedAsset(
    BuildContext context,
    AssetEntity entity,
  ) async {
    // S3：图片走 Garage presign 直传；视频仍走旧链路（待 S5）。
    if (entity.type == AssetType.image) {
      try {
        final meta = await AttachmentApi.uploadImageEntityViaPresign(entity);
        await handleImageUploadPresign(meta, entity);
      } on Object catch (e) {
        debugPrint("Selected image presign upload error: $e");
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final resp = await AttachmentApi.uploadVideoViaPresign(entity);
        await handleSelectedVideoUpload(resp);
      } on Object catch (e) {
        debugPrint("Selected video presign upload error: $e");
      }
    }
  }

  /// 处理选择的视频上传
  Future<void> handleSelectedVideoUpload(Map<String, dynamic> resp) async {
    final thumb = (resp['thumb'] as EntityImage).toJson();
    final video = resp['video'] as EntityVideo;

    final message = VideoMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      source: video.uri,
      text: video.name,
      name: video.name,
      size: video.size ?? 0,
      width: video.width.toDouble(),
      height: video.height.toDouble(),
      metadata: _withBurnMetadata({
        'peer_id': peerId,
        'md5': video.md5,
        'thumb': thumb,
        if (video.duration != null)
          'duration_ms': (video.duration! * 1000).round(),
      }),
    );
    await onMessageCreated(message);
  }

  /// 处理语音选择
  Future<void> handleVoiceSelection(AudioFile? obj) async {
    if (obj == null) return;
    final Uint8List bytes = await obj.file.readAsBytes();
    if (bytes.isEmpty) return;

    // S4：语音走 Garage presign 直传（source 存 object_key，播放经 getSingleFile 解析）。
    try {
      final String mime = obj.mimeType;
      final String ext = mime.contains('/') ? mime.split('/').last : 'mp3';
      final String name = '${Xid().toString()}.$ext';
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        name,
        mime,
        process: false,
      );
      final message = AudioMessage(
        authorId: _currentUser.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
        id: Xid().toString(),
        source: meta['object_key'] as String,
        text: '',
        size: bytes.length,
        duration: obj.duration,
        waveform: obj.waveform,
        metadata: _withBurnMetadata({
          'peer_id': peerId,
          'md5': meta['md5'].toString(),
          'mime_type': obj.mimeType,
        }),
      );
      await obj.file.delete(recursive: true);
      await onMessageCreated(message);
    } on Object catch (e) {
      debugPrint("Voice presign upload error: $e");
    }
  }

  /// 处理位置选择
  Future<void> handleLocationSelection(
    BuildContext context,
    String id,
    Uint8List? imageBytes,
    String address,
    String title,
    String latitude,
    String longitude,
  ) async {
    if (imageBytes == null) return;
    final image = img.decodeImage(imageBytes)!;
    final result = img.encodeJpg(image, quality: 65);
    await AttachmentApi.uploadBytesViaPresignCompat(
      "location",
      result,
      (Map<String, dynamic> resp, String imgUrl) async {
        // imgUrl 现为 object_key（presign），Garage 不支持 &width 缩放，直接存
        final message = CustomMessage(
          authorId: _currentUser.id,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            DateTimeHelper.millisecond(),
            isUtc: true,
          ),
          id: Xid().toString(),
          metadata: _withBurnMetadata({
            'msg_type': 'location',
            'peer_id': peerId,
            'title': title,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
            'thumb': imgUrl,
            'size': resp['data']['size'],
            'md5': resp['data']['md5'].toString(),
          }),
        );
        await onMessageCreated(message);
      },
      (Error error) => debugPrint("Location upload error: ${error.toString()}"),
      process: false,
    );
  }

  /// 发送表情消息
  Future<void> sendExpressionMessage(
    BuildContext context,
    String url,
    String text, {
    int? width,
    int? height,
  }) async {
    final message = CustomMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'msg_type': 'expression',
        'peer_id': peerId,
        'url': url,
        'text': text,
        'width': width ?? 120,
        'height': height ?? 120,
      }),
    );
    await onMessageCreated(message);
  }

  /// 发送收藏消息
  Future<void> sendCollectMessage(
    BuildContext context,
    Map<String, dynamic> collectInfo,
  ) async {
    final data = Map<String, dynamic>.from(collectInfo)
      ..addAll({
        MessageRepo.id: Xid().toString(),
        MessageRepo.from: UserRepoLocal.to.currentUid,
        MessageRepo.to: peerId,
        MessageRepo.status: 10,
        MessageRepo.conversationUk3: conversationUk3,
        MessageRepo.createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
      });
    final msg0 = await MessageModel.fromJson(data).toTypeMessage();
    final msg = burnEnabled
        ? msg0.copyWith(
            metadata: _withBurnMetadata(
              Map<String, dynamic>.from(msg0.metadata ?? {}),
            ),
          )
        : msg0;
    await onMessageCreated(msg);
  }

  /// 发送名片消息
  Future<void> sendVisitCardMessage(
    BuildContext context,
    String uid,
    String title,
    String avatar,
  ) async {
    final message = CustomMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'msg_type': 'visitCard',
        'peer_id': peerId,
        'uid': uid,
        'title': title,
        'avatar': avatar,
      }),
    );
    final res = await onMessageCreated(message);
    if (res && context.mounted) {
      EasyLoading.showSuccess(t.common.tipSuccess);
    } else if (context.mounted) {
      EasyLoading.showError(t.common.tipFailed);
    }
  }
}
