/// 聊天页面附件处理器
///
/// 负责处理所有附件相关的上传、选择和消息创建逻辑
library;

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart'
    show AssetEntity, AssetType;
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:image/image.dart' as img;
import 'package:xid/xid.dart';
import 'package:mime/mime.dart';

import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_conversation_ref.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/e2ee_service.dart';
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

/// E2EE-061 附件封装的**分阶段开关**，默认 `false`。
///
/// ⚠️⚠️ **打开它之前必须先有 Slice 6（下载侧解密 + 完整性门）。**
/// 今天的读取链路（`cachedImageProvider` / `IMBoyCacheManager.getSingleFile`）
/// 直接把对象字节交给渲染器，**没有任何一处会调用
/// [AttachmentEncryptor.open]**。此时开启封装的后果不是「更安全」，而是
/// E2EE 会话里**所有新附件对谁都打不开**——包括发送者自己。
///
/// 消息侧不会丢：descriptor 随加密 payload 落库，Slice 6 上线后旧密文仍可解。
/// 但那扇窗口期内用户看到的是坏图。故按裁决规则选 fail-closed 的那个默认值。
///
/// 翻开时只改这一行；`ChatAttachmentHandler.sealRollout` 会跟着变。
// ponytail: 单个 const 而非 feature flag 服务——它只会翻一次，翻的条件是
// Slice 6 合入，不需要远端下发也不需要按用户灰度。
const bool kAttachmentSealRolloutEnabled = false;

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
    this.sealRollout = kAttachmentSealRolloutEnabled,
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

  /// 是否已进入 E2EE-061 附件封装的推出阶段，默认 [kAttachmentSealRolloutEnabled]。
  /// 关闭时上传路径逐字节维持今天的明文行为。
  final bool sealRollout;

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
  /// ⚠️ 实现下沉到 [AttachmentConversationRef.c2cKey]（**全项目唯一一份**）：
  /// 接收侧要用同一套规则重算绑定值，两份实现哪怕只在排序回退上分歧，
  /// 都会变成「上传 scope 与绑定值对不上」的隐性错配。
  static String _c2cConvKey(String a, String b) =>
      AttachmentConversationRef.c2cKey(a, b);

  /// 添加阅后即焚元数据
  Map<String, dynamic> _withBurnMetadata(Map<String, dynamic> base) {
    if (!burnEnabled) return base;
    return <String, dynamic>{
      ...base,
      'burn': true,
      'burn_after_ms': burnAfterMs,
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // E2EE-061 Slice 4：附件封装接线（本类内**唯一**入口）
  // ───────────────────────────────────────────────────────────────────────────

  /// 绑定值（方案甲）用的 `conversation_id`。
  ///
  /// ⚠️⚠️ **不能用 [conversationUk3]**：群会话的 uk3 是
  /// `C2G_<本机uid>_<gid>`（见 [ConversationUk3Generator]），**逐用户不同**——
  /// 拿它算绑定值，除发送者外没有任何人能算出同一个 AAD，群附件对所有收件人
  /// 直接不可读。这里复用上传 scope 的 `scope_ref`：C2C 是
  /// `c2c:<min>:<max>`（整数归一化，两端一致），C2G 是 group_id（两端一致）。
  ///
  /// 非聊天面（scope=private，scopeRef 为 null）返回空串 → 闸门判 missingBinding
  /// → 不封装（fail-closed）。
  @visibleForTesting
  String get sealConversationId => _uploadScope.scopeRef ?? '';

  /// 纯函数：这次上传要不要封装、封装用什么绑定值。
  ///
  /// 抽成静态纯函数是为了让判定可被穷举验收——上传本身依赖文件 IO 与静态
  /// [AttachmentApi]，进不了单测。
  @visibleForTesting
  static AttachmentSealRequest? buildSealRequest({
    required bool rolloutEnabled,
    required bool payloadWillBeEncrypted,
    required String messageId,
    required String conversationId,
    required String senderUid,
    required String attachmentId,
  }) {
    if (!rolloutEnabled) return null;
    final decision = AttachmentSealPolicy.decide(
      payloadWillBeEncrypted: payloadWillBeEncrypted,
      messageId: messageId,
      conversationId: conversationId,
      senderUid: senderUid,
    );
    if (decision is! SealApproved) return null;
    return AttachmentSealRequest(
      bindingHash: AttachmentBinding.compute(
        messageId: messageId,
        conversationId: conversationId,
        senderUid: senderUid,
      ),
      attachmentId: attachmentId,
    );
  }

  /// 取「这条消息的 payload 会不会被加密」——必须与真正决定加密的那一处
  /// **同一个判据**：`ChatNetworkService.sendWsMsg` 用的就是
  /// `E2EEService.shouldEncryptOutgoingPayload(type)`。
  ///
  /// ⚠️ 刻意**不**把 `encryptPayload` 里那个 `groupMegolm` 条件并进来：
  /// `sendWsMsg` 在 `shouldEncryptOutgoingPayload` 为假时**根本不会调用**
  /// `encryptPayload`，直接走明文分支。跟着 `groupMegolm` 判「会加密」会让
  /// 群附件在 payload 实际明文出网时被封装，**content key 明文出网**——
  /// 比今天的明文附件更糟。判据必须抄发送路径实际用的那个，不是它内部
  /// 那个更宽的。
  ///
  /// PolicyGate 拿不到策略时抛 [E2eeSecurityException]：拿不准 → 不封装，
  /// 退回今天已知的明文行为（这条消息随后会被 `sendWsMsg` 的同一道门拒发）。
  bool get _payloadWillBeEncrypted {
    try {
      return E2EEService.shouldEncryptOutgoingPayload(type);
    } on Object {
      return false;
    }
  }

  AttachmentSealRequest? _sealFor(String messageId, String attachmentId) =>
      buildSealRequest(
        rolloutEnabled: sealRollout,
        payloadWillBeEncrypted: _payloadWillBeEncrypted,
        messageId: messageId,
        conversationId: sealConversationId,
        senderUid: _currentUser.id,
        attachmentId: attachmentId,
      );

  /// 把 descriptor 放进消息 metadata —— 它会被 `getMsgFromTMsg`
  /// 原样并入 payload，从而随 PFv3 一起加密。
  ///
  /// ⚠️ descriptor 含 content key。只有 [_sealFor] 判定通过时它才存在，
  /// 而那个判定的前提正是「payload 会被加密」。
  Map<String, dynamic> _withDescriptor(
    Map<String, dynamic> base,
    AttachmentSealRequest? seal,
  ) {
    final descriptor = seal?.descriptor;
    if (descriptor == null) return base;
    return <String, dynamic>{
      ...base,
      AttachmentSealPolicy.descriptorPayloadKey: descriptor.toMap(),
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
      // message_id 必须在上传**之前**生成：它是绑定值（方案甲）的输入。
      final String messageId = Xid().toString();
      final seal = _sealFor(messageId, 'file');
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        file.name,
        mime,
        scope: s.scope,
        scopeRef: s.scopeRef,
        seal: seal,
      );
      final message = FileMessage(
        id: messageId,
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
        metadata: _withBurnMetadata(
          _withDescriptor({
            'peer_id': peerId,
            'file_hash256': meta['file_hash256'].toString(),
          }, seal),
        ),
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

      // 相机拍摄统一走全局 MediaPickerCapability.pickCameraDual（双模：
      // 点按拍照 / 长按录像），不再在此直调 CameraPicker——全局唯一相机入口，
      // 与 moment/channel/profile 等复用同一实现。返回 AssetEntity 与下面
      // uploadCameraAsset 的图片/视频双分支上传逻辑无缝对接，无需改动。
      final AssetEntity? entity = await CapabilityLocator.I
          .get<MediaPickerCapability>()
          .pickCameraDual(context);

      if (!context.mounted || entity == null) return;
      await uploadCameraAsset(context, entity);
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
        final String messageId = Xid().toString();
        final seal = _sealFor(messageId, 'image');
        final meta = await AttachmentApi.uploadImageEntityViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          seal: seal,
        );
        await handleImageUploadPresign(
          meta,
          entity,
          messageId: messageId,
          seal: seal,
        );
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleImageUploadPresign error: $e');
        // 静默 catch 会让用户以为"点了确认什么都没发生"，必须给可见反馈
        AppLoading.showError(t.common.uploadFailed);
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final s = _uploadScope;
        final String messageId = Xid().toString();
        final seal = _sealFor(messageId, 'video');
        final resp = await AttachmentApi.uploadVideoViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          videoSeal: seal,
          // Slice 7：缩略图必须一起封装，否则预览即泄漏（设计 §3.3）
          thumbSeal: _sealFor(messageId, 'video_thumb'),
        );
        await handleVideoUpload(resp, messageId: messageId, seal: seal);
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleVideoUpload error: $e');
        // 同上：视频压缩/上传失败此前完全无提示（BUG#65）
        AppLoading.showError(t.common.uploadFailed);
      }
    }
    // 上传后删除临时文件
    (await entity.file)?.deleteSync();
  }

  /// 处理图片上传（S3 presign：source 存 object_key，渲染经 cachedImageProvider 异步解析）
  ///
  /// [messageId] 由上传前生成并透传（绑定值的输入）；为 null 时退回自生成，
  /// 保留既有调用形状。
  Future<void> handleImageUploadPresign(
    Map<String, dynamic> meta,
    AssetEntity entity, {
    String? messageId,
    AttachmentSealRequest? seal,
  }) async {
    final message = ImageMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: messageId ?? Xid().toString(),
      text: await entity.titleAsync,
      height: entity.height * 1.0,
      width: entity.width * 1.0,
      size: meta['size'] as int?,
      // Garage 不支持 nginx 式 width 缩放，source 直接存 object_key（不拼 &width）
      source: meta['object_key'] as String,
      metadata: _withBurnMetadata(
        _withDescriptor({
          'peer_id': peerId,
          'file_hash256': meta['file_hash256'].toString(),
        }, seal),
      ),
    );
    await _sendMessage(message);
  }

  /// 处理视频上传
  Future<void> handleVideoUpload(
    Map<String, dynamic> resp, {
    String? messageId,
    AttachmentSealRequest? seal,
  }) async {
    final thumb = (resp['thumb'] as EntityImage).toJson();
    final video = resp['video'] as EntityVideo;

    final message = VideoMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: messageId ?? Xid().toString(),
      source: video.uri,
      text: video.name,
      name: video.name,
      size: video.size ?? 0,
      width: video.width.toDouble(),
      height: video.height.toDouble(),
      // ⚠️ thumb 仍是明文对象（Slice 7）：视频本体加密不掩盖缩略图泄漏预览。
      metadata: _withBurnMetadata(
        _withDescriptor({
          'peer_id': peerId,
          'file_hash256': video.fileHash256,
          'thumb': thumb,
          // MediaInfo.duration 本身就是**毫秒**，此前又乘了一次 1000，
          // 3 秒的视频会显示成 52:34（BUG#67）。此前视频压根发不出去
          // （BUG#64），所以这个错误一直没暴露。
          if (video.duration != null) 'duration_ms': video.duration!.round(),
        }, seal),
      ),
    );
    await _sendMessage(message);
  }

  /// 通过 FilePicker 选择图片并上传（Android fallback 方案）。
  ///
  /// 在部分定制 ROM（如华为 Android 9）上，photo_manager 的所有 platform
  /// channel 调用都挂起，导致 wechat_assets_picker 的选择器无法弹出。
  /// 此方法用 file_picker（走 Android 原生 Intent ACTION_GET_CONTENT）
  /// 完全绕过 photo_manager。
  Future<void> handleImageFileSelection(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      if (!context.mounted) return;

      for (final file in result.files) {
        await _uploadImagePlatformFile(context, file);
      }
    } catch (e) {
      debugPrint('[attachment_handler] handleImageFileSelection error: $e');
    }
  }

  /// 上传 FilePicker 选中的图片文件
  Future<void> _uploadImagePlatformFile(
    BuildContext context,
    PlatformFile file,
  ) async {
    try {
      // 获取图片字节
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        debugPrint('[attachment_handler] image bytes is null: ${file.name}');
        return;
      }

      // 解析图片尺寸
      int width = 0;
      int height = 0;
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          width = decoded.width;
          height = decoded.height;
        }
      } catch (e) {
        debugPrint('[attachment_handler] decodeImage error: $e');
      }

      final fileName = file.name.isNotEmpty ? file.name : '${Xid()}.jpg';
      final ext = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
          : 'jpg';
      final mime = 'image/$ext';

      final s = _uploadScope;
      final String messageId = Xid().toString();
      final seal = _sealFor(messageId, 'image');
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        '${Xid()}.$ext',
        mime,
        scope: s.scope,
        scopeRef: s.scopeRef,
        seal: seal,
      );

      final message = ImageMessage(
        authorId: _currentUser.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
        id: messageId,
        text: fileName,
        height: height * 1.0,
        width: width * 1.0,
        size: meta['size'] as int?,
        source: meta['object_key'] as String,
        metadata: _withBurnMetadata(
          _withDescriptor({
            'peer_id': peerId,
            'file_hash256': meta['file_hash256'].toString(),
          }, seal),
        ),
      );
      await _sendMessage(message);
    } on Object catch (e) {
      debugPrint('[attachment_handler] _uploadImagePlatformFile error: $e');
    }
  }

  /// 处理图片选择
  Future<void> handleImageSelection(
    BuildContext context,
    Future<List<AssetEntity>?> Function() onSelect,
  ) async {
    try {
      final result = await onSelect();
      if (!context.mounted) return;
      if (result != null) {
        for (var entity in result) {
          await uploadSelectedAsset(context, entity);
        }
      }
    } on StateError catch (e) {
      debugPrint('[chat] handleImageSelection: permission error: $e');
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
        final String messageId = Xid().toString();
        final seal = _sealFor(messageId, 'image');
        final meta = await AttachmentApi.uploadImageEntityViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          seal: seal,
        );
        await handleImageUploadPresign(
          meta,
          entity,
          messageId: messageId,
          seal: seal,
        );
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleImageUploadPresign error: $e');
        // 静默 catch 会让用户以为"点了确认什么都没发生"，必须给可见反馈
        AppLoading.showError(t.common.uploadFailed);
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final s = _uploadScope;
        final String messageId = Xid().toString();
        final seal = _sealFor(messageId, 'video');
        final resp = await AttachmentApi.uploadVideoViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          videoSeal: seal,
          // Slice 7：缩略图必须一起封装，否则预览即泄漏（设计 §3.3）
          thumbSeal: _sealFor(messageId, 'video_thumb'),
        );
        await handleSelectedVideoUpload(resp, messageId: messageId, seal: seal);
      } on Object catch (e) {
        debugPrint('[attachment_handler] handleSelectedVideoUpload error: $e');
        AppLoading.showError(t.common.uploadFailed);
      }
    }
  }

  /// 处理选择的视频上传
  Future<void> handleSelectedVideoUpload(
    Map<String, dynamic> resp, {
    String? messageId,
    AttachmentSealRequest? seal,
  }) async {
    final thumb = (resp['thumb'] as EntityImage).toJson();
    final video = resp['video'] as EntityVideo;

    final message = VideoMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: messageId ?? Xid().toString(),
      source: video.uri,
      text: video.name,
      name: video.name,
      size: video.size ?? 0,
      width: video.width.toDouble(),
      height: video.height.toDouble(),
      // ⚠️ thumb 仍是明文对象（Slice 7）
      metadata: _withBurnMetadata(
        _withDescriptor({
          'peer_id': peerId,
          'file_hash256': video.fileHash256,
          'thumb': thumb,
          // MediaInfo.duration 本身就是**毫秒**，此前又乘了一次 1000，
          // 3 秒的视频会显示成 52:34（BUG#67）。此前视频压根发不出去
          // （BUG#64），所以这个错误一直没暴露。
          if (video.duration != null) 'duration_ms': video.duration!.round(),
        }, seal),
      ),
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
      final String messageId = Xid().toString();
      final seal = _sealFor(messageId, 'voice');
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        name,
        mime,
        process: false,
        scope: s.scope,
        scopeRef: s.scopeRef,
        seal: seal,
      );
      final message = AudioMessage(
        authorId: _currentUser.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
        id: messageId,
        source: meta['object_key'] as String,
        text: '',
        size: bytes.length,
        duration: obj.duration,
        waveform: obj.waveform,
        // ⚠️ waveform 仍随消息发送、未加密时是明文（设计 §3.3 点名的旁路之一）
        metadata: _withBurnMetadata(
          _withDescriptor({
            'peer_id': peerId,
            'file_hash256': meta['file_hash256'].toString(),
            'mime_type': obj.mimeType,
          }, seal),
        ),
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
    final String messageId = Xid().toString();
    final seal = _sealFor(messageId, 'location_thumb');
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
          id: messageId,
          // ⚠️ 经纬度本身在 payload 里：加密会话下随 payload 加密，
          // 非加密会话下明文——与地图快照是否封装无关。
          metadata: _withBurnMetadata(
            _withDescriptor({
              'msg_type': 'location',
              'peer_id': peerId,
              'title': title,
              'address': address,
              'latitude': latitude,
              'longitude': longitude,
              'thumb': imgUrl,
              'size': resp['data']['size'],
              'file_hash256': resp['data']['file_hash256'].toString(),
            }, seal),
          ),
        );
        await _sendMessage(message);
      },
      (Error error) => debugPrint("Location upload error: ${error.toString()}"),
      process: false,
      scope: s.scope,
      scopeRef: s.scopeRef,
      seal: seal,
    );
  }

  // sendExpressionMessage 已删除：唯一调用方是假贴图面板（16 个硬编码 emoji，
  // url 恒为空），本端不再生产 expression 消息。接收侧的
  // ExpressionMessageTypePlugin 保留，仍能渲染他端/历史的贴图消息。
  // 要恢复生产，前提是后端有表情包资源（当前 user_collect 的 kind 1~7 里没有）。

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
