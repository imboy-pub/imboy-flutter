// integration_test/enterprise/oa_login_real_backend_test.dart
//
// OA inbound 双入口登录 × 真实后端联调（无 mock，EPGZ-06 login 旅程）。
//
// 覆盖（每个用例都是一次真实 HTTP 往返，后端必须已在运行）：
//   step01 internal 签票(login) → exchange → 未关联 external_user 返回
//         pending_token + expires_in 300 + requires_account_choice，不签会话；
//   step02 register(confirm_create=true 由 OaLoginApi 注入) → 建号并签发
//         user_id/token/refreshtoken；
//   step03 同一 external_user_id 再签票 login → exchange 直接复用 step02 账号
//         （user_id 相同），不再进入 pending 分支；
//   step04 负例：新签一张票，用错误 code_verifier exchange → HTTP 非 200、
//         信封 code≠0、无会话字段，且真实客户端 OaLoginApi 将失败抛为异常。
//
// 运行（macOS 直连本机后端；flutter 在 PATH）：
//   flutter test integration_test/enterprise/oa_login_real_backend_test.dart \
//     -d macos \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//     --dart-define=OA_REAL_TEST_CREDENTIAL=ib_int_<测试专用 credential>
//
// 环境门（对齐 integration_test/README.md 跳过策略：先 markTestSkipped 显式
// 标记、调用方立即 return，禁止静默跳过）：
//   - API_BASE_URL_OVERRIDE（或 OA_REAL_BACKEND）缺省 →
//     markTestSkipped('REAL_BACKEND_NOT_CONFIGURED: ...')；
//   - OA_REAL_TEST_CREDENTIAL 缺省 → 同上显式标记。
//
// 客户端形态说明：exchange/register 走真实业务客户端 OaLoginApi（两端点在
// 后端 902 免签白名单内，OaLoginApi 的签名头不影响）；internal 签票端点
// /api/internal/v1/oa/login/tickets 是 OA 服务侧合成入口（业务上由 OA H5
// 持 credential 调用，App 客户端无此方法），测试内用 Dio 直调，不新增业务
// 依赖。PKCE 复用客户端实现 OaLoginAttempt.create/challenge 生成。

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/modules/enterprise_oa/data/oa_login_api.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_login_attempt.dart';
import 'package:imboy/service/storage.dart';

/// 真实后端地址：优先 API_BASE_URL_OVERRIDE，缺省回落 OA_REAL_BACKEND。
const String _kOverrideBase = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const String _kOaRealBackend = String.fromEnvironment('OA_REAL_BACKEND');

/// internal credential（--dart-define 注入；测试专用合成数据，非 secret 泄露面）。
const String _kCredential = String.fromEnvironment('OA_REAL_TEST_CREDENTIAL');

/// OA 应用标识（公开标识符；与后端 default-oa 部署一致）。
const String _kApplicationKey = 'default-oa';

/// ticket / verifier / pending_token 的服务端 token 形态（43 字符 base64url）。
final RegExp _kTokenShape = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// 跨用例共享旅程状态（同进程按声明顺序执行，enterprise_cs_e2e 同款）。
final Map<String, Object?> _ctx = <String, Object?>{};

String get _backend =>
    _kOverrideBase.isNotEmpty ? _kOverrideBase : _kOaRealBackend;

/// 环境门：缺真实后端 / credential 时显式标记并跳过（不静默、不假绿）。
bool _requireRealBackend() {
  if (_backend.isEmpty) {
    markTestSkipped(
      'REAL_BACKEND_NOT_CONFIGURED: 需 --dart-define=API_BASE_URL_OVERRIDE='
      'http://127.0.0.1:9800（或 OA_REAL_BACKEND）指向运行中的 imboy 后端',
    );
    return false;
  }
  if (_kCredential.isEmpty) {
    markTestSkipped(
      'REAL_BACKEND_NOT_CONFIGURED: 需 --dart-define=OA_REAL_TEST_CREDENTIAL='
      '<internal credential>',
    );
    return false;
  }
  return true;
}

/// 真实业务客户端（HttpConfig.baseUrl 指向真实后端；exchange/register 为
/// 公开端点，不携带会话 token）。
OaLoginApi _api() => OaLoginApi(backend: _backend);

/// 测试直调 Dio（internal 签票 + 负例的 HTTP 层断言）。
Dio _rawDio() => Dio(
  BaseOptions(
    baseUrl: _backend,
    contentType: 'application/json',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (int? status) => status != null,
  ),
);

/// internal 签票：credential Bearer 鉴权，PKCE S256，断言信封与 token 形态。
Future<String> _issueLoginTicket(OaLoginAttempt attempt) async {
  final resp = await _rawDio().post<Map<String, dynamic>>(
    '/api/internal/v1/oa/login/tickets',
    data: <String, dynamic>{
      'external_user_id': _ctx['external_user_id'],
      'intent': 'login',
      'code_challenge_method': 'S256',
      'code_challenge': attempt.challenge,
      'application_key': _kApplicationKey,
    },
    options: Options(
      headers: <String, String>{'Authorization': 'Bearer $_kCredential'},
    ),
  );
  final body = resp.data ?? <String, dynamic>{};
  expect(
    resp.statusCode,
    200,
    reason: 'internal 签票应 200：code=${body['code']} msg=${body['msg']}',
  );
  expect(body['code'], 0, reason: 'internal 签票信封 code 应为 0');
  final payload = (body['payload'] is Map<String, dynamic>)
      ? body['payload'] as Map<String, dynamic>
      : <String, dynamic>{};
  final ticket = payload['ticket'] as String?;
  expect(ticket, isNotNull, reason: '签票 payload 应含 ticket');
  expect(
    _kTokenShape.hasMatch(ticket ?? ''),
    isTrue,
    reason: 'ticket 应为 43 字符 base64url 形态',
  );
  expect(payload['expires_in'], 60, reason: 'ticket 有效期应为 60 秒');
  return ticket!;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('step01 未关联 external_user 的 exchange 返回 pending 且不签会话', (
    tester,
  ) async {
    if (!_requireRealBackend()) return;
    // OaLoginApi 走 app HttpClient，请求前会读 UserRepoLocal.currentUid，
    // 需先初始化本地存储（enterprise_cs_e2e 同款前置；init 幂等）。
    await StorageService.init();

    final runId = DateTime.now().millisecondsSinceEpoch;
    _ctx['external_user_id'] = 'ext-app-$runId';
    _ctx['did'] = 'did-gz-oa-$runId'; // 后端约束 did ≤ 40 字节
    final attempt = OaLoginAttempt.create(
      'login',
      backend: _backend,
      deviceId: _ctx['did'] as String,
      applicationKey: _kApplicationKey,
    );
    _ctx['verifier'] = attempt.verifier;
    debugPrint('[oa-real-it] run external_user_id=${_ctx['external_user_id']}');

    final ticket = await _issueLoginTicket(attempt);
    final payload = await _api().exchange(ticket, <String, dynamic>{
      'code_verifier': attempt.verifier,
      'did': _ctx['did'],
      'application_key': _kApplicationKey,
    });

    // 未关联：pending 分支，不签会话。
    expect(
      _kTokenShape.hasMatch(payload['pending_token'] as String? ?? ''),
      isTrue,
      reason: 'exchange 应返回 43 字符 pending_token：$payload',
    );
    expect(payload['requires_account_choice'], isTrue);
    expect(payload['expires_in'], 300, reason: 'pending 有效期应为 300 秒');
    expect(payload.containsKey('token'), isFalse, reason: 'pending 不应签发 token');
    expect(
      payload.containsKey('user_id'),
      isFalse,
      reason: 'pending 不应携带 user_id（账号尚未创建/关联）',
    );
    _ctx['pending_token'] = payload['pending_token'];
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('step02 register 显式确认后建号并签发会话', (tester) async {
    if (!_requireRealBackend()) return;
    await StorageService.init();
    final payload = await _api().register(
      _ctx['pending_token'] as String,
      <String, dynamic>{
        'code_verifier': _ctx['verifier'],
        'did': _ctx['did'],
        'application_key': _kApplicationKey,
      },
    );

    final userId = payload['user_id'];
    expect(userId, isNotNull, reason: 'register 应返回 user_id：$payload');
    expect(
      (payload['token'] as String?)?.isNotEmpty,
      isTrue,
      reason: '应签发 token',
    );
    expect(
      (payload['refreshtoken'] as String?)?.isNotEmpty,
      isTrue,
      reason: '应签发 refreshtoken',
    );
    expect(payload.containsKey('pending_token'), isFalse);
    debugPrint('[oa-real-it] registered user_id=$userId');
    _ctx['user_id'] = userId;
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('step03 同一 external_user_id 再次 login 直接复用既有账号', (tester) async {
    if (!_requireRealBackend()) return;
    await StorageService.init();
    // 新一轮 PKCE + 新票（login 双入口复登旅程）。
    final attempt = OaLoginAttempt.create(
      'login',
      backend: _backend,
      deviceId: _ctx['did'] as String,
      applicationKey: _kApplicationKey,
    );
    final ticket = await _issueLoginTicket(attempt);
    final payload = await _api().exchange(ticket, <String, dynamic>{
      'code_verifier': attempt.verifier,
      'did': _ctx['did'],
      'application_key': _kApplicationKey,
    });

    // 已关联：直接签会话，user_id 与 step02 建的账号一致。
    expect(payload['user_id'], _ctx['user_id'], reason: '复登应复用同一账号');
    expect(
      (payload['token'] as String?)?.isNotEmpty,
      isTrue,
      reason: '已关联 exchange 应签发 token',
    );
    expect(
      payload.containsKey('pending_token'),
      isFalse,
      reason: '已关联 exchange 不应再进入 pending 分支',
    );
    expect(payload.containsKey('requires_account_choice'), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('step04 负例：错误 code_verifier 的 exchange 非成功且不产生会话', (
    tester,
  ) async {
    if (!_requireRealBackend()) return;
    await StorageService.init();
    final attempt = OaLoginAttempt.create(
      'login',
      backend: _backend,
      deviceId: _ctx['did'] as String,
      applicationKey: _kApplicationKey,
    );
    final ticket = await _issueLoginTicket(attempt);
    // 合法形态但与 challenge 不匹配的 verifier（43 字符 base64url）。
    final wrongVerifier = OaLoginAttempt.create('login').verifier;
    expect(wrongVerifier, isNot(attempt.verifier));

    // HTTP 层：非 200、信封 code≠0、无任何会话字段。
    final resp = await _rawDio().post<Map<String, dynamic>>(
      '/api/v1/oa/login/exchange',
      data: <String, dynamic>{
        'ticket': ticket,
        'code_verifier': wrongVerifier,
        'did': _ctx['did'],
        'application_key': _kApplicationKey,
      },
    );
    final body = resp.data ?? <String, dynamic>{};
    debugPrint(
      '[oa-real-it] wrong-verifier exchange status=${resp.statusCode} '
      'code=${body['code']} msg=${body['msg']}',
    );
    expect(resp.statusCode, isNot(200), reason: '错 verifier 不应成功');
    expect(body['code'], isNot(0), reason: '错 verifier 信封 code 应非 0');
    final errorPayload = body['payload'];
    if (errorPayload is Map) {
      expect(errorPayload.containsKey('token'), isFalse);
      expect(errorPayload.containsKey('pending_token'), isFalse);
    }

    // 客户端层：OaLoginApi 对同一失败按异常上抛（throwIfFailed）。
    final api = _api();
    await expectLater(
      api.exchange(ticket, <String, dynamic>{
        'code_verifier': wrongVerifier,
        'did': _ctx['did'],
        'application_key': _kApplicationKey,
      }),
      throwsA(anything),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
