// test/unit_test/api/api_test_client.dart
//
// 纯 Dart HTTP 测试客户端，供本目录（Tier 1 API 契约测试）使用。
// 不依赖 Flutter 绑定，不需要设备：
//   API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=xxx TEST_PASSWORD=xxx \
//   flutter test test/unit_test/api/ --concurrency=1
// （dart test 不可用：pubspec 的 patrol 等 Flutter-only 依赖让 dart pub 解析
//   必崩，见 pre_push_gate.sh 注；真实网络由本目录就近的
//   flutter_test_config.dart 恢复。）
// 业务写入测试还必须显式设置 TEST_ALLOW_API_WRITES=true；生产或未知地址始终拒绝。
//
// 与 integration_test/e2e/api_test_client.dart 的区别：
//   - 不引入 package:flutter
//   - did 在构造时固定，整个 client 生命周期不变
//   - 配置从环境变量读取（兼容 CI secret injection）

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';

// ──────────────────────────────────────────────
// 配置（环境变量，兼容 CI）
// ──────────────────────────────────────────────

class ApiTestConfig {
  ApiTestConfig._();

  static String get testPhone => Platform.environment['TEST_PHONE'] ?? '';
  static String get testPassword => Platform.environment['TEST_PASSWORD'] ?? '';
  static String get testCode => Platform.environment['TEST_CODE'] ?? '';
  static String get testPhone2 => Platform.environment['TEST_PHONE2'] ?? '';
  static String get testPassword2 =>
      Platform.environment['TEST_PASSWORD2'] ?? '';
  static String get testLoginType =>
      Platform.environment['TEST_LOGIN_TYPE'] ?? '';
  static String get apiBaseUrl =>
      Platform.environment['API_BASE_URL'] ?? 'http://127.0.0.1:9800';

  static bool get allowBusinessWrites =>
      (Platform.environment['TEST_ALLOW_API_WRITES'] ?? '').toLowerCase() ==
      'true';

  static bool _isSafeNonProductionHost(String host) {
    final normalized = host.toLowerCase().trim();
    if (normalized == 'localhost' ||
        normalized == 'dev.imboy.pub' ||
        normalized.endsWith('.local')) {
      return true;
    }
    final ipv4 = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$').firstMatch(normalized);
    if (ipv4 == null) return false;
    final octets = [for (int i = 1; i <= 4; i++) int.parse(ipv4.group(i)!)];
    if (octets[0] == 127 || octets[0] == 10) return true;
    if (octets[0] == 192 && octets[1] == 168) return true;
    return octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31;
  }

  static bool get targetsProductionOrUnknown {
    return !_isSafeNonProductionUrl(apiBaseUrl);
  }

  static bool _isSafeNonProductionUrl(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host;
    return host != null && _isSafeNonProductionHost(host);
  }

  static void ensureBusinessWriteAllowed({
    required String path,
    required String baseUrl,
  }) {
    if (!allowBusinessWrites) {
      throw StateError('API 写入测试已阻止：请显式设置 TEST_ALLOW_API_WRITES=true');
    }
    if (!_isSafeNonProductionUrl(baseUrl)) {
      throw StateError('API 写入测试已阻止：目标地址不是已识别的本地/开发环境（path=$path）');
    }
  }

  /// 当前网络是否被 HttpOverrides mock 掉（拿不到真实后端响应）。
  ///
  /// flutter_test 框架与 test/unit_test 根 config 都会装 HttpOverrides mock
  /// （任何真实请求恒假响应）。本目录打真实后端，靠就近的
  /// flutter_test_config.dart 把 HttpOverrides.global 恢复为 null——
  /// 因此这里探测运行时真相而非猜运行器：仍有 override 残留 = 网络被 mock。
  static bool get isNetworkMocked => HttpOverrides.current != null;

  /// 网络不可用（被 mock 掉）时应跳过而非失败的原因说明。
  static String? get skipReasonIfNoRealNetwork => isNetworkMocked
      ? 'API 契约测试需真实网络与后端；HttpOverrides 仍被 mock'
            '（api/flutter_test_config.dart 未生效？）。'
      : null;

  static bool get isConfigured =>
      testPhone.isNotEmpty && (testPassword.isNotEmpty || testCode.isNotEmpty);

  /// 签名密钥是否可用（不泄露值，仅探测）。匿名鉴权负向用例只需要
  /// 签名头不需要登录，用此跳过无密钥环境（如本机 flutter test 裸跑）。
  static bool get hasSigningKey {
    try {
      ApiTestClient._loadSigningKey();
      return true;
    } on Object {
      return false;
    }
  }

  static bool get isDualConfigured =>
      isConfigured && testPhone2.isNotEmpty && testPassword2.isNotEmpty;
}

// ──────────────────────────────────────────────
// HTTP 客户端
// ──────────────────────────────────────────────

class ApiTestClient {
  final Dio _dio;
  final String baseUrl;
  final String _deviceId;
  final String? _signingKey;

  String? _accessToken;
  String? _refreshToken;
  String? _currentUid;

  String? get accessToken => _accessToken;
  String? get currentUid => _currentUid;

  ApiTestClient({
    required this.baseUrl,
    String? deviceId,
    String? accessToken,
    Dio? dio,
    String? signingKey,
  }) : _signingKey = signingKey?.trim(),
       _accessToken = accessToken?.trim(),
       _deviceId = deviceId ?? 'e2e-dart-test-001',
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               contentType: 'application/json',
               connectTimeout: const Duration(seconds: 30),
               receiveTimeout: const Duration(seconds: 30),
               validateStatus: (status) => status != null,
             ),
           ) {
    if (_dio.options.baseUrl.isNotEmpty && _dio.options.baseUrl != baseUrl) {
      throw ArgumentError(
        'Injected Dio baseUrl must match ApiTestClient baseUrl',
      );
    }
    _dio.options.baseUrl = baseUrl;
    _dio.options.followRedirects = false;
  }

  Map<String, String> _defaultHeaders() {
    // 生产验签已 per-pkg 化（auth_ds 按 pkg_cos_sk 查 config 表）：可用
    // TEST_SIGN_COS/TEST_SIGN_PKG 覆盖为有登记的组合（如 android/
    // imboy.chat），不设置时保持按宿主平台推导的历史默认值。
    final env = Platform.environment;
    final cos =
        env['TEST_SIGN_COS'] ??
        (Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
            ? 'android'
            : Platform.isMacOS
            ? 'macos'
            : 'linux');
    final pkg = env['TEST_SIGN_PKG'] ?? 'pub.imboy.app';
    const vsn = '0.8.0';
    final raw = '$_deviceId|$vsn|$cos|$pkg';
    final key = utf8.encode(_signingKey ?? _loadSigningKey());
    final signature = base64.encode(
      crypto.Hmac(crypto.sha512, key).convert(utf8.encode(raw)).bytes,
    );

    return {
      'cos': cos,
      'vsn': vsn,
      'pkg': pkg,
      'did': _deviceId,
      'tz_offset': '${DateTime.now().timeZoneOffset.inMilliseconds}',
      'method': 'sha512',
      'sk': '1',
      'sign': signature,
    };
  }

  Map<String, String> _authHeaders() {
    final h = _defaultHeaders();
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      h['authorization'] = 'Bearer $_accessToken';
    }
    return h;
  }

  static String _md5(String s) => crypto.md5.convert(utf8.encode(s)).toString();

  static String _loadSigningKey() {
    final injectedKey = Platform.environment['IMBOY_SOLIDIFIED_KEY']?.trim();
    if (injectedKey != null && injectedKey.isNotEmpty) return injectedKey;

    final configuredPath = Platform.environment['IMBOY_ENV_PRO'];
    final candidates = [
      if (configuredPath != null && configuredPath.isNotEmpty) configuredPath,
      if (ApiTestConfig.targetsProductionOrUnknown) '.env.pro',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      for (final line in file.readAsLinesSync()) {
        if (!line.startsWith('SOLIDIFIED_KEY=')) continue;
        final value = line.substring('SOLIDIFIED_KEY='.length).trim();
        if (value.length >= 2 &&
            ((value.startsWith("'") && value.endsWith("'")) ||
                (value.startsWith('"') && value.endsWith('"')))) {
          return value.substring(1, value.length - 1);
        }
        return value;
      }
    }
    throw StateError('API 契约测试需要 IMBOY_SOLIDIFIED_KEY，或目标环境对应的配置文件');
  }

  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
    String? type,
  }) async {
    final loginType =
        type ??
        (ApiTestConfig.testLoginType.isNotEmpty
            ? ApiTestConfig.testLoginType
            : account.contains('@')
            ? 'email'
            : 'mobile');
    _log('登录: $account');
    Future<Map<String, dynamic>> postPwd(String pwd) async {
      final resp = await requestWithRateLimitRetry(
        () => _dio.post<dynamic>(
          '/api/v1/passport/login',
          data: {
            'account': account,
            'pwd': pwd,
            'type': loginType,
            'rsa_encrypt': '0',
          },
          options: Options(headers: _defaultHeaders()),
        ),
        login: true,
      );
      return _parse(resp);
    }

    // 与真实客户端（passport_notifier）一致：先上送 md5(明文)。
    var body = await postPwd(_md5(password));
    // alpha.69 密码协议迁移（imboy ba8da098）后，存量账号哈希为
    // hmac(md5hex) 旧格式时 md5 上送恒 errorPassword；镜像真实客户端的
    // 明文回退重试一次，保证新旧两种存储格式均可登录。
    if (body['code'] != 0 && '${body['msg']}'.contains('errorPassword')) {
      _log('md5 拒收，尝试明文回退');
      body = await postPwd(password);
    }
    if (body['code'] == 0) {
      final p = body['payload'] as Map<String, dynamic>?;
      _accessToken = p?['token'] as String?;
      _refreshToken = p?['refreshtoken'] as String?;
      _currentUid = '${p?['uid'] ?? ''}';
      _log('登录成功: uid=$_currentUid');
    } else {
      _log('登录失败: ${body['msg']}');
    }
    return body;
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final h = _defaultHeaders();
    if (_refreshToken != null) h['imboy-refreshtoken'] = _refreshToken!;
    final resp = await requestWithRateLimitRetry(
      () => _dio.post<dynamic>(
        '/api/v1/refreshtoken',
        options: Options(headers: h),
      ),
    );
    final body = _parse(resp);
    if (body['code'] == 0) {
      final p = body['payload'] as Map<String, dynamic>?;
      _accessToken = p?['token'] as String?;
      _refreshToken = p?['refreshtoken'] as String?;
    }
    return body;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    int? expectedStatusCode,
  }) async {
    final resp = await requestWithRateLimitRetry(
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: _authHeaders()),
      ),
    );
    if (expectedStatusCode != null && resp.statusCode != expectedStatusCode) {
      throw StateError(
        'GET $path expected HTTP $expectedStatusCode, got ${resp.statusCode}',
      );
    }
    return _parse(resp);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    bool readOnly = false,
  }) async {
    if (!readOnly) {
      ApiTestConfig.ensureBusinessWriteAllowed(path: path, baseUrl: baseUrl);
    }
    final resp = await requestWithRateLimitRetry(
      () => _dio.post<dynamic>(
        path,
        data: data,
        options: Options(headers: _authHeaders()),
      ),
      retryable: readOnly,
    );
    return _parse(resp);
  }

  Map<String, dynamic> _parse(Response<dynamic> resp) {
    if (resp.data is Map<String, dynamic>) {
      return resp.data as Map<String, dynamic>;
    }
    if (resp.data is String) {
      try {
        return jsonDecode(resp.data as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    // 非 JSON 响应（如 HTML 错误页）不再伪装成成功，保留原始 HTTP 状态
    return {'code': resp.statusCode, 'msg': 'non_json_response', 'data': null};
  }

  void close() => _dio.close();

  static void _log(String msg) => stderr.writeln('[API-TEST] $msg');
}

/// Login fixtures must respect the server's IP window across suite isolates.
/// A login waits at most three 60-second windows; business writes never retry.
Future<Response<dynamic>> requestWithRateLimitRetry(
  Future<Response<dynamic>> Function() request, {
  bool retryable = true,
  bool login = false,
  Future<void> Function(Duration)? wait,
}) async {
  const maxRetries = 3;
  for (var attempt = 0; attempt <= maxRetries; attempt++) {
    final response = await request();
    if (!retryable || response.statusCode != 429 || attempt == maxRetries) {
      return response;
    }
    var delay = Duration(seconds: login ? 60 : 1 << attempt);
    final retryAfter = response.headers.value('retry-after');
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) {
        delay = Duration(seconds: seconds);
      } else {
        try {
          delay = HttpDate.parse(retryAfter).difference(DateTime.now().toUtc());
        } on HttpException {
          // HttpDate rejects malformed HTTP dates with HttpException.
        } on FormatException {
          // Retain the bounded fallback for malformed numeric date fields.
        }
      }
    }
    if (delay > const Duration(minutes: 1)) return response;
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    await (wait ?? Future<void>.delayed)(delay);
  }
  throw StateError('rate-limit retry loop exhausted');
}

// ──────────────────────────────────────────────
// 断言工具
// ──────────────────────────────────────────────

class ApiAssert {
  static void success(Map<String, dynamic> resp, {String? context}) {
    final code = resp['code'];
    if (code != 0) {
      throw AssertionError(
        '${context ?? 'API'} 期望成功(code=0), 实际 code=$code, msg=${resp['msg']}',
      );
    }
  }

  static void failure(
    Map<String, dynamic> resp, {
    int? expectedCode,
    String? context,
  }) {
    final code = resp['code'];
    if (code == 0) {
      throw AssertionError('${context ?? 'API'} 期望失败，但实际成功(code=0)');
    }
    if (expectedCode != null && code != expectedCode) {
      throw AssertionError(
        '${context ?? 'API'} 期望 code=$expectedCode, 实际 code=$code',
      );
    }
  }

  static void hasField(
    Map<String, dynamic> resp,
    String field, {
    String? context,
  }) {
    // ponytail: server envelope uses 'payload', not 'data'
    // 上限：只能断言 payload 下的一层直接字段。嵌套路径（payload.list[0].x）
    // 和非 envelope 响应（裸数组 / 文件流）都用不了，调用方只能自己手写取值。
    // 升级触发：后端 envelope 变更（改名或加版本化外层），或测试开始需要断言
    // 嵌套路径时，改成传取值路径（如 'payload.list.0.x'）而不是写死 'payload'。
    final payload = resp['payload'];
    if (payload is! Map || !payload.containsKey(field)) {
      throw AssertionError(
        '${context ?? 'API'} 响应缺少字段: $field (payload=$payload)',
      );
    }
  }

  static void fieldNotEmpty(
    Map<String, dynamic> resp,
    String field, {
    String? context,
  }) {
    hasField(resp, field, context: context);
    final value = (resp['payload'] as Map)[field];
    if (value == null || (value is String && value.isEmpty)) {
      throw AssertionError('${context ?? 'API'} 字段 $field 为空');
    }
  }
}
