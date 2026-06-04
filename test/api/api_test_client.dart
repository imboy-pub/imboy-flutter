// test/api/api_test_client.dart
//
// 纯 Dart HTTP 测试客户端，供 test/api/ 下的 dart test 使用。
// 不依赖 Flutter 绑定，不需要设备，可在 CI 中直接运行：
//   API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=xxx TEST_PASSWORD=xxx \
//   dart test test/api/ --concurrency=1
//
// 与 integration_test/e2e/api_test_client.dart 的区别：
//   - 不引入 package:flutter
//   - did 在构造时固定，整个 client 生命周期不变
//   - 配置从环境变量读取（兼容 CI secret injection）

import 'dart:convert';
import 'dart:io';

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
  static String get apiBaseUrl =>
      Platform.environment['API_BASE_URL'] ?? 'http://127.0.0.1:9800';

  static bool get isConfigured =>
      testPhone.isNotEmpty && (testPassword.isNotEmpty || testCode.isNotEmpty);

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

  String? _accessToken;
  String? _refreshToken;
  String? _currentUid;

  String? get accessToken => _accessToken;
  String? get currentUid => _currentUid;

  ApiTestClient({required this.baseUrl, String? deviceId})
    : _deviceId = deviceId ?? 'e2e-dart-test-001',
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: 'application/json',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null,
        ),
      );

  Map<String, String> _defaultHeaders() {
    final cos = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
        ? 'android'
        : Platform.isMacOS
        ? 'macos'
        : 'linux';

    return {
      'cos': cos,
      'vsn': '0.8.0',
      'pkg': 'pub.imboy.app',
      'did': _deviceId,
      'tz_offset': '${DateTime.now().timeZoneOffset.inMilliseconds}',
      'method': 'sha512',
      'sk': '1',
    };
  }

  Map<String, String> _authHeaders() {
    final h = _defaultHeaders();
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      h['authorization'] = 'Bearer $_accessToken';
    }
    return h;
  }

  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
    String type = 'mobile',
  }) async {
    _log('登录: $account');
    final resp = await _dio.post<dynamic>(
      '/v1/passport/login',
      data: {
        'account': account,
        'pwd': password,
        'type': type,
        'rsa_encrypt': '0',
      },
      options: Options(headers: _defaultHeaders()),
    );
    final body = _parse(resp);
    if (body['code'] == 0) {
      _accessToken = body['data']?['token'] as String?;
      _refreshToken = body['data']?['refreshtoken'] as String?;
      _currentUid = '${body['data']?['uid'] ?? ''}';
      _log('登录成功: uid=$_currentUid');
    } else {
      _log('登录失败: ${body['msg']}');
    }
    return body;
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final h = _defaultHeaders();
    if (_refreshToken != null) h['imboy-refreshtoken'] = _refreshToken!;
    final resp = await _dio.post<dynamic>(
      '/v1/refreshtoken',
      options: Options(headers: h),
    );
    final body = _parse(resp);
    if (body['code'] == 0) {
      _accessToken = body['data']?['token'] as String?;
      _refreshToken = body['data']?['refreshtoken'] as String?;
    }
    return body;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final resp = await _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: Options(headers: _authHeaders()),
    );
    return _parse(resp);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final resp = await _dio.post<dynamic>(
      path,
      data: data,
      options: Options(headers: _authHeaders()),
    );
    return _parse(resp);
  }

  Map<String, dynamic> _parse(Response<dynamic> resp) {
    if (resp.data is Map<String, dynamic>)
      return resp.data as Map<String, dynamic>;
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
    final data = resp['data'];
    if (data is! Map || !data.containsKey(field)) {
      throw AssertionError('${context ?? 'API'} 响应缺少字段: $field');
    }
  }

  static void fieldNotEmpty(
    Map<String, dynamic> resp,
    String field, {
    String? context,
  }) {
    hasField(resp, field, context: context);
    final value = (resp['data'] as Map)[field];
    if (value == null || (value is String && value.isEmpty)) {
      throw AssertionError('${context ?? 'API'} 字段 $field 为空');
    }
  }
}
