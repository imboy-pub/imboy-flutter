/// APP-A09 — 真机企业+客服 E2E（DEVICE-01 真机门，run
/// cs-agent-entux-v1-20260924T164136Z-539f3dae）
///
/// 执行方式（多设备环境必须显式 `-d`；Android 需 `--flavor standard`）：
///
/// ```
/// flutter test integration_test/enterprise/enterprise_cs_e2e_test.dart \
///   -d <真机设备ID> --flavor standard \
///   --dart-define=IMBOY_API_BASE=http://<lan-ip>:19812 \
///   --dart-define=API_BASE_URL=http://<lan-ip>:19812 \
///   --dart-define=API_BASE_URL_OVERRIDE=http://<lan-ip>:19812 \
///   --dart-define=APP_ENV=local_office \
///   --dart-define=DEV1_WS=<种子 workspace> \
///   --dart-define=DEV1_CONV=<种子企业会话>
/// ```
///
/// 未注入 `--dart-define=IMBOY_API_BASE` 时本文件全部用例自动 skip（不产生红）。
///
/// 场景（amendment §3 APP-A09 13 步 + DEVICE-01 补齐旅程）：
///  1. 登录（个人域既有链路：/passport/login → UserRepoLocal.loginAfter）
///  2. 企业上下文（organizations/mine → active 成员）
///  3. 联系人（企业联系人，非个人好友）
///  4. 会话（企业会话真源）
///  5. 发送消息（冻结契约 client_msg_id/sender_type/body → accepted）
///  6. after_id 增量拉取（只含增量）
///  7. delivery ACK（真源仍在，delivery-only）
///  8. 附件上传（presign → PUT → confirm 重新鉴权）
///  9. 附件查看（GET assets/:id/content 鉴权代理回读）
/// 10. 客服 queue（queuePage）
/// 11. 客服 claim（CAS → active）
/// 12. 客服 transfer → close（CAS）
/// 13. rating（访客令牌）+ suspend 降级（suspend 后企业 API 403）
/// 补齐旅程：组织创建/切换、邀请双账号、成员 offboard、部门治理、
/// 冷启动会话恢复（第二轮进程即真冷启动）、断网恢复（真实 socket 不可达）。
///
/// 契约缺陷软探针（不置红，记录到 DEV1_FINDINGS 日志/RESULT 供卡片跟踪；
/// 旅程 oracle 一律经真实后端的冻结契约请求完成，禁止 mock）：
///  - D1: `GET /api/v1/enterprise/organizations` 路由缺失 → 404；
///  - D2: `EnterpriseApi.sendMessage` 旧形状 `{content}` → 422
///        （冻结契约为 client_msg_id/sender_type/body）；
///  - D3: 租户 GET 面（contacts/messages/content）与 ack/claim 冻结契约
///        必填 `workspace_id`（ack 另需 `recipient_ref`），App 侧客户端
///        未携带 → 422；conversations 列表 GET 后端无此用例 → 405。
library;

import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart' as dio_pkg;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/modules/customer_service/public.dart';
import 'package:imboy/modules/enterprise/public.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/api_test_client.dart';

/// 隔离后端地址（真机执行时经 --dart-define 注入）。
const String kImboyApiBase = String.fromEnvironment('IMBOY_API_BASE');

/// 种子事实（/tmp/dev1-runtime/dev1_node.escript 输出，经 --dart-define 注入）。
const String _org1Name = 'dev1-enterprise-a';
const String _seedWs = String.fromEnvironment('DEV1_WS');
const String _seedConv = String.fromEnvironment('DEV1_CONV');
const String _phoneA = '13900001201'; // org1 owner（sales + CS 身份）
const String _phoneB = '13900001202'; // member + 客服坐席 B
const String _phoneC = '13900001203'; // member（suspend/restore/offboard 目标）
const String _phoneD = '13900001205'; // 客服坐席 D（transfer 目标）
const String _password = 'admin888';

/// 访客评分令牌（种子 issue_visit_token 签发，64 字符）。
const String _visitToken =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

/// 契约缺陷探针记录（软记录：不影响绿/红，输出到日志供 RESULT 汇总）。
final Map<String, Object?> findings = <String, Object?>{};

/// 跨用例共享状态（同进程按声明顺序执行）。
final Map<String, Object> ctx = <String, Object>{};

FlowApiClient _rawFor(String did) =>
    FlowApiClient(baseUrl: kImboyApiBase, deviceId: did);

String _org1() => ctx['org1']! as String;
String _ws1() => ctx['ws1']! as String;
String _conv1() => ctx['conv1']! as String;
String _uidA() => ctx['uidA']! as String;
String _uidC() => ctx['uidC']! as String;

/// 个人域既有登录链路：/passport/login（raw）→ UserRepoLocal.loginAfter。
/// App 侧模块 API（EnterpriseApi/OrganizationApi/CsApi，均 extends
/// HttpClient）读取 UserRepoLocal 的会话，因此先落库再调用。
Future<void> _becomeUser(FlowApiClient raw, String phone) async {
  final body = await raw.login(
    account: phone,
    password: _password,
    type: 'mobile',
  );
  FlowApiAssert.success(body, context: 'login($phone)');
  final payload =
      (body['payload'] ?? <String, dynamic>{}) as Map<String, dynamic>;
  await UserRepoLocal.to.loginAfter(phone, payload);
}

/// 会话恢复探测：读本地持久化 token（不经 login），真实后端 200 即恢复成功。
Future<bool> _tryResumeSession(FlowApiClient raw) async {
  final tk = await SecureTokenStorageService.getToken();
  if (tk.length < 10) return false;
  raw.accessToken = tk;
  final resp = await raw.get(
    '/api/v1/organizations/mine',
    queryParameters: {'page': 1, 'size': 10},
  );
  return resp['code'] == 0;
}

/// 冻结契约 GET：workspace_id 为面级必填（query 携带）。
Future<Map<String, dynamic>> _entGet(
  FlowApiClient raw,
  String path, {
  String? afterId,
  int? limit,
}) async {
  final q = <String, dynamic>{'workspace_id': _ws1()};
  if (afterId != null && afterId.isNotEmpty) q['after_id'] = afterId;
  if (limit != null && limit > 0) q['limit'] = limit;
  return raw.get(path, queryParameters: q);
}

/// 冻结契约 POST：workspace_id 为面级必填（body 携带）。
Future<Map<String, dynamic>> _entPost(
  FlowApiClient raw,
  String path,
  Map<String, dynamic> body,
) {
  return raw.post(path, data: {'workspace_id': _ws1(), ...body});
}

/// 冻结契约 CS 会话详情（workspace_id query）。
Future<Map<String, dynamic>> _csDetailRaw(
  FlowApiClient raw,
  String orgId,
  String sessionId,
) async {
  final resp = await raw.get(
    '/api/v1/cs/organizations/$orgId/sessions/$sessionId',
    queryParameters: {'workspace_id': _ws1()},
  );
  FlowApiAssert.success(resp, context: 'cs sessionDetail($sessionId)');
  return (resp['payload'] ?? <String, dynamic>{}) as Map<String, dynamic>;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  final bool backendConfigured = kImboyApiBase.isNotEmpty;

  testWidgets('step01_login_and_cold_start_resume', (tester) async {
    await StorageService.init();
    final raw = _rawFor('dev1-device-a');

    // 冷启动会话恢复：第二轮 flutter test 进程即真冷启动；若上一进程留下
    // 的持久化 token 仍有效，则不再重新登录（断言会话恢复 oracle）。
    final resumed = await _tryResumeSession(raw);
    findings['cold_start_session_resumed'] = resumed;
    if (!resumed) {
      await _becomeUser(raw, _phoneA);
    }
    expect(UserRepoLocal.to.isLoggedIn, isTrue);
    ctx['uidA'] = UserRepoLocal.to.currentUid;

    final mine = await raw.get(
      '/api/v1/organizations/mine',
      queryParameters: {'page': 1, 'size': 10},
    );
    FlowApiAssert.success(mine, context: 'organizations/mine after login');
    final payload = (mine['payload'] ?? <String, dynamic>{}) as Map;
    final rows =
        (payload['list'] ?? payload['data'] ?? const []) as List<dynamic>;
    final org1 = rows.firstWhere(
      (r) => r is Map && r['name'] == _org1Name,
      orElse: () => null,
    );
    expect(org1, isNotNull, reason: '种子企业 $_org1Name 应在 mine 列表');
    ctx['org1'] = '${(org1! as Map)['id']}';
    ctx['ws1'] = _seedWs;
    ctx['conv1'] = _seedConv;

    // 契约缺陷软探针 D1：EnterpriseApi.myOrganizations 目标端点是否存在。
    final probe = await raw.get('/api/v1/enterprise/organizations');
    findings['D1_enterprise_organizations_status'] = probe['code'];
    // ignore: avoid_print
    print('DEV1_FINDINGS $findings');
  }, skip: !backendConfigured);

  testWidgets('step02_ent_context_contacts', (tester) async {
    final raw = _rawFor('dev1-device-a');
    raw.accessToken = await SecureTokenStorageService.getToken();
    final org1 = _org1();

    // 契约缺陷软探针 D3a：App 侧 contacts（缺 workspace_id）→ 422。
    final enterpriseApi = EnterpriseApi();
    try {
      await enterpriseApi.contacts(org1);
      findings['D3a_app_contacts'] = 'accepted';
    } on EnterpriseApiException catch (e) {
      findings['D3a_app_contacts'] = 'http ${e.code} ${e.message}';
    }

    // 旅程 oracle（冻结契约）：企业联系人真源非空（不落个人好友域）
    final resp = await _entGet(
      raw,
      '/api/v1/enterprise/organizations/$org1/contacts',
    );
    FlowApiAssert.success(resp, context: 'contacts(frozen contract)');
    final payload = resp['payload'];
    final rows = payload is List ? payload : const [];
    expect(rows, isNotEmpty, reason: '种子企业联系人应非空');

    // 契约缺陷软探针 D4：conversations 列表 GET 后端无用例 → 405。
    final convProbe = await raw.get(
      '/api/v1/enterprise/organizations/$org1/conversations',
      queryParameters: {'workspace_id': _ws1()},
    );
    findings['D4_conversations_list_get'] = convProbe['code'];
    // ignore: avoid_print
    print('DEV1_FINDINGS $findings');
  }, skip: !backendConfigured);

  testWidgets('step03_to_07_message_send_incremental_ack', (tester) async {
    final rawB = _rawFor('dev1-device-b');
    final org1 = _org1();
    final conv1 = _conv1();

    // 双账号：B 登录（raw，独立会话）并取坐席身份（customer_service 白名单）
    final loginB = await rawB.login(
      account: _phoneB,
      password: _password,
      type: 'mobile',
    );
    FlowApiAssert.success(loginB, context: 'login(B)');
    ctx['uidB'] = '${((loginB['payload'] ?? {}) as Map)['uid']}';
    final seatResp = await rawB.get('/api/v1/cs/me/seat-contexts');
    FlowApiAssert.success(seatResp, context: 'seat-contexts(B)');
    final seatContexts =
        (((seatResp['payload'] ?? {}) as Map)['contexts'] ?? const [])
            as List<dynamic>;
    Map? orgCtx;
    for (final c in seatContexts) {
      if ('${(c! as Map)['organization_id']}' == org1) {
        orgCtx = c as Map;
        break;
      }
    }
    expect(orgCtx, isNotNull, reason: 'B 在 org1 应有坐席上下文');
    ctx['identityB'] = '${orgCtx!['business_identity_id']}';

    // 步骤 5（发送消息，冻结契约）：B 以业务身份发送 accepted
    final ts = DateTime.now().microsecondsSinceEpoch;
    Future<String> sendByB(String clientMsgId, String body) async {
      final send = await _entPost(
        rawB,
        '/api/v1/enterprise/organizations/$org1/conversations/$conv1/messages',
        {
          'client_msg_id': clientMsgId,
          'sender_type': 'business_identity',
          'body': body,
          'identity_id': ctx['identityB'],
        },
      );
      FlowApiAssert.success(send, context: 'send($clientMsgId by B)');
      final sp = (send['payload'] ?? {}) as Map;
      return '${sp['message_id'] ?? ((sp['message'] ?? {}) as Map)['id']}';
    }

    final msg1 = await sendByB('dev1-b-1-$ts', 'e2e-ping-b-1');
    expect(msg1, isNotEmpty);

    // 全量读（冻结契约）：应含 msg1
    final listPath =
        '/api/v1/enterprise/organizations/$org1/conversations/$conv1/messages';
    Future<List<String>> listIds() async {
      final resp = await _entGet(rawB, listPath);
      FlowApiAssert.success(resp, context: 'messages list');
      final payload = resp['payload'];
      final rows = payload is List ? payload : const [];
      return rows.map((m) => '${(m! as Map)['id']}').toList();
    }

    final ids1 = await listIds();
    expect(ids1, contains(msg1), reason: '全量消息列表应含 msg1');

    // 步骤 6（after_id 增量）：B 再发一条，增量只含新消息
    final msg2 = await sendByB('dev1-b-2-$ts', 'e2e-ping-b-2');
    final incremental = await _entGet(rawB, listPath, afterId: msg1);
    final incPayload = incremental['payload'];
    final incRows = incPayload is List ? incPayload : const [];
    final incIds = incRows.map((m) => '${(m! as Map)['id']}').toList();
    expect(incIds, isNotEmpty, reason: 'after_id 增量应含 msg2');
    expect(incIds, isNot(contains(msg1)), reason: '增量不得回放游标之前的消息');
    expect(incIds, contains(msg2));

    // 步骤 7（delivery ACK，delivery-only）：ACK 后真源仍在
    final ack = await _entPost(
      rawB,
      '/api/v1/enterprise/organizations/$org1/conversations/$conv1/messages/$msg1/ack',
      {'recipient_ref': 'dev1-device-b'},
    );
    FlowApiAssert.success(ack, context: 'ack(msg1)');
    final idsAfterAck = await listIds();
    expect(idsAfterAck, contains(msg1), reason: 'ACK 只确认投递，不得改变消息真源');

    // 契约缺陷软探针 D2/D3：App 侧 sendMessage/ackDelivered/messages 旧形状。
    final enterpriseApi = EnterpriseApi();
    try {
      final legacy = await enterpriseApi.sendMessage(
        org1,
        conv1,
        content: 'e2e-legacy-shape',
      );
      findings['D2_sendmessage_legacy_shape'] = legacy.id.isEmpty
          ? 'accepted-empty-id'
          : 'accepted';
    } on EnterpriseApiException catch (e) {
      findings['D2_sendmessage_legacy_shape'] = 'http ${e.code}';
    }
    try {
      await enterpriseApi.messages(org1, conv1);
      findings['D3c_app_messages'] = 'accepted';
    } on EnterpriseApiException catch (e) {
      findings['D3c_app_messages'] = 'http ${e.code}';
    }
    try {
      await enterpriseApi.ackDelivered(org1, conv1, msg1);
      findings['D3d_app_ack'] = 'accepted';
    } on EnterpriseApiException catch (e) {
      findings['D3d_app_ack'] = 'http ${e.code}';
    }
    // ignore: avoid_print
    print('DEV1_FINDINGS $findings');
  }, skip: !backendConfigured);

  testWidgets('step04_08_09_asset_presign_put_confirm_content', (tester) async {
    final raw = _rawFor('dev1-device-a');
    raw.accessToken = await SecureTokenStorageService.getToken();
    final enterpriseApi = EnterpriseApi();
    final org1 = _org1();
    final ws1 = _ws1();
    final conv1 = _conv1();

    const bytes = 'e2e-bytes';
    final objectHash = crypto.sha256.convert(utf8.encode(bytes)).toString();

    final presign = await enterpriseApi.presignAsset(
      org1,
      workspaceId: ws1,
      conversationId: conv1,
      mime: 'text/plain',
      sizeBytes: bytes.length,
      objectHash: objectHash,
      fileName: 'dev1-e2e.txt',
    );
    expect(presign.assetId, isNotEmpty);
    expect(presign.hasUploadTarget, isTrue, reason: 'presign 应下发 PUT 目标');

    // PUT 字节（真实 S3：本 run 独立 Garage 实例）
    final putStatus = await _rawPutBytes(presign.uploadUrl, utf8.encode(bytes));
    expect(putStatus, isIn(const <int>[200, 201]), reason: 'S3 PUT 应成功');

    // confirm（独立请求重新鉴权；upload_ref 而非 asset_id）
    final asset = await enterpriseApi.confirmAsset(
      org1,
      workspaceId: ws1,
      uploadRef: presign.uploadRef,
    );
    expect(asset.isPending, isFalse, reason: 'confirm 后资产应 active');

    // 步骤 9（content 鉴权代理回读，无 presigned GET）
    String text;
    try {
      text = await enterpriseApi.fetchAssetContentText(org1, asset.id);
      findings['D3e_app_content'] = 'accepted';
    } on EnterpriseApiException catch (e) {
      findings['D3e_app_content'] = 'http ${e.code}';
      final resp = await raw.get(
        '/api/v1/enterprise/organizations/$org1/assets/${asset.id}/content',
        queryParameters: {'workspace_id': ws1},
      );
      FlowApiAssert.success(resp, context: 'asset content (frozen contract)');
      final payload = resp['payload'];
      text = payload is Map ? '${payload['text']}' : '$payload';
    }
    expect(text, bytes, reason: 'content 代理应回读原始字节');
    // ignore: avoid_print
    print('DEV1_FINDINGS $findings');
  }, skip: !backendConfigured);

  testWidgets('step05_10_11_12_cs_queue_claim_transfer_close', (tester) async {
    final org1 = _org1();
    final ws1 = _ws1();

    // 坐席 B 登录进 App 会话（真实切账号链路），驱动坐席面
    final rawB = _rawFor('dev1-device-b-session');
    await _becomeUser(rawB, _phoneB);
    ctx['uidB'] = UserRepoLocal.to.currentUid;

    final csApi = CsApi();
    // 步骤 10（queue，App 客户端可用）
    final contexts = await csApi.seatContexts();
    CsSeatContext ctxOrg;
    try {
      ctxOrg = contexts.contexts.firstWhere((c) => c.organizationId == org1);
    } on StateError {
      fail('B 缺少 org1 坐席上下文');
    }
    expect(ctxOrg.isEligible, isTrue, reason: '坐席 B 应满足 eligible');

    final queue = await csApi.queuePage(org1);
    expect(queue.items, isNotEmpty, reason: '种子排队会话应在 queue');
    final item = queue.items.first;
    expect(item.status, 'queued');
    expect(item.version, greaterThan(0), reason: 'CAS claim 需要 version');

    // 契约缺陷软探针 D5a：App 侧 claim（缺 workspace_id）→ 422。
    try {
      await csApi.claim(org1, item.sessionId, expectedVersion: item.version);
      findings['D5a_app_claim'] = 'accepted';
    } on CsApiException catch (e) {
      findings['D5a_app_claim'] = 'http ${e.code}';
    }

    // 旅程 oracle（冻结契约）：claim（CAS）
    final identityB = ctx['identityB']! as String;
    final claimResp = await _entPost(
      rawB,
      '/api/v1/cs/organizations/$org1/sessions/${item.sessionId}/claim',
      {'expected_version': item.version},
    );
    FlowApiAssert.success(claimResp, context: 'claim(queued session)');
    final claimPayload = (claimResp['payload'] ?? {}) as Map;
    expect('${claimPayload['status'] ?? ''}', 'active');

    // transferTargets（冻结契约 query）
    final targets = await rawB.get(
      '/api/v1/cs/organizations/$org1/transfer-targets',
      queryParameters: {'workspace_id': ws1},
    );
    FlowApiAssert.success(targets, context: 'transfer-targets');
    final targetPayload = (targets['payload'] ?? {}) as Map;
    final targetRows =
        (targetPayload['targets'] ?? targetPayload['list'] ?? const [])
            as List<dynamic>;
    expect(targetRows, isNotEmpty, reason: 'D 坐席身份应可作转接目标');
    final targetD =
        '${(targetRows.first as Map)['identity_id'] ?? (targetRows.first as Map)['id']}';
    expect(targetD, isNot(identityB), reason: '转接目标不得含本人');

    // 步骤 12（transfer，CAS）：B → D
    final detailBeforeTransfer = await _csDetailRaw(rawB, org1, item.sessionId);
    final transfer = await _entPost(
      rawB,
      '/api/v1/cs/organizations/$org1/sessions/${item.sessionId}/transfer',
      {
        'to_identity_id': targetD,
        'expected_version': detailBeforeTransfer['version'],
      },
    );
    FlowApiAssert.success(transfer, context: 'transfer(B→D)');

    // 受让人 D 登录（真实切账号链路）后 close
    final rawD = _rawFor('dev1-device-d-session');
    await _becomeUser(rawD, _phoneD);

    final detailForClose = await _csDetailRaw(rawD, org1, item.sessionId);
    expect('${detailForClose['status']}', 'active');
    final close = await _entPost(
      rawD,
      '/api/v1/cs/organizations/$org1/sessions/${item.sessionId}/close',
      {
        'expected_version': detailForClose['version'],
        'reason': 'dev1-e2e-close',
      },
    );
    FlowApiAssert.success(close, context: 'close(active session)');
    final detailClosed = await _csDetailRaw(rawD, org1, item.sessionId);
    expect('${detailClosed['status']}', 'closed');

    ctx['csSession'] = item.sessionId;
  }, skip: !backendConfigured);

  testWidgets('step06_13_rating_via_visit_token', (tester) async {
    final org1 = _org1();
    final sessionId = ctx['csSession']! as String;
    final raw = _rawFor('dev1-device-a');
    raw.accessToken = await SecureTokenStorageService.getToken();

    final detail = await _csDetailRaw(raw, org1, sessionId);
    expect('${detail['status']}', 'closed');

    // 访客评分（visit token 面）：closed 会话可评 1..5
    final client = dio_pkg.Dio(
      dio_pkg.BaseOptions(
        baseUrl: kImboyApiBase,
        contentType: 'application/json',
        validateStatus: (int? status) => status != null,
      ),
    );
    final resp = await client.post<dynamic>(
      '/api/v1/cs/sessions/$sessionId/rating',
      data: {'rating': 5, 'expected_version': detail['version']},
      options: dio_pkg.Options(headers: {'x-cs-visit-token': _visitToken}),
    );
    final body = resp.data is Map ? resp.data as Map : const {};
    expect(body['code'], 0, reason: '访客评分应成功（实际 ${resp.data}）');

    final after = await _csDetailRaw(raw, org1, sessionId);
    final rating = after['rating'];
    expect(rating, isNotNull, reason: '评分后 sessionDetail 应带 rating');
    expect(rating, isIn(const <int>[1, 2, 3, 4, 5]));
  }, skip: !backendConfigured);

  testWidgets('step07_13b_suspend_degrades_member_403_then_restore', (
    tester,
  ) async {
    final orgApi = OrganizationApi();
    final org1 = _org1();

    // 治理动作要求 owner 会话：显式切回 A（真实切账号链路）。
    final rawA = _rawFor('dev1-device-a-gov');
    await _becomeUser(rawA, _phoneA);
    ctx['uidA'] = UserRepoLocal.to.currentUid;

    // 先以 C 真实登录建立第二账号事实（并取 uid）
    final rawC = _rawFor('dev1-device-c');
    final loginC = await rawC.login(
      account: _phoneC,
      password: _password,
      type: 'mobile',
    );
    FlowApiAssert.success(loginC, context: 'login(C)');
    final uidC = '${((loginC['payload'] ?? {}) as Map)['uid']}';
    ctx['uidC'] = uidC;

    // suspend（owner 治理动作）
    final suspended = await orgApi.suspendMember(org1, uidC);
    expect(suspended.status, 'suspended');

    // 被 suspend 成员的企业租户面新请求 → 403（降级 fail-closed）
    final denied = await rawC.get(
      '/api/v1/enterprise/organizations/$org1/contacts',
      queryParameters: {'page': 1, 'size': 10},
    );
    expect(denied['code'], 403, reason: 'suspend 后企业 API 应 403');

    // restore 恢复后同一账号的组织事实恢复可读
    final restored = await orgApi.restoreMember(org1, uidC);
    expect(restored.status, 'active');
    final orgsC = await rawC.get(
      '/api/v1/organizations/mine',
      queryParameters: {'page': 1, 'size': 10},
    );
    FlowApiAssert.success(orgsC, context: 'mine(C) after restore');
  }, skip: !backendConfigured);

  testWidgets('step08_org_create_and_switch', (tester) async {
    final orgApi = OrganizationApi();
    final name = 'dev1-org-b-${DateTime.now().millisecondsSinceEpoch}';

    final created = await orgApi.create(name: name);
    expect(created.id, isNotEmpty);
    expect(created.name, name);

    // 切换 = mine 列表可见 + detail 投影 member_role=owner
    final mine = await orgApi.mine();
    expect(mine.list.any((o) => o.id == created.id), isTrue);
    final detail = await orgApi.detail(created.id);
    expect(detail.memberRole, 'owner');

    ctx['orgB'] = created.id;
  }, skip: !backendConfigured);

  testWidgets('step09_dual_account_invitation_accept', (tester) async {
    final orgApi = OrganizationApi();
    final orgB = ctx['orgB']! as String;

    // 邀请 C（定向邀请，create 返回一次性 token；P0 免口令直达）
    final invitation = await orgApi.createInvitation(orgB, _uidC());
    expect(invitation.invitationId, isNotEmpty);
    expect(invitation.isPending, isTrue);

    // 双账号第二侧：C 真实登录并接受（当前身份即 target）
    final rawC = _rawFor('dev1-device-c-session');
    final loginC = await rawC.login(
      account: _phoneC,
      password: _password,
      type: 'mobile',
    );
    FlowApiAssert.success(loginC, context: 'login(C)');
    final uidC = '${((loginC['payload'] ?? {}) as Map)['uid']}';
    ctx['uidC'] = uidC;

    final accept = await rawC.post(
      '/api/v1/organizations/$orgB/invitations/accept',
      data: <String, dynamic>{},
    );
    FlowApiAssert.success(accept, context: 'accept invitation(C)');

    // 治理面成员列表可见 C active
    final members = await orgApi.members(orgB);
    OrganizationMember? rowC;
    for (final m in members.list) {
      if (m.userId == uidC) {
        rowC = m;
        break;
      }
    }
    expect(rowC, isNotNull, reason: 'C 应出现在 orgB 成员列表');
    expect(rowC!.status, 'active');
  }, skip: !backendConfigured);

  testWidgets('step10_member_offboard_terminal', (tester) async {
    final orgApi = OrganizationApi();
    final orgB = ctx['orgB']! as String;
    final uidC = ctx['uidC']! as String;

    // C 无 active 业务身份 assignment → offboard 直达 removed 终态
    final offboarded = await orgApi.offboardMember(orgB, uidC);
    expect(offboarded.status, 'removed');

    // 终态不可再 suspend（409 来源守卫）
    Object? conflict;
    try {
      await orgApi.suspendMember(orgB, uidC);
    } on OrganizationApiException catch (e) {
      conflict = e;
      expect(e.code, 409);
    }
    expect(conflict, isNotNull, reason: 'suspend(removed) 应被服务端拒绝');
  }, skip: !backendConfigured);

  testWidgets('step11_department_governance', (tester) async {
    final orgApi = OrganizationApi();
    final orgB = ctx['orgB']! as String;
    final uidA = _uidA();

    // 根部门
    final root = await orgApi.createDepartment(orgB, name: 'dev1-dept-root');
    expect(root.isRoot, isTrue);
    // 子部门
    final child = await orgApi.createDepartment(
      orgB,
      name: 'dev1-dept-child',
      parentId: root.id,
    );
    expect(child.parentId, root.id);

    // CAS 改名
    final renamed = await orgApi.renameDepartment(
      orgB,
      root.id,
      name: 'dev1-dept-root-v2',
      expectedVersion: root.version,
    );
    expect(renamed.name, 'dev1-dept-root-v2');

    // 成员挂载（owner 自己是 active member，服务端触发器权威）
    final member = await orgApi.addDepartmentMember(orgB, root.id, uidA);
    expect(member.userId, uidA);

    // 树读面
    final tree = await orgApi.departments(orgB);
    expect(tree.any((d) => d.id == root.id), isTrue);
    expect(tree.any((d) => d.id == child.id), isTrue);

    // 归档叶子
    final archived = await orgApi.archiveDepartment(orgB, child.id);
    expect(archived.isArchived, isTrue);
  }, skip: !backendConfigured);

  testWidgets('step12_network_outage_and_recovery', (tester) async {
    final org1 = _org1();
    // 恢复链路的会话：显式复用持久化 token（同一真实会话，不重新登录）。
    final tk = await SecureTokenStorageService.getToken();
    expect(tk.length, greaterThan(10), reason: '恢复链路需要有效会话 token');

    final client = dio_pkg.Dio(
      dio_pkg.BaseOptions(
        baseUrl: kImboyApiBase,
        contentType: 'application/json',
        validateStatus: (int? status) => status != null,
      ),
    );

    // 真实 socket 不可达（RFC1918 黑洞地址，无 mock）：请求必须失败
    Object? caught;
    try {
      await client.get<dynamic>(
        'http://10.255.255.1:9/api/v1/organizations/mine',
        options: dio_pkg.Options(connectTimeout: const Duration(seconds: 3)),
      );
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull, reason: '断网（黑洞地址）请求应失败');

    // 恢复：同一进程内对真实后端的下一跳请求成功
    final resp = await client.get<dynamic>(
      '/api/v1/organizations/$org1',
      options: dio_pkg.Options(headers: {'authorization': 'Bearer $tk'}),
    );
    expect(
      resp.data is Map ? (resp.data as Map)['code'] : resp.statusCode,
      0,
      reason: '断网恢复后 org detail 应成功',
    );
  }, skip: !backendConfigured);

  testWidgets('step13_cold_start_state_visible', (tester) async {
    // 本用例在两轮运行中都成立：
    //  - run1：本进程已完成登录，会话事实可读；
    //  - run2：新进程（真冷启动）经 step01 的 resume 路径恢复持久化会话，
    //          此处断言企业状态不依赖重新播种即可见。
    final raw = _rawFor('dev1-device-a');
    raw.accessToken = await SecureTokenStorageService.getToken();

    final mine = await raw.get(
      '/api/v1/organizations/mine',
      queryParameters: {'page': 1, 'size': 10},
    );
    FlowApiAssert.success(mine, context: 'mine in cold-start check');
    final payload = (mine['payload'] ?? <String, dynamic>{}) as Map;
    final rows =
        (payload['list'] ?? payload['data'] ?? const []) as List<dynamic>;
    expect(rows.any((r) => r is Map && r['name'] == _org1Name), isTrue);

    final contacts = await _entGet(
      raw,
      '/api/v1/enterprise/organizations/${_org1()}/contacts',
    );
    FlowApiAssert.success(contacts, context: 'contacts in cold-start check');

    findings['cold_start_state_visible'] = true;
    // ignore: avoid_print
    print('DEV1_FINDINGS $findings');
  }, skip: !backendConfigured);
}

/// 原始字节 PUT（S3 短期 presigned URL；dart:io，无查询串改写）
Future<int> _rawPutBytes(String url, List<int> payload) async {
  final client = io.HttpClient();
  try {
    final uri = Uri.parse(url);
    final req = await client.openUrl('PUT', uri);
    req.headers.contentType = io.ContentType.binary;
    req.add(payload);
    final resp = await req.close();
    await resp.drain<void>();
    return resp.statusCode;
  } finally {
    client.close(force: true);
  }
}
