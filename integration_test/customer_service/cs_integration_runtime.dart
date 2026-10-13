import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_attachment_preparation.dart';
import 'package:imboy/modules/customer_service/presentation/cs_attachment_save.dart';

import 'cs_owned_device_files.dart';

import 'package:imboy/config/const.dart';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/http/http_retry_interceptor.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';

import 'cs_integration_fixture.dart';

/// Delegates existing keys; only the explicitly admitted run origin changes.
class CsRunEnvironment implements Env {
  CsRunEnvironment(this.original, this.origin);
  final Env original;
  final Uri origin;
  @override
  String get apiBaseUrl => origin.toString();
  @override
  String? get wsUrl =>
      origin.replace(scheme: 'wss', path: '/api/v1/ws').toString();
  @override
  String get solidifiedKey => original.solidifiedKey;
  @override
  String get solidifiedKeyIv => original.solidifiedKeyIv;
  @override
  String get iosAppId => original.iosAppId;
  @override
  String get aMapIosKey => original.aMapIosKey;
  @override
  String get aMapAndroidKey => original.aMapAndroidKey;
  @override
  String get aMapWebKey => original.aMapWebKey;
  @override
  String get jiguangAppKey => original.jiguangAppKey;
  @override
  String get alipayAppId => original.alipayAppId;
  @override
  String get alipayUniversalLink => original.alipayUniversalLink;
  @override
  String get openaiApiKey => original.openaiApiKey;
  @override
  String get anthropicApiKey => original.anthropicApiKey;
  @override
  bool get aiTestEnabled => original.aiTestEnabled;
}

class CsIntegrationRuntime {
  CsIntegrationRuntime(this.fixture) : ownedFiles = CsOwnedDeviceFiles(fixture);
  final CsIntegrationFixture fixture;
  final CsOwnedDeviceFiles ownedFiles;
  final requestCounts = <String, int>{};
  Env? _original;
  String? _previousEnvironment;

  Future<void> initialize() async {
    if (fixture.assetMime != 'application/octet-stream') {
      throw StateError('CS_REAL_BINARY_FILE_FIXTURE_REQUIRED');
    }
    await StorageService.init();
    final original = envMap[fixture.environment];
    if (original == null ||
        sha256.convert(utf8.encode(original.solidifiedKey)).toString() !=
            fixture.signKeySha) {
      throw StateError('CS_DEVICE_SIGN_KEY_UNVERIFIED');
    }
    final actualDid = await _requireDeviceProfile();
    await ownedFiles.readInput();
    _original = original;
    _previousEnvironment = currentEnv;
    currentEnv = fixture.environment;
    envMap[fixture.environment] = CsRunEnvironment(original, fixture.apiBase);
    deviceId = actualDid;
  }

  Future<String> _requireDeviceProfile() async {
    if (!Platform.isAndroid ||
        !(await DeviceExt.to.androidInfo).isPhysicalDevice) {
      throw StateError('CS_PHYSICAL_DEVICE_REQUIRED');
    }
    final existingUid = StorageService.to.getString(Keys.currentUid);
    if (existingUid.isNotEmpty &&
        existingUid != fixture.seat('A').uid &&
        existingUid != fixture.seat('B').uid) {
      throw StateError('CS_DEVICE_PROFILE_NOT_OWNED');
    }
    final actualDid = await DeviceExt.did;
    if (actualDid != fixture.deviceId) {
      throw StateError('CS_DEVICE_BINDING_REFUSED');
    }
    final external = await getExternalStorageDirectory();
    if (external?.path !=
        '/storage/emulated/0/Android/data/$packageName/files') {
      throw StateError('CS_ANDROID_USER0_PROFILE_REQUIRED');
    }
    return actualDid;
  }

  Future<void> login(String seat) async {
    final principal = fixture.seat(seat);
    final ok = await UserRepoLocal.to.loginAfter(fixture.runId, {
      'uid': principal.uid,
      'token': principal.token,
      'refreshtoken': principal.refresh,
    });
    final scope = authSessionReader.current;
    if (!ok ||
        scope.uid != principal.uid ||
        !authSessionReader.isCurrent(scope)) {
      throw StateError('CS_REAL_LOGIN_REFUSED');
    }
  }

  CsSessionAttachmentPreparation
  preparation() => CsSessionAttachmentPreparation(
    pickFiles: () async {
      final selected = await FilePicker.pickFiles(type: FileType.any);
      if (selected.isEmpty) return selected;
      if (selected.length != 1 ||
          selected.single.path == null ||
          selected.single.name != fixture.assetName) {
        throw const CsOwnedFileRefused();
      }
      await ownedFiles.readPicked(File(selected.single.path!));
      // A cache copy without a public original-source proof is refused above.
      return selected;
    },
    readHead: (file) async {
      final bytes = await ownedFiles.readPicked(file);
      return Uint8List.fromList(bytes.take(64).toList());
    },
    readBytes: ownedFiles.readPicked,
  );

  CsAttachmentSave saver() => CsAttachmentSave(
    saveFile: ({required fileName, required bytes, required mimeType}) async {
      if (fileName != fixture.assetName ||
          bytes.length != fixture.assetSize ||
          sha256.convert(bytes).toString() != fixture.assetSha) {
        throw const CsOwnedFileRefused();
      }
      await ownedFiles.assertOutputAbsent();
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (uri != null) await ownedFiles.verifySaveUri(uri);
      // Native UI writes before returning. A foreign selection fails this gate;
      // only the leased operator window can constrain that native choice.
      return uri;
    },
  );

  CsApi api() => _quiet(CsApi(assetApiFactory: () => _quiet(EnterpriseApi())));

  T _quiet<T>(T client) {
    final dio = client is CsApi ? client.dio : (client as EnterpriseApi).dio;
    dio.options.baseUrl = fixture.apiBase.toString();
    dio.options.followRedirects = false;
    dio.options.maxRedirects = 0;
    // Owned instances only; Auth/signing interceptors remain production code.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, next) {
          if (o.method == 'POST' || o.method == 'PUT') {
            final category = o.path.endsWith('/presign')
                ? 'presign'
                : o.path.endsWith('/confirm')
                ? 'confirm'
                : o.path.endsWith('/messages')
                ? 'message'
                : o.method == 'PUT'
                ? 'put'
                : 'other_write';
            requestCounts.update(category, (v) => v + 1, ifAbsent: () => 1);
          }
          next.next(o);
        },
      ),
    );
    dio.interceptors.removeWhere(
      (i) => i is LogInterceptor || i is HttpRetryInterceptor,
    );
    return client;
  }

  void restoreEnvironment() {
    if (_original != null) envMap[fixture.environment] = _original!;
    if (_previousEnvironment != null) currentEnv = _previousEnvironment!;
  }
}
