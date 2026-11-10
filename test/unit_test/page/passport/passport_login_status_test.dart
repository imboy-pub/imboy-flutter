import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart' as imboy_http;
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _LoginNotifier extends PassportNotifier {
  @override
  PassportState build() {
    final controller = TextEditingController();
    ref.onDispose(controller.dispose);
    return PassportState(loginAccountCtl: controller);
  }
}

class _SyntheticDeviceInfo extends DeviceInfoPlatform {
  @override
  Future<BaseDeviceInfo> deviceInfo() async {
    if (Platform.isLinux) {
      return LinuxDeviceInfo(
        name: 'test',
        id: 'synthetic-device',
        prettyName: 'test',
        machineId: 'synthetic-machine',
      );
    }
    return BaseDeviceInfo({
      'computerName': 'test',
      'hostName': 'test',
      'arch': 'arm64',
      'model': 'test',
      'modelName': 'test',
      'kernelVersion': 'test',
      'osRelease': 'test',
      'majorVersion': 1,
      'minorVersion': 0,
      'patchVersion': 0,
      'activeCPUs': 1,
      'memorySize': 1,
      'cpuFrequency': 1,
      'systemGUID': 'synthetic-device',
    });
  }
}

class _LoginAdapter implements HttpClientAdapter {
  _LoginAdapter(this.encryptedConfig);
  final String encryptedConfig;
  int status = 0;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Map<String, dynamic> payload;
    if (options.path == API.initConfig) {
      payload = {'res_v2': encryptedConfig};
    } else if (options.path == API.login) {
      payload = {'status': status};
    } else {
      throw StateError('Unexpected synthetic request: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'msg': '', 'payload': payload}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<String> _configResponse() async {
  final salt = Uint8List.fromList(List<int>.filled(16, 7));
  final iv = Uint8List.fromList(List<int>.filled(12, 3));
  final key = Uint8List.fromList(
    utf8.encode(EncrypterService.md5(await Env.signKey())),
  );
  final encrypted = EncrypterService.aesGcmEncryptBytesWithIV(
    Uint8List.fromList(utf8.encode(jsonEncode({'login_pwd_rsa_encrypt': '0'}))),
    key,
    iv,
    aad: salt,
  );
  return base64Encode([...salt, ...iv, ...base64Decode(encrypted['ct']!)]);
}

void main() {
  late ProviderContainer container;
  late _LoginAdapter adapter;
  late DeviceInfoPlatform originalDeviceInfo;
  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.loginHistoryAccount: ['retained'],
    });
    await StorageService.init();
    AppInitializer.clearInitConfigCache();
    originalDeviceInfo = DeviceInfoPlatform.instance;
    DeviceInfoPlatform.instance = _SyntheticDeviceInfo();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          if (call.method == 'read' && args['key'] == Keys.publicKey) {
            return 'synthetic-device-public-key';
          }
          return null;
        });
    adapter = _LoginAdapter(await _configResponse());
    final client = imboy_http.HttpClient(
      conf: HttpConfig(baseUrl: Env().apiBaseUrl),
      retryEnabled: false,
    );
    client.dio.httpClientAdapter = adapter;
    serviceContainer.put(client);
    container = ProviderContainer(
      overrides: [passportProvider.overrideWith(_LoginNotifier.new)],
    );
    container.listen(passportProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    serviceContainer.clear();
    AppInitializer.clearInitConfigCache();
    DeviceInfoPlatform.instance = originalDeviceInfo;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  for (final useCode in [false, true]) {
    for (final status in [0, 7]) {
      test(
        'successful HTTP response with status $status is not an authenticated login (code: $useCode)',
        () async {
          adapter.status = status;
          final notifier = container.read(passportProvider.notifier);
          final error = useCode
              ? await notifier.loginUserByCode(
                  'email',
                  'alice@example.test',
                  '123456',
                )
              : await notifier.loginUser(
                  'account',
                  'alice',
                  'synthetic-password',
                );

          expect(
            adapter.requests.where((request) => request.path == API.login),
            hasLength(1),
          );
          expect(error, t.common.operationFailedAgainLater);
          expect(UserRepoLocal.to.currentUid, isEmpty);
          expect(StorageService.to.getList(Keys.loginHistoryAccount), [
            'retained',
          ]);
          expect(
            StorageService.to.getString(LoginAccountHistoryService.storageKey),
            isEmpty,
          );
        },
      );
    }
  }
}
