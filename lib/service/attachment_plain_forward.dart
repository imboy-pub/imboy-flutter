/// 明文附件的跨会话重上传（FWDFIX 第二刀）
///
/// ## 为什么明文附件也必须重上传
///
/// 附件读取授权绑在**上传时的 scope** 上：`attach_logic:authorize/3` 对
/// `scope=c2c` 判 `Uid ∈ c2c_members(scope_ref)`、对 `scope=group` 判
/// `authorize_group_access`。而转发若原样复制源 payload 的 `uri`（object_key），
/// 收件人既不在原会话里，也拿不到 `view_url` 的签发 —— 消息看起来完全正常，
/// 点开图片/语音/文件一律 403。这比「不支持的消息类型」更难排查：前者至少
/// 明说打不开，后者是「看起来有内容、永远加载失败」。
///
/// 加密附件（带 content key）已由 [AttachmentForward] 重封装解决，那边还要
/// 换密钥；明文附件没有这层，只需要 下载原字节 → 按目标会话 scope 重上传 →
/// 改写 uri/size/file_hash256。两者产物形状一致（新 object_key + 新哈希），
/// 但**不能合并**：混进 E2EE 模块会让「要不要解密」变成一个运行时开关，
/// 那正是最容易漏判的写法。
///
/// ## 边界
///
/// - 绝对 http(s) 地址不动：外链换会话照样能打开，重上传反而会把别人的图
///   搬进自家对象存储；
/// - 任一步失败抛 [PlainAttachmentForwardException]，调用方在**落库之前**失败，
///   不留半转发状态；重试是新消息 id + 新 object_key，天然幂等；
/// - 只处理 [uri]/[thumb]/[url]/`images[]` 四处引用，其余字段原样保留
///   （文件名、宽高、时长等展示信息必须跟原消息一致）。
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:xid/xid.dart';

import 'package:imboy/component/upload/upload_mime.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/store/api/attachment_api.dart';

/// 对象字节获取器（object_key → 字节）。
typedef ObjectFetcher = Future<Uint8List> Function(String objectKey);

/// 明文附件重上传失败。**不产生半转发状态**：抛出即表示「这条转发没有发生」。
class PlainAttachmentForwardException implements Exception {
  /// 机器可读稳定码（复用 [SendToNotifier.forwardFailureToast] 的既有映射）：
  /// - `attachment_forward_fetch_failed`：源对象下载失败（授权被拒/网络中断）；
  /// - `attachment_forward_upload_failed`：重上传失败（presign/PUT/confirm）。
  final String reason;

  /// 下层异常类型（只落 runtimeType，不输出对象本身）。
  final String? cause;

  const PlainAttachmentForwardException(this.reason, [this.cause]);

  @override
  String toString() =>
      'PlainAttachmentForwardException: $reason'
      '${cause == null ? '' : ' ($cause)'}';
}

/// 重上传产出的新对象信息。
class PlainForwardResult {
  /// 目标会话 scope 下的新 object_key。
  final String objectKey;

  /// 与服务端 `attachment.file_hash256` 同值的明文哈希（收藏引用计数与
  /// 孤儿清理按它 JOIN，必须用服务端返回值而不是本地重算）。
  final String fileHash256;

  /// 字节数（明文大小）。
  final int size;

  const PlainForwardResult({
    required this.objectKey,
    required this.fileHash256,
    required this.size,
  });
}

class PlainAttachmentForward {
  /// payload 是否引用了「需要重新授权才能读」的对象。
  ///
  /// 纯文本 / 卡片 / 外链型 payload 返回 false，调用方据此**整条跳过网络**：
  /// 转发文字不该触发任何上传。
  static bool needsReupload(Object? payload) {
    if (payload is! Map) return false;
    if (_objectKeyOf(payload['uri']) != null) return true;
    if (_objectKeyOf(payload['url']) != null) return true;
    final thumb = payload['thumb'];
    if (_objectKeyOf(thumb) != null) return true;
    // 视频的 thumb 是 EntityImage json，object_key 嵌在 uri 里。
    if (thumb is Map && _objectKeyOf(thumb['uri']) != null) return true;
    final images = payload[AttachmentSealPolicy.imagesPayloadKey];
    if (images is List) {
      return images.any((e) => e is Map && _objectKeyOf(e['uri']) != null);
    }
    return false;
  }

  /// 下载源对象 → 按目标会话重上传 → 回写 payload 里的对象引用。
  ///
  /// [newMessageId] 作上传锚点（群 scope 的 confirm 要求非空锚点，与发送侧
  /// 同序：先上传拿 meta、再建消息）。返回**新 map**，不改入参。
  static Future<Map<String, dynamic>> reupload({
    required Map<String, dynamic> payload,
    required String newMessageId,
    required String targetScope,
    required String? targetConversationId,
    ObjectFetcher? fetchObject,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
  }) async {
    final fetch = fetchObject ?? defaultFetchObject;
    // `private` scope 的读授权只给上传者本人：往这种会话转发附件，收件人
    // 永远打不开。宁可显式失败（用户在转发时就知道没发出去），也不要投递
    // 一条「看起来正常、点开 403」的消息。仅在 payload 真引用对象时才会
    // 走到这里，纯文本不受影响。
    if (targetScope == 'private') {
      throw const PlainAttachmentForwardException(
        'attachment_forward_private_scope',
      );
    }
    final out = Map<String, dynamic>.from(payload);

    Future<PlainForwardResult> push(String objectKey) => _reuploadOne(
      objectKey,
      newMessageId: newMessageId,
      targetScope: targetScope,
      targetConversationId: targetConversationId,
      fetch: fetch,
      presignFn: presignFn,
      putFn: putFn,
      confirmFn: confirmFn,
    );

    // ── 多图：逐项重上传，保持顺序与张数 ──────────────────────────────
    final images = out[AttachmentSealPolicy.imagesPayloadKey];
    if (images is List && images.isNotEmpty) {
      final next = <dynamic>[];
      for (final e in images) {
        if (e is! Map) {
          next.add(e);
          continue;
        }
        final item = Map<String, dynamic>.from(e);
        final key = _objectKeyOf(item['uri']);
        if (key != null) {
          final r = await push(key);
          item['uri'] = r.objectKey;
          item['size'] = r.size;
          item['file_hash256'] = r.fileHash256;
        }
        next.add(item);
      }
      out[AttachmentSealPolicy.imagesPayloadKey] = next;
      // total 与 images 长度必须同步，否则列表渲染会少图/多占位。
      out['total'] = next.length;
    }

    // ── 主体 ────────────────────────────────────────────────────────
    final mainKey = _objectKeyOf(out['uri']);
    if (mainKey != null) {
      final r = await push(mainKey);
      out['uri'] = r.objectKey;
      out['size'] = r.size;
      out['file_hash256'] = r.fileHash256;
    }

    // ── 缩略图：视频是 map（EntityImage json），位置是 object_key 字符串 ──
    final thumb = out['thumb'];
    if (thumb is Map) {
      final t = Map<String, dynamic>.from(thumb);
      final key = _objectKeyOf(t['uri']);
      if (key != null) {
        final r = await push(key);
        t['uri'] = r.objectKey;
        t['file_hash256'] = r.fileHash256;
        // 只回填原本就有的字段，不给 EntityImage 造出它不认识的键。
        if (t.containsKey('size')) t['size'] = r.size;
        out['thumb'] = t;
      }
    } else if (thumb is String) {
      final key = _objectKeyOf(thumb);
      if (key != null) {
        out['thumb'] = (await push(key)).objectKey;
      }
    }

    // ── 贴纸外链：只有自家对象才重传，http(s) 已在 _objectKeyOf 里排除 ──
    final urlKey = _objectKeyOf(out['url']);
    if (urlKey != null) {
      out['url'] = (await push(urlKey)).objectKey;
    }

    return out;
  }

  /// 单个对象：下载 → 上传到目标会话 scope → 返回新 key/哈希/大小。
  ///
  /// 文件名按新 Xid 重建（原 key 里的文件名不可信，也可能带空格/中文导致
  /// 签名链路失败），但**扩展名沿用原 key**：服务端按扩展名 + 魔数双校验，
  /// 改扩展名会让合法的 HEIC/MOV 被判成非法类型。
  static Future<PlainForwardResult> _reuploadOne(
    String objectKey, {
    required String newMessageId,
    required String targetScope,
    required String? targetConversationId,
    required ObjectFetcher fetch,
    PresignFn? presignFn,
    PutFn? putFn,
    ConfirmFn? confirmFn,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await fetch(objectKey);
    } on PlainAttachmentForwardException {
      rethrow;
    } catch (e) {
      // 下载侧的失败不保证是 Exception（Dio 与授权解析都可能抛 Error 子类），
      // 统一收敛成稳定码，避免裸类型穿透到调用方被当成「未知错误」静默吞掉。
      throw PlainAttachmentForwardException(
        'attachment_forward_fetch_failed',
        '${e.runtimeType}',
      );
    }
    if (bytes.isEmpty) {
      throw const PlainAttachmentForwardException(
        'attachment_forward_fetch_failed',
      );
    }

    final String fileName = _fileNameFor(objectKey);
    final String mime = resolveUploadMime(fileName, bytes);
    final Map<String, dynamic> meta;
    try {
      meta = await AttachmentApi.uploadBytesViaPresignMeta(
        bytes,
        fileName,
        mime,
        scope: targetScope,
        scopeRef: targetConversationId,
        anchorMsgId: newMessageId,
        presignFn: presignFn,
        putFn: putFn,
        confirmFn: confirmFn,
      );
    } on PlainAttachmentForwardException {
      rethrow;
    } catch (e) {
      throw PlainAttachmentForwardException(
        'attachment_forward_upload_failed',
        '${e.runtimeType}',
      );
    }
    final Object? newKey = meta['object_key'];
    if (newKey is! String || newKey.isEmpty) {
      throw const PlainAttachmentForwardException(
        'attachment_forward_upload_failed',
      );
    }
    return PlainForwardResult(
      objectKey: newKey,
      fileHash256: meta['file_hash256'].toString(),
      size: bytes.length,
    );
  }

  /// 默认对象获取器：object_key → 短时 presigned GET URL → 裸 GET 字节。
  ///
  /// 与 [AttachmentForward.defaultFetchCiphertext] 同一授权出口
  /// （[AssetUrlResolver]，符合 AssetsService.viewUrl 规范）；明文对象没有
  /// 封装层，取回的字节**就是**明文，因此这里不做解密。
  ///
  /// ⚠️ 刻意不走 `IMBoyCacheManager.getSingleFile`：那是按
  /// `AttachmentOpenRegistry` 命中与否决定是否 materialize 的漏斗，行为随缓存
  /// 状态变化，转发需要的是确定性原始字节。
  static Future<Uint8List> defaultFetchObject(String objectKey) async {
    final String url = await AssetUrlResolver.instance.resolve(objectKey);
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const PlainAttachmentForwardException(
        'attachment_forward_fetch_failed',
      );
    }
    return Uint8List.fromList(data);
  }

  /// 从 object_key 造新文件名：新 Xid + 原扩展名。
  static String _fileNameFor(String objectKey) {
    final int slash = objectKey.lastIndexOf('/');
    final String base = slash >= 0 ? objectKey.substring(slash + 1) : objectKey;
    final int dot = base.lastIndexOf('.');
    String ext = dot >= 0 && dot < base.length - 1
        ? base.substring(dot + 1)
        : '';
    // 扩展名只接受字母数字（避免把 query 串/诡异字符带进签名链路）
    if (!RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(ext)) ext = 'bin';
    return '${Xid().toString()}.$ext';
  }

  /// 对象引用 → object_key；不是自家对象（空值 / 绝对外链）时返回 null。
  static String? _objectKeyOf(Object? value) {
    if (value is! String) return null;
    final String s = value.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return null;
    return s;
  }
}
