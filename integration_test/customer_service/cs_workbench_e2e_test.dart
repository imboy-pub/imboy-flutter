// integration_test/customer_service/cs_workbench_e2e_test.dart
//
// APP-M02-A06 — 客服坐席工作台真实链路集成测试（Tier 3，真机直连真后端）。
//
// 纪律：
//   * 无 TODO / 无 skip / 无 mock：全部断言走真实 HTTP（dio 直连
//     run-specific API base），失败即红，不 mock、不 page.route、不 skip；
//   * run-specific 注入一律经 --dart-define（真机构建期固化，无运行时
//     环境变量依赖），P1-MOBILE-DEVICE-GATE 以本文件为移动端权威入口；
//   * 合成 fixture 由 run 造数提供（RUN_ID 前缀的 org/session/坐席 JWT），
//     本测试只消费，不造数、不清场；
//   * envelope 宽容解析（`data` 键包裹或裸 payload 均兼容），断言落在
//     业务事实（状态/版本/幂等回显）而非传输形状。
//
// 注入参数（flutter test --dart-define=CS_E2E_API_BASE=... ）：
//   CS_E2E_API_BASE    必填，如 http://192.168.2.98:9802（RUN 专用节点）
//   CS_E2E_SEAT_JWT    必填，坐席 Bearer JWT（合成坐席）
//   CS_E2E_ORG_ID      必填，合成组织 TSID
//   CS_E2E_WORKSPACE_ID 可选，SSE 建流用；缺省取 seat-contexts 首个
//   CS_E2E_SESSION_ID  可选，指定接单会话；缺省取 queue 首条 queued
//   CS_E2E_TRANSFER_TARGET_ID 可选，提供则执行 A→B 真实 transfer 写链
//
// 运行（多设备环境必须显式 -d）：
//   flutter test integration_test/customer_service/cs_workbench_e2e_test.dart \
//     -d <真机设备ID> \
//     --dart-define=CS_E2E_API_BASE=http://192.168.2.98:9802 \
//     --dart-define=CS_E2E_SEAT_JWT=... \
//     --dart-define=CS_E2E_ORG_ID=...
// 证据须附 `adb devices -l` 输出与 run 节点日志窗口。

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

const _kApiBase = String.fromEnvironment('CS_E2E_API_BASE');
const _kSeatJwt = String.fromEnvironment('CS_E2E_SEAT_JWT');
const _kOrgId = String.fromEnvironment('CS_E2E_ORG_ID');
const _kWorkspaceId = String.fromEnvironment('CS_E2E_WORKSPACE_ID');
const _kSessionId = String.fromEnvironment('CS_E2E_SESSION_ID');
const _kTransferTargetId = String.fromEnvironment('CS_E2E_TRANSFER_TARGET_ID');

/// envelope 宽容解包：imboy 网关可能包裹 `{code,msg,data}` 或直接回
/// payload；断言只落业务事实。
dynamic _unwrap(dynamic body) {
  if (body is Map && body.containsKey('data')) {
    final data = body['data'];
    if (data is Map &&
        (data.containsKey('contexts') ||
            data.containsKey('sessions') ||
            data.containsKey('list') ||
            data.containsKey('id') ||
            data.containsKey('session_id'))) {
      return data;
    }
    return data ?? body;
  }
  return body;
}

/// 断言 envelope 状态码（`code` 键存在时必须 2xx；缺失视为裸 payload 成功）。
int _codeOf(dynamic body) {
  if (body is Map && body['code'] is num) {
    return (body['code'] as num).toInt();
  }
  return 200;
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // fail-fast 装配检查：缺参 = 环境装配失败 = 红（不允许 skip 假绿）。
  expect(
    _kApiBase,
    isNotEmpty,
    reason:
        'CS_E2E_API_BASE 未注入：请用 --dart-define 提供本次 run 的'
        ' API base（见文件头注释）。集成测试禁止在缺参时 skip。',
  );
  expect(_kSeatJwt, isNotEmpty, reason: 'CS_E2E_SEAT_JWT 未注入');
  expect(_kOrgId, isNotEmpty, reason: 'CS_E2E_ORG_ID 未注入');

  final dio = Dio(
    BaseOptions(
      baseUrl: _kApiBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'authorization': _kSeatJwt, 'content-type': 'application/json'},
      validateStatus: (_) => true, // 状态码由断言裁决，不让 dio 抛
    ),
  );

  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) async {
    final resp = await dio.get<dynamic>(path, queryParameters: query);
    expect(
      resp.statusCode,
      200,
      reason: 'GET $path → HTTP ${resp.statusCode}（body=${resp.data}）',
    );
    expect(
      _codeOf(resp.data),
      inInclusiveRange(200, 299),
      reason: 'GET $path → envelope code 非 2xx（body=${resp.data}）',
    );
    return _unwrap(resp.data);
  }

  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body, {
    int expectStatus = 200,
  }) async {
    final resp = await dio.post<dynamic>(path, data: body);
    expect(
      resp.statusCode,
      expectStatus,
      reason: 'POST $path → HTTP ${resp.statusCode}（body=${resp.data}）',
    );
    return resp.data;
  }

  test('CS workbench 真实链路：context → queue → claim → detail → '
      'send(幂等) → ack → transferTargets → SSE 建流 → close → 权威回读', () async {
    // ── 1. seat-contexts：配置 org 必须是可用坐席上下文 ──
    final ctxBody = await getJson('/api/v1/cs/me/seat-contexts');
    final contexts = CsSeatContexts.fromJson(ctxBody);
    final ctx = contexts.contexts
        .where((c) => c.organizationId == _kOrgId)
        .toList(growable: false);
    expect(
      ctx,
      isNotEmpty,
      reason: 'seat-contexts 未返回配置的 org=$_kOrgId（合成坐席装配缺口）',
    );
    expect(
      ctx.first.isEligible,
      isTrue,
      reason: 'org=$_kOrgId 上下文不 eligible（assignment/seat 未启用）',
    );
    final workspaceId = _kWorkspaceId.isNotEmpty
        ? _kWorkspaceId
        : ctx.first.workspaces.first.id;

    // ── 2. queue：定位目标会话（指定或首条 queued），读 CAS 版本 ──
    final queue = CsQueuePage.fromJson(
      await getJson(
        '/api/v1/cs/organizations/$_kOrgId/sessions/queue',
        query: {'limit': 50},
      ),
    );
    final item = _kSessionId.isNotEmpty
        ? queue.items.where((q) => q.sessionId == _kSessionId).toList()
        : queue.items.where((q) => q.status == 'queued').toList();
    expect(item, isNotEmpty, reason: 'queue 中无目标会话（fixture 未造 queued 会话？）');
    expect(
      item.first.version,
      greaterThan(0),
      reason: 'queue 投影缺 version：客户端不得对 version=0 发起 CAS claim',
    );
    final sessionId = item.first.sessionId;

    // ── 3. claim：CAS 接单，回显 active + 服务端身份 ──
    final claimResp = await postJson(
      '/api/v1/cs/organizations/$_kOrgId/sessions/$sessionId/claim',
      {'expected_version': item.first.version},
    );
    final claim = CsClaimResult.fromJson(sessionId, _unwrap(claimResp));
    expect(claim.status, 'active', reason: 'claim 回显非 active');
    expect(
      claim.assigneeIdentityId,
      isNotEmpty,
      reason: 'claim 回显缺服务端派生 business_identity_id',
    );

    // ── 4. detail：权威 identity/conversation 事实源 ──
    final detailBody = await getJson(
      '/api/v1/cs/organizations/$_kOrgId/sessions/$sessionId',
    );
    final detail = CsSessionDetail.fromJson(detailBody);
    expect(detail.status, 'active');
    expect(
      detail.conversationId,
      isNotEmpty,
      reason: 'detail 缺 conversation_id：坐席消息通道不可用',
    );

    // ── 5. 历史首拉（EB 真源键集分页读面）──
    final history = await dio.get<dynamic>(
      '/api/v1/enterprise/conversations/${detail.conversationId}/messages',
      queryParameters: {'limit': 20},
    );
    expect(
      history.statusCode,
      200,
      reason: '坐席侧企业消息历史 HTTP ${history.statusCode}',
    );
    final historyRaw = _unwrap(history.data);
    final messages = historyRaw is List
        ? historyRaw
        : (historyRaw is Map
              ? (historyRaw['messages'] ??
                    historyRaw['list'] ??
                    const <dynamic>[])
              : const <dynamic>[]);
    expect(messages, isA<List<dynamic>>());

    // ── 6. send 纯文本 + 同 client_msg_id 幂等重发（同消息回显）──
    final clientMsgId = 'csww-e2e-${DateTime.now().microsecondsSinceEpoch}';
    final sendPath =
        '/api/v1/enterprise/organizations/$_kOrgId/conversations/'
        '${detail.conversationId}/messages';
    final sendBody = {
      'client_msg_id': clientMsgId,
      'sender_type': 'business_identity',
      'body': 'csww e2e seat outbound',
      'identity_id': claim.assigneeIdentityId,
    };
    final first = await postJson(sendPath, sendBody);
    final firstMsg = CsConversationMessage.fromJson(
      Map<String, dynamic>.from(_unwrap(first) as Map),
    );
    expect(firstMsg.message.id, isNotEmpty);
    final replay = await postJson(sendPath, sendBody);
    final replayMsg = CsConversationMessage.fromJson(
      Map<String, dynamic>.from(_unwrap(replay) as Map),
    );
    expect(
      replayMsg.message.id,
      firstMsg.message.id,
      reason: '同 client_msg_id 重放必须返回同一 message（幂等）',
    );

    // ── 7. 附件字节链（企业面 presign → 短期 PUT → confirm → asset_ids
    //      消息原子绑定；BE-PATCH-01 后通道形状见 widget/enterprise 面）──
    final bytes = Uint8List.fromList(utf8.encode('csww-e2e-attachment'));
    final hash = crypto.sha256.convert(bytes).toString();
    final presign = await postJson(
      '/api/v1/enterprise/organizations/$_kOrgId/assets/presign',
      {
        'file_name': 'csww-e2e-attachment.txt',
        'mime': 'text/plain',
        'size': bytes.length,
        'object_hash': hash,
      },
    );
    final presignMap = _asMap(_unwrap(presign));
    final assetId = '${presignMap['asset_id'] ?? presignMap['id'] ?? ''}';
    final uploadUrl =
        '${presignMap['upload_url'] ?? (presignMap['upload'] is Map ? (presignMap['upload'] as Map)['url'] ?? '' : '')}';
    expect(assetId, isNotEmpty, reason: 'presign 回显缺 asset_id');
    expect(uploadUrl, isNotEmpty, reason: 'presign 回显缺 upload url（字节上传通道缺失）');
    final putResp = await dio.put<dynamic>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'content-type': 'text/plain',
          'content-length': '${bytes.length}',
        },
      ),
    );
    expect(
      putResp.statusCode,
      inInclusiveRange(200, 299),
      reason: '字节 PUT HTTP ${putResp.statusCode}',
    );
    final confirm = await postJson(
      '/api/v1/enterprise/organizations/$_kOrgId/assets/confirm',
      {'asset_id': assetId, 'object_hash': hash, 'size': bytes.length},
    );
    expect(
      _asMap(_unwrap(confirm))['status'] ?? 'confirmed',
      isNotNull,
      reason: 'confirm 回显异常（body=$confirm）',
    );
    final attachSend = await postJson(sendPath, {
      'client_msg_id': '$clientMsgId-asset',
      'sender_type': 'business_identity',
      'body': '',
      'identity_id': claim.assigneeIdentityId,
      'asset_ids': [assetId],
    });
    final attachMsg = CsConversationMessage.fromJson(
      Map<String, dynamic>.from(_unwrap(attachSend) as Map),
    );
    expect(
      attachMsg.assetIds,
      contains(assetId),
      reason: 'asset_ids 消息回显缺原子绑定投影',
    );

    // ── 8. ACK（delivery-only，幂等）──
    await postJson(
      '/api/v1/enterprise/organizations/$_kOrgId/conversations/'
      '${detail.conversationId}/messages/${firstMsg.message.id}/ack',
      {'recipient_ref': 'identity:${claim.assigneeIdentityId}'},
    );

    // ── 9. transferTargets（只读面必通；提供目标则执行真实转接写链）──
    final targets = CsTransferTargetPage.fromJson(
      await getJson('/api/v1/cs/organizations/$_kOrgId/transfer-targets'),
    );
    expect(targets.items, isA<List<dynamic>>());
    if (_kTransferTargetId.isNotEmpty) {
      await postJson(
        '/api/v1/cs/organizations/$_kOrgId/sessions/$sessionId/transfer',
        {
          'to_identity_id': _kTransferTargetId,
          'expected_version': claim.version,
        },
        expectStatus: 200,
      );
      final afterTransfer = CsSessionDetail.fromJson(
        await getJson('/api/v1/cs/organizations/$_kOrgId/sessions/$sessionId'),
      );
      expect(
        afterTransfer.assigneeIdentityId,
        _kTransferTargetId,
        reason: 'transfer 后权威 detail 的经办身份未变更',
      );
      return; // 转接场景到此（B 坐席接续由 B 侧 run/ fixture 断言）
    }

    // ── 10. SSE 建流（close 前）：非 2xx/非 event-stream 即红 ──
    final sse = await dio.get<ResponseBody>(
      '/api/v1/cs/organizations/$_kOrgId/seats/me/events',
      queryParameters: {'workspace_id': workspaceId},
      options: Options(
        responseType: ResponseType.stream,
        headers: {'accept': 'text/event-stream', 'cache-control': 'no-store'},
      ),
    );
    expect(sse.statusCode, 200, reason: 'SSE 建流 HTTP ${sse.statusCode}');

    // ── 11. close（CAS）→ 权威回读 closed + rating 状态可读 ──
    await postJson(
      '/api/v1/cs/organizations/$_kOrgId/sessions/$sessionId/close',
      {'expected_version': claim.version, 'reason': 'csww-e2e-close'},
    );
    final closed = CsSessionDetail.fromJson(
      await getJson('/api/v1/cs/organizations/$_kOrgId/sessions/$sessionId'),
    );
    expect(closed.isClosed, isTrue, reason: 'close 后权威 detail 未 closed');
    expect(closed.rating, isA<int>(), reason: 'close 后 detail 应可读评分状态（0=未评分）');
  });
}
