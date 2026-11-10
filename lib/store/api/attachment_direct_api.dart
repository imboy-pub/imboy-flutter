import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' as io;

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart' show CancelToken;
import 'package:imboy/store/api/attachment_api.dart' show AttachmentApi;
import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/attachment_api.dart';

part 'attachment_direct_transport.dart';

/// direct-v1（协议 docs/architecture/attachment-direct-transfer-v1-protocol.md，
/// backend attachment_direct_logic）的客户端实现。
///
/// 与 V5 [AttachmentApi.uploadViaPresign]（Uint8List 整文件内存路径）并行：
///   register（RESERVED，无写能力）→ declare（expected 冻结）→ grant（COMMIT
///   后签发 staging s3_put 描述符）→ fixed-length 流式 PUT（required_headers
///   仅 Content-Type + x-amz-checksum-sha256，无业务凭据）→ finalize（服务端
///   单次 Copy dispatch + proof + winner pin）→ CONFIRMED。
///
/// 安全合同（客户端侧）：
///   * required_headers 原样发送、不增不减——grant URL 是签名绑定
///     （content-type;host;x-amz-checksum-sha256），任何额外 x-amz-*/ACL/copy-source
///     头都会破坏签名或越权（T07）；
///   * 无业务 JWT/Cookie 进存储 PUT（T29：业务 Bearer 仅送本实例 API）；
///   * 大文件全程不 readAsBytes：hash 与 PUT 均为 File.openRead 流式（R04）；
///   * grant 是单次写授权：PUT 失败/取消后不得重放同一 URL，重试只能
///     renew_grant（新 attempt + 新 target，I05）；重试上限 3（服务端预算硬门）；
///   * finalize 返回 UNKNOWN_QUARANTINED（服务端封存中）时不得把附件发出，
///     重试仍走新 attempt；
///   * 恢复以服务端 status 为权威（本地 journal 仅加速定位会话，epoch=uid
///     不符即拒绝，E10）。

/// direct-v1 会话请求 seam（默认 [HttpClient.client]；测试注入 fake）。
typedef DirectSessionFn = Future<IMBoyHttpResponse> Function(
  String path, {
  Map<String, dynamic>? body,
});

/// fixed-length 流式 PUT seam（默认 [_ioFilePut]；测试注入 fake 捕获 headers）。
typedef DirectFilePutFn = Future<void> Function(
  String url,
  io.File file,
  int length,
  Map<String, String> headers,
);

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

/// direct-v1 上传编排（文件化全链）。
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
    if (mime == 'image/jpg') mime = 'image/jpeg';
    final int size = file.lengthSync();
    final String? validationError = AttachmentApi.validateUpload(size, mime);
    if (validationError != null) {
      throw Exception(validationError);
    }

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

    // 1. register（RESERVED，无写能力/R08）：同 client_upload_id 同声明幂等。
    String registeredState = '';
    final String objectKey = await registerSession(
      fileName: fileName,
      scope: scope,
      scopeRef: scopeRef,
      clientUploadId: clientUploadId,
      cipher: cipher,
      purpose: purpose,
      anchorMsgId: anchorMsgId,
      sessionFn: sessionFn,
      cancelToken: cancelToken,
      onState: (state) => registeredState = state,
    );
    _checkCancelled(cancelToken, objectKey);
    await checkpoint?.call(
      DirectCheckpoint(
        DirectCheckpointStage.registered,
        objectKey: objectKey,
        clientUploadId: clientUploadId,
      ),
    );

    if (registeredState == stateConfirmed ||
        registeredState == 'GRANTED' ||
        registeredState == stateFinalizing) {
      return resumeDirect(
        objectKey: objectKey,
        file: file,
        mime: mime,
        sessionFn: sessionFn,
        cancelToken: cancelToken,
        putFn: putFn,
        onProgress: onProgress,
        checkpoint: checkpoint,
      );
    }

    if (registeredState != 'RESERVED' && registeredState != 'DECLARED') {
      throw StateError('direct session terminal: $registeredState');
    }

    // 2. declare：expected 冻结（同值幂等；异值 expected_conflict）。
    final String sha256Hex = await sha256OfFile(file);
    final IMBoyHttpResponse decl = await session(
      'declare',
      body: <String, dynamic>{
        'object_key': objectKey,
        'sha256': sha256Hex,
        'size_bytes': size,
        'mime': mime,
      },
    );
    if (!decl.ok) {
      throw Exception('direct declare 失败: code=${decl.code} msg=${decl.msg}');
    }
    await checkpoint?.call(
      DirectCheckpoint(DirectCheckpointStage.declared, objectKey: objectKey),
    );

    // 3..N grant → 流式 PUT → finalize；失败/隔离只能 renew 新 attempt。
    int attemptId = 0;
    for (int round = 1; round <= maxAttempts; round++) {
      final IMBoyHttpResponse grantResp = round == 1
          ? await session(
              'grant',
              body: <String, dynamic>{
                'object_key': objectKey,
                'sha256': sha256Hex,
              },
            )
          : await session(
              'renew',
              body: <String, dynamic>{
                'object_key': objectKey,
                'sha256': sha256Hex,
              },
            );
      if (!grantResp.ok) {
        // 预算耗尽等：把信封语义上抛（40904 attempt_budget_exhausted）。
        throw Exception(
          'direct grant 失败: code=${grantResp.code} msg=${grantResp.msg}',
        );
      }
      final DirectGrantDescriptor grant = grantOf(grantResp.payload);
      attemptId = grant.attemptId;
      await checkpoint?.call(
        DirectCheckpoint(
          DirectCheckpointStage.granted,
          objectKey: objectKey,
          attemptId: attemptId,
        ),
      );

      _checkCancelled(cancelToken, objectKey);
      bool cancelled = false;
      bool putFailed = false;
      try {
        final Future<void> putting = putFn != null
            ? putFn(grant.url, file, size, grant.requiredHeaders)
            : _ioFilePut(
                grant.url,
                file,
                size,
                grant.requiredHeaders,
                onProgress: onProgress,
                cancelToken: cancelToken,
              );
        registerCancelHandler?.call();
        await putting;
        _checkCancelled(cancelToken, objectKey);
      } on DirectUploadCancelled {
        cancelled = true;
      } catch (_) {
        _checkCancelled(cancelToken, objectKey);
        // 普通 PUT 失败（网络/5xx）：该 attempt 已 dispatch、无 closed 证据，
        // 不得 finalize 它；URL 是单次授权，重放同一 URL 无意义（I05）——
        // 直接 renew 新 attempt。预算由服务端 23514 硬门兜底。
        putFailed = round != maxAttempts;
        if (!putFailed) rethrow;
      }
      if (cancelled) {
        // 本地取消：不 finalize（服务端会话超期由 sweep 收敛，物理残留由
        // step-7 cleanup 账本收敛）。重试必须新 attempt。
        throw DirectUploadCancelled(objectKey);
      }
      if (putFailed) {
        continue;
      }
      await checkpoint?.call(
        DirectCheckpoint(
          DirectCheckpointStage.putDone,
          objectKey: objectKey,
          attemptId: attemptId,
        ),
      );

      final IMBoyHttpResponse fin = await session(
        'finalize',
        body: <String, dynamic>{
          'object_key': objectKey,
          'attempt_id': attemptId,
        },
      );
      if (fin.ok) {
        final String state = str(fin.payload, 'state');
        // confirmed checkpoint 只对应真 CONFIRMED——UNKNOWN 封存态（FINALIZING）
        // 发 confirmed 会让持久化该 checkpoint 的调用方误判"已确认"而发出
        // 未证明附件，与下方 quarantined 标志自相矛盾。
        if (state == stateConfirmed) {
          await checkpoint?.call(
            DirectCheckpoint(
              DirectCheckpointStage.confirmed,
              objectKey: objectKey,
              attemptId: attemptId,
            ),
          );
        }
        _checkCancelled(cancelToken, objectKey);
        return DirectUploadResult(
          objectKey: objectKey,
          state: state,
          attemptId: attemptId,
          // UNKNOWN_QUARANTINED：本次 attempt 已被服务端隔离，调用方不得
          // 把附件发出（重试走 resumeDirect/新 attempt）
          quarantined: str(fin.payload, 'outcome') == 'UNKNOWN_QUARANTINED',
        );
      }
      // 非确认信封：rejected（可重试新 attempt）或预算耗尽（40904 上抛）。
      final int code = fin.code;
      final bool retryable = code == 409; // 409 attempt_rejected/illegal_state
      if (!retryable || round == maxAttempts) {
        throw Exception('direct finalize 失败: code=$code msg=${fin.msg}');
      }
    }
    throw StateError('direct upload exhausted attempts (objectKey=$objectKey)');
  }

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
    if (mime == 'image/jpg') mime = 'image/jpeg';
    final int size = file.lengthSync();
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

    const String statusPath = '/api/v1/attachment/direct/status';
    final Map<String, dynamic> statusQuery = {'object_key': objectKey};
    final IMBoyHttpResponse st = sessionFn != null
        ? await sessionFn(statusPath, body: statusQuery)
        : await HttpClient.client.get(
            statusPath,
            queryParameters: statusQuery,
            cancelToken: cancelToken,
          );
    _checkCancelled(cancelToken, objectKey);
    if (!st.ok) {
      throw Exception('direct status 失败: code=${st.code} msg=${st.msg}');
    }
    final String state = str(st.payload, 'state');
    if (state != stateConfirmed &&
        state != 'GRANTED' &&
        state != stateFinalizing) {
      throw StateError('direct session terminal: $state');
    }
    final payload = IMBoyHttpResponse.payloadAsMap(st.payload);
    final rawExpected = payload['expected'];
    final dynamic decoded = rawExpected is String
        ? jsonDecode(rawExpected)
        : rawExpected;
    final sha256Hex = await sha256OfFile(file);
    _checkCancelled(cancelToken, objectKey);
    if (decoded is! Map ||
        decoded['sha256'] != sha256Hex ||
        decoded['size_bytes']?.toString() != size.toString() ||
        decoded['mime'] != mime) {
      throw StateError('direct upload does not match local file');
    }
    if (state == stateConfirmed) {
      return DirectUploadResult(
        objectKey: objectKey,
        state: state,
        attemptId: 0,
      );
    }
    final int used = attemptCount(st.payload);
    if (used >= maxAttempts) {
      throw StateError('direct attempt budget exhausted (remote)');
    }
    final IMBoyHttpResponse renew = await session(
      'renew',
      body: <String, dynamic>{'object_key': objectKey, 'sha256': sha256Hex},
    );
    if (!renew.ok) {
      throw Exception('direct renew 失败: code=${renew.code} msg=${renew.msg}');
    }
    final DirectGrantDescriptor grant = grantOf(renew.payload);
    await checkpoint?.call(
      DirectCheckpoint(
        DirectCheckpointStage.granted,
        objectKey: objectKey,
        attemptId: grant.attemptId,
      ),
    );
    _checkCancelled(cancelToken, objectKey);
    if (putFn != null) {
      await putFn(grant.url, file, size, grant.requiredHeaders);
    } else {
      await _ioFilePut(
        grant.url,
        file,
        size,
        grant.requiredHeaders,
        onProgress: onProgress,
      );
    }
    _checkCancelled(cancelToken, objectKey);
    await checkpoint?.call(
      DirectCheckpoint(
        DirectCheckpointStage.putDone,
        objectKey: objectKey,
        attemptId: grant.attemptId,
      ),
    );
    final IMBoyHttpResponse fin = await session(
      'finalize',
      body: <String, dynamic>{
        'object_key': objectKey,
        'attempt_id': grant.attemptId,
      },
    );
    if (!fin.ok) {
      throw Exception('direct finalize 失败: code=${fin.code} msg=${fin.msg}');
    }
    // 与 uploadFile 同规则：confirmed checkpoint 只对应真 CONFIRMED
    //（UNKNOWN 封存态不得让调用方误判"已确认"）。
    if (str(fin.payload, 'state') == stateConfirmed) {
      await checkpoint?.call(
        DirectCheckpoint(
          DirectCheckpointStage.confirmed,
          objectKey: objectKey,
          attemptId: grant.attemptId,
        ),
      );
    }
    _checkCancelled(cancelToken, objectKey);
    return DirectUploadResult(
      objectKey: objectKey,
      state: str(fin.payload, 'state'),
      attemptId: grant.attemptId,
      // 与 uploadFile 同合同：UNKNOWN 封存态不得把附件发出
      quarantined: str(fin.payload, 'outcome') == 'UNKNOWN_QUARANTINED',
    );
  }

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
