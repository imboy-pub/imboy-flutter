import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart' as imboy;
import 'package:imboy/component/http/http_exceptions.dart' as errors;
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({this.body, this.networkFailure = false, this.statusCode = 200});

  final String? body;
  final bool networkFailure;
  final int statusCode;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (networkFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: const SocketException('synthetic network failure'),
      );
    }
    return ResponseBody.fromString(
      body!,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<List<ChannelModel>> _load(ChannelApi api, bool search) =>
    search ? api.searchChannels('synthetic') : api.discoverChannels();

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
  });

  tearDown(() {
    imboy.HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  for (final search in [true, false]) {
    final endpoint = search ? 'search' : 'discover';
    final path = '/api/v1/channels/$endpoint';

    test('$endpoint preserves a transport NetworkException', () async {
      final adapter = _Adapter(networkFailure: true);
      imboy.HttpClient.adapterForTest = adapter;
      await expectLater(
        _load(ChannelApi(), search),
        throwsA(isA<errors.NetworkException>()),
      );
      expect(adapter.requests.single.path, path);
    });

    test('$endpoint preserves the business error and code', () async {
      final adapter = _Adapter(
        body: '{"code":1234,"msg":"synthetic failure","payload":null}',
      );
      imboy.HttpClient.adapterForTest = adapter;
      await expectLater(
        _load(ChannelApi(), search),
        throwsA(
          isA<errors.BadRequestException>()
              .having((e) => e.code, 'code', 1234)
              .having((e) => e.message, 'message', 'synthetic failure'),
        ),
      );
      expect(adapter.requests.single.path, path);
    });

    test('$endpoint preserves an HTTP server failure', () async {
      final adapter = _Adapter(
        statusCode: 503,
        body: '{"code":503,"msg":"synthetic unavailable","payload":null}',
      );
      imboy.HttpClient.adapterForTest = adapter;
      await expectLater(
        _load(ChannelApi(), search),
        throwsA(
          isA<errors.BadRequestException>()
              .having((e) => e.code, 'code', 503)
              .having((e) => e.message, 'message', 'synthetic unavailable'),
        ),
      );
      expect(adapter.requests.single.path, path);
    });

    test('$endpoint returns an empty list for a valid empty result', () async {
      final adapter = _Adapter(
        body: '{"code":0,"msg":"success","payload":{"list":[],"total":0}}',
      );
      imboy.HttpClient.adapterForTest = adapter;
      expect(await _load(ChannelApi(), search), isEmpty);
      expect(adapter.requests.single.path, path);
    });

    for (final payload in [
      'null',
      '{}',
      '{"list":null}',
      '{"list":{}}',
      '[]',
    ]) {
      test('$endpoint rejects invalid list payload $payload', () async {
        final adapter = _Adapter(
          body: '{"code":0,"msg":"success","payload":$payload}',
        );
        imboy.HttpClient.adapterForTest = adapter;
        await expectLater(
          _load(ChannelApi(), search),
          throwsA(isA<FormatException>()),
        );
        expect(adapter.requests.single.path, path);
      });
    }

    test('$endpoint rejects an invalid list row', () async {
      final adapter = _Adapter(
        body: '{"code":0,"msg":"success","payload":{"list":[42]}}',
      );
      imboy.HttpClient.adapterForTest = adapter;
      await expectLater(
        _load(ChannelApi(), search),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'invalid channel list row',
          ),
        ),
      );
      expect(adapter.requests.single.path, path);
    });
  }
}
