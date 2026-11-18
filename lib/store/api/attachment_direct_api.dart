import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart' show CancelToken;
import 'package:imboy/store/api/attachment_api.dart' show AttachmentApi;
import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_api.dart';

import 'package:imboy/component/upload/browser_direct_put_stub.dart'
    if (dart.library.js_interop) 'package:imboy/component/upload/browser_direct_put_web.dart'
    as browser_put;

part 'attachment_direct_transport.dart';
part 'attachment_direct_source.dart';
part 'attachment_direct_source_engine.dart';
part 'attachment_direct_confirmation.dart';

/// direct-v1 客户端：register → declare → grant → PUT → finalize → CONFIRMED。
/// [AttachmentApi.uploadViaPresign] 的生产出口复用本状态机。
/// 原生 File 与浏览器字节/stream source 共用状态机；原生 hash/PUT 保持流式。
/// PUT 只带 required_headers，不携带业务 JWT/Cookie，也不跟随重定向。
/// 失败或取消不重放旧 URL；renew 新 attempt，服务端预算为 3。
/// UNKNOWN 不进入业务 outbox；恢复以 status 和原账号/材料为准。

/// direct-v1 会话请求 seam（默认 [HttpClient.client]；测试注入 fake）。
typedef DirectSessionFn = Future<IMBoyHttpResponse> Function(
  String path, {
  Map<String, dynamic>? body,
});

/// 保留原生 File PUT seam 的既有签名；默认运输由平台 source 适配。
typedef DirectFilePutFn = Future<void> Function(
  String url,
  io.File file,
  int length,
  Map<String, String> headers,
);

/// source PUT seam；取消令牌与真实字节进度由平台运输接收。
typedef DirectSourcePutFn = Future<void> Function(
  String url,
  DirectUploadSource source,
  int length,
  Map<String, String> headers, {
  CancelToken? cancelToken,
  void Function(int sent, int total)? onProgress,
});

/// direct-v1 阶段检查点（持久化由调用方决定；材料只有明文文件本身，
/// 无密钥类敏感值——与 V5 sealed 检查点不同，不进安全存储）。
enum DirectCheckpointStage { registered, declared, granted, putDone, confirmed }

class DirectCheckpoint {
  final DirectCheckpointStage stage;
  final String? objectKey;
  final String? clientUploadId;
  final int? attemptId;

  const DirectCheckpoint(
    this.stage, {
    this.objectKey,
    this.clientUploadId,
    this.attemptId,
  });
}

/// grant 下发的 s3_put 描述符（协议 §3；required_headers 原样透传）。
class DirectGrantDescriptor {
  final String url;
  final String method;
  final Map<String, String> requiredHeaders;
  final int attemptId;
  final int expiresIn;

  const DirectGrantDescriptor({
    required this.url,
    required this.method,
    required this.requiredHeaders,
    required this.attemptId,
    required this.expiresIn,
  });
}

class DirectUploadResult {
  final String objectKey;

  /// CONFIRMED 或 FINALIZING（服务端封存中；quarantined=true 时本次 attempt
  /// 已被隔离，重试必须新 attempt）。
  final String state;
  final int attemptId;
  final bool quarantined;

  const DirectUploadResult({
    required this.objectKey,
    required this.state,
    required this.attemptId,
    this.quarantined = false,
  });
}

/// 原登记身份与当前协议声明不一致，必须隔离原任务。
class DirectRegistrationConflict implements Exception {
  const DirectRegistrationConflict();
}

/// 本地取消（用户中止）：中止流/不调 finalize，服务端会话由 sweep 收敛。
class DirectUploadCancelled implements Exception {
  final String objectKey;
  const DirectUploadCancelled(this.objectKey);
  @override
  String toString() => 'DirectUploadCancelled($objectKey)';
}

/// 跨账号恢复拒绝（E10：credentials epoch 期间旧任务不向新账号写回）。
class DirectUploadEpochMismatch implements Exception {
  final String journalUid;
  final String currentUid;
  const DirectUploadEpochMismatch(this.journalUid, this.currentUid);
  @override
  String toString() => 'DirectUploadEpochMismatch($journalUid != $currentUid)';
}

/// 生成 36 位 UUID v4 形态的 client_upload_id（幂等恢复键）。
///
/// 后端 register 仅校验「36 字节 binary」才落库为幂等键（更短/未提供落
/// NULL，会话失去 kill 后恢复能力）；用 [Random.secure] 自足生成，不引
/// 新依赖。
String newClientUploadId([Random? random]) {
  final Random r = random ?? Random.secure();
  final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  final String hex = [for (int i = 0; i < 16; i++) h(i)].join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}

/// 流式计算文件 SHA-256（File.openRead 分块；**绝不 readAsBytes**）。
/// 返回 64 位小写 hex。
Future<String> sha256OfFile(io.File file) async {
  // Hash.bind(Stream) 流式增量：内存有界，绝不 readAsBytes（R04）。
  final crypto.Digest digest = await crypto.sha256.bind(file.openRead()).first;
  return digest.toString();
}

/// direct-v1 上传编排（原生文件与浏览器字节流共用）。
class DirectAttachmentApi {
  /// PUT 重试上限：与协议 §1.3 每 session 最大写 attempt 数一致（服务端
  /// fn_dv1_attempt_create 23514 硬门为最终防线）。
  static const int maxAttempts = 3;

  static void _checkCancelled(CancelToken? token, [String objectKey = '']) {
    if (token?.isCancelled == true) {
      throw DirectUploadCancelled(objectKey);
    }
  }

  /// 会话信封里的处理中/终态字面量（与后端 direct_state 对齐）。
  static const String stateConfirmed = 'CONFIRMED';
  static const String stateFinalizing = 'FINALIZING';

  /// register 单步（RESERVED，无写能力/R08）：同 client_upload_id 同声明幂
  /// 等，返回服务端生成的 object_key。
  ///
  /// 供调用方在 PUT/finalize 之前把 object_key 持久化（恢复链上 status 查
  /// 询以 object_key 为键；先落盘再续作，崩溃窗口不丢单）。
  static Future<String> registerSession({
    required String fileName,
    String scope = 'private',
    String? scopeRef,
    String? clientUploadId,
    String? cipher,
    String purpose = 'attachment',
    String? anchorMsgId,
    DirectSessionFn? sessionFn,
    CancelToken? cancelToken,
    void Function(String state)? onState,
  }) async {
    _checkCancelled(cancelToken);
    Future<IMBoyHttpResponse> session(
      String action, {
      Map<String, dynamic>? body,
    }) async {
      _checkCancelled(cancelToken);
      final String path = '/api/v1/attachment/direct/$action';
      final response = sessionFn != null
          ? await sessionFn(path, body: body)
          : await HttpClient.client.post(
              path,
              data: body,
              cancelToken: cancelToken,
            );
      _checkCancelled(cancelToken);
      return response;
    }

    final IMBoyHttpResponse reg = await session(
      'register',
      body: <String, dynamic>{
        'filename': fileName,
        'scope': scope,
        if (scopeRef != null && scopeRef.isNotEmpty) 'scope_ref': scopeRef,
        'client_upload_id': ?clientUploadId,
        'cipher': ?cipher,
        'purpose': purpose,
        'anchor_msg_id': ?anchorMsgId,
      },
    );
    _checkCancelled(cancelToken);
    if (!reg.ok) {
      if (reg.msg == 'declaration_conflict') {
        throw const DirectRegistrationConflict();
      }
      throw Exception('direct register 失败: code=${reg.code} msg=${reg.msg}');
    }
    final String objectKey = str(reg.payload, 'object_key');
    if (objectKey.isEmpty) {
      throw Exception('direct register 响应缺少 object_key');
    }
    onState?.call(str(reg.payload, 'state'));
    return objectKey;
  }

  /// 首传：register→declare→grant→PUT→finalize（全链）。
  ///
  /// [file] 即明文材料本身：恢复无需密钥存储，重启后按 [resumeDirect] 以
  /// 服务端 status 为权威续作。所有网络面均可注入脱离真实网络。
  static Future<DirectUploadResult> uploadFile(
    io.File file, {
    required String fileName,
    required String mime,
    String scope = 'private',
    String? scopeRef,
    String? clientUploadId,
    String? cipher,
    String purpose = 'attachment',
    String? anchorMsgId,

    /// 非 null 时本地取消该 attempt（AbortSignal 语义）：中断流并抛
    /// [DirectUploadCancelled]，不调 finalize。
    VoidCallback? registerCancelHandler,
    DirectSessionFn? sessionFn,
    CancelToken? cancelToken,
    DirectFilePutFn? putFn,
    void Function(int sent, int total)? onProgress,
    Future<void> Function(DirectCheckpoint event)? checkpoint,
  }) async {
    _checkCancelled(cancelToken);
    return uploadSource(
      _fileUploadSource(file),
      fileName: fileName,
      mime: mime,
      scope: scope,
      scopeRef: scopeRef,
      clientUploadId: clientUploadId,
      cipher: cipher,
      purpose: purpose,
      anchorMsgId: anchorMsgId,
      registerCancelHandler: registerCancelHandler,
      sessionFn: sessionFn,
      cancelToken: cancelToken,
      onProgress: onProgress,
      checkpoint: checkpoint,
      putFn: _filePutAdapter(file, putFn),
    );
  }

  /// 使用可重开字节流，复用 register/declare/grant/PUT/finalize 状态机。
  static Future<DirectUploadResult> uploadSource(
    DirectUploadSource source, {
    required String fileName,
    required String mime,
    String scope = 'private',
    String? scopeRef,
    String? clientUploadId,
    String? cipher,
    String purpose = 'attachment',
    String? anchorMsgId,

    /// 非 null 时本地取消该 attempt（AbortSignal 语义）：中断流并抛
    /// [DirectUploadCancelled]，不调 finalize。
    VoidCallback? registerCancelHandler,
    DirectSessionFn? sessionFn,
    CancelToken? cancelToken,
    DirectSourcePutFn? putFn,
    void Function(int sent, int total)? onProgress,
    Future<void> Function(DirectCheckpoint event)? checkpoint,
  }) => _uploadDirectSource(
    source,
    fileName: fileName,
    mime: mime,
    scope: scope,
    scopeRef: scopeRef,
    clientUploadId: clientUploadId,
    cipher: cipher,
    purpose: purpose,
    anchorMsgId: anchorMsgId,
    registerCancelHandler: registerCancelHandler,
    sessionFn: sessionFn,
    cancelToken: cancelToken,
    onProgress: onProgress,
    checkpoint: checkpoint,
    putFn: putFn,
  );

  /// 查询会话当前状态（恢复第一跳；RESERVED/DECLARED/GRANTED/FINALIZING/
  /// CONFIRMED 等服务端权威状态）。网络/信封失败抛异常。
  static Future<String?> strictStatus({
    required String objectKey,
    DirectSessionFn? sessionFn,
    CancelToken? cancelToken,
  }) async {
    _checkCancelled(cancelToken, objectKey);
    const path = '/api/v1/attachment/direct/status';
    final query = <String, dynamic>{'object_key': objectKey};
    final response = sessionFn != null
        ? await sessionFn(path, body: query)
        : await HttpClient.client.get(
            path,
            queryParameters: query,
            cancelToken: cancelToken,
          );
    _checkCancelled(cancelToken, objectKey);
    final payload = response.payload;
    if (!response.ok ||
        payload is! Map ||
        payload['object_key'] != objectKey ||
        !payload.containsKey('state')) {
      throw StateError('direct status unavailable or invalid');
    }
    final state = payload['state'];
    if (state != null && state is! String) {
      throw StateError('direct status invalid state');
    }
    return state as String?;
  }

  static Future<DirectUploadResult> status({
    required String objectKey,
    DirectSessionFn? sessionFn,
    CancelToken? cancelToken,
  }) async {
    _checkCancelled(cancelToken, objectKey);
    const String path = '/api/v1/attachment/direct/status';
    final Map<String, dynamic> query = {'object_key': objectKey};
    final IMBoyHttpResponse st = sessionFn != null
        ? await sessionFn(path, body: query)
        : await HttpClient.client.get(
            path,
            queryParameters: query,
            cancelToken: cancelToken,
          );
    _checkCancelled(cancelToken, objectKey);
    if (!st.ok) {
      throw Exception('direct status 失败: code=${st.code} msg=${st.msg}');
    }
    _checkCancelled(cancelToken, objectKey);
    return DirectUploadResult(
      objectKey: objectKey,
      state: str(st.payload, 'state'),
      attemptId: 0,
    );
  }

  /// 恢复（重启/断线后续作）：以服务端 status 为权威。
  ///
  /// * CONFIRMED → 直接返回（幂等，不重发）；
  /// * GRANTED/FINALIZING → renew_grant 新 attempt 续传（不 readAsBytes）；
  /// * 其他终态 → 抛错（会话已被服务端收敛，调用方应重建会话）。
  static Future<DirectUploadResult> resumeDirect({
    required String objectKey,
    required io.File file,
    required String mime,
    DirectSessionFn? sessionFn,
    CancelToken? cancelToken,
    DirectFilePutFn? putFn,
    void Function(int sent, int total)? onProgress,
    Future<void> Function(DirectCheckpoint event)? checkpoint,
  }) async {
    _checkCancelled(cancelToken, objectKey);
    return resumeSource(
      objectKey: objectKey,
      mime: mime,
      sessionFn: sessionFn,
      cancelToken: cancelToken,
      onProgress: onProgress,
      checkpoint: checkpoint,
      source: _fileUploadSource(file),
      putFn: _filePutAdapter(file, putFn),
    );
  }

  /// 使用相同状态机恢复可重开的浏览器或原生材料。
  static Future<DirectUploadResult> resumeSource({
    required String objectKey,
    required DirectUploadSource source,
    required String mime,
    DirectSessionFn? sessionFn,
    CancelToken? cancelToken,
    DirectSourcePutFn? putFn,
    void Function(int sent, int total)? onProgress,
    Future<void> Function(DirectCheckpoint event)? checkpoint,
  }) => _resumeDirectSource(
    objectKey: objectKey,
    mime: mime,
    sessionFn: sessionFn,
    cancelToken: cancelToken,
    onProgress: onProgress,
    checkpoint: checkpoint,
    source: source,
    putFn: putFn,
  );

  static DirectGrantDescriptor grantOf(dynamic payload) {
    final dynamic g = payload is Map ? payload['grant'] : null;
    if (g is! Map) {
      throw Exception('direct grant 响应缺少 grant 描述符');
    }
    final dynamic rh = g['required_headers'];
    // 后端 to_js 线格式：tuple {K,V} → JSON 二元数组 [K, V]（20b 真 HTTP
    // driver 实证）。只按真实形态解析——同时兼容 {K:V} 会再次掩盖两端漂移。
    if (rh is! List ||
        rh.length != 2 ||
        g['transport'] != 's3_put' ||
        g['method'] != 'PUT') {
      throw StateError('invalid direct grant');
    }
    final headers = <String, String>{};
    for (final item in rh) {
      if (item is! List ||
          item.length != 2 ||
          item[0] is! String ||
          item[1] is! String) {
        throw StateError('invalid direct grant header');
      }
      final key = (item[0] as String).toLowerCase();
      final value = item[1] as String;
      if (!{'content-type', 'x-amz-checksum-sha256'}.contains(key) ||
          value.isEmpty ||
          value.contains('\r') ||
          value.contains('\n') ||
          headers.keys.any((existing) => existing.toLowerCase() == key)) {
        throw StateError('invalid direct grant header');
      }
      headers[item[0] as String] = value;
    }
    final rawUrl = g['url'];
    if (rawUrl is! String || rawUrl.trim() != rawUrl || rawUrl.contains('\\')) {
      throw StateError('invalid direct grant url');
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                (uri.host == 'localhost' || uri.host == '127.0.0.1')))) {
      throw StateError('invalid direct grant url');
    }
    final attemptId =
        int.tryParse('${payload is Map ? payload['attempt_id'] : null}') ?? 0;
    if (attemptId <= 0) throw StateError('invalid direct attempt');
    return DirectGrantDescriptor(
      url: rawUrl,
      method: 'PUT',
      requiredHeaders: headers,
      attemptId: attemptId,
      expiresIn: int.tryParse('${g['expires_in']}') ?? 3600,
    );
  }

  static int attemptCount(dynamic payload) {
    if (payload is! Map) return 0;
    final dynamic attempts = payload['attempts'];
    return attempts is List ? attempts.length : 0;
  }

  static String str(dynamic payload, String key) {
    return IMBoyHttpResponse.payloadStr(payload, key) ?? '';
  }
}

/// 跨进程会话定位 journal（加速恢复；服务端 status 仍是权威）。
/// 只存非敏感定位字段（uid/client_upload_id/object_key），无密钥、无 URL。
class DirectUploadJournal {
  final String uid;
  final String clientUploadId;
  final String objectKey;
  final String stage;

  const DirectUploadJournal({
    required this.uid,
    required this.clientUploadId,
    required this.objectKey,
    required this.stage,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
    'uid': uid,
    'client_upload_id': clientUploadId,
    'object_key': objectKey,
    'stage': stage,
  };

  static DirectUploadJournal fromMap(Map<String, dynamic> m) =>
      DirectUploadJournal(
        uid: '${m['uid']}',
        clientUploadId: '${m['client_upload_id']}',
        objectKey: '${m['object_key']}',
        stage: '${m['stage']}',
      );

  /// epoch 校验（E10）：uid 不符即拒绝恢复，旧任务不得向新账号写回。
  void requireEpoch(String currentUid) {
    if (uid != currentUid) {
      throw DirectUploadEpochMismatch(uid, currentUid);
    }
  }

  /// 默认落盘位置（应用临时目录；只作加速，丢失后 status 仍可恢复）。
  static io.File journalFile(io.Directory base) => io.File(
    '${base.path}${io.Platform.pathSeparator}imboy_direct_upload_journal.json',
  );

  static Future<void> save(io.Directory base, DirectUploadJournal j) async {
    await journalFile(base).writeAsString(jsonEncode(j.toMap()), flush: true);
  }

  static Future<DirectUploadJournal?> load(io.Directory base) async {
    final io.File f = journalFile(base);
    if (!f.existsSync()) return null;
    try {
      final dynamic decoded = jsonDecode(f.readAsStringSync());
      return decoded is Map
          ? fromMap(Map<String, dynamic>.from(decoded))
          : null;
    } catch (_) {
      return null;
    }
  }
}
