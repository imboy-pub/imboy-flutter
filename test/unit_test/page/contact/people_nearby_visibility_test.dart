import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class _Adapter implements HttpClientAdapter {
  final requested = Completer<void>();
  final response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (!requested.isCompleted) requested.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Adapter adapter;
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '1001');
    await StorageService.setMap(Keys.currentUser, {
      'uid': '1001',
      'setting': {'people_nearby_visible': false},
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'read' &&
              call.arguments['key'] == 'secure_token') {
            final body = base64Url
                .encode(
                  utf8.encode(
                    jsonEncode({
                      'exp':
                          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                    }),
                  ),
                )
                .replaceAll('=', '');
            return 'e30.$body.signature';
          }
          return null;
        });
    adapter = _Adapter();
    HttpClient.adapterForTest = adapter;
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void reply(bool success) {
    adapter.response.complete(
      ResponseBody.fromString(
        '{"code":${success ? 0 : 1},"msg":"","payload":{}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  test(
    'failed show keeps confirmed visibility while pending and after failure',
    () async {
      final notifier = container.read(peopleNearbyProvider.notifier);
      notifier.updateLocation('113', '23');
      final pending = notifier.makeMyselfVisible();
      await adapter.requested.future.timeout(const Duration(seconds: 5));
      expect(container.read(peopleNearbyProvider).peopleNearbyVisible, false);
      reply(false);
      expect(await pending, false);
      expect(container.read(peopleNearbyProvider).peopleNearbyVisible, false);
      expect(UserRepoLocal.to.setting.peopleNearbyVisible, false);
    },
  );

  test('failed hide does not falsely claim location is hidden', () async {
    await StorageService.setMap(Keys.currentUser, {
      'uid': '1001',
      'setting': {'people_nearby_visible': true},
    });
    final notifier = container.read(peopleNearbyProvider.notifier);
    final pending = notifier.makeMyselfUnVisible();
    await adapter.requested.future.timeout(const Duration(seconds: 5));
    expect(container.read(peopleNearbyProvider).peopleNearbyVisible, true);
    reply(false);
    expect(await pending, false);
    expect(container.read(peopleNearbyProvider).peopleNearbyVisible, true);
    expect(UserRepoLocal.to.setting.peopleNearbyVisible, true);
  });

  test(
    'show is idempotent and persists only after server confirmation',
    () async {
      await StorageService.setMap(Keys.currentUser, {
        'uid': '1001',
        'setting': {'people_nearby_visible': true},
      });
      final notifier = container.read(peopleNearbyProvider.notifier);
      notifier.updateLocation('113', '23');
      final pending = notifier.makeMyselfVisible();
      await adapter.requested.future.timeout(const Duration(seconds: 5));
      expect(container.read(peopleNearbyProvider).peopleNearbyVisible, true);
      reply(true);
      expect(await pending, true);
      expect(container.read(peopleNearbyProvider).peopleNearbyVisible, true);
      expect(UserRepoLocal.to.setting.peopleNearbyVisible, true);
    },
  );
}
