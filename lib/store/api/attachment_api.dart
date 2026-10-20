import 'dart:io';
import 'dart:typed_data';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:video_compress/video_compress.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:xid/xid.dart';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/upload/upload_mime.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/entity_image.dart';
import 'package:imboy/store/model/entity_video.dart';
import 'package:imboy/i18n/strings.g.dart';

/// presign 请求注入 seam（默认走 [HttpClient]，测试可注入 fake）。
typedef UploadSessionFn = Future<IMBoyHttpResponse> Function(
  Map<String, dynamic> query,
);

typedef PresignFn = Future<IMBoyHttpResponse> Function(
  String filename,
  String mime,
);

/// PUT 直传注入 seam（默认走 [AttachmentApi._putToGarage]，测试可注入 fake）。
typedef PutFn = Future<void> Function(
  String putUrl,
  Uint8List bytes,
  String mime,
  bool process,
);

/// confirm 落库注入 seam（默认走 [HttpClient]，测试可注入 fake）。
typedef ConfirmFn = Future<IMBoyHttpResponse> Function(
  Map<String, dynamic> body,
);

/// 单次 PUT 注入 seam（默认 [AttachmentApi._rawDioPut]，测试可注入 fake 验证重试编排）。
typedef SinglePutFn = Future<void> Function(
  String putUrl,
  Uint8List bytes,
  String mime,
  bool process,
);

/// 退避延时注入 seam（默认真实 [Future.delayed]，测试可注入零延时避免真实等待）。
typedef DelayFn = Future<void> Function(Duration d);

/// W5-01 上传阶段检查点枚举（与 attachment_upload_task.stage 对齐）。
enum UploadCheckpointStage { presigned, sealed, putDone, confirmed }

/// W5-01：单个远程阶段边界的检查点事件。
class UploadCheckpoint {
  final UploadCheckpointStage stage;

  /// presigned 边界携带（持久化到任务行）。
  final String? objectKey;

  /// sealed 边界携带（contentKey/baseNonce 需立即进安全存储，
  /// ciphertextSha256 回填任务行）；恢复路径回放时为空串。
  final Uint8List? contentKey;
  final Uint8List? baseNonce;
  final String? ciphertextSha256;
  final Uint8List? uploadBytes;
  final AttachmentDescriptor? descriptor;

  const UploadCheckpoint(
    this.stage, {
    this.objectKey,
    this.contentKey,
    this.baseNonce,
    this.ciphertextSha256,
    this.uploadBytes,
    this.descriptor,
  });

  const UploadCheckpoint.presigned({required String objectKey})
    : this(UploadCheckpointStage.presigned, objectKey: objectKey);
  const UploadCheckpoint.sealed({
    required Uint8List contentKey,
    required Uint8List baseNonce,
    required String ciphertextSha256,
    Uint8List? uploadBytes,
    AttachmentDescriptor? descriptor,
  }) : this(
         UploadCheckpointStage.sealed,
         contentKey: contentKey,
         baseNonce: baseNonce,
         ciphertextSha256: ciphertextSha256,
         uploadBytes: uploadBytes,
         descriptor: descriptor,
       );
  const UploadCheckpoint.putDone({String? ciphertextSha256})
    : this(UploadCheckpointStage.putDone, ciphertextSha256: ciphertextSha256);
  const UploadCheckpoint.confirmed() : this(UploadCheckpointStage.confirmed);
}

/// W5-01：恢复上传的既有检查点状态（来自任务行 + 安全存储材料）。
class ResumableUploadState {
  /// 任务检查点里的 object_key（skipPut 直通 confirm 时沿用它）。
  final String objectKey;

  /// 安全存储取回的既有密钥材料（非空 → 复用，不重新随机 seal）。
  final Uint8List? contentKey;
  final Uint8List? baseNonce;

  /// true：密文已 PUT（put_done 检查点）→ 重建原 descriptor，跳过 PUT 并重试 confirm。
  final bool skipPut;

  /// put_done 检查点记录的密文 hash（直通 confirm 时上报同值）。
  final String? ciphertextSha256;
  final SealedAttachment? sealedAttachment;

  const ResumableUploadState({
    required this.objectKey,
    this.contentKey,
    this.baseNonce,
    this.skipPut = false,
    this.ciphertextSha256,
    this.sealedAttachment,
  });
}

/// E2EE-061 Slice 4：附件加密上传的输入与产物承载。
///
/// 为什么用一个可变承载而不是改 [AttachmentApi.uploadViaPresign] 的返回类型：
/// 该函数有 5 个调用入口，改返回类型会让它们全部跟着改，而其中多数在本刀内
/// **还不需要**加密。用承载对象把「要不要加密」与「谁需要 descriptor」解耦，
/// 未接线的入口一行不用动。
class AttachmentSealRequest {
  /// AAD 绑定值（方案甲，见 [AttachmentBinding]）。32 字节。
  final Uint8List bindingHash;

  /// 本附件的标识，进 AAD；同一条消息内多个附件不可互换。
  final String attachmentId;

  /// 分块大小。默认取已拍板的 1 MiB。
  final int chunkSize;

  /// E2EE-061 Slice 7：**先封装好的缩略图** descriptor，随本次封装挂进主 descriptor。
  /// 由调用方按「先传缩略图、再传本体」的顺序填入。
  AttachmentDescriptor? thumbDescriptor;

  /// 上传完成后由 [AttachmentApi.uploadViaPresign] 回填。
  /// ⚠️ 它含 **content key**：必须随 PFv3 加密 payload 发送，
  /// 绝不可写日志、绝不可进未加密字段。
  AttachmentDescriptor? descriptor;

  /// 上传完成后回填：**实际上报给服务端的** `file_hash256`（加密时是密文哈希）。
  ///
  /// 消息体里的 `file_hash256` 必须与服务端 `attachment.file_hash256` **同值**——
  /// 收藏引用计数 (`user_collect.attach_file_hash256`) 与孤儿清理都按该值 JOIN。
  /// 封装后服务端存的是密文哈希，消息体若继续带明文哈希，这两条链会一起断
  /// （最坏情况：对象被判定无人引用而清理掉）。明文哈希只留在 descriptor 内。
  String? uploadedFileHash256;

  AttachmentSealRequest({
    required this.bindingHash,
    required this.attachmentId,
    this.chunkSize = AttachmentEncryptor.defaultChunkSize,
  }) {
    if (attachmentId.isEmpty) {
      throw ArgumentError.value(
        attachmentId,
        'attachmentId',
        '不得为空：空值会让同一消息内多个附件共用同一 AAD',
      );
    }
  }
}

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
  /// direct-v1（attachment_direct_api）复用同一校验源——大小/白名单规则
  /// 双份维护必然漂移，故此处对外可见。
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

    /// 群附件消息锚点（group attachment anchor）：C2G 会话上传时传客户端
    /// 预生成的消息 id（Xid）——服务端 attachment 落库与消息锚定共用同值，
    /// group scope 缺失时 confirm 会 400「群附件缺少消息锚点」。
    /// 非 group scope 服务端忽略该字段；缺省 null 保持既有调用方零改动。
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    // 以下三个为 @visibleForTesting 注入 seam：默认 null 走真实实现，
    // 调用方零改动；测试注入 fake 以脱离 HttpClient/Dio/网络验证编排逻辑。
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,

    /// 非 null 时上传**密文**：明文经 [AttachmentEncryptor.seal] 分块 AEAD 后直传，
    /// confirm 上报的是**密文**哈希与大小（拍板 ①：明文哈希永不到达服务端），
    /// 并带上 `cipher` 判别位（后端迁移 00000052）。
    /// 为 null 时行为**逐字节不变**——这是本刀零风险接线的前提。
    AttachmentSealRequest? seal,

    /// W5-01（AC08 恢复）：非 null 时按任务检查点跳过已完成阶段——
    /// objectKey 已有则跳过 presign 网络调用；contentKey/baseNonce 由
    /// 安全存储取回复用（同 key 同密文，绝不重新随机 seal）；skipPut
    /// 为 true 时跳过 PUT 直传（put_done 检查点后的续传）。
    ResumableUploadState? resume,
    String? clientUploadId,
    bool persistTask = true,
    UploadSessionFn? sessionFn,

    /// W5-01：远程阶段边界的持久化检查点。每个边界 await 一次；抛错即
    /// 中止上传推进（durable checkpoint fail-closed：材料未落盘不上网络）。
    /// 测试以抛错模拟进程被杀。
    Future<void> Function(UploadCheckpoint event)? checkpoint,
  }) async {
    // image/jpg 是 image/jpeg 的非标准别名：客户端 _isAllowedMime 按前缀
    // 放行，但服务端附件白名单是精确清单（elib_oss ?ALLOWED_TYPES）只认
    // 标准值——按扩展名拼 mime 的调用方（桌面拍摄/file_picker 的 .jpg）
    // 会被 presign 以 invalid_file_type 拒绝（冒烟实证）。在唯一出口归一。
    if (mime == 'image/jpg') mime = 'image/jpeg';

    if (persistTask &&
        presignFn == null &&
        putFn == null &&
        confirmFn == null &&
        checkpoint == null &&
        resume == null) {
      return ResumableAttachmentUploader(
        sealRequest: seal,
        encrypt: seal != null,
        process: process,
      ).uploadProduction(
        userId: UserRepoLocal.to.currentUid,
        bytes: bytes,
        fileName: fileName,
        mime: mime,
        scope: scope,
        scopeRef: scopeRef,
        anchorMsgId: anchorMsgId,
        messageIntent: messageIntent,
        clientUploadId: clientUploadId,
      );
    }

    // 1. 前置校验（系统边界，快速失败）
    final String? validationError = validateUpload(bytes.length, mime);
    if (validationError != null) {
      throw Exception(validationError);
    }

    // 2. presign（JWT，走 HttpClient；可注入）。
    // W5-01 恢复分两态：put_done 行（skipPut）密文已落在旧 object_key 上，
    // 直通 confirm（跳过 presign/seal/put，object_key 沿用检查点值）；
    // presigned 行按 client_upload_id 先 status 再 renew；签名 URL 不落盘，
    // 响应 object_key 必须与原登记相同，禁止把旧密文材料移到新 key。
    // 同 key 同 nonce 重放 AES-GCM 密文逐字节不变，服务端只认密文 hash。
    String? putUrl;
    String objectKey;
    bool fastConfirm = resume != null && resume.skipPut;
    Future<IMBoyHttpResponse> session(Map<String, dynamic> query) =>
        sessionFn != null
        ? sessionFn(query)
        : HttpClient.client.get(API.attachmentPresign, queryParameters: query);
    IMBoyHttpResponse? renewed;
    if (resume != null &&
        resume.objectKey.isNotEmpty &&
        clientUploadId != null &&
        (presignFn == null || sessionFn != null)) {
      final status = await session({
        'operation': 'status',
        'client_upload_id': clientUploadId,
      });
      if (!status.ok) {
        throw StateError('upload status rejected: ${status.code}');
      }
      final remoteKey = IMBoyHttpResponse.payloadStr(
        status.payload,
        'object_key',
      );
      if (remoteKey != resume.objectKey) {
        throw StateError('upload object identity changed');
      }
      final state = IMBoyHttpResponse.payloadStr(
        status.payload,
        'session_state',
      );
      if (state == 'confirmed') {
        fastConfirm = true;
      } else if (state == 'registered') {
        if (!fastConfirm) {
          renewed = await session({
            'operation': 'renew',
            'client_upload_id': clientUploadId,
          });
        }
      } else {
        throw StateError('upload session terminal: $state');
      }
    }
    if (fastConfirm) {
      objectKey = resume!.objectKey;
    } else {
      final IMBoyHttpResponse presignResp =
          renewed ??
          (presignFn != null
              ? await presignFn(fileName, mime)
              : await HttpClient.client.get(
                  API.attachmentPresign,
                  queryParameters: <String, dynamic>{
                    'operation': 'register',
                    'client_upload_id': ?clientUploadId,
                    'filename': fileName,
                    'mime_type': mime,
                    'scope': scope,
                    if (scopeRef != null && scopeRef.isNotEmpty)
                      'scope_ref': scopeRef,
                  },
                ));
      if (!presignResp.ok) {
        throw Exception(
          'presign 失败: code=${presignResp.code} msg=${presignResp.msg}',
        );
      }
      final dynamic pp = presignResp.payload;
      putUrl = IMBoyHttpResponse.payloadStr(pp, 'put_url');
      final String? okFromResp = IMBoyHttpResponse.payloadStr(pp, 'object_key');
      if (putUrl == null ||
          putUrl.isEmpty ||
          okFromResp == null ||
          okFromResp.isEmpty) {
        throw Exception('presign 响应缺少 put_url/object_key');
      }
      objectKey = okFromResp;
      if (resume != null &&
          resume.objectKey.isNotEmpty &&
          objectKey != resume.objectKey) {
        throw StateError('upload object identity changed');
      }
      await checkpoint?.call(UploadCheckpoint.presigned(objectKey: objectKey));
    }

    // 2.5 E2EE-061：按需封装。**必须在 presign 之后**——descriptor 要带 object_key。
    // MIME 按拍板保持真实值（不隐藏），因此 presign 契约无需任何改动。
    // W5-01：resume 携带安全存储取回的既有材料——同 key 同 nonce 重放
    // AES-GCM 得到逐字节相同密文（same_key_same_ciphertext_after_restart）。
    SealedAttachment? sealed = resume?.sealedAttachment;
    if (sealed != null) {
      seal?.descriptor = sealed.descriptor;
      await checkpoint?.call(
        UploadCheckpoint.sealed(
          contentKey: sealed.descriptor.contentKey,
          baseNonce: sealed.descriptor.baseNonce,
          ciphertextSha256: sealed.ciphertextSha256Hex,
          uploadBytes: sealed.ciphertext,
          descriptor: sealed.descriptor,
        ),
      );
    } else if (seal != null) {
      if (fastConfirm &&
          (resume?.contentKey == null || resume?.baseNonce == null)) {
        throw StateError(
          'confirmed encrypted upload requires original material',
        );
      }
      final Uint8List ck =
          resume?.contentKey ?? AttachmentEncryptor.randomContentKey();
      final Uint8List bn =
          resume?.baseNonce ?? AttachmentEncryptor.randomBaseNonce();
      sealed = AttachmentEncryptor.seal(
        plaintext: bytes,
        bindingHash: seal.bindingHash,
        attachmentId: seal.attachmentId,
        objectKey: objectKey,
        mime: mime,
        name: fileName,
        contentKey: ck,
        baseNonce: bn,
        chunkSize: seal.chunkSize,
        thumb: seal.thumbDescriptor,
      );
      seal.descriptor = sealed.descriptor;
      await checkpoint?.call(
        UploadCheckpoint.sealed(
          contentKey: ck,
          baseNonce: bn,
          ciphertextSha256: sealed.ciphertextSha256Hex,
          uploadBytes: sealed.ciphertext,
          descriptor: sealed.descriptor,
        ),
      );
    } else if (checkpoint != null) {
      // 明文路径也封检查点（无材料可持久化，仅阶段推进）
      await checkpoint.call(
        UploadCheckpoint(
          UploadCheckpointStage.sealed,
          uploadBytes: bytes,
          ciphertextSha256: sha256.convert(bytes).toString(),
        ),
      );
    }
    // 实际上传的字节：加密时是密文，否则是原明文
    final Uint8List bodyBytes = sealed?.ciphertext ?? bytes;

    // 3. PUT 直传 Garage（裸 Dio，不注 JWT；指数退避重试；可注入）。
    // W5-01：put_done 检查点后的恢复（resume.skipPut）跳过重传。
    if (!fastConfirm) {
      if (putFn != null) {
        await putFn(putUrl!, bodyBytes, mime, process);
      } else {
        final target = Uri.parse(putUrl!);
        final uploadUrl = target.hasScheme
            ? putUrl
            : Uri.parse(Env().apiBaseUrl).resolveUri(target).toString();
        await _putToGarage(uploadUrl, bodyBytes, mime, process: process);
      }
      await checkpoint?.call(
        UploadCheckpoint.putDone(ciphertextSha256: sealed?.ciphertextSha256Hex),
      );
    }

    if (fastConfirm && !(resume?.skipPut ?? false)) {
      // status 已证明远端 confirmed；调和丢失的本地 PUT 检查点。
      await checkpoint?.call(
        UploadCheckpoint.putDone(ciphertextSha256: sealed?.ciphertextSha256Hex),
      );
    }

    // 4. confirm 落库（JWT，走 HttpClient；可注入）
    // ⚠️ 拍板 ①：加密上传只上报**密文**哈希。明文 SHA-256 只进加密的 descriptor，
    // 永不到达服务端——否则服务端仍可与已知文件库比对，内容加密的收益被抵消大半。
    final String fileHash256 =
        sealed?.ciphertextSha256Hex ??
        resume?.ciphertextSha256 ??
        sha256.convert(bytes).toString();
    seal?.uploadedFileHash256 = fileHash256;
    final Map<String, dynamic> confirmBody = <String, dynamic>{
      'object_key': objectKey,
      'file_hash256': fileHash256,
      'mime_type': mime,
      // 密文大小 ≠ 明文大小；明文大小只在 descriptor 内
      'size': bodyBytes.length,
      if (sealed != null) 'cipher': AttachmentDescriptor.supportedCipher,
      'scope': scope,
      if (scopeRef != null && scopeRef.isNotEmpty) 'scope_ref': scopeRef,
      if (anchorMsgId != null && anchorMsgId.isNotEmpty)
        'anchor_msg_id': anchorMsgId,
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
    await checkpoint?.call(
      const UploadCheckpoint(UploadCheckpointStage.confirmed),
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
      final String mime = resolveUploadMime(path, bytes);
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
      await callback(
        compatResp(meta),
        IMBoyHttpResponse.payloadStr(meta, 'object_key') ?? '',
      );
    } on Object catch (e, s) {
      // 上传失败此前静默吞异常，导致线上（尤其真机直传）无法定位根因。
      // 打印 scope + 具体异常 + 前三行栈，覆盖文件读取/presign/PUT garage 各步。
      debugPrint('[upload][presignCompat] FAIL scope=$scope err=$e');
      debugPrint(
        '[upload][presignCompat] stack=${s.toString().split('\n').take(3).join(' | ')}',
      );
      // 调用方 onError 回调签名是 (Error)，dio/文件读取抛的是 Exception——
      // 直接透传会在回调参数隐式转型处抛 TypeError，把真正的失败原因吞掉
      // （批次125 头像上传实证）。非 Error 统一包装，保住原始错误信息。
      errorCallback(e is Error ? e : StateError('upload failed: $e'));
    }
  }

  /// presign 兼容版字节上传（drop-in 替换旧 [uploadBytes]，签名一致）。
  ///
  /// [seal] 非 null 时上传密文；回调 resp 的 `data.file_hash256` 随之变成密文哈希，
  /// descriptor 由调用方从 [AttachmentSealRequest.descriptor] 取。
  static Future<void> uploadBytesViaPresignCompat(
    String prefix,
    Uint8List file,
    Function callback,
    Function errorCallback, {
    String path = "",
    bool process = true,
    String scope = 'private',
    String? scopeRef,
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    AttachmentSealRequest? seal,
  }) async {
    try {
      String ext = path.contains('.')
          ? path.substring(path.lastIndexOf('.') + 1)
          : 'png';
      if (ext.isEmpty) ext = 'png';
      final String fileName = '${Xid().toString()}.$ext';
      final String mime = resolveUploadMime(fileName, file);
      final meta = await uploadBytesViaPresignMeta(
        file,
        fileName,
        mime,
        process: process,
        scope: scope,
        scopeRef: scopeRef,
        anchorMsgId: anchorMsgId,
        messageIntent: messageIntent,
        seal: seal,
      );
      await callback(
        compatResp(meta),
        IMBoyHttpResponse.payloadStr(meta, 'object_key') ?? '',
      );
    } on Object catch (e) {
      // 同 uploadFileViaPresignCompat：非 Error 的 Exception 包装后回调，
      // 避免在调用方 (Error) 签名处抛 TypeError 吞掉真实失败原因。
      errorCallback(e is Error ? e : StateError('upload failed: $e'));
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
        'file_hash256': meta['file_hash256'],
      },
    };
  }

  /// 原始字节经 presign 直传，返回 `{object_key, size, md5}`（voice/file 复用）。
  ///
  /// [seal] 非 null 时上传密文，且返回的 `file_hash256` 是**服务端实际持有的**
  /// 密文哈希（见 [AttachmentSealRequest.uploadedFileHash256]）；
  /// `size` 始终是**明文**大小——它进的是加密 payload，给 UI 显示用。
  static Future<Map<String, dynamic>> uploadBytesViaPresignMeta(
    Uint8List bytes,
    String fileName,
    String mime, {
    bool process = true,
    String scope = 'private',
    String? scopeRef,
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    AttachmentSealRequest? seal,
    // 与 [uploadViaPresign] 同一组注入 seam：默认 null 走真实实现。
    // 这里透传是为了让「meta 里的 file_hash256 与服务端同值」这条不变量
    // 能在不触网的前提下被验收。
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
  }) async {
    final String objectKey = await uploadViaPresign(
      bytes,
      fileName,
      mime,
      process: process,
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      seal: seal,
      presignFn: presignFn,
      putFn: putFn,
      confirmFn: confirmFn,
    );
    return <String, dynamic>{
      'object_key': objectKey,
      'size': bytes.length,
      'file_hash256':
          seal?.uploadedFileHash256 ?? sha256.convert(bytes).toString(),
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
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    AttachmentSealRequest? seal,
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
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      seal: seal,
    );
    return <String, dynamic>{
      'object_key': objectKey,
      'size': bytes.length,
      'file_hash256':
          seal?.uploadedFileHash256 ?? sha256.convert(bytes).toString(),
      'width': entity.width,
      'height': entity.height,
    };
  }

  /// 视频 AssetEntity 经 presign 直传（缩略图 + 压缩视频双 object_key）。
  ///
  /// 仅用于聊天视频（S5）：缩略图与视频分别 presign 直传，返回
  /// `{thumb: EntityImage, video: EntityVideo}`（uri 均为 object_key），
  /// 下游 handleVideoUpload 无需改。
  /// [videoSeal] 封装视频本体，[thumbSeal]（Slice 7）封装缩略图。
  ///
  /// ⚠️ 设计 §3.3：缩略图是独立对象，**不加密 = 预览即泄漏**——拿到缩略图
  /// 就看得到画面内容，ATT-04 在缩略图上直接失败。因此两者要么一起封装，
  /// 要么一起明文；**只封装本体是自欺**。
  /// 故：只传其一时**上传前直接失败**（fail-closed）——降级双明文会把
  /// required E2EE 会话的附件静默送去对象存储（调用方还以为已加密），
  /// 比失败更糟。正常调用方（ChatAttachmentHandler）两次判定的输入完全
  /// 一致，此闸门只在将来判定漂移时触发（E2EE-062 第七刀教训）。
  static Future<Map<String, dynamic>> uploadVideoViaPresign(
    AssetEntity entity, {
    String scope = 'private',
    String? scopeRef,
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    AttachmentSealRequest? videoSeal,
    AttachmentSealRequest? thumbSeal,
  }) async {
    // 一致性闸门（判据在 AttachmentSealPolicy，不在这里各写一份 if）：
    // 只有一个时拒绝整次上传——先于任何文件 IO，上传 seam 零调用。
    if (!AttachmentSealPolicy.sealTogether(videoSeal, thumbSeal)) {
      throw const E2eeSecurityException('attachment_partial_seal');
    }
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

    // 2. 压缩视频 → presign
    //
    // 压缩是优化而非必需：部分机型（实测华为 MRD-AL00 / MTK 编码器）转码必失败
    // （TranscodeEngine: Failed to stop the muxer），此前直接抛异常导致
    // **视频消息完全发不出去且无任何提示**。失败一律退回原视频，
    // 大小超限由下游 uploadViaPresign 的 maxUploadBytes 校验兜底。
    // deleteOrigin 必须为 false，否则降级时原文件已被删掉。
    MediaInfo? info;
    try {
      info = await VideoCompress.compressVideo(
        path,
        quality: VideoQuality.Res640x480Quality,
        deleteOrigin: false,
      );
    } on Object catch (e) {
      debugPrint('uploadVideoViaPresign: 视频压缩失败，退回原视频上传: $e');
    }
    if (info == null) {
      // 降级路径的元数据必须探测原视频拿，不能用 entity 推算：
      // 实测 entity.duration 在相机合成的 asset 上是**毫秒**（与 photo_manager
      // 文档的"秒"不符），据此换算会把 3 秒视频显示成 50:00。
      // getMediaInfo 只读元数据不转码，压缩失败的机型上同样可用。
      try {
        info = await VideoCompress.getMediaInfo(path);
      } on Object catch (e) {
        debugPrint('uploadVideoViaPresign: 读取原视频元数据失败: $e');
      }
    }
    final File videoFile = info?.file ?? file;
    final Uint8List videoBytes = await videoFile.readAsBytes();
    final String videoName = '${Xid().toString()}.mp4';
    await _prepareVideoPair(
      thumbBytes: thumbBytes,
      thumbName: thumbName,
      videoBytes: videoBytes,
      videoName: videoName,
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      thumbSeal: thumbSeal,
      videoSeal: videoSeal,
    );
    final thumbMeta = await uploadBytesViaPresignMeta(
      thumbBytes,
      thumbName,
      'image/jpeg',
      process: false,
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      seal: thumbSeal,
    );
    // 缩略图先封装完，它的 descriptor 才能挂进视频的 descriptor
    // （接收侧由 AttachmentOpenRegistry 一并登记两个 object_key）。
    videoSeal?.thumbDescriptor = thumbSeal?.descriptor;

    final String videoObjKey = await uploadViaPresign(
      videoBytes,
      videoName,
      'video/mp4',
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      seal: videoSeal,
    );

    final EntityImage thumb = EntityImage(
      fileHash256:
          IMBoyHttpResponse.payloadStr(thumbMeta, 'file_hash256') ?? '',
      name: thumbName,
      uri: IMBoyHttpResponse.payloadStr(thumbMeta, 'object_key') ?? '',
      size: IMBoyHttpResponse.payloadInt(thumbMeta, 'size') ?? 0,
      width: width,
      height: height,
    );
    final EntityVideo video = EntityVideo(
      // 与服务端 attachment.file_hash256 同值：封装时是密文哈希
      fileHash256:
          videoSeal?.uploadedFileHash256 ??
          sha256.convert(videoBytes).toString(),
      name: videoName,
      uri: videoObjKey,
      // info 现在来自压缩结果或原视频探测，两者的 duration 都是毫秒。
      // 探测也失败时宁可留空，也不拿 entity.duration 换算——单位不可靠。
      size: info?.filesize ?? videoBytes.length,
      duration: info?.duration,
      author: info?.author,
      width: info?.width ?? entity.width,
      height: info?.height ?? entity.height,
    );
    await VideoCompress.deleteAllCache();
    return <String, dynamic>{'thumb': thumb, 'video': video};
  }

  static Future<void> _prepareVideoPair({
    required Uint8List thumbBytes,
    required String thumbName,
    required Uint8List videoBytes,
    required String videoName,
    required String scope,
    String? scopeRef,
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    AttachmentSealRequest? thumbSeal,
    AttachmentSealRequest? videoSeal,
  }) async {
    if (messageIntent == null || anchorMsgId == null) return;
    final uid = UserRepoLocal.to.currentUid;
    await ResumableAttachmentUploader(
      sealRequest: thumbSeal,
      encrypt: thumbSeal != null,
      process: false,
    ).uploadProduction(
      userId: uid,
      bytes: thumbBytes,
      fileName: thumbName,
      mime: 'image/jpeg',
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      prepareOnly: true,
    );
    await ResumableAttachmentUploader(
      sealRequest: videoSeal,
      encrypt: videoSeal != null,
    ).uploadProduction(
      userId: uid,
      bytes: videoBytes,
      fileName: videoName,
      mime: 'video/mp4',
      scope: scope,
      scopeRef: scopeRef,
      anchorMsgId: anchorMsgId,
      messageIntent: messageIntent,
      prepareOnly: true,
    );
  }

  /// File 版视频上传（压缩+缩略图+上传三件套），供已持有 File 与元数据
  /// （时长/宽高）、无 AssetEntity 的场景使用：频道发布（明文）与桌面拍摄
  /// （聊天，带 E2EE 封装）共用。
  ///
  /// 与 [uploadVideoViaPresign]（AssetEntity 版）流程一致，差异：
  ///   - 直接接收 [file]（不经 entity.file 再取一次）；
  ///   - width/height/durationMs 由调用方传入，不再从 entity 反推；
  ///   - [anchorMsgId]/[videoSeal]/[thumbSeal] 为聊天桌面拍摄新增，语义与
  ///     AssetEntity 版完全一致（含缩略图 descriptor 挂接与 partial seal 闸门）。
  ///
  /// 返回值按是否封装分流：
  ///   - 未带 seal（频道等明文场景）：返回扁平
  ///     `{video_uri, size, thumb_uri, duration, width, height}`，失败返回
  ///     null（调用方以 `result == null` 判失败，不抛异常）；
  ///   - 带 seal（桌面拍摄）：返回 `{thumb: EntityImage, video: EntityVideo}`，
  ///     与 [uploadVideoViaPresign] 同形，下游 handleVideoUpload 可直接消费；
  ///     同样以 null 表示失败，partial seal 除外——闸门先于一切 IO 直接抛出
  ///     （fail-closed 与 AssetEntity 版对齐，不静默降级）。
  static Future<Map<String, dynamic>?> uploadVideoFileViaPresign(
    File file, {
    required int durationMs,
    required int width,
    required int height,
    String scope = 'private',
    String? scopeRef,
    String? anchorMsgId,
    Map<String, dynamic>? messageIntent,
    AttachmentSealRequest? videoSeal,
    AttachmentSealRequest? thumbSeal,
  }) async {
    // 一致性闸门（与 uploadVideoViaPresign 同款）：只封其一时整次失败——
    // 先于任何文件 IO，上传 seam 零调用。
    if (!AttachmentSealPolicy.sealTogether(videoSeal, thumbSeal)) {
      throw const E2eeSecurityException('attachment_partial_seal');
    }
    final bool sealed = videoSeal != null && thumbSeal != null;
    final int videoWidth = width;
    final int videoHeight = height;
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

      // 2. 压缩视频 → presign（同上：压缩失败退回原视频，不放弃整次上传）
      MediaInfo? info;
      try {
        info = await VideoCompress.compressVideo(
          path,
          quality: VideoQuality.Res640x480Quality,
          deleteOrigin: false,
        );
      } on Object catch (e) {
        debugPrint('[attachment_api] 视频压缩失败，退回原视频上传: $e');
      }
      final File videoFile = info?.file ?? File(path);
      final Uint8List videoBytes = await videoFile.readAsBytes();
      final String videoName = '${Xid().toString()}.mp4';
      await _prepareVideoPair(
        thumbBytes: thumbBytes,
        thumbName: thumbName,
        videoBytes: videoBytes,
        videoName: videoName,
        scope: scope,
        scopeRef: scopeRef,
        anchorMsgId: anchorMsgId,
        messageIntent: messageIntent,
        thumbSeal: thumbSeal,
        videoSeal: videoSeal,
      );
      final thumbMeta = await uploadBytesViaPresignMeta(
        thumbBytes,
        thumbName,
        'image/jpeg',
        process: false,
        scope: scope,
        scopeRef: scopeRef,
        anchorMsgId: anchorMsgId,
        messageIntent: messageIntent,
        seal: thumbSeal,
      );
      // 缩略图先封装完，它的 descriptor 才能挂进视频的 descriptor
      // （接收侧由 AttachmentOpenRegistry 一并登记两个 object_key）。
      videoSeal?.thumbDescriptor = thumbSeal?.descriptor;

      final String videoObjKey = await uploadViaPresign(
        videoBytes,
        videoName,
        'video/mp4',
        scope: scope,
        scopeRef: scopeRef,
        anchorMsgId: anchorMsgId,
        messageIntent: messageIntent,
        seal: videoSeal,
      );

      await VideoCompress.deleteAllCache();
      if (sealed) {
        // 缩略图尺寸（沿用 uploadVideoViaPresign：长边压到 800 内）
        final int thumbW = videoWidth < 800 ? videoWidth : 800;
        final int thumbH = videoWidth < 800
            ? videoHeight
            : (videoHeight / videoWidth * 800).toInt();
        final EntityImage thumb = EntityImage(
          fileHash256:
              IMBoyHttpResponse.payloadStr(thumbMeta, 'file_hash256') ?? '',
          name: thumbName,
          uri: IMBoyHttpResponse.payloadStr(thumbMeta, 'object_key') ?? '',
          size: IMBoyHttpResponse.payloadInt(thumbMeta, 'size') ?? 0,
          width: thumbW,
          height: thumbH,
        );
        final EntityVideo video = EntityVideo(
          // 与服务端 attachment.file_hash256 同值：封装时是密文哈希
          fileHash256:
              videoSeal.uploadedFileHash256 ??
              sha256.convert(videoBytes).toString(),
          name: videoName,
          uri: videoObjKey,
          // duration：压缩结果与调用方 stopwatch 计时都是毫秒；探测缺失时
          // 退调用方值，宁可近似也不留空。
          size: info?.filesize ?? videoBytes.length,
          duration: info?.duration ?? durationMs.toDouble(),
          author: info?.author,
          width: info?.width ?? videoWidth,
          height: info?.height ?? videoHeight,
        );
        return <String, dynamic>{'thumb': thumb, 'video': video};
      }
      return <String, dynamic>{
        'video_uri': videoObjKey,
        'thumb_uri':
            IMBoyHttpResponse.payloadStr(thumbMeta, 'object_key') ?? '',
        'size': info?.filesize ?? videoBytes.length,
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
    // 直接用 Uint8List body（非 Stream）：Dio/dart:io 自动设正确 Content-Length，
    // 跨平台一致且 sendTimeout 生效。此前用 Stream<List<int>> body 在 Android 上
    // dart:io HttpClient 会发 chunked transfer-encoding（忽略手动 content-length），
    // 而 Garage/S3 presigned PUT 要求 Content-Length → 真机直传 hang/被拒（mac 正常）。
    await dio.put<dynamic>(
      putUrl,
      data: bytes,
      options: Options(contentType: mime),
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
