/// E2EE-061 / FWDFIX —— 加密附件转发的重封装（Signal 同款语义）
///
/// ## 为什么转发必须重封装（run-20261003-094804 C07 根因结论）
///
/// 发送侧附件密文块的 AAD 绑定值是
/// `SHA-256(canonical_cbor({message_id, conversation_id, sender_uid}))`
/// （方案甲，[AttachmentBinding]）。旧转发语义（`buildForwardPayload` 原样
/// 复制源 metadata）把 descriptor 与密文 object_key 原样搬进新消息——
/// 新消息拿到**新 message_id**、进**新会话**、发送者是**转发者**，
/// 接收侧按新三元组重算绑定 → AAD 失配 → `AttachmentOpenException`
/// fail-closed 拒开（C04「命运一」钉住的行为：方向正确，纯功能缺口）。
///
/// 正确修复 = 转发时**本地解密**（经 [AttachmentEncryptor.open] 认证解密，
/// 完整性门全过才拿明文）→ 按目标会话三元组**重封装**（全新独立 content
/// key / base nonce，descriptor 进新消息的 PFv3 加密信封）→ 经既有上传入口
/// **重上传**（`anchor_msg_id` = 新消息 id，scope = 目标会话 scope，目标
/// 会话成员据此获得下载授权）→ 发送新消息。
///
/// ## 明文目标域（三域一致性，C06）
///
/// 源消息带 content key（descriptor 在场）而目标会话 payload 不会被加密
/// （AI 托管域已确认豁免 / 全局 plaintext 档）时，**拒绝转发**：
/// descriptor 含解密钥匙，明文出网比明文附件更糟（E2EE-061）。该语义与
/// 既有出网闸门（`carriesContentKey`，chat_network_service）与重发闸门
/// （`shouldBlockPlaintextRetry`，message_retry）三域同规
/// （`three_domain_consistency_test.dart`「带 content key 的明文行重试必拦：
/// 优先级高于任何域的策略判定」）。本模块把同一拒绝**提前到转发动作处**
/// 显式失败（不落库、不产生「落库后被出网闸门卡成死信」的半转发状态），
/// 双闸门原样保留作为纵深防御。
///
/// ## 失败语义
///
/// 任何一步失败（下载原件 / 认证解密 / 重上传）→ 抛
/// [AttachmentForwardException] → 调用方（send_to_provider）**不落库**、
/// 返回失败；无任何半转发状态残留。重试 = 全新 Xid + 全新独立密钥重封装，
/// 天然幂等（与整链重传语义一致，见 attachment_coverage_matrix 组「重试
/// trace」：跨对象/跨会话绝不复用 key/nonce）。
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:imboy/service/e2ee/attachment_binding.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/store/api/attachment_api.dart';

/// 密文对象字节获取器（默认实现见 [AttachmentForward.defaultFetchCiphertext]，
/// 测试注入 fake 以脱离网络）。
typedef CiphertextFetcher = Future<Uint8List> Function(String objectKey);

/// 转发失败。**不产生半转发状态**：抛出即表示「这条转发没有发生」。
class AttachmentForwardException implements Exception {
  /// 机器可读稳定码（不进 UI、不含密钥/明文/PII）：
  /// - `attachment_forward_plaintext_target`：目标会话 payload 不会加密，
  ///   content key 不得明文出网 → 拒绝（三域一致性）；
  /// - `attachment_forward_undecryptable`：源消息在本机推不出解密绑定输入
  ///   （会话类型非标/字段缺失）——fail-closed，不静默复制旧 descriptor；
  /// - `attachment_forward_open_failed`：原件认证解密失败（缺钥/密文损坏）；
  /// - `attachment_forward_fetch_failed`：原件密文下载失败；
  /// - `attachment_forward_upload_failed`：重封装后上传失败。
  final String reason;

  /// 下层异常类型（仅 runtimeType，Finding 014 口径）。
  final String? cause;

  const AttachmentForwardException(this.reason, [this.cause]);

  @override
  String toString() =>
      'AttachmentForwardException: $reason${cause == null ? '' : ' ($cause)'}';
}

/// 转发动作的规划结果（纯函数，见 [AttachmentForward.decide]）。
sealed class AttachmentForwardDecision {
  const AttachmentForwardDecision();
}

/// 源消息不带 content key（纯文本 / 历史明文附件）——照旧原样转发，
/// 既有行为逐字节不变。
final class ForwardNotSealed extends AttachmentForwardDecision {
  const ForwardNotSealed();
}

/// 需要重封装：本地解密 → 新绑定/新密钥 → 重上传。
final class ForwardReSeal extends AttachmentForwardDecision {
  const ForwardReSeal();
}

/// 拒绝转发（reason 取 [AttachmentForwardException] 稳定码）。
final class ForwardRejected extends AttachmentForwardDecision {
  final String reason;
  const ForwardRejected(this.reason);
}

/// 重封装产物：调用方据此覆盖转发 payload 的附件字段。
class ForwardedAttachment {
  /// 新（主对象）descriptor——含新独立 content key / base nonce，
  /// thumb（若存在）为新缩略图 descriptor。
  final AttachmentDescriptor descriptor;

  /// 新 object_key（目标会话 scope 上传，anchor=新消息 id）。
  final String objectKey;

  /// 与服务端 confirm 同值的**密文**哈希——消息体 `file_hash256` 必须与
  /// 服务端 `attachment.file_hash256` 同值（收藏引用计数与孤儿清理按它 JOIN）。
  final String fileHash256;

  /// 明文大小（进加密 payload 给 UI；密文大小只在 confirm）。
  final int plainSize;

  /// 新缩略图 object_key（视频双对象 / 位置缩略图；无 thumb 时 null）。
  final String? thumbObjectKey;

  /// 新缩略图密文哈希（thumb 元数据回填用；无 thumb 时 null）。
  final String? thumbFileHash256;

  const ForwardedAttachment({
    required this.descriptor,
    required this.objectKey,
    required this.fileHash256,
    required this.plainSize,
    this.thumbObjectKey,
    this.thumbFileHash256,
  });
}

class AttachmentForward {
  AttachmentForward._();

  /// 纯判定：这次转发怎么处理源附件。
  ///
  /// - 源 payload 无 descriptor → [ForwardNotSealed]（明文附件/文本照旧）；
  /// - 有 descriptor 且目标 payload 不会加密 → [ForwardRejected]
  ///   （`attachment_forward_plaintext_target`，三域一致性：content key
  ///   不得明文出网）；
  /// - 有 descriptor 但源绑定输入推不出（conversation_uk3 前缀非标 /
  ///   fromUid/toUid/messageId 缺失）→ [ForwardRejected]
  ///   （`attachment_forward_undecryptable`，fail-closed：宁可明确失败，
  ///   不静默复制一个在新会话打不开、在旧会话仍有效的 descriptor）；
  /// - 其余 → [ForwardReSeal]。
  static AttachmentForwardDecision decide({
    required Object? sourceMetadata,
    required bool targetPayloadWillBeEncrypted,
    required String sourceMessageId,
    required String sourceChatType,
    required String sourceFromUid,
    required String sourceToUid,
  }) {
    if (!AttachmentSealPolicy.carriesContentKey(sourceMetadata)) {
      return const ForwardNotSealed();
    }
    if (!targetPayloadWillBeEncrypted) {
      return const ForwardRejected('attachment_forward_plaintext_target');
    }
    // 与 AttachmentOpener.bindingFor 同一组 fail-closed 校验：推不出绑定
    // 输入 = 本机解不开原件 = 转发不可能成功，提前显式失败。
    if (sourceMessageId.isEmpty ||
        sourceChatType.isEmpty ||
        sourceFromUid.isEmpty ||
        sourceToUid.isEmpty) {
      return const ForwardRejected('attachment_forward_undecryptable');
    }
    return const ForwardReSeal();
  }

  /// 源会话类型推导：`C2C_xxx` / `C2G_xxx`（大小写/分隔符不敏感）→
  /// `C2C` / `C2G`；其余空串（fail-closed，不赌）。
  ///
  /// 转发侧拿不到源 ConversationModel，会话类型只能从源消息
  /// `metadata['conversation_uk3']` 前缀推导（toTypeMessage 保证该字段在场）。
  static String chatTypeFromConversationUk3(String? uk3) {
    final String uk = (uk3 ?? '').toUpperCase();
    if (uk.startsWith('C2G')) return 'C2G';
    if (uk.startsWith('C2C')) return 'C2C';
    return '';
  }

  /// 重封装编排：下载源密文 → 认证解密 → 新绑定重 seal → 重上传。
  ///
  /// [sourcePayload] 是源消息完整 metadata（含 descriptor；`uri` 字段
  /// **不被依赖**——下载源一律取 `descriptor.object_key`，它才是权威）。
  ///
  /// 源绑定四元组（[sourceMessageId]/[sourceChatType]/[sourceFromUid]/
  /// [sourceToUid]）来自源消息本身；转发者是源会话参与者，按方案甲双方能
  /// 算出同一 AAD（C2C 整数归一化与方向无关、C2G 两端 to 同为 gid，
  /// 见 [AttachmentConversationRef]）。
  ///
  /// 新绑定三元组 =（[newMessageId]，[targetConversationId]（目标会话
  /// scope_ref，与上传侧 `deriveUploadScope` 同源），[forwarderUid]）。
  /// 主体与缩略图共用同一新绑定（同一条消息，与发送侧一致）。
  ///
  /// 上传顺序沿用 Slice 7：先缩略图、后主体（主体 seal 时挂入 thumb
  /// descriptor）。任一步失败抛 [AttachmentForwardException]，不留下
  /// 「上传了对象但没有消息引用」之外的任何本地状态（孤儿对象由服务端按
  /// file_hash256 JOIN 的既有清理机制兜底）。
  static Future<ForwardedAttachment> reSeal({
    required Map<String, dynamic> sourcePayload,
    required String sourceMessageId,
    required String sourceChatType,
    required String sourceFromUid,
    required String sourceToUid,
    required String newMessageId,
    required String targetScope,
    required String targetConversationId,
    required String forwarderUid,
    CiphertextFetcher? fetchCiphertext,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
  }) async {
    final fetcher = fetchCiphertext ?? defaultFetchCiphertext;

    final AttachmentDescriptor sourceDescriptor;
    try {
      final d = AttachmentOpener.descriptorFrom(sourcePayload);
      if (d == null) {
        // carriesContentKey 为 true 却解析不出 descriptor = 语义缝隙，
        // fail-closed 拒绝，不把坏 descriptor 复制进新会话。
        throw const AttachmentForwardException(
          'attachment_forward_undecryptable',
        );
      }
      sourceDescriptor = d;
    } on AttachmentOpenException catch (e) {
      throw AttachmentForwardException(
        'attachment_forward_undecryptable',
        '${e.runtimeType}',
      );
    }

    final bindings = _forwardBindings(
      sourceMessageId: sourceMessageId,
      sourceChatType: sourceChatType,
      sourceFromUid: sourceFromUid,
      sourceToUid: sourceToUid,
      newMessageId: newMessageId,
      targetConversationId: targetConversationId,
      forwarderUid: forwarderUid,
    );
    return _reSealObject(
      sourceDescriptor: sourceDescriptor,
      sourceBinding: bindings.source,
      newBinding: bindings.target,
      newMessageId: newMessageId,
      targetScope: targetScope,
      targetConversationId: targetConversationId,
      fetcher: fetcher,
      presignFn: presignFn,
      putFn: putFn,
      confirmFn: confirmFn,
    );
  }

  /// 多图（imageMulti）逐图重封装。
  ///
  /// 返回改写后的 `images[]` 元素列表（顺序与源一致）：带 descriptor 的项
  /// 下载 → 认证解密 → 按目标会话新绑定/新密钥重封装 → 重上传，并改写
  /// uri / file_hash256 / size / descriptor（attachmentId 沿用源值，逐图天然
  /// 互异）；明文项（历史明文多图）原样保留。任一项失败抛
  /// [AttachmentForwardException]——整条转发不发生，无半转发状态。
  static Future<List<Map<String, dynamic>>> reSealImages({
    required Map<String, dynamic> sourcePayload,
    required String sourceMessageId,
    required String sourceChatType,
    required String sourceFromUid,
    required String sourceToUid,
    required String newMessageId,
    required String targetScope,
    required String targetConversationId,
    required String forwarderUid,
    CiphertextFetcher? fetchCiphertext,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
  }) async {
    final fetcher = fetchCiphertext ?? defaultFetchCiphertext;
    final items = sourcePayload[AttachmentSealPolicy.imagesPayloadKey];
    if (items is! List) {
      throw const AttachmentForwardException(
        'attachment_forward_undecryptable',
      );
    }
    final bindings = _forwardBindings(
      sourceMessageId: sourceMessageId,
      sourceChatType: sourceChatType,
      sourceFromUid: sourceFromUid,
      sourceToUid: sourceToUid,
      newMessageId: newMessageId,
      targetConversationId: targetConversationId,
      forwarderUid: forwarderUid,
    );
    final out = <Map<String, dynamic>>[];
    for (final e in items) {
      if (e is! Map) {
        throw const AttachmentForwardException(
          'attachment_forward_undecryptable',
        );
      }
      final item = Map<String, dynamic>.from(e);
      final List<AttachmentDescriptor> found;
      try {
        found = AttachmentOpener.descriptorsFrom(item);
      } on AttachmentOpenException catch (err) {
        throw AttachmentForwardException(
          'attachment_forward_undecryptable',
          '${err.runtimeType}',
        );
      }
      if (found.isEmpty) {
        out.add(item);
        continue;
      }
      final forwarded = await _reSealObject(
        sourceDescriptor: found.first,
        sourceBinding: bindings.source,
        newBinding: bindings.target,
        newMessageId: newMessageId,
        targetScope: targetScope,
        targetConversationId: targetConversationId,
        fetcher: fetcher,
        presignFn: presignFn,
        putFn: putFn,
        confirmFn: confirmFn,
      );
      out.add(
        item
          ..['uri'] = forwarded.objectKey
          ..['file_hash256'] = forwarded.fileHash256
          ..['size'] = forwarded.plainSize
          ..[AttachmentSealPolicy.descriptorPayloadKey] = forwarded.descriptor
              .toMap(),
      );
    }
    return out;
  }

  /// 源 / 目标绑定值（方案甲）。
  ///
  /// 源绑定值由转发者以参与者身份重算（与原发送/接收侧同一函数）；目标
  /// 三元组全部换成目标会话语境（目标 conversation_id 为空 = 会话类型推不出
  /// scope_ref 的矛盾态：正常 decide 已在明文域/非标源处拒绝，这里防御性
  /// 收敛为显式失败，不让 AttachmentOpenException / AttachmentBindingException
  /// 以裸类型穿透调用方）。
  static ({Uint8List source, Uint8List target}) _forwardBindings({
    required String sourceMessageId,
    required String sourceChatType,
    required String sourceFromUid,
    required String sourceToUid,
    required String newMessageId,
    required String targetConversationId,
    required String forwarderUid,
  }) {
    final Uint8List sourceBinding;
    try {
      sourceBinding = AttachmentOpener.bindingFor(
        messageId: sourceMessageId,
        chatType: sourceChatType,
        fromUid: sourceFromUid,
        toUid: sourceToUid,
      );
    } on AttachmentOpenException catch (e) {
      throw AttachmentForwardException(
        'attachment_forward_undecryptable',
        '${e.runtimeType}',
      );
    }
    final Uint8List newBinding;
    try {
      newBinding = AttachmentBinding.compute(
        messageId: newMessageId,
        conversationId: targetConversationId,
        senderUid: forwarderUid,
      );
    } on AttachmentBindingException catch (e) {
      throw AttachmentForwardException(
        'attachment_forward_undecryptable',
        '${e.runtimeType}',
      );
    }
    return (source: sourceBinding, target: newBinding);
  }

  /// 单个对象（含其缩略图）的解密 → 重封装 → 重上传。
  ///
  /// 上传顺序沿用 Slice 7：先缩略图、后主体（主体 seal 时挂入 thumb
  /// descriptor）。主体与缩略图共用同一新绑定（同一条消息，与发送侧一致）。
  static Future<ForwardedAttachment> _reSealObject({
    required AttachmentDescriptor sourceDescriptor,
    required Uint8List sourceBinding,
    required Uint8List newBinding,
    required String newMessageId,
    required String targetScope,
    required String targetConversationId,
    required CiphertextFetcher fetcher,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
  }) async {
    // ── 缩略图（若在）：先解密重封装上传 ──────────────────────────────
    AttachmentDescriptor? newThumbDescriptor;
    String? newThumbObjectKey;
    String? newThumbHash;
    final sourceThumb = sourceDescriptor.thumb;
    if (sourceThumb != null) {
      final thumbPlain = await _decryptObject(
        fetcher: fetcher,
        descriptor: sourceThumb,
        bindingHash: sourceBinding,
      );
      final thumbSeal = AttachmentSealRequest(
        bindingHash: newBinding,
        attachmentId: sourceThumb.attachmentId,
      );
      try {
        final thumbMeta = await AttachmentApi.uploadBytesViaPresignMeta(
          thumbPlain,
          sourceThumb.name,
          sourceThumb.mime,
          scope: targetScope,
          scopeRef: targetConversationId,
          anchorMsgId: newMessageId,
          seal: thumbSeal,
          presignFn: presignFn,
          putFn: putFn,
          confirmFn: confirmFn,
        );
        newThumbDescriptor = thumbSeal.descriptor;
        newThumbObjectKey = thumbMeta['object_key'] as String;
        newThumbHash = thumbMeta['file_hash256'].toString();
      } on Exception catch (e) {
        throw AttachmentForwardException(
          'attachment_forward_upload_failed',
          '${e.runtimeType}',
        );
      }
      if (newThumbDescriptor == null) {
        throw const AttachmentForwardException(
          'attachment_forward_upload_failed',
        );
      }
    }

    // ── 主体：解密 → 重封装（挂新 thumb descriptor）→ 上传 ────────────
    final mainPlain = await _decryptObject(
      fetcher: fetcher,
      descriptor: sourceDescriptor,
      bindingHash: sourceBinding,
    );
    final mainSeal = AttachmentSealRequest(
      bindingHash: newBinding,
      attachmentId: sourceDescriptor.attachmentId,
    )..thumbDescriptor = newThumbDescriptor;
    final Map<String, dynamic> mainMeta;
    try {
      mainMeta = await AttachmentApi.uploadBytesViaPresignMeta(
        mainPlain,
        sourceDescriptor.name,
        sourceDescriptor.mime,
        scope: targetScope,
        scopeRef: targetConversationId,
        anchorMsgId: newMessageId,
        seal: mainSeal,
        presignFn: presignFn,
        putFn: putFn,
        confirmFn: confirmFn,
      );
    } on Exception catch (e) {
      throw AttachmentForwardException(
        'attachment_forward_upload_failed',
        '${e.runtimeType}',
      );
    }
    final newDescriptor = mainSeal.descriptor;
    if (newDescriptor == null) {
      throw const AttachmentForwardException(
        'attachment_forward_upload_failed',
      );
    }

    return ForwardedAttachment(
      descriptor: newDescriptor,
      objectKey: mainMeta['object_key'] as String,
      fileHash256: mainMeta['file_hash256'].toString(),
      plainSize: mainPlain.length,
      thumbObjectKey: newThumbObjectKey,
      thumbFileHash256: newThumbHash,
    );
  }

  /// 下载并**认证解密**一个对象（主体或缩略图同一路径）。
  ///
  /// 完整性门（块数量/每块 tag/明文大小/明文 SHA-256）全过才返回明文；
  /// 解不开（旧消息缺钥/密文损坏/跨对象替换）→ `attachment_forward_open_failed`
  /// 显式失败，绝不返回部分明文。
  static Future<Uint8List> _decryptObject({
    required CiphertextFetcher fetcher,
    required AttachmentDescriptor descriptor,
    required Uint8List bindingHash,
  }) async {
    final Uint8List ciphertext;
    try {
      ciphertext = await fetcher(descriptor.objectKey);
    } on AttachmentForwardException {
      rethrow;
    } on Exception catch (e) {
      throw AttachmentForwardException(
        'attachment_forward_fetch_failed',
        '${e.runtimeType}',
      );
    }
    try {
      return AttachmentEncryptor.open(
        ciphertext: ciphertext,
        descriptor: descriptor,
        bindingHash: bindingHash,
      );
    } on AttachmentSealException catch (e) {
      throw AttachmentForwardException(
        'attachment_forward_open_failed',
        '${e.runtimeType}',
      );
    }
  }

  /// 默认密文获取器：object_key → 短时 presigned GET URL（同一授权出口
  /// [AssetUrlResolver]，符合 AssetsService.viewUrl 授权规范）→ 裸 GET 字节。
  ///
  /// ⚠️ 刻意**不走** `IMBoyCacheManager.getSingleFile`：该漏斗按
  /// `AttachmentOpenRegistry` 命中与否决定是否自动 materialize——转发需要
  /// 的是**原始密文**（再自行认证解密），registry 冷启动空窗时它返回密文、
  /// 命中时返回缓存明文，行为不定。此处直连 resolver 拿确定性密文。
  static Future<Uint8List> defaultFetchCiphertext(String objectKey) async {
    final String url = await AssetUrlResolver.instance.resolve(objectKey);
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const AttachmentForwardException('attachment_forward_fetch_failed');
    }
    return Uint8List.fromList(data);
  }
}
