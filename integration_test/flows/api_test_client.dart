// integration_test/flows/api_test_client.dart
//
// Flutter integration test 专用 HTTP 客户端。
// 配置通过 --dart-define 传入（flutter test 的标准方式）。
//
// 与 test/api/api_test_client.dart 的区别：
//   - 此文件用于 flutter integration_test（需设备，Tier 2/3）
//   - test/api/ 版本用于 dart test（无设备，Tier 1），通过环境变量读取配置
//
// 使用示例：
//   flutter test integration_test/smoke/smoke_test.dart \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=TEST_PHONE=+8613800138000 \
//     --dart-define=TEST_PASSWORD=<pwd>

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class FlowApiConfig {
  FlowApiConfig._();

  static String get testPhone =>
      const String.fromEnvironment('TEST_PHONE', defaultValue: '');

  static String get testPassword =>
      const String.fromEnvironment('TEST_PASSWORD', defaultValue: '');

  static String get testCode =>
      const String.fromEnvironment('TEST_CODE', defaultValue: '');

  static String get testPhone2 =>
      const String.fromEnvironment('TEST_PHONE2', defaultValue: '');

  static String get testPassword2 =>
      const String.fromEnvironment('TEST_PASSWORD2', defaultValue: '');

  static String get apiBaseUrl =>
      const String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static bool get isConfigured =>
      testPhone.isNotEmpty && (testPassword.isNotEmpty || testCode.isNotEmpty);

  static bool get isDualConfigured =>
      isConfigured && testPhone2.isNotEmpty && testPassword2.isNotEmpty;
}

class FlowApiClient {
  final Dio _dio;
  final String baseUrl;
  final String _deviceId;

  String? _accessToken;
  String? _refreshToken;
  String? _currentUid;

  String? get accessToken => _accessToken;
  String? get currentUid => _currentUid;

  FlowApiClient({required this.baseUrl, String? deviceId})
    : _deviceId = deviceId ?? 'e2e-flow-test-001',
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
    final resp = await _dio.post<dynamic>(
      '/v1/refreshtoken',
      options: Options(headers: h),
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
    if (resp.data is Map<String, dynamic>) {
      return resp.data as Map<String, dynamic>;
    }
    if (resp.data is String) {
      try {
        return jsonDecode(resp.data as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {'code': resp.statusCode, 'msg': 'non_json_response', 'data': null};
  }

  void close() => _dio.close();

  static void _log(String msg) => debugPrint('[FLOW-API] $msg');
}

class FlowApiAssert {
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

  static void fieldNotEmpty(
    Map<String, dynamic> resp,
    String field, {
    String? context,
  }) {
    final data = resp['payload'];
    if (data is! Map || !data.containsKey(field)) {
      throw AssertionError('${context ?? 'API'} 响应缺少字段: $field');
    }
    final value = data[field];
    if (value == null || (value is String && value.isEmpty)) {
      throw AssertionError('${context ?? 'API'} 字段 $field 为空');
    }
  }
}
