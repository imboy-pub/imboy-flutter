import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show serviceContainer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_provider.dart';
import 'package:imboy/page/contact/confirm_new_friend/confirm_new_friend_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Reuses confirm_friend_unknown_test's real provider/container + HttpClient
// pattern. Only the HTTP I/O result is synthetic; no notifier/wrapper/owner mock.
// Captures actual Dio request options before returning a definite refusal, so
// no success-only SQLite writes occur. This is not a real network/Fetch proof.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await prepareWebWriter();
    await LocaleSettings.setLocale(AppLocale.zhCn);
    SharedPreferences.setMockInitialValues({Keys.currentUid: '2'});
    await StorageService.init();
    String part(Object x) =>
        base64Url.encode(utf8.encode(jsonEncode(x))).replaceAll('=', '');
    FlutterSecureStorage.setMockInitialValues({
      'secure_token':
          '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}',
    });
  });

  for (final confirm in [false, true]) {
    for (final changeOwner in [false, true]) {
      testWidgets(
        'real ${confirm ? 'confirm' : 'apply'} wrapper shape ownerChanged=$changeOwner',
        (tester) async {
          await tester.runAsync(
            () => StorageService.to.setString(Keys.currentUid, '2'),
          );
          final client = HttpClient();
          final captured = <RequestOptions>[];
          final payload = {
            'from': {'msg': 'synthetic'},
            'to': <String, dynamic>{},
          };
          client.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                captured.add(options);
                expect(options.method, 'POST');
                expect(
                  options.uri.path,
                  confirm ? API.confirmFriend : API.addFriend,
                );
                expect(
                  options.contentType,
                  kIsWeb
                      ? Headers.jsonContentType
                      : 'application/x-www-form-urlencoded',
                );
                final data = options.data as Map;
                expect(data['to'], confirm ? '2' : '1');
                expect(jsonDecode(data['payload'] as String), payload);
                if (confirm) {
                  expect(data['from'], '1');
                  expect(options.extra[httpNoAutoRetry], isTrue);
                  expect(options.responseDecoder, isNotNull);
                } else {
                  expect(data['created_at'], isA<int>());
                  // Preserve the pre-existing apply policy; do not falsely claim it
                  // already had the confirmation path's explicit no-auto-retry flag.
                  expect(options.extra[httpNoAutoRetry] == true, isFalse);
                }
                final guard = options.extra[httpRequestGuard];
                expect(guard, isA<void Function()>());
                expect(isWebWriterReady, isTrue);
                expect(guard as void Function(), returnsNormally);
                if (changeOwner) {
                  await StorageService.to.setString(Keys.currentUid, '3');
                  expect(guard, throwsA(isA<Exception>()));
                }
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 422,
                    data: {
                      'code': 422,
                      'msg': 'synthetic_refusal',
                      'payload': {'field': 'synthetic_refusal'},
                    },
                  ),
                );
              },
            ),
          );
          serviceContainer.put<HttpClient>(client);
          final container = ProviderContainer();
          final applyKeep = container.listen(applyFriendProvider, (_, _) {});
          final confirmKeep = container.listen(
            confirmNewFriendProvider,
            (_, _) {},
          );
          await tester.pumpWidget(
            TranslationProvider(
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: AppLoading.init()(context, child),
                ),
                home: const Scaffold(),
              ),
            ),
          );
          try {
            final operation = tester.runAsync(
              () => confirm
                  ? container
                        .read(confirmNewFriendProvider.notifier)
                        .confirm(from: '1', to: '2', payload: payload)
                  : container
                        .read(applyFriendProvider.notifier)
                        .apply(
                          to: '1',
                          peerNickname: 'synthetic',
                          peerAvatar: '',
                          payload: payload,
                        ),
            );
            await tester.pump();
            final result = await operation;
            expect(result, isFalse);
            expect(captured, hasLength(1));
            if (changeOwner)
              expect(StorageService.to.getString(Keys.currentUid), '3');
          } finally {
            final dismissed = AppLoading.dismiss(animation: false);
            await tester.pump();
            await dismissed;
            await tester.pump(const Duration(seconds: 4));
            applyKeep.close();
            confirmKeep.close();
            container.dispose();
            client.dio.close(force: true);
            serviceContainer.clear();
            await tester.runAsync(
              () => StorageService.to.setString(Keys.currentUid, '2'),
            );
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    }
  }
}
