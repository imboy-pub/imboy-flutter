import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/confirm_new_friend/confirm_new_friend_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TimeoutAdapter implements HttpClientAdapter {
  int requests = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionTimeout,
    );
  }
}

void main() {
  testWidgets(
    'timeout is unknown and never automatically resends confirmation',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '2'});
      await StorageService.init();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => call.method == 'read' ? 'synthetic-token' : null,
          );
      final adapter = _TimeoutAdapter();
      HttpClient.adapterForTest = adapter;
      serviceContainer.put(HttpClient());
      addTearDown(() {
        HttpClient.adapterForTest = null;
        serviceContainer.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(
                'plugins.it_nomads.com/flutter_secure_storage',
              ),
              null,
            );
      });
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const Scaffold()),
      );
      final container = ProviderContainer();
      final keep = container.listen(confirmNewFriendProvider, (_, _) {});
      final result = await tester.runAsync(
        () => container
            .read(confirmNewFriendProvider.notifier)
            .confirm(from: '1', to: '2', payload: {}),
      );
      await tester.pump();
      expect(result, isFalse);
      expect(adapter.requests, 1);
      expect(find.text(t.common.friendConfirmResultUnknown), findsOneWidget);
      keep.close();
      container.dispose();
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
