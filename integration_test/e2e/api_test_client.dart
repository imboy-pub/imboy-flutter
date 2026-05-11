// E2E API 联调测试 - HTTP 客户端
//
// 提供直接调用后端 API 的能力，绕过 Flutter UI 层，
// 用于验证前后端数据链路的完整性。
//
// 使用方法：
// flutter test integration_test/e2e/api_e2e_test.dart \
//   --dart-define=APP_ENV=local_office \
//   --dart-define=TEST_PHONE=13800138000 \
//   --dart-define=TEST_PASSWORD=test123456

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// E2E 测试配置
class E2ETestConfig {
  E2ETestConfig._();

  /// 测试手机号
  static String get testPhone =>
      const String.fromEnvironment('TEST_PHONE', defaultValue: '');

  /// 测试密码
  static String get testPassword =>
      const String.fromEnvironment('TEST_PASSWORD', defaultValue: '');

  /// 测试验证码
  static String get testCode =>
      const String.fromEnvironment('TEST_CODE', defaultValue: '');

  /// 第二个测试账号（用于双端联调）
  static String get testPhone2 =>
      const String.fromEnvironment('TEST_PHONE2', defaultValue: '');

  static String get testPassword2 =>
      const String.fromEnvironment('TEST_PASSWORD2', defaultValue: '');

  /// API 基础 URL
  static String get apiBaseUrl =>
      const String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// 是否已配置
  static bool get isConfigured =>
      testPhone.isNotEmpty && (testPassword.isNotEmpty || testCode.isNotEmpty);

  /// 是否配置了双账号
  static bool get isDualConfigured =>
      isConfigured && testPhone2.isNotEmpty && testPassword2.isNotEmpty;
}

/// API 测试客户端
///
/// 直接发起 HTTP 请求到后端，不依赖 Flutter app 初始化。
/// 用于 E2E 联调验证。
class ApiTestClient {
  final Dio _dio;
  final String baseUrl;

  String? _accessToken;
  String? _refreshToken;
  String? _currentUid;

  String? get accessToken => _accessToken;
  String? get currentUid => _currentUid;

  ApiTestClient({required this.baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: 'application/json',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null,
        ),
      );

  /// 构建默认请求头（模拟 Flutter 客户端）
  Map<String, String> _defaultHeaders() {
    final cos = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
        ? 'android'
        : Platform.isMacOS
        ? 'macos'
        : 'unknown';
    final did = 'e2e-test-device-${DateTime.now().millisecondsSinceEpoch}';
    final vsn = '0.8.0';
    final pkg = 'pub.imboy.app';

    return {
      'cos': cos,
      'vsn': vsn,
      'pkg': pkg,
      'did': did,
      'tz_offset': '${DateTime.now().timeZoneOffset.inMilliseconds}',
      'method': 'sha512',
      'sk': '1',
    };
  }

  /// 构建认证请求头
  Map<String, String> _authHeaders() {
    final headers = _defaultHeaders();
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  /// 登录
  ///
  /// 返回完整的登录响应数据
  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
    String type = 'mobile',
  }) async {
    _log('登录: account=$account');

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/passport/login',
      data: {
        'account': account,
        'pwd': password,
        'type': type,
        'rsa_encrypt': '0', // 测试环境不加密
      },
      options: Options(headers: _defaultHeaders()),
    );

    final body = _parseResponse(response);
    if (body['code'] == 0) {
      _accessToken = body['data']?['token'];
      _refreshToken = body['data']?['refreshtoken'];
      _currentUid = '${body['data']?['uid'] ?? ''}';
      _log('登录成功: uid=$_currentUid');
    } else {
      _log('登录失败: ${body['msg']}');
    }
    return body;
  }

  /// 刷新 Token
  Future<Map<String, dynamic>> refreshToken() async {
    _log('刷新 Token');
    final headers = _defaultHeaders();
    if (_refreshToken != null) {
      headers['imboy-refreshtoken'] = _refreshToken!;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/refreshtoken',
      options: Options(headers: headers),
    );
    final body = _parseResponse(response);
    if (body['code'] == 0) {
      _accessToken = body['data']?['token'];
      _refreshToken = body['data']?['refreshtoken'];
      _log('Token 刷新成功');
    }
    return body;
  }

  /// GET 请求（需登录）
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: Options(headers: _authHeaders()),
    );
    return _parseResponse(response);
  }

  /// POST 请求（需登录）
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(headers: _authHeaders()),
    );
    return _parseResponse(response);
  }

  /// 解析响应
  Map<String, dynamic> _parseResponse(Response<dynamic> response) {
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is String) {
      try {
        return jsonDecode(response.data as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    return {
      'code': response.statusCode,
      'msg': 'unexpected response format',
      'data': response.data,
    };
  }

  /// 关闭客户端
  void close() {
    _dio.close();
  }

  static void _log(String msg) {
    debugPrint('[E2E-API] $msg');
  }
}

/// 断言辅助
class ApiAssert {
  /// 断言 API 响应成功（code == 0）
  static void success(Map<String, dynamic> resp, {String? context}) {
    final code = resp['code'];
    final msg = resp['msg'] ?? '';
    if (code != 0) {
      throw AssertionError(
        '${context ?? 'API'} 期望成功(code=0), 实际 code=$code, msg=$msg',
      );
    }
  }

  /// 断言 API 响应失败
  static void failure(
    Map<String, dynamic> resp, {
    int? expectedCode,
    String? context,
  }) {
    final code = resp['code'];
    if (code == 0) {
      throw AssertionError('${context ?? 'API'} 期望失败, 但实际成功(code=0)');
    }
    if (expectedCode != null && code != expectedCode) {
      throw AssertionError(
        '${context ?? 'API'} 期望 code=$expectedCode, 实际 code=$code',
      );
    }
  }

  /// 断言响应数据包含指定字段
  static void hasField(
    Map<String, dynamic> resp,
    String field, {
    String? context,
  }) {
    final data = resp['data'];
    if (data is! Map || !data.containsKey(field)) {
      throw AssertionError('${context ?? 'API'} 响应数据缺少字段: $field');
    }
  }

  /// 断言响应数据字段不为空
  static void fieldNotEmpty(
    Map<String, dynamic> resp,
    String field, {
    String? context,
  }) {
    hasField(resp, field, context: context);
    final value = resp['data'][field];
    if (value == null || (value is String && value.isEmpty)) {
      throw AssertionError('${context ?? 'API'} 字段 $field 为空');
    }
  }
}
