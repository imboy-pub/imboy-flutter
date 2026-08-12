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
import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/config/env.dart';
import 'package:imboy/service/encrypter.dart';

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
  final String? _deviceTypeOverride;

  String? _accessToken;
  String? _refreshToken;
  String? _currentUid;

  String? get accessToken => _accessToken;
  String? get currentUid => _currentUid;

  FlowApiClient({required this.baseUrl, String? deviceId, String? deviceType})
    : _deviceId = deviceId ?? 'e2e-flow-test-001',
      _deviceTypeOverride = deviceType,
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: 'application/json',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null,
        ),
      ) {
    // 集成测试不启动完整 AppInitializer，但签名密钥仍依赖 currentEnv。
    // 同步显式 dart-define，避免 currentEnv 为空时 Env() 静默回退生产配置。
    const testEnv = String.fromEnvironment('APP_ENV', defaultValue: '');
    if (testEnv.isNotEmpty) currentEnv = testEnv;
  }

  Future<Map<String, String>> _defaultHeaders() async {
    final cos =
        _deviceTypeOverride ??
        (Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
            ? 'android'
            : Platform.isMacOS
            ? 'macos'
            : 'linux');
    // pkg 必须与各平台实际 bundle id/applicationId 一致，否则后端 902
    final pkg =
        _deviceTypeOverride == 'android' ||
            (_deviceTypeOverride == null && Platform.isAndroid)
        ? 'imboy.chat'
        : _deviceTypeOverride == 'macos' ||
              (_deviceTypeOverride == null && Platform.isMacOS)
        ? 'pub.imboy.macos'
        : _deviceTypeOverride == 'ios' ||
              (_deviceTypeOverride == null && Platform.isIOS)
        ? 'pub.imboy.2'
        : 'pub.imboy.app';
    // package_info_plus 在当前构建产物中返回的平台版本并不完全一致：
    // Android 为 pubspec 的 alpha 版本，macOS 为构建后的 1.0.0.15。
    // 签名原文必须与运行中的 App 版本一致，否则服务端返回 902。
    final vsn = Platform.isMacOS ? '1.0.0.15' : '1.0.0-alpha.15';
    final key = await Env.signKey();

    return {
      'cos': cos,
      'vsn': vsn,
      'pkg': pkg,
      'did': _deviceId,
      'tz_offset': '${DateTime.now().timeZoneOffset.inMilliseconds}',
      'method': 'sha512',
      'sk': '1',
      // 与 App 客户端一致：base64(HMAC-SHA512("did|vsn|cos|pkg", key))
      'sign': EncrypterService.sha512('$_deviceId|$vsn|$cos|$pkg', key),
      'X-Client-Type': 'mobile',
    };
  }

  Future<Map<String, String>> _authHeaders() async {
    final h = await _defaultHeaders();
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      h['authorization'] = 'Bearer $_accessToken';
    }
    return h;
  }

  /// 对密码做 MD5，与 Flutter app 行为一致（backend 存储 md5(plaintext)）
  static String _md5(String s) => md5.convert(utf8.encode(s)).toString();

  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
    String? type,
    // 服务端 7/1 迁移后新账号存储 hmac_sha512(明文)，只接受明文；
    // 存量账号（md5 存储）依赖 default_md5 兼容分支接受 md5 传输。
    // 默认 md5（兼容存量账号/生产），新格式测试账号传 true 用明文。
    bool plainPassword = false,
  }) async {
    // 自动推断 type：包含 @ 的是 email，否则默认 mobile
    final loginType = type ?? (account.contains('@') ? 'email' : 'mobile');
    final loginCos =
        _deviceTypeOverride ??
        (Platform.isAndroid
            ? 'android'
            : Platform.isMacOS
            ? 'macos'
            : 'linux');
    _log('登录: $account (type=$loginType)');
    final resp = await _dio.post<dynamic>(
      '/api/v1/passport/login',
      data: {
        'account': account,
        'pwd': plainPassword ? password : _md5(password),
        'type': loginType,
        'rsa_encrypt': '0',
        'did': _deviceId,
        'cos': loginCos,
      },
      options: Options(headers: await _defaultHeaders()),
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
    final h = await _defaultHeaders();
    if (_refreshToken != null) h['imboy-refreshtoken'] = _refreshToken!;
    final resp = await _dio.post<dynamic>(
      '/api/v1/refreshtoken',
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
      options: Options(headers: await _authHeaders()),
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
      options: Options(headers: await _authHeaders()),
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
