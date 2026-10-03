/// Offline synthetic session-start test. Secure storage writes always fail
/// before login commit: no database, WebSocket, push or real credential access.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';

class _PendingMine implements HttpClientAdapter {
  _PendingMine(this.pages);
  final int pages;
  final pending = Completer<ResponseBody>();
  final observed = Completer<void>();
  int calls = 0;
  ResponseBody response() => ResponseBody.fromString(
    jsonEncode({
      'code': 0,
      'msg': 'success',
      'payload': {
        'list': [
          {'id': 7001, 'name': 'synthetic organization'},
        ],
        'page': calls,
        'size': 100,
        'total': pages,
        'total_page': pages,
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    if (calls == 1) {
      observed.complete();
      return pending.future;
    }
    return Future.value(response());
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '91001'});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'write') {
              throw PlatformException(code: 'synthetic-keychain-write-stop');
            }
            if (call.method == 'read') {
              final encode = base64Url.encode;
              return '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.'
                  '${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.'
                  '${encode(utf8.encode('synthetic-signature'))}';
            }
            return null;
          },
        );
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  for (final pages in [1, 2]) {
    test('会话代次提前变化但UID未更新时丢弃旧$pages页组织结果', () async {
      final adapter = _PendingMine(pages);
      HttpClient.adapterForTest = adapter;
      final result = OrganizationApi().allMine();
      await adapter.observed.future.timeout(const Duration(seconds: 2));
      final repo = UserRepoLocal.to;
      final generation = repo.sessionGeneration;
      var notifications = 0;
      void notified() => notifications++;
      repo.addListener(notified);
      addTearDown(() => repo.removeListener(notified));
      await expectLater(
        repo.loginAfter('synthetic-session', {
          'uid': '91002',
          'token': 'synthetic-access-value',
          'refreshtoken': 'synthetic-refresh-value',
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(repo.sessionGeneration, generation + 1);
      expect(repo.currentUid, '91001');
      expect(notifications, 0);
      final rejected = expectLater(
        result,
        throwsA(
          isA<OrganizationApiException>().having((e) => e.code, 'code', 409),
        ),
      );
      adapter.pending.complete(adapter.response());
      await rejected;
      expect(adapter.calls, 1);
    });
  }
}
