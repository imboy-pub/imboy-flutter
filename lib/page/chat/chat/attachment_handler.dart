/// 聊天页面附件处理器
///
/// 负责处理所有附件相关的上传、选择和消息创建逻辑
library;

import 'dart:convert' show jsonDecode;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:wechat_assets_picker/wechat_assets_picker.dart'
    show AssetEntity, AssetType;
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:image/image.dart' as img;
import 'package:xid/xid.dart';
import 'package:mime/mime.dart';
import 'package:video_compress/video_compress.dart';

import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_conversation_ref.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/service/message_type_constants.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/voice_record/voice_widget.dart' show AudioFile;
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

part 'attachment_handler_multi_image.dart';

/// 附件上传回调
typedef AttachmentUploadedCallback = Future<bool> Function(Message message);

/// E2EE-061 附件封装的**发布开关**。
///
/// Slice 6（下载侧解密 + 完整性门）已合入读取链路：
/// `AttachmentOpenRegistry.materialize`（`IMBoyCacheManager.getSingleFile`
/// 下载后、落盘前）调用 [AttachmentEncryptor.open]，descriptor 经
/// `message_model_mapper` 登记、随加密 payload 落库。后端 `attachment.cipher`
/// 列（migration 00000052）与 `normalize_cipher` fail-closed 校验均已就绪，
/// 密文 confirm 只上报密文哈希/大小。
///
/// 因此开关翻开后：
/// - 旧明文附件不受影响（payload 无 descriptor → 照旧直读）；
/// - 新密文被旧客户端读到只是坏图/坏文件，不泄漏；
/// - registry 冷启动空窗靠图片魔数校验自愈（多一次重下）。
///
/// 翻开关就是这一行；`ChatAttachmentHandler.sealRollout` 会跟着变。
// ponytail: 单个 const 而非 feature flag 服务——它只会翻一次，翻的条件是
// Slice 6 合入，不需要远端下发也不需要按用户灰度。
const bool kAttachmentSealRolloutEnabled = true;

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
    this.ownerGeneration,
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
  final int? ownerGeneration;

  /// 是否已进入 E2EE-061 附件封装的推出阶段，默认 [kAttachmentSealRolloutEnabled]。
  /// 关闭时上传路径逐字节维持今天的明文行为。
  final bool sealRollout;

  /// 安全拦截：如果用户被禁言，直接拦截消息创建与发送，并弹出 EasyLoading 提示 (C13)
  Future<bool> _sendMessage(Message message) async {
    if (isMutedCheck != null && isMutedCheck!()) {
      AppLoading.showError(t.chat.youAreMuted);
      return false;
    }
    if (currentUserOverride == null && (type == 'C2C' || type == 'C2G')) {
      final actor = UserRepoLocal.to;
      final generation = actor.sessionGeneration;
      final uid = actor.currentUid;
      if (message.authorId != uid ||
          actor.isAuthTransitioning ||
          (ownerGeneration != null &&
              !actor.isCurrentSession(ownerGeneration!))) {
        return false;
      }
      final repo = MessageRepo(tableName: MessageRepo.getTableName(type));
      final existing = await repo.find(message.id);
      final tasks = await AttachmentUploadTaskRepo().findByAnchor(
        message.id,
        uid,
      );
      final uncertain = tasks.any(
        (row) =>
            row.businessIntent != null &&
            (jsonDecode(row.businessIntent!) as Map)['state'] != 'uploading',
      );
      final ready =
          tasks.isNotEmpty &&
          tasks.every(
            (row) =>
                (jsonDecode(row.businessIntent!) as Map)['state'] ==
                'outbox_ready',
          );
      if (ready) return true;
      if (existing != null || uncertain) {
        final committed = await MsgApi().isCommitted(
          chatType: type.toLowerCase(),
          peerId: peerId,
          messageId: message.id,
        );
        if (!actor.isCurrentSession(generation) ||
            actor.currentUid != uid ||
            !committed) {
          return false;
        }
        if (existing != null) {
          await repo.update({
            'id': message.id,
            'status': IMBoyMessageStatus.sent,
          });
        }
        return true;
      }
      if (tasks.isNotEmpty) {
        final uploader = ResumableAttachmentUploader();
        await uploader.recoverBusinessOutbox(uid);
        final refreshed = await uploader.repo.findByAnchor(message.id, uid);
        return actor.isCurrentSession(generation) &&
            refreshed.every(
              (r) =>
                  (jsonDecode(r.businessIntent!) as Map)['state'] ==
                  'outbox_ready',
            );
      }
    }
    return await onMessageCreated(message);
  }

  Map<String, dynamic> _safeMessageJson(Message message) {
    final result = message.toJson();
    final metadata = Map<String, dynamic>.from(message.metadata ?? {});
    metadata.remove(AttachmentSealPolicy.descriptorPayloadKey);
    if (message is AudioMessage) {
      metadata['duration_ms'] = message.duration.inMilliseconds;
    }
    result['metadata'] = metadata;
    return result;
  }

  /// 构造附件上传日志的 businessIntent + 消息模板。
  ///
  /// 实现体 [attachmentIntentFor] 在 part 文件（行数门禁 + imageMulti 支持）；
  /// 本方法只是保持既有调用签名的薄委托。
  Map<String, dynamic> pendingMessageIntent(
    String id,
    String kind, {
    String name = '',
    int size = 0,
    double width = 0,
    double height = 0,
    Duration duration = Duration.zero,
    List<double>? waveform,
    Map<String, dynamic> extra = const {},
    int? expectedObjects,
    Map<String, dynamic> intentExtra = const {},
  }) => attachmentIntentFor(
    this,
    id: id,
    kind: kind,
    name: name,
    size: size,
    width: width,
    height: height,
    duration: duration,
    waveform: waveform,
    extra: extra,
    expectedObjects: expectedObjects,
    intentExtra: intentExtra,
  );

  /// Recovery uses the original conversation, template and sending callback.
  Future<void> recoverPendingMessages() async {
    final actor = UserRepoLocal.to;
    final uid = actor.currentUid;
    final generation = actor.sessionGeneration;
    await ResumableAttachmentUploader.recoverCurrentSession();
    if (!actor.isCurrentSession(generation)) return;
    final uploader = ResumableAttachmentUploader();
    final seen = <String>{};
    for (final row in await uploader.repo.listBusinessPending(uid)) {
      if (!actor.isCurrentSession(generation)) return;
      if (row.anchorMsgId == null || !seen.add(row.anchorMsgId!)) continue;
      final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
      if (intent['peer_id'] != peerId ||
          intent['chat_type'] != type.toLowerCase()) {
        continue;
      }
      if (intent['state'] == 'committed' || intent['state'] == 'outbox_ready') {
        continue;
      }
      final group = await uploader.repo.findByAnchor(row.anchorMsgId!, uid);
      if (group.any((r) => r.stage != AttachmentUploadStage.confirmed)) {
        AppLoading.showError('附件恢复未完成，原上传记录已保留；请保留原文件，联网后重新打开会话恢复');
        continue;
      }
      if (intent['state'] != 'uploading' ||
          intent['message_template'] == null) {
        AppLoading.showError('附件消息提交结果未知，已保留原消息，请联网后重新打开会话核对；不会重复发送');
        continue;
      }
      if (intent['state'] == 'uploading') {
        AppLoading.showError('附件消息暂未进入发送队列，上传记录已保留；请联网后重试恢复');
      }
    }
  }

  static Message messageFromPendingTemplate(Map<String, dynamic> json) =>
      ResumableAttachmentUploader.messageFromPendingTemplate(json);

  Map<String, dynamic> _businessIntent(String messageId) {
    if (ownerGeneration != null &&
        !UserRepoLocal.to.isCurrentSession(ownerGeneration!)) {
      throw StateError('attachment owner session changed');
    }
    return {
      'message_id': messageId,
      'author_id': _currentUser.id,
      'peer_id': peerId,
      'chat_type': type.toLowerCase(),
      'conversation_uk3': conversationUk3,
      'state': 'uploading',
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'burn': burnEnabled,
      'burn_after_ms': burnAfterMs,
    };
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
  ///
  /// FWDFIX：转发重封装（send_to_provider → AttachmentForward）复用本函数
  /// 推导目标会话 scope —— 上传 scope 与绑定值 conversation_id 必须同源，
  /// 两份实现哪怕只在排序回退上分歧都会变成隐性错配（见 [_c2cConvKey]），
  /// 因此保持 public static。
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
  /// **同一组判据**：`ChatNetworkService.sendWsMsg` 同时检查群级 E2EE
  /// 强制门与 `E2EEService.shouldEncryptOutgoingPayload(type)`。
  ///
  /// ⚠️ 这里必须把 `encryptPayload` 里的 `groupMegolm` 条件同步进来：
  /// `sendWsMsg` 在全局策略和群级 E2EE 强制门都为假时才会走明文分支。
  /// 因此这里必须与发送入口共享两条判据：群级 E2EE 开启时，即使全局策略
  /// 是 plaintext，消息 payload 仍会进入 `encryptPayload`，附件也必须封装。
  ///
  /// PolicyGate 拿不到策略时抛 [E2eeSecurityException]：必须让异常中止上传，
  /// 不能先把原文件明文上传、再等 `sendWsMsg` 拒绝消息。
  ///
  /// LT02-SEC-01（AI-ID=B）：AI 明文豁免只经共享身份门 [AiPlaintextGate]
  /// 授权（用户显式确认绑定五元组）。本地徽章 account_type 只能渲染 UI
  /// badge，不再单独让附件免封装明文直传。本路径是 **UI 语境**（用户主动
  /// 上传附件），允许触发首次确认弹窗；确认后附件不封装，先于消息侧判定
  /// 且与消息侧同一结论（ATT-01 上传序不变）。
  Future<bool> _payloadWillBeEncrypted() async {
    if (type.toUpperCase() == 'C2G' &&
        await GroupSessionService.to.isGroupE2EE(peerId)) {
      return true;
    }
    return E2EEService.shouldEncryptOutgoingPayload(
      type,
      toId: peerId,
      interactiveConfirm: true,
    );
  }

  @visibleForTesting
  Future<bool> payloadWillBeEncryptedForTest() => _payloadWillBeEncrypted();

  /// 本刀的 fail-closed 语义：payload 将被加密（required E2EE）却拿不到
  /// 绑定输入（如登出半态 senderUid 为空、scope 派生退化）时，**必须在
  /// 上传前中止**——绝不能先把明文附件传上对象存储、再等 `sendWsMsg`
  /// 拒绝消息（那时附件已明文出网，ATT-01 在上传侧就输了）。
  ///
  /// 明文会话（PlaintextAllowed）与开关关闭时 seal 为 null 是**合法**路径：
  /// 不加密就不需要绑定值，照旧明文上传。
  Future<AttachmentSealRequest?> _sealFor(
    String messageId,
    String attachmentId,
  ) async {
    final bool encrypted = await _payloadWillBeEncrypted();
    final seal = buildSealRequest(
      rolloutEnabled: sealRollout,
      payloadWillBeEncrypted: encrypted,
      messageId: messageId,
      conversationId: sealConversationId,
      senderUid: _currentUser.id,
      attachmentId: attachmentId,
    );
    if (seal == null && encrypted && sealRollout) {
      throw E2eeSecurityException('attachment_binding_missing:$attachmentId');
    }
    return seal;
  }

  @visibleForTesting
  Future<AttachmentSealRequest?> sealRequestForTest(
    String messageId,
    String attachmentId,
  ) => _sealFor(messageId, attachmentId);

  /// 附件链路失败时给用户看的文案 + 日志 token（C 区：错误呈现）。
  ///
  /// - E2EE 封装失败（`attachment_binding_missing` / `attachment_partial_seal`，
  ///   均在上传前抛出：未上传任何明文，可安全重试）→ 专用提示
  ///   [Translatables.common.e2eeErrAttachmentSeal]；
  /// - 其余（网络失败、文件 IO 等）→ 通用 [Translatables.common.uploadFailed]。
  ///
  /// [log] 按 Finding 014 口径收窄：E2EE 类只含 errType 与机器可读 reason
  /// （不含密钥/明文/PII）；非 E2EE 类附 detail=异常全文——这条链路的异常
  /// 消息是服务端错误码与网络描述，同样无密钥/明文/PII，而只打 errType 时
  /// 失败完全不可诊断（macOS 冒烟：presign 被拒与网络中断都呈现为
  /// errType=_Exception，无法定位）。
  static ({String toast, String log}) _attachmentFailurePresentation(Object e) {
    if (e is E2eeSecurityException) {
      final isSealFailure =
          e.reason.startsWith('attachment_binding_missing') ||
          e.reason.startsWith('attachment_partial_seal');
      return (
        toast: isSealFailure
            ? t.common.e2eeErrAttachmentSeal
            : t.common.uploadFailed,
        log: 'errType=${e.runtimeType} reason=${e.reason}',
      );
    }
    return (
      toast: t.common.uploadFailed,
      log: 'errType=${e.runtimeType} detail=$e',
    );
  }

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
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: FileType.any);
    } on Object catch (e) {
      // macOS App Sandbox 缺 user-selected entitlement 时，file_picker 抛
      // PlatformException(ENTITLEMENT_NOT_FOUND)；不捕获即 uncaught，
      // 用户点「文件」毫无反馈。取消选择返回空列表，不会进这里。
      debugPrint(
        '[attachment_handler] handleFileSelection error, '
        'errType=${e.runtimeType}',
      );
      AppLoading.showError(
        e is PlatformException
            ? t.common.permissionAcquisitionFailed
            : t.common.operationFailedAgainLater,
      );
      return;
    }
    if (files.isEmpty || files.single.path == null) {
      return;
    }
    if (!context.mounted) return;
    await uploadFile(context, files.single);
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
      // file_picker 4.x platform_interface: length() 可返回 null，本地路径兜底取实际大小
      final int fileSize = (await file.length()) ?? File(path).lengthSync();
      final s = _uploadScope;
      // message_id 必须在上传**之前**生成：它是绑定值（方案甲）的输入。
      final String messageId = Xid().toString();
      final seal = await _sealFor(messageId, 'file');
      // 上传对象名匿名化（对齐图片路径 '${Xid()}.$ext'）：macOS 等桌面端原始
      // 文件名常含空格/中文/emoji，直接进 presign→object_key→PUT 签名链路会
      // 因编码不一致被 Garage 拒收（重试 3 次后抛 Exception）。展示名仍用
      // file.name，落在 FileMessage.name 上，与上传对象名解耦。
      final String rawName = file.name;
      final String ext =
          rawName.contains('.') &&
              rawName.substring(rawName.lastIndexOf('.') + 1).isNotEmpty
          ? rawName.substring(rawName.lastIndexOf('.') + 1).toLowerCase()
          : 'bin';
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        '${Xid()}.$ext',
        // 普通文件按二进制直传；消息仍保留原始名称、扩展名及 MIME。
        'application/octet-stream',
        scope: s.scope,
        scopeRef: s.scopeRef,
        // 群附件消息锚点：messageId 即最终消息 id（服务端按 scope 消费）
        anchorMsgId: messageId,
        messageIntent: pendingMessageIntent(
          messageId,
          'file',
          name: file.name,
          size: fileSize,
          extra: {'mime_type': mime},
        ),
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
        size: fileSize,
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
      final p = _attachmentFailurePresentation(e);
      debugPrint('[attachment_handler] uploadFile failed, ${p.log}');
      // 全量异常落调试日志（同 uploadFileViaPresignCompat 先例）：errType 收窄
      // 日志在「图片成功、文件失败」这类差异场景下无法定位根因，必须能看到
      // presign/confirm/PUT 各步的真实错误消息才能收敛。
      debugPrint('[attachment_handler] uploadFile FAIL err=$e');
      // 静默 catch 会让用户以为"点了发送什么都没发生"，必须给可见反馈
      AppLoading.showError(p.toast);
    }
  }

  /// 处理相机选择
  Future<void> handlePickerSelection(BuildContext context) async {
    if (!context.mounted) return;
    // Phase 2.2: Web 平台不支持原生 camera picker (wechat_camera_picker 是
    // 移动端专用)。提示用户改用 + 号选文件（file_picker 已在 Web 工作）。
    if (kIsWeb) {
      if (context.mounted) {
        AppLoading.showToast(
          'Camera not supported on Web. Use file picker instead.',
        );
      }
      return;
    }
    try {
      // 桌面(macOS/Windows/Linux)：拍摄产物为本地临时文件（不经照片库，
      // 不依赖照片库 TCC 授权），走文件直传管道；移动端维持 AssetEntity
      // 管线不变（kIsWeb 已在上方 return，此处 Platform 安全）。
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final PickedMedia? media = await CapabilityLocator.I
            .get<MediaPickerCapability>()
            .pickCameraCapture(context, dual: true);
        if (!context.mounted || media == null) return;
        await uploadCameraFile(context, File(media.path), type: media.type);
        return;
      }

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
    } on Object catch (e) {
      // 014 口径：相机异常只落 errType，toast 用稳定文案不拼 $e
      debugPrint(
        '[attachment_handler] pickCamera error, errType=${e.runtimeType}',
      );
      if (context.mounted) {
        AppLoading.showToast(t.common.cameraShootFailed);
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
        final seal = await _sealFor(messageId, 'image');
        final meta = await AttachmentApi.uploadImageEntityViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          // 群附件消息锚点：messageId 即最终消息 id，服务端按 scope 消费
          // （group 校验必需，c2c/private 忽略）
          anchorMsgId: messageId,
          messageIntent: pendingMessageIntent(
            messageId,
            'image',
            name: await entity.titleAsync,
            width: entity.width.toDouble(),
            height: entity.height.toDouble(),
          ),
          seal: seal,
        );
        await handleImageUploadPresign(
          meta,
          entity,
          messageId: messageId,
          seal: seal,
        );
      } on Object catch (e) {
        final p = _attachmentFailurePresentation(e);
        debugPrint(
          '[attachment_handler] handleImageUploadPresign failed, ${p.log}',
        );
        // 静默 catch 会让用户以为"点了确认什么都没发生"，必须给可见反馈；
        // E2EE 封装失败（未上传明文、可安全重试）给专用文案
        AppLoading.showError(p.toast);
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final s = _uploadScope;
        final String messageId = Xid().toString();
        final seal = await _sealFor(messageId, 'video');
        final resp = await AttachmentApi.uploadVideoViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          // 群附件消息锚点：messageId 即最终消息 id（服务端按 scope 消费）
          anchorMsgId: messageId,
          messageIntent: pendingMessageIntent(
            messageId,
            'video',
            name: await entity.titleAsync,
            width: entity.width.toDouble(),
            height: entity.height.toDouble(),
            duration: Duration(milliseconds: entity.duration),
          ),
          videoSeal: seal,
          // Slice 7：缩略图必须一起封装，否则预览即泄漏（设计 §3.3）
          thumbSeal: await _sealFor(messageId, 'video_thumb'),
        );
        await handleVideoUpload(resp, messageId: messageId, seal: seal);
      } on Object catch (e) {
        final p = _attachmentFailurePresentation(e);
        debugPrint('[attachment_handler] handleVideoUpload failed, ${p.log}');
        // 同上：视频压缩/上传失败此前完全无提示（BUG#65）
        AppLoading.showError(p.toast);
      }
    }
    // 上传后删除临时文件
    (await entity.file)?.deleteSync();
  }

  /// 桌面拍摄产物上传（本地文件语义）：产物只落临时目录、不经照片库，
  /// 因此不依赖照片库授权（App Sandbox TCC）。图片走 [_uploadImageBytes]
  /// 字节管道；视频元数据经 VideoCompress 探测后走 uploadVideoFileViaPresign
  /// （seal/锚点语义与 uploadCameraAsset 视频分支一致）。无论成败，上传
  /// 尝试后删除临时文件（对齐 uploadCameraAsset 的 deleteSync 语义）。
  Future<void> uploadCameraFile(
    BuildContext context,
    File file, {
    required MediaType type,
  }) async {
    try {
      if (type == MediaType.video) {
        final s = _uploadScope;
        final String messageId = Xid().toString();
        final seal = await _sealFor(messageId, 'video');
        // 探测只读元数据不转码；探测失败不放弃上传（0 值由下游兜底）
        MediaInfo? info;
        try {
          info = await VideoCompress.getMediaInfo(file.path);
        } on Object catch (e) {
          debugPrint('[attachment_handler] getMediaInfo failed: $e');
        }
        final resp = await AttachmentApi.uploadVideoFileViaPresign(
          file,
          durationMs: info?.duration?.round() ?? 0,
          width: info?.width ?? 0,
          height: info?.height ?? 0,
          scope: s.scope,
          scopeRef: s.scopeRef,
          anchorMsgId: messageId,
          messageIntent: pendingMessageIntent(
            messageId,
            'video',
            name: file.path.split('/').last,
            size: await file.length(),
            width: (info?.width ?? 0).toDouble(),
            height: (info?.height ?? 0).toDouble(),
            duration: Duration(milliseconds: info?.duration?.round() ?? 0),
          ),
          videoSeal: seal,
          thumbSeal: await _sealFor(messageId, 'video_thumb'),
        );
        if (resp == null) {
          throw Exception('uploadVideoFileViaPresign returned null');
        }
        await handleVideoUpload(resp, messageId: messageId, seal: seal);
      } else {
        final Uint8List bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          debugPrint('[attachment_handler] camera image bytes is empty');
          return;
        }
        final String name = file.path.split(Platform.pathSeparator).last;
        await _uploadImageBytes(bytes, fileName: name);
      }
    } on Object catch (e) {
      final p = _attachmentFailurePresentation(e);
      debugPrint('[attachment_handler] uploadCameraFile failed, ${p.log}');
      AppLoading.showError(p.toast);
    } finally {
      try {
        if (file.existsSync()) file.deleteSync();
      } on Object {
        // 临时文件删除失败不影响主流程
      }
    }
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
    final message = _videoMessageFromUploadResp(
      resp,
      messageId: messageId,
      seal: seal,
    );
    await _sendMessage(message);
  }

  /// 上传响应 → 视频消息，按返回形状分流（macOS 冒烟实证：明文会话视频
  /// 上传后构造消息直接 _TypeError）：
  ///   - 封装形状 {thumb: EntityImage, video: EntityVideo}——
  ///     uploadVideoViaPresign（AssetEntity 版）恒为此形状；
  ///     uploadVideoFileViaPresign 在 seal 非 null 时同形；
  ///   - 扁平形状 {video_uri, thumb_uri, size, duration, width, height}——
  ///     仅 uploadVideoFileViaPresign 在 seal 为 null（明文会话合法路径）
  ///     时返回。
  VideoMessage _videoMessageFromUploadResp(
    Map<String, dynamic> resp, {
    String? messageId,
    AttachmentSealRequest? seal,
  }) {
    final dynamic thumb = resp['thumb'];
    if (thumb is EntityImage) {
      final video = resp['video'] as EntityVideo;
      return VideoMessage(
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
            'thumb': thumb.toJson(),
            // MediaInfo.duration 本身就是**毫秒**，此前又乘了一次 1000，
            // 3 秒的视频会显示成 52:34（BUG#67）。此前视频压根发不出去
            // （BUG#64），所以这个错误一直没暴露。
            if (video.duration != null) 'duration_ms': video.duration!.round(),
          }, seal),
        ),
      );
    }
    // 扁平形状（明文会话）：无 file_hash256（不加密即无封装元数据）；
    // thumb 只需 uri（气泡端 message_video_builder 只读 thumb['uri']）。
    final String videoUri = resp['video_uri'] as String? ?? '';
    if (videoUri.isEmpty) {
      throw Exception('uploadVideo: 响应缺少 thumb/video（形状不符）');
    }
    final String name = videoUri.split('/').last;
    return VideoMessage(
      authorId: _currentUser.id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        DateTimeHelper.millisecond(),
        isUtc: true,
      ),
      id: messageId ?? Xid().toString(),
      source: videoUri,
      text: name,
      name: name,
      size: (resp['size'] as num?)?.toInt() ?? 0,
      width: (resp['width'] as num?)?.toDouble() ?? 0,
      height: (resp['height'] as num?)?.toDouble() ?? 0,
      metadata: _withBurnMetadata(
        _withDescriptor(<String, dynamic>{
          'peer_id': peerId,
          'thumb': <String, dynamic>{'uri': resp['thumb_uri'] ?? ''},
          // 扁平形状的 duration 单位是毫秒（uploadVideoFileViaPresign 透传
          // durationMs），与封装路径的 duration_ms 同单位。
          if (resp['duration'] != null)
            'duration_ms': (resp['duration'] as num).round(),
        }, seal),
      ),
    );
  }

  /// 通过 FilePicker 选择图片并上传（Android/macOS fallback 方案）。
  ///
  /// Android：部分定制 ROM（如华为 Android 9）上 photo_manager 的所有
  /// platform channel 调用都挂起，导致 wechat_assets_picker 的选择器无法
  /// 弹出，用 file_picker（走系统原生 Intent ACTION_GET_CONTENT）完全绕过。
  /// macOS：App Sandbox 下 wechat_assets_picker 依赖照片库 TCC 授权（可拒），
  /// 同样绕行系统选择器（配合 Runner entitlements 的 user-selected read-only）。
  Future<void> handleImageFileSelection(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isEmpty) return;
      if (!context.mounted) return;

      for (final file in files) {
        await _uploadImagePlatformFile(file);
      }
    } on Object catch (e) {
      debugPrint(
        '[attachment_handler] handleImageFileSelection error, '
        'errType=${e.runtimeType}',
      );
      // 与 handleFileSelection 同款：失败必须可见，否则用户以为点击无效
      AppLoading.showError(
        e is PlatformException
            ? t.common.permissionAcquisitionFailed
            : t.common.operationFailedAgainLater,
      );
    }
  }

  /// 上传 FilePicker 选中的图片文件
  Future<void> _uploadImagePlatformFile(PlatformFile file) async {
    // file_picker 12 移除同步 bytes，统一走异步读取
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      debugPrint('[attachment_handler] image bytes is null: ${file.name}');
      return;
    }
    await _uploadImageBytes(bytes, fileName: file.name);
  }

  /// 图片字节上传公共管道（file_picker 选中文件与桌面拍摄产物共用）：
  /// 尺寸解码 → seal → presign 直传 → ImageMessage。
  Future<void> _uploadImageBytes(
    Uint8List bytes, {
    required String fileName,
    String? anchorId,
  }) async {
    try {
      // 解析图片尺寸
      int width = 0;
      int height = 0;
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          width = decoded.width;
          height = decoded.height;
        }
      } on Object catch (e) {
        debugPrint(
          '[attachment_handler] decodeImage error, errType=${e.runtimeType}',
        );
      }

      final name = fileName.isNotEmpty ? fileName : '${Xid()}.jpg';
      final ext = name.contains('.')
          ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
          : 'jpg';
      final mime = 'image/$ext';

      final s = _uploadScope;
      final String messageId = anchorId ?? Xid().toString();
      final seal = await _sealFor(messageId, 'image');
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        '${Xid()}.$ext',
        mime,
        scope: s.scope,
        scopeRef: s.scopeRef,
        anchorMsgId: messageId,
        messageIntent: pendingMessageIntent(
          messageId,
          'image',
          name: name,
          size: bytes.length,
          width: width.toDouble(),
          height: height.toDouble(),
        ),
        seal: seal,
      );

      final message = ImageMessage(
        authorId: _currentUser.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
        id: messageId,
        text: name,
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
      final p = _attachmentFailurePresentation(e);
      debugPrint('[attachment_handler] _uploadImageBytes failed, ${p.log}');
      // 静默 catch 会让用户以为"点了发送什么都没发生"，必须给可见反馈
      AppLoading.showError(p.toast);
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
        // ≥2 张图片聚合为单条 imageMulti，其余逐条（见 part 文件）
        await uploadPickedImages(this, context, result);
      }
    } on StateError catch (e) {
      debugPrint(
        '[attachment_handler] handleImageSelection permission error, '
        'errType=${e.runtimeType}',
      );
      // 相册权限被拒（移动端未授权 / macOS TCC 拒绝）：只打日志会变成
      // 「点了没反应」，提示文案与 moment_album_picker 保持一致
      AppLoading.showError(t.common.permissionAcquisitionFailed);
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
        final seal = await _sealFor(messageId, 'image');
        final meta = await AttachmentApi.uploadImageEntityViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          // 群附件消息锚点：messageId 即最终消息 id，服务端按 scope 消费
          // （group 校验必需，c2c/private 忽略）
          anchorMsgId: messageId,
          messageIntent: pendingMessageIntent(
            messageId,
            'image',
            name: await entity.titleAsync,
            width: entity.width.toDouble(),
            height: entity.height.toDouble(),
          ),
          seal: seal,
        );
        await handleImageUploadPresign(
          meta,
          entity,
          messageId: messageId,
          seal: seal,
        );
      } on Object catch (e) {
        final p = _attachmentFailurePresentation(e);
        debugPrint(
          '[attachment_handler] handleImageUploadPresign failed, ${p.log}',
        );
        // 静默 catch 会让用户以为"点了确认什么都没发生"，必须给可见反馈；
        // E2EE 封装失败（未上传明文、可安全重试）给专用文案
        AppLoading.showError(p.toast);
      }
    } else if (entity.type == AssetType.video) {
      // S5：视频走 Garage presign 直传（缩略图+视频双 object_key）。
      try {
        final s = _uploadScope;
        final String messageId = Xid().toString();
        final seal = await _sealFor(messageId, 'video');
        final resp = await AttachmentApi.uploadVideoViaPresign(
          entity,
          scope: s.scope,
          scopeRef: s.scopeRef,
          // 群附件消息锚点：messageId 即最终消息 id（服务端按 scope 消费）
          anchorMsgId: messageId,
          messageIntent: pendingMessageIntent(
            messageId,
            'video',
            name: await entity.titleAsync,
            width: entity.width.toDouble(),
            height: entity.height.toDouble(),
            duration: Duration(milliseconds: entity.duration),
          ),
          videoSeal: seal,
          // Slice 7：缩略图必须一起封装，否则预览即泄漏（设计 §3.3）
          thumbSeal: await _sealFor(messageId, 'video_thumb'),
        );
        await handleSelectedVideoUpload(resp, messageId: messageId, seal: seal);
      } on Object catch (e) {
        final p = _attachmentFailurePresentation(e);
        debugPrint(
          '[attachment_handler] handleSelectedVideoUpload failed, ${p.log}',
        );
        AppLoading.showError(p.toast);
      }
    }
  }

  /// 处理选择的视频上传
  Future<void> handleSelectedVideoUpload(
    Map<String, dynamic> resp, {
    String? messageId,
    AttachmentSealRequest? seal,
  }) async {
    final message = _videoMessageFromUploadResp(
      resp,
      messageId: messageId,
      seal: seal,
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
      final seal = await _sealFor(messageId, 'voice');
      final meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        name,
        mime,
        process: false,
        scope: s.scope,
        scopeRef: s.scopeRef,
        anchorMsgId: messageId,
        messageIntent: pendingMessageIntent(
          messageId,
          'voice',
          size: bytes.length,
          duration: obj.duration,
          waveform: obj.waveform,
          extra: {'mime_type': mime},
        ),
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
      final p = _attachmentFailurePresentation(e);
      debugPrint('[attachment_handler] handleVoiceSelection failed, ${p.log}');
      // 同 C1：语音上传失败此前完全无提示，必须给可见反馈
      AppLoading.showError(p.toast);
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
    try {
      final image = img.decodeImage(imageBytes)!;
      final result = img.encodeJpg(image, quality: 65);
      final s = _uploadScope;
      final String messageId = Xid().toString();
      final seal = await _sealFor(messageId, 'location_thumb');
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
        (Error error) =>
            debugPrint('Location upload error, errType=${error.runtimeType}'),
        process: false,
        scope: s.scope,
        scopeRef: s.scopeRef,
        // 群附件消息锚点：messageId 即最终消息 id（服务端按 scope 消费）
        anchorMsgId: messageId,
        messageIntent: pendingMessageIntent(
          messageId,
          'location',
          size: result.length,
          extra: {
            'title': title,
            'address': address,
            'latitude': latitude,
            'longitude': longitude,
          },
        ),
        seal: seal,
      );
    } on Object catch (e) {
      final p = _attachmentFailurePresentation(e);
      debugPrint(
        '[attachment_handler] handleLocationSelection failed, ${p.log}',
      );
      // 位置消息上传失败同样必须有可见反馈（与图片/语音同口径）
      AppLoading.showError(p.toast);
    }
  }

  // sendExpressionMessage 已删除：唯一调用方是假贴图面板（16 个硬编码 emoji，
  // url 恒为空），本端不再生产 expression 消息。接收侧的
  // ExpressionMessageTypePlugin 保留，仍能渲染他端/历史的贴图消息。
  // 要恢复生产，前提是后端有表情包资源（当前 user_collect 的 kind 1~7 里没有）。

  /// 收藏 info 里的消息 payload，归一成 map。
  ///
  /// 历史收藏三种形态：
  /// - 信封形（现行客户端）：info['payload'] 是 map（或 JSON 字符串）；
  /// - 解密形（v1/v3 加密收藏）：`decryptIncomingPayload` 把解密原文整体
  ///   替换进 info，内容平铺在顶层，没有 payload 键——剔除信封列后
  ///   从 info 顶层提取（列表渲染 buildItemBody 读的就是这些顶层键）；
  /// - 坏形（解密失败/密文残留）：payload 是非 JSON 密文串，兜底同样走
  ///   info 平铺，仍为空则由调用方放弃发送。
  @visibleForTesting
  static Map<String, dynamic> collectPayload(UserCollectModel collect) {
    final Object? raw = collect.info['payload'];
    final Map<String, dynamic> payload = <String, dynamic>{};
    if (raw is Map<String, dynamic>) {
      payload.addAll(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) payload.addAll(decoded);
      } on FormatException {
        // 历史密文/脏数据：走 info 平铺兜底
      }
    }
    if (payload.isEmpty) {
      collect.info.forEach((Object? key, Object? value) {
        if (value != null && !_envelopeKeys.contains(key.toString())) {
          payload[key.toString()] = value;
        }
      });
    }
    return payload;
  }

  /// MessageModel 信封列（toJson/decryptIncomingPayload 的结构性键）。
  /// info 平铺兜底时必须剔除，避免把 from_id/e2ee 密文等带进线上 payload。
  static const Set<String> _envelopeKeys = <String>{
    'id',
    'auto_id',
    'type',
    'from_id',
    'to_id',
    'status',
    'created_at',
    'is_author',
    'topic_id',
    'conversation_uk3',
    'msg_type',
    'action',
    'e2ee',
    'sender_did',
    'sender_dtype',
    'payload',
    'metadata',
    'client_send_ts',
  };

  /// toTypeMessage 管线有专属分支、能构造成 flutter_chat_core 类型化消息的
  /// msg_type；其余（location/visitCard 等业务卡）走直构 CustomMessage。
  static const Set<String> _pipelineMsgTypes = <String>{
    MessageType.text,
    MessageType.image,
    MessageType.file,
    MessageType.video,
    MessageType.voice,
  };

  /// 收藏对应的线上 msg_type：info 顶层 → payload 内 → kind 推导，
  /// 统一归一到渲染真值（audio→voice，与 MessageTypeNormalizer 同口径）。
  ///
  /// 历史收藏常缺顶层 msg_type——直接 MessageModel.fromJson(info)
  /// 会因 msg_type 为空命中「无效消息类型」占位分支，把「[不支持的消息]」
  /// 当正文发出去（真机实证：macOS 收藏的位置消息转发到群后显示
  /// [不支持的消息]）。'unsupported' 与 v2.0 之前的 'e2ee' 是脏值，
  /// 同样不能作为发送类型。
  @visibleForTesting
  static String collectMsgType(
    UserCollectModel collect,
    Map<String, dynamic> payload,
  ) {
    final Set<String> validTypes = <String>{
      ...MessageType.allTypes,
      MessageType.custom,
    };
    final List<Object?> candidates = <Object?>[
      collect.info['msg_type'],
      payload['msg_type'],
    ];
    for (final Object? v in candidates) {
      final String s = v?.toString() ?? '';
      if (validTypes.contains(s)) {
        return s == MessageType.audio ? MessageType.voice : s;
      }
    }
    // Kind 被收藏的资源种类：
    // 1 文本 2 图片 3 语音 4 视频 5 文件 6 位置消息 7 个人名片
    switch (collect.kind) {
      case 1:
        return MessageType.text;
      case 2:
        return MessageType.image;
      case 3:
        return MessageType.voice;
      case 4:
        return MessageType.video;
      case 5:
        return MessageType.file;
      case 6:
        return MessageType.location;
      case 7:
        return MessageType.visitCard;
      default:
        return MessageType.custom;
    }
  }

  /// 收藏 → 出站 payload：内容归一 + msg_type 解析 + 目标会话重绑定（纯函数）。
  ///
  /// 内容无法还原（加密收藏解密失败/空收藏）时抛异常，由调用方给可见反馈，
  /// 不生产脏消息。
  @visibleForTesting
  static Map<String, dynamic> collectOutboundPayload(
    UserCollectModel collect, {
    required String targetPeerId,
  }) {
    // 仍未解密的加密收藏（解密失败时 decryptIncomingPayload 原样保留）：
    // 内容还是密文，fail-closed 拒发，不能把密文/空壳当消息内容发出
    final Object? e2ee = collect.info['e2ee'];
    if (e2ee != null && e2ee != '') {
      throw Exception('collect ${collect.kindId} is still encrypted');
    }
    final Map<String, dynamic> payload = collectPayload(collect);
    if (payload.isEmpty) {
      // 内容无法还原（本地缓存 info 为空/只剩信封列）：把形状带给日志便于
      // 定位历史数据形态——只落键名与值类型，不落内容（Finding 014 口径）
      final String shape = collect.info.keys
          .map((k) => '$k:${collect.info[k].runtimeType}')
          .join(',');
      throw Exception(
        'collect ${collect.kindId} payload unavailable, '
        'kind=${collect.kind}, infoKeys=[$shape]',
      );
    }
    final String msgType = collectMsgType(collect, payload);
    // 文本正文兜底：部分旧收藏把 text 平铺在 info 顶层（列表渲染同款兜底）
    if (payload['text'] == null && collect.info['text'] != null) {
      payload['text'] = collect.info['text'];
    }
    // 历史视频收藏内容嵌套在 payload['video'] 里（后端 user_collect_logic
    // kind-4 与列表渲染 buildItemBody 同款形状）；线上 video payload 是顶层
    // uri/size/width/height，发送前提升，否则 uri 为空发出去是坏视频
    if (msgType == MessageType.video &&
        (payload['uri']?.toString().isEmpty ?? true) &&
        payload['video'] is Map) {
      (payload['video'] as Map).forEach((Object? k, Object? v) {
        if (v != null && payload[k.toString()] == null) {
          payload[k.toString()] = v;
        }
      });
    }
    // 源会话绑定不得跟随收藏转发（与 buildForwardPayload 同一口径）：
    // getMsgFromTMsg 以 metadata['peer_id'] 为 toId，残留源 peer_id 会串会话
    payload
      ..remove('peer_id')
      ..remove('conversation_uk3')
      ..['msg_type'] = msgType
      ..['peer_id'] = targetPeerId;
    return payload;
  }

  /// 发送收藏消息
  ///
  /// 输入是收藏项而非裸 info：msg_type 缺失、payload 形态不一、源会话
  /// 绑定残留（peer_id/conversation_uk3）三类历史问题都在
  /// [collectOutboundPayload] 里消化。结构化类型（text/image/file/video/
  /// voice）复用 toTypeMessage 管线构造；位置/名片等 custom 族
  /// toTypeMessage 无对应分支，直构干净的 CustomMessage（与
  /// handleLocationSelection/sendVisitCardMessage 同一形状），避免兜底
  /// 分支把 unsupported/error 噪声写进线上 payload。
  Future<void> sendCollectMessage(
    BuildContext context,
    UserCollectModel collect,
  ) async {
    final Map<String, dynamic> payload = collectOutboundPayload(
      collect,
      targetPeerId: peerId,
    );
    final String msgType = collectMsgType(collect, payload);
    final DateTime created = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
      isUtc: true,
    );
    final Message msg0;
    if (_pipelineMsgTypes.contains(msgType)) {
      final data = Map<String, dynamic>.from(collect.info)
        ..addAll({
          MessageRepo.id: Xid().toString(),
          MessageRepo.from: UserRepoLocal.to.currentUid,
          MessageRepo.to: peerId,
          MessageRepo.status: 10,
          MessageRepo.conversationUk3: conversationUk3,
          MessageRepo.createdAt: created,
          'payload': payload,
          'msg_type': msgType,
        });
      msg0 = await MessageModel.fromJson(data).toTypeMessage();
    } else {
      msg0 = CustomMessage(
        authorId: _currentUser.id,
        createdAt: created,
        id: Xid().toString(),
        metadata: _withBurnMetadata(payload),
      );
    }
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
        'peer_id': peerId,
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
        'peer_id': peerId,
        'id': data['id'],
        'amount': data['amount'],
        'remark': data['remark'],
        'status': 'pending',
      }),
    );
    await _sendMessage(message);
  }
}
