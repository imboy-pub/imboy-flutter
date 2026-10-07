import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/storage.dart';

class _OfflineAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool empty = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'msg': 'success',
        'payload': {
          'c2c': {
            'list': empty
                ? <Map<String, dynamic>>[]
                : [
                    {
                      'msg_id': 'offline_failure_probe',
                      'from': '995012',
                      'to': '995011',
                      'msg_type': 'text',
                      'payload': {'text': 'probe'},
                      'created_at': 1750000000000,
                    },
                  ],
            'has_more': false,
            'next_last_msg_at': 1750000000000,
          },
        },
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

Future<void> _expectStorageFailures(
  WidgetTester tester,
  MessageOfflineService service,
) async {
  // SQLite is deliberately unavailable: exercise the real repository failure.
  for (var attempt = 1; attempt <= 2; attempt++) {
    final result = await tester.runAsync(
      () => service.requestPull(source: 'storage_failure_test', force: true),
    );
    expect(result, isFalse);
    expect(service.getPullStats()['succeeded_total'], 0);
    expect(service.getPullStats()['failed_total'], attempt);
    expect(MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c), 0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _OfflineAdapter adapter;
  late MessageOfflineService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    FlutterSecureStorage.setMockInitialValues({
      'secure_token':
          '${encode({'alg': 'none'})}.${encode({'exp': 4102444800, 'uid': 995011})}.test',
    });
    AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
    adapter = _OfflineAdapter();
    HttpClient.adapterForTest = adapter;
    serviceContainer.put(HttpClient());
    service = MessageOfflineService.instance;
  });

  testWidgets(
    'failed storage neither commits cursor nor counts success; retry retains cursor',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
      );
      try {
        await _expectStorageFailures(tester, service);
        expect(
          adapter.requests.length,
          2,
          reason: 'failed messages must not be ACKed',
        );
        expect(
          adapter.requests.every(
            (request) =>
                !request.queryParameters.containsKey('c2c_last_msg_at'),
          ),
          isTrue,
        );
        adapter.empty = true;
        expect(
          await tester.runAsync(
            () => service.requestPull(source: 'recovery_test', force: true),
          ),
          isTrue,
        );
        expect(service.getPullStats()['succeeded_total'], 1);
        expect(service.getPullStats()['failed_total'], 2);
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
          1750000000000,
        );
        await tester.pumpAndSettle();
      } finally {
        service.onDispose();
        HttpClient.adapterForTest = null;
        serviceContainer.clear();
        await AppFeatureRegistry.clear();
      }
    },
  );
}
