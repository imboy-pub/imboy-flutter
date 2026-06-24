/// 聊天页面附件处理器
///
/// 负责处理所有附件相关的上传、选择和消息创建逻辑
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/ui/app_loading.dart';
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
    this.type = '',
    this.burnEnabled = false,
    this.burnAfterMs = 0,
    this.currentUserOverride,
    this.isMutedCheck,
  });

  /// 对方 ID
  final String peerId;

  /// 会话类型（权威源）：`C2C` | `C2G` | `C2S`。用于派生上传 scope，
  /// 优先于 conversationUk3 前缀（后者可能来自历史/options 非标准值）。
  final String type;

  /// 会话唯一标识
  final String conversationUk3;

  /// 消息创建回调
  final AttachmentUploadedCallback onMessageCreated;

  /// 禁言检查回调 (C13)
  final bool Function()? isMutedCheck;

  /// 是否启用阅后即焚
  final bool burnEnabled;

  /// 阅后即焚时长（毫秒）
  final int burnAfterMs;

  /// 当前用户注入 seam（仅测试用）：默认 null 走真实 [UserRepoLocal]，
  /// 测试注入 fake 以脱离 StorageService 单例（`current` 在无数据时抛 StateError）。
  @visibleForTesting
  final User? currentUserOverride;

  /// 安全拦截：如果用户被禁言，直接拦截消息创建与发送，并弹出 EasyLoading 提示 (C13)
  Future<bool> _sendMessage(Message message) async {
    if (isMutedCheck != null && isMutedCheck!()) {
      AppLoading.showError(t.chat.youAreMuted);
      return false;
    }
    return await onMessageCreated(message);
  }

  /// 获取当前用户
  User get _currentUser =>
      currentUserOverride ??
      User(
        id: UserRepoLocal.to.currentUid,
        name: UserRepoLocal.to.current.nickname,
        imageSource: UserRepoLocal.to.current.avatar,
      );

  /// 由会话键（conv_key）派生附件上传的 scope 与 scope_ref
  /// （资源访问控制 resource-access-control.md §5/§7）。
  ({String scope, String? scopeRef}) get _uploadScope => deriveUploadScope(
    conversationUk3: conversationUk3,
    currentUid: _currentUser.id,
    peerId: peerId,
    type: type,
  );

  /// 纯函数：派生附件上传的 scope 与 scope_ref（资源访问控制 §5/§7）。
  ///
  /// 来源优先级：**会话类型 [type]（权威）** > conversationUk3 【类型前缀】。
  /// 早期实现仅按 conversationUk3 的冒号前缀（`c2c:`/`c2g:`）判断，但生成器
  /// [ConversationUk3Generator] 实际产出大写下划线格式（`C2C_min_max` /
  /// `C2G_uid_gid`），导致永远回退 private（c2c/group 鉴权失效）。此函数以
  /// type 为权威、uk3 前缀为兜底，与具体分隔符形态解耦，修复该回归。
  ///
  /// - C2G → (scope: 'group', scopeRef: group_id == peerId)
  /// - C2C → (scope: 'c2c', scopeRef: `c2c:<minUid>:<maxUid>` 整数归一化顺序)
  /// - C2S/未知 → (scope: 'private', scopeRef: null) 避免误标可见范围（fail-safe）
  @visibleForTesting
  static ({String scope, String? scopeRef}) deriveUploadScope({
    required String conversationUk3,
    required String currentUid,
    required String peerId,
    String? type,
  }) {
    final String t = (type ?? '').toUpperCase();
    // 1) 会话类型为权威源
    if (t == 'C2G') {
      return (scope: 'group', scopeRef: peerId);
    }
    if (t == 'C2C') {
      return (scope: 'c2c', scopeRef: _c2cConvKey(currentUid, peerId));
    }
    // 2) type 缺失/非标准时，退回 conversationUk3 前缀兜底
    final String uk = conversationUk3.toUpperCase();
    if (uk.startsWith('C2G')) {
      return (scope: 'group', scopeRef: peerId);
    }
    if (uk.startsWith('C2C')) {
      return (scope: 'c2c', scopeRef: _c2cConvKey(currentUid, peerId));
    }
    return (scope: 'private', scopeRef: null);
  }

  /// 构造单聊 conv_key：`c2c:<minUid>:<maxUid>`，按整数归一化顺序。
  ///
  /// 用 [BigInt] 解析：TSID 为 64 位整数，超过 Web（dart2js）53 位 int 精度；
  /// BigInt 在所有平台精确，避免大 TSID 排序错乱致 conv_key 与后端不匹配。
  /// 非数字时回退字符串序，保证确定性。
  static String _c2cConvKey(String a, String b) {
    final BigInt? ai = BigInt.tryParse(a);
    final BigInt? bi = BigInt.tryParse(b);
    final bool aFirst = (ai != null && bi != null)
        ? ai <= bi
        : a.compareTo(b) <= 0;
    final String minUid = aFirst ? a : b;
    final String maxUid = aFirst ? b : a;
    return 'c2c:$minUid:$maxUid';
  }

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
    if (!context.mounted) return;
    await uploadFile(context, result.files.single);
  }

  /// 上传文件
  ///
  /// S6：聊天文件走 Garage presign 直传（source 存 object_key，
  /// 下载经 IMBoyCacheManager.getSingleFile 异步解析）。
  Future<void> uploadFile(BuildContext context, PlatformFile file) async {
    final String? path = file.path;
    if (path == null) {
      return;
    }
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      final String mime = lookupMimeType(path) ?? 'application/octet-stream';
      final s = _uploadScope;
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        file.name,
        mime,
        scope: s.scope,
        scopeRef: s.scopeRef,
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
      await _sendMessage(message);
    } on Object catch (e) {
      debugPrint('[attachment_handler] onMessageCreated error: $e');
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

      final List<AssetEntity>? assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.common,
        ),
      );

      if (!context.mounted || assets == null || assets.isEmpty) return;
      await uploadCameraAsset(context, assets.first);
    } catch (e) {
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
        final s = _uploadScope;
        final meta = await AttachmentApi.uploadImageEntityViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
        );
        await handleImageUploadPresign(meta, entity);
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleImageUploadPresign error: $e');
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final s = _uploadScope;
        final resp = await AttachmentApi.uploadVideoViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
        );
        await handleVideoUpload(resp);
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleVideoUpload error: $e');
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
    await _sendMessage(message);
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
    await _sendMessage(message);
  }

  /// 处理图片选择
  Future<void> handleImageSelection(
    BuildContext context,
    Future<List<AssetEntity>?> Function() onSelect,
  ) async {
    bool hasPermission = await requestPhotoPermission();
    if (!hasPermission) return;

    final result = await onSelect();
    if (!context.mounted) return;
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
        final s = _uploadScope;
        final meta = await AttachmentApi.uploadImageEntityViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
        );
        await handleImageUploadPresign(meta, entity);
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleImageUploadPresign error: $e');
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final s = _uploadScope;
        final resp = await AttachmentApi.uploadVideoViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
        );
        await handleSelectedVideoUpload(resp);
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleSelectedVideoUpload error: $e');
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
    await _sendMessage(message);
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
      final s = _uploadScope;
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        name,
        mime,
        process: false,
        scope: s.scope,
        scopeRef: s.scopeRef,
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
      await _sendMessage(message);
    } on Object catch (e) {
      debugPrint('[attachment_handler] onMessageCreated error: $e');
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
    final s = _uploadScope;
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
        await _sendMessage(message);
      },
      (Error error) => debugPrint("Location upload error: ${error.toString()}"),
      process: false,
      scope: s.scope,
      scopeRef: s.scopeRef,
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
    await _sendMessage(message);
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
    await _sendMessage(msg);
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
    final res = await _sendMessage(message);
    if (res && context.mounted) {
      AppLoading.showSuccess(t.common.tipSuccess);
    } else if (context.mounted) {
      AppLoading.showError(t.common.tipFailed);
    }
  }

  /// 处理发送红包消息
  Future<void> handleRedPacketSelection(Map<String, dynamic> data) async {
    final message = CustomMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'msg_type': 'redPacket',
        'id': data['id'],
        'greeting': data['greeting'],
        'amount': data['amount'],
        'count': data['count'],
        'type': data['type'],
      }),
    );
    await _sendMessage(message);
  }

  /// 处理发送转账消息
  Future<void> handleTransferSelection(Map<String, dynamic> data) async {
    final message = CustomMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: Xid().toString(),
      metadata: _withBurnMetadata({
        'msg_type': 'transfer',
        'id': data['id'],
        'amount': data['amount'],
        'remark': data['remark'],
        'status': 'pending',
      }),
    );
    await _sendMessage(message);
  }
}
