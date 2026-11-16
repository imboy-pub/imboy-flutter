@TestOn('chrome')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../env_test_pin.dart';

const _id = '9007199254740993';
const _mine =
    '{"code":0,"payload":{"list":[{"conversation_id":9007199254740993,"conversation_type":"c2c","server_ts":42,"nested":{"conversation_id":5}}]}}';
const _pinned =
    '{"code":0,"payload":{"items":[{"conversation_id":9007199254740993,"conversation_type":"c2g","server_ts":43}]}}';

class _Adapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      options.uri.path.endsWith('/pinned') ? _pinned : _mine,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    pinLoopbackTestEnv();
    await prepareWebWriter();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '2'});
    await StorageService.init();
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    FlutterSecureStorage.setMockInitialValues({
      'secure_token':
          '${part({'alg': 'none'})}.${part({'exp': 4102444800})}.${part('synthetic')}',
    });
  });
  test(
    'production ConversationApi decodes exact mine and pinned IDs',
    () async {
      expect(
        (jsonDecode(_mine) as Map)['payload']['list'][0]['conversation_id']
            .toString(),
        isNot(_id),
      );
      final api = ConversationApi();
      final adapter = _Adapter();
      api.dio.httpClientAdapter = adapter;
      try {
        final mine = await api.listMine();
        final pinned = await api.pinnedList();
        expect(mine.single['conversation_id'], _id);
        expect(mine.single['server_ts'], 42);
        expect(mine.single['nested']['conversation_id'], 5);
        expect(pinned.single['conversation_id'], _id);
        expect(pinned.single['server_ts'], 43);
        expect(adapter.paths, [
          '/api/v1/web/conversation/mine',
          '/api/v1/web/conversation/pinned',
        ]);
      } finally {
        api.dio.close(force: true);
      }
    },
  );
}
