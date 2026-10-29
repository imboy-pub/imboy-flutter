import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ResultAdapter implements HttpClientAdapter {
  _ResultAdapter(this.peer);
  final String peer;
  RequestOptions? request;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"code":0,"msg":"success","payload":{"message_id":"m-1",'
      '"chat_type":"c2c","peer_id":$peer,"state":"committed",'
      '"conv_seq":17,"other":9007199254740993}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
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
  });

  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  test('raw result binds exact peer and rejects adjacent identity', () async {
    final adapter = _ResultAdapter('9007199254740993');
    HttpClient.adapterForTest = adapter;
    final api = MsgApi();
    expect(
      await api.isCommitted(
        chatType: 'c2c',
        peerId: '9007199254740993',
        messageId: 'm-1',
      ),
      isTrue,
    );
    expect(adapter.request!.queryParameters['peer_id'], '9007199254740993');
    expect(
      await api.isCommitted(
        chatType: 'c2c',
        peerId: '9007199254740992',
        messageId: 'm-1',
      ),
      isFalse,
    );
  });

  test(
    'only peer_id is rewritten; sequence and other values keep JSON types',
    () {
      final payload =
          jsonDecode(
                rewriteChannelIds(
                  '{"payload":{"peer_id":9007199254740993,"conv_seq":17,"other":23}}',
                  ChannelResponseShape.messageResult,
                ),
              )['payload']
              as Map;
      expect(payload['peer_id'], '9007199254740993');
      expect(payload['conv_seq'], 17);
      expect(payload['other'], 23);
    },
  );
}
