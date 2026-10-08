import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/e2ee_health_check_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket_events.dart';

class _CountingAdapter implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'msg': 'success',
        'payload': options.path.contains('notifications/pull')
            ? <Object>[]
            : {'has_valid_key': false},
      }),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _CountingAdapter adapter;
  final service = E2EEHealthCheckService.to;

  setUp(() async {
    service.dispose();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'none'})}.'
        '${encode({'exp': 4102444800, 'uid': 995011})}.test';
    FlutterSecureStorage.setMockInitialValues({'secure_token': token});
    adapter = _CountingAdapter();
    HttpClient.adapterForTest = adapter;
    AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
  });

  tearDown(() async {
    service.dispose();
    HttpClient.adapterForTest = null;
    await AppFeatureRegistry.clear();
  });

  test('disabled background health calls do not access the API', () async {
    await service.pullKeyNotifications();
    await service.checkServerKeyStatusAndGuide();
    expect(adapter.paths, isEmpty);
    expect(StorageService.to.getInt('e2ee_notification_last_since'), isNull);
  });

  test('disabled initialization does not start reconnect requests', () async {
    service.init();
    AppEventBus.fire(const WebSocketStatusChangedEvent(status: 'connected'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(adapter.paths, isEmpty);
  });

  test('disabled health page returns an explicit local state', () async {
    final result = await service.getHealthStatus();
    expect(result['status'], 'disabled');
    expect(result['has_key'], false);
    expect(adapter.paths, isEmpty);
  });

  test('notification pull respects the compiled encryption boundary', () async {
    AppFeatureRegistry.replaceSnapshotForTest({'e2ee': true});
    await service.pullKeyNotifications();
    if (compiledProductFeatures.contains('e2ee')) {
      expect(adapter.paths, hasLength(1));
      expect(adapter.paths.single, contains('notifications/pull'));
    } else {
      expect(adapter.paths, isEmpty);
      expect(StorageService.to.getInt('e2ee_notification_last_since'), isNull);
    }
  });
}
