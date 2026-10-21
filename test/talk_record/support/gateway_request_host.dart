// Private host-only bootstrap. No API, signature or transport implementation is replaced.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart' as app;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/talk_record_api.dart';

class OwnedHostEnv implements Env {
  OwnedHostEnv(this.apiBaseUrl, this.solidifiedKey);
  @override
  final String apiBaseUrl, solidifiedKey;
  @override
  final String solidifiedKeyIv = '0000000000000000';
  @override
  final String iosAppId = '', aMapIosKey = '', aMapAndroidKey = '';
  @override
  final String aMapWebKey = '', jiguangAppKey = '', alipayAppId = '';
  @override
  final String alipayUniversalLink = '', openaiApiKey = '';
  @override
  final String anthropicApiKey = '';
  @override
  final bool aiTestEnabled = false;
  @override
  String? get wsUrl => null;
}

class SignedHost {
  SignedHost._(this.api, this.config);
  final TalkRecordApi api;
  final Map<String, dynamic> config;
  final Map<String, String> _secure = {};

  static Future<SignedHost> load(String privateConfigPath) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = jsonDecode(
      await io.File(privateConfigPath).readAsString(),
    ) as Map<String, dynamic>;
    final origin = Uri.parse(c['base_url'] as String);
    if (origin.scheme != 'http' ||
        origin.host != '127.0.0.1' ||
        !origin.hasPort ||
        origin.path.isNotEmpty ||
        origin.hasQuery) {
      throw StateError('An owned loopback origin is required');
    }
    // Flutter's default test socket stub is a host concern; retain production Dio IO.
    io.HttpOverrides.global = null;
    // ignore: invalid_use_of_visible_for_testing_member
    app.HttpClient.adapterForTest = null;
    currentEnv = 'owned_signed_host';
    envMap[currentEnv] = OwnedHostEnv(
      origin.toString(),
      c['sign_key'] as String,
    );
    deviceId = c['device_id'] as String;
    appVsn = c['app_version'] as String;
    globalSignKeyVsn = c['sign_key_version'] as String;
    packageName = c['package_name'] as String;
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final api = TalkRecordApi();
    if (api.dio.httpClientAdapter is! IOHttpClientAdapter) {
      throw StateError('Real Dio IO adapter required');
    }
    // The actual part transport obtains this same authenticated instance for PUT.
    serviceContainer.put<app.HttpClient>(api);
    final host = SignedHost._(api, c);
    host._installPrivateStorage();
    await host.useActor('owner');
    return host;
  }

  void _installPrivateStorage() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final a = Map<String, dynamic>.from(call.arguments as Map);
            final key = a['key'] as String?;
            switch (call.method) {
              case 'read':
                return _secure[key];
              case 'write':
                _secure[key!] = a['value'] as String;
                return null;
              case 'delete':
                _secure.remove(key);
                return null;
              case 'readAll':
                return Map<String, String>.from(_secure);
              case 'containsKey':
                return _secure.containsKey(key);
              case 'deleteAll':
                _secure.clear();
                return null;
              default:
                throw StateError('Undeclared secure storage host method');
            }
          },
        );
  }

  Future<void> useActor(String name) async {
    final actor = (config['actors'] as Map)[name] as Map;
    await StorageService.to.setString(Keys.currentUid, actor['uid'] as String);
    await StorageService.setMap(Keys.currentUser, {
      'uid': actor['uid'],
      'nickname': 'Synthetic',
    });
    await SecureTokenStorageService.saveToken(actor['jwt'] as String);
  }
}
