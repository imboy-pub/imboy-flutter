@TestOn('chrome')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../env_test_pin.dart';

const exactUid = '9007199254740993';
const wire =
    '{"code":0,"payload":{"uid":9007199254740993,'
    '"user_id":9007199254740993,"status":1,"role":7,'
    '"nested":{"uid":12},"text":"9007199254740993"}}';

class _LoginAdapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      wire,
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
    SharedPreferences.setMockInitialValues({Keys.currentUid: ''});
    await StorageService.init();
  });
  test('production Web login control preserves raw identity fields', () async {
    final original = jsonDecode(wire) as Map<String, dynamic>;
    expect(original['payload']['uid'].toString(), isNot(exactUid));
    final client = HttpClient(
      conf: HttpConfig(baseUrl: 'http://127.0.0.1:9800'),
      retryEnabled: false,
    );
    // Only the transport is fake; the production request interceptor, Dio
    // transformer, and response parsing are exercised in Chrome.
    final adapter = _LoginAdapter();
    client.dio.httpClientAdapter = adapter;
    try {
      for (final body in [
        {'type': 'account', 'account': 'synthetic', 'pwd': 'synthetic'},
        {'type': 'account', 'account': 'synthetic', 'pwd': 'retry'},
        {'type': 'email', 'account': 'synthetic', 'code': 'synthetic'},
      ]) {
        final response = await client.post(API.login, data: body);
        expect(response.ok, isTrue);
        final payload = response.payload as Map<String, dynamic>;
        expect(payload['uid'], exactUid);
        expect(payload['user_id'], exactUid);
        expect(payload['status'], 1);
        expect(payload['role'], 7);
        expect(payload['nested']['uid'], 12);
        expect(payload['text'], exactUid);
      }
      expect(adapter.paths, List.filled(3, '/api/v1/web/passport/login'));
    } finally {
      client.dio.close(force: true);
    }
  });
}
