// Test-only session bootstrap. Business requests remain production UI requests.
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'owned_clock.dart';

void _require(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}

Uri _ownedEndpoint() {
  const environment = String.fromEnvironment('APP_ENV');
  const base = String.fromEnvironment('API_BASE_URL');
  const actualBase = String.fromEnvironment('API_BASE_URL_OVERRIDE');
  const ws = String.fromEnvironment('WS_URL_OVERRIDE');
  const session = String.fromEnvironment('MC_OWNED_SESSION_URL');
  final api = Uri.tryParse(base);
  final socket = Uri.tryParse(ws);
  final endpoint = Uri.tryParse(session);
  _require(environment == 'local', 'owned journey requires local environment');
  _require(
    api != null && endpoint != null && socket != null,
    'explicit owned endpoints required',
  );
  _require(
    api!.scheme == 'http' &&
        api.host == '127.0.0.1' &&
        api.userInfo.isEmpty &&
        base == actualBase,
    'API must use matching explicit loopback override',
  );
  _require(
    endpoint!.scheme == 'http' &&
        endpoint.host == '127.0.0.1' &&
        endpoint.path == '/mc-owned/android/session' &&
        endpoint.query.isEmpty &&
        endpoint.fragment.isEmpty &&
        endpoint.userInfo.isEmpty,
    'session endpoint must be explicit owned loopback',
  );
  _require(
    socket!.scheme == 'ws' &&
        socket.host == api.host &&
        socket.port == api.port &&
        socket.path == '/api/v1/ws' &&
        socket.userInfo.isEmpty &&
        socket.query.isEmpty,
    'WebSocket must use owned same-origin transport',
  );
  return endpoint;
}

Future<void> _requireEmptySession() async {
  await StorageService.init();
  _require(
    !UserRepoLocal.to.isLoggedIn &&
        (await SecureTokenStorageService.getToken()).isEmpty &&
        (await SecureTokenStorageService.getRefreshToken()).isEmpty,
    'existing account detected; refuse replacement',
  );
}

Future<Map<String, dynamic>> _readSession(Uri endpoint) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(
      endpoint.replace(queryParameters: {'did': deviceId}),
    );
    request.followRedirects = false;
    const key = String.fromEnvironment('MC_OWNED_BOOTSTRAP_KEY');
    _require(key.length >= 32, 'private bootstrap key required');
    request.headers.set('x-mc-owned-bootstrap', key);
    final response = await request.close().timeout(const Duration(seconds: 15));
    _require(response.statusCode == 200, 'owned session request rejected');
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      _require(bytes.length <= 65536, 'owned session response oversized');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    _require(
      decoded is Map && decoded['code'] == 0 && decoded['payload'] is Map,
      'invalid owned session envelope',
    );
    return Map<String, dynamic>.from(decoded['payload'] as Map);
  } catch (_) {
    // Transport/decode exceptions must not expose the session response or JWT.
    throw StateError('owned session acquisition failed');
  } finally {
    client.close(force: true);
  }
}

Future<void> establishOwnedAndroidSession() async {
  final endpoint = _ownedEndpoint();
  _require(Platform.isAndroid, 'physical Android required');
  final info = await DeviceInfoPlugin().androidInfo;
  _require(info.isPhysicalDevice, 'simulator rejected');
  const uid = String.fromEnvironment('MC_OWNED_UID');
  _require(
    RegExp(r'^[1-9][0-9]*$').hasMatch(uid),
    'explicit fixture UID required',
  );
  _require(
    !const bool.fromEnvironment('IMBOY_JPUSH_ENABLED'),
    'remote push provider must remain disabled',
  );
  await _requireEmptySession();
  await prepareOwnedClock();
  await AppInitializer.initialize(env: 'local', signKeyVsn: '1');
  _require(
    currentEnv == 'local' &&
        Env().apiBaseUrl ==
            const String.fromEnvironment('API_BASE_URL_OVERRIDE'),
    'runtime environment drift rejected',
  );
  _require(
    Firebase.apps.isEmpty &&
        !PushNotificationService.instance.fcmEnabled &&
        PushNotificationService.instance.pushToken == null,
    'remote push configuration detected',
  );
  await _requireEmptySession();
  await _commitOwnedSession(endpoint, uid);
}

Future<void> _commitOwnedSession(Uri endpoint, String uid) async {
  final payload = await _readSession(endpoint);
  _require(
    (payload['user_id'] ?? payload['uid']).toString() == uid &&
        payload['did'] == deviceId &&
        payload['channel_id'].toString() ==
            const String.fromEnvironment('MC_CHANNEL_ID') &&
        payload['group_id'].toString() ==
            const String.fromEnvironment('MC_DISCUSSION_GROUP_ID') &&
        payload['product_profile'] == 'community',
    'owned session identity mismatch',
  );
  final profile = payload['profile'];
  _require(profile is Map, 'owned user profile required');
  final loginPayload = <String, dynamic>{
    ...Map<String, dynamic>.from(profile as Map),
    'user_id': uid,
    'uid': uid,
    'token': payload['token'],
    'refreshtoken': payload['refreshtoken'],
  };
  try {
    _require(
      await UserRepoLocal.to.loginAfter(uid, loginPayload),
      'owned session commit rejected',
    );
  } catch (_) {
    throw StateError('owned session commit failed');
  }
  _require(UserRepoLocal.to.currentUid == uid, 'owned session not established');
}
