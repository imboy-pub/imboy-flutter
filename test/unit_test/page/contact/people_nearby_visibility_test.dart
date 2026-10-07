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
import 'package:imboy/store/model/people_model.dart';

class _Adapter implements HttpClientAdapter {
  final requested = Completer<void>();
  final paths = <String>[];
  int responseCode = 0;
  final response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    paths.add(options.path);
    if (!requested.isCompleted) requested.complete();
    return response.future.then(
      (_) => ResponseBody.fromString(
        '{"code":$responseCode,"msg":"","payload":{}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
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
    adapter.responseCode = success ? 0 : 1;
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
  Future<void> switchAccount({required bool visible}) async {
    await StorageService.to.setString(Keys.currentUid, '2002');
    await UserRepoLocal.to.changeInfo({
      'uid': '2002',
      'setting': {'people_nearby_visible': visible},
    });
  }

  test('account switch clears old nearby coordinates and people', () async {
    final notifier = container.read(peopleNearbyProvider.notifier);
    notifier.updateLocation('113', '23');
    notifier.updatePeopleList([PeopleModel(id: 123, account: 'synthetic')]);
    await switchAccount(visible: false);
    final current = container.read(peopleNearbyProvider);
    expect(current.longitude, isEmpty);
    expect(current.latitude, isEmpty);
    expect(current.peopleList, isEmpty);
    expect(current.peopleNearbyVisible, false);
  });

  test('old show response cannot make new account visible', () async {
    final notifier = container.read(peopleNearbyProvider.notifier);
    notifier.updateLocation('113', '23');
    final pending = notifier.makeMyselfVisible();
    await adapter.requested.future.timeout(const Duration(seconds: 5));
    await switchAccount(visible: false);
    container.read(peopleNearbyProvider);
    reply(true);
    expect(await pending, false);
    expect(container.read(peopleNearbyProvider).peopleNearbyVisible, false);
    expect(UserRepoLocal.to.setting.peopleNearbyVisible, false);
  });

  test('old hide response cannot hide new account', () async {
    final notifier = container.read(peopleNearbyProvider.notifier);
    final pending = notifier.makeMyselfUnVisible();
    await adapter.requested.future.timeout(const Duration(seconds: 5));
    await switchAccount(visible: true);
    container.read(peopleNearbyProvider);
    reply(true);
    expect(await pending, false);
    expect(container.read(peopleNearbyProvider).peopleNearbyVisible, true);
    expect(UserRepoLocal.to.setting.peopleNearbyVisible, true);
  });
  test(
    'settings reject wrong account and expired session generation',
    () async {
      final repo = UserRepoLocal.to;
      final setting = repo.setting..peopleNearbyVisible = true;
      expect(
        await repo.changeSettingForSession(
          setting,
          uid: '2002',
          generation: repo.sessionGeneration,
        ),
        false,
      );
      expect(
        await repo.changeSettingForSession(
          setting,
          uid: '1001',
          generation: repo.sessionGeneration - 1,
        ),
        false,
      );
      expect(repo.setting.peopleNearbyVisible, false);
      expect(
        await repo.changeSettingForSession(
          setting,
          uid: '1001',
          generation: repo.sessionGeneration,
        ),
        true,
      );
      expect(repo.setting.peopleNearbyVisible, true);
    },
  );

  test(
    'old nearby response leaves new account location and list empty',
    () async {
      final notifier = container.read(peopleNearbyProvider.notifier);
      notifier.updateLocation('113', '23');
      final pending = notifier.peopleNearby();
      await adapter.requested.future.timeout(const Duration(seconds: 5));
      await switchAccount(visible: false);
      container.read(peopleNearbyProvider);
      reply(true);
      await pending;
      final current = container.read(peopleNearbyProvider);
      expect(current.longitude, isEmpty);
      expect(current.latitude, isEmpty);
      expect(current.peopleList, isEmpty);
      expect(current.isLoading, false);
    },
  );
  test('rapid show then hide sends visibility changes in order', () async {
    final notifier = container.read(peopleNearbyProvider.notifier);
    notifier.updateLocation('113', '23');
    final show = notifier.makeMyselfVisible();
    await adapter.requested.future.timeout(const Duration(seconds: 5));
    final hide = notifier.makeMyselfUnVisible();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(adapter.paths, [API.makeMyselfVisible]);
    reply(true);
    expect(await show, true);
    expect(await hide, true);
    expect(adapter.paths, [API.makeMyselfVisible, API.makeMyselfUnVisible]);
    expect(container.read(peopleNearbyProvider).peopleNearbyVisible, false);
    expect(UserRepoLocal.to.setting.peopleNearbyVisible, false);
  });
  test(
    'new account can update visibility while old account queue is pending',
    () async {
      final oldNotifier = container.read(peopleNearbyProvider.notifier);
      oldNotifier.updateLocation('113', '23');
      final oldShow = oldNotifier.makeMyselfVisible();
      await adapter.requested.future.timeout(const Duration(seconds: 5));
      final oldHide = oldNotifier.makeMyselfUnVisible();
      await switchAccount(visible: true);
      container.read(peopleNearbyProvider);
      final newAdapter = _Adapter();
      HttpClient.adapterForTest = newAdapter;
      final newHide = container
          .read(peopleNearbyProvider.notifier)
          .makeMyselfUnVisible();
      await newAdapter.requested.future.timeout(const Duration(seconds: 5));
      newAdapter.response.complete(ResponseBody.fromString('', 200));
      expect(await newHide, true);
      expect(UserRepoLocal.to.setting.peopleNearbyVisible, false);
      reply(true);
      expect(await oldShow, false);
      expect(await oldHide, false);
      expect(adapter.paths, [API.makeMyselfVisible]);
      expect(UserRepoLocal.to.setting.peopleNearbyVisible, false);
    },
  );
}
