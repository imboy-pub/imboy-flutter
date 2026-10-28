import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/contact/assistant_plaza/assistant_plaza_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/agent_api.dart';
import 'package:imboy/store/api/location_api.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"code":0,"msg":"success","payload":{"total":1,"list":['
    '{"id":9007199254740993,"uid":9007199254740995,'
    '"name":"assistant","nickname":"person","distance":1.5}]}}',
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    HttpClient.adapterForTest = _Adapter();
  });

  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  test('user search, recent and nearby preserve raw person IDs', () async {
    final payloads = [
      await UserApi.to.userSearch(keyword: 'x'),
      await UserApi.to.ftsRecentlyUser(),
      await LocationApi().peopleNearby(longitude: '0', latitude: '0'),
    ];
    for (final payload in payloads) {
      final row = (payload!['list'] as List).single as Map<String, dynamic>;
      expect(row['id'], '9007199254740993');
      expect(PeopleModel.fromJson(row).id, '9007199254740995');
      expect(row['distance'], 1.5);
      expect(payload['total'], 1);
    }
  });

  test('assistant provider keeps the exact raw ID', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(assistantPlazaProvider.notifier).initData();
    expect(
      container.read(assistantPlazaProvider).list.single.id,
      '9007199254740993',
    );
    expect(await AgentApi.to.agentList(), isNotNull);
  });
}
