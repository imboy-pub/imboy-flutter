import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';

import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_retry_interceptor.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingApi extends ChannelApi {
  _CapturingApi([this.response]);
  final Future<IMBoyHttpResponse>? response;
  late Options sent;
  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    sent = options!;
    return response ?? IMBoyHttpResponse.success(<String, dynamic>{});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '1001');
  });
  testWidgets('旧账号失败不显示，当前账号失败仍显示原因', (tester) async {
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const Scaffold()),
    );
    final oldResponse = Completer<IMBoyHttpResponse>();
    final oldApi = _CapturingApi(oldResponse.future);
    final oldRequest = oldApi.subscribe('10');
    await StorageService.to.setString(Keys.currentUid, '1002');
    oldResponse.complete(
      IMBoyHttpResponse.failure(errCode: 403, errMsg: '旧账号错误'),
    );
    expect(await oldRequest, isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('旧账号错误'), findsNothing);
    final currentApi = _CapturingApi(
      Future.value(IMBoyHttpResponse.failure(errCode: 403, errMsg: '当前账号错误')),
    );
    expect(await currentApi.unsubscribe('10'), isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('当前账号错误'), findsOneWidget);
  });
  for (final subscribing in [true, false]) {
    test('频道${subscribing ? '订阅' : '退订'}不自动重试且切号后阻止发送', () async {
      io.HttpOverrides.global = null;
      final api = _CapturingApi();
      if (subscribing) {
        expect(await api.subscribe('10'), isTrue);
      } else {
        expect(await api.unsubscribe('10'), isTrue);
      }
      expect(api.sent.extra![httpNoAutoRetry], isTrue);
      final server = await io.HttpServer.bind(
        io.InternetAddress.loopbackIPv4,
        0,
      );
      var requests = 0;
      final serving = () async {
        await for (final _ in server) {
          requests++;
          // Leave the response open to induce an actual receive timeout.
        }
      }();
      final dio = Dio(
        BaseOptions(receiveTimeout: const Duration(milliseconds: 100)),
      );
      final retry = HttpRetryInterceptor(
        maxRetries: 1,
        retryInterval: Duration.zero,
        exponentialBackoff: false,
      );
      retry.bindDio(dio);
      dio.interceptors.add(retry);
      dio.interceptors.add(HttpRequestGuardInterceptor());
      final url = 'http://127.0.0.1:${server.port}/channel';
      try {
        await expectLater(
          dio.post<dynamic>(url, options: api.sent),
          throwsA(isA<DioException>()),
        );
        expect(requests, 1);
        await StorageService.to.setString(Keys.currentUid, '1002');
        await expectLater(
          dio.post<dynamic>(url, options: api.sent),
          throwsA(isA<DioException>()),
        );
        expect(requests, 1);
      } finally {
        dio.close(force: true);
        await server.close(force: true);
        await serving;
      }
    });
  }
}
