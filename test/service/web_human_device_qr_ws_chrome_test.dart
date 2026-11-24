@TestOn('chrome')
library;

import 'fixtures/web_qr_stable_anonymous_cases.dart' as stable_anonymous;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/page/passport/sse_client.dart';
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/service/protocol/imboy_frame.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/service/websocket.dart';
import 'package:web/web.dart' as web;

class _ApiEnv implements Env {
  @override
  String get apiBaseUrl => 'https://human-api.example.invalid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CaptureSse implements SseClient {
  final _frames = StreamController<String>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  String? lastUrl;
  bool _open = false;
  bool _closed = false;

  @override
  bool get isOpen => _open;
  @override
  Stream<String> get frames => _frames.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Future<void> connect(String url) async {
    lastUrl = url;
    _open = true;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _open = false;
    await _frames.close();
    await _errors.close();
  }
}

void main() {
  group('stable anonymous QR create', stable_anonymous.main);
  TestWidgetsFlutterBinding.ensureInitialized();
  test('self profile maps only authenticated Web GET intent', () {
    final origin = Uri.parse('http://127.0.0.1:0');
    expect(
      webHumanRequestUri('GET', Uri.parse('/api/v1/user/me'), origin).path,
      '/api/v1/web/user/me',
    );
    expect(
      () => webHumanRequestUri('POST', Uri.parse('/api/v1/user/me'), origin),
      throwsFormatException,
    );
  });
  late String? oldDid;
  late String oldEnv;
  late Map<String, Env> oldEnvMap;

  setUpAll(prepareWebWriter);
  setUp(() {
    oldDid = web.window.localStorage.getItem('web_device_id');
    oldEnv = init.currentEnv;
    oldEnvMap = Map<String, Env>.of(envMap);
  });
  tearDown(() {
    if (oldDid == null) {
      web.window.localStorage.removeItem('web_device_id');
    } else {
      web.window.localStorage.setItem('web_device_id', oldDid!);
    }
    init.currentEnv = oldEnv;
    envMap
      ..clear()
      ..addAll(oldEnvMap);
  });

  test(
    'new DID is read back and reused by the actual DeviceExt path',
    () async {
      web.window.localStorage.removeItem('web_device_id');
      final device = DeviceExt();
      final first = (await device.detail)!;
      final second = (await device.detail)!;
      expect(first['did'], isNotEmpty);
      expect(first['did'], web.window.localStorage.getItem('web_device_id'));
      expect(second['did'], first['did']);
      expect(first['deviceName'], 'Web Browser');
      expect(
        (first['deviceName'] as String).runes.length,
        lessThanOrEqualTo(80),
      );
    },
  );

  test('fresh browser IDs have independent random suffixes', () async {
    final suffixes = <String>{};
    for (var i = 0; i < 10; i++) {
      web.window.localStorage.removeItem('web_device_id');
      final did = (await DeviceExt().detail)!['did'] as String;
      expect(did, matches(RegExp(r'^web_\d+_[a-z0-9]{22}$')));
      expect(did.length, lessThanOrEqualTo(40));
      suffixes.add(did.split('_').last);
    }
    expect(suffixes, hasLength(10));
  });

  test('DID limit counts UTF8-valid code points without truncation', () async {
    final exactly128 = List.filled(128, '设').join();
    web.window.localStorage.setItem('web_device_id', exactly128);
    expect((await DeviceExt().detail)!['did'], exactly128);
    final tooLong = '$exactly128外';
    web.window.localStorage.setItem('web_device_id', tooLong);
    await expectLater(DeviceExt().detail, throwsStateError);
    expect(web.window.localStorage.getItem('web_device_id'), tooLong);
    web.window.localStorage.setItem(
      'web_device_id',
      String.fromCharCode(0xD800),
    );
    await expectLater(DeviceExt().detail, throwsStateError);
  });

  test(
    'a changed persistent DID cannot silently change an active identity',
    () async {
      web.window.localStorage.setItem('web_device_id', 'web_synthetic_first');
      final device = DeviceExt();
      expect((await device.detail)!['did'], 'web_synthetic_first');
      web.window.localStorage.setItem('web_device_id', 'web_synthetic_second');
      await expectLater(device.detail, throwsStateError);
      expect(
        web.window.localStorage.getItem('web_device_id'),
        'web_synthetic_second',
      );
    },
  );

  test('actual QR notifier passes an absolute Web alias to SSE', () async {
    init.currentEnv = 'dev';
    envMap['dev'] = _ApiEnv();
    final container = ProviderContainer();
    final fake = _CaptureSse();
    container.listen(qRLoginProvider, (_, _) {});
    final notifier = container.read(qRLoginProvider.notifier);
    notifier.sseClientBuilderForTesting = () => fake;
    try {
      notifier.startSseSession('synthetic+session/token==');
      await Future<void>.delayed(Duration.zero);
      final uri = Uri.parse(fake.lastUrl!);
      expect(uri.origin, 'https://human-api.example.invalid');
      expect(uri.path, '/api/v1/web/passport/qr_login/subscribe');
      expect(uri.queryParameters, {
        'session_token': 'synthetic+session/token==',
      });
    } finally {
      container.dispose();
      await fake.close();
    }
  });

  test('production WS protocol builder emits exactly v2 and UTF8 raw tk', () {
    const raw = 'synthetic-合成+/==';
    final protocols = webHumanSocketProtocols(raw);
    expect(protocols, hasLength(2));
    expect(protocols.first, 'imboy.v2');
    final auth = protocols.last;
    expect(auth, startsWith('imboy.auth.'));
    final encoded = auth.substring('imboy.auth.'.length);
    expect(encoded, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(utf8.decode(base64Url.decode(base64Url.normalize(encoded))), raw);
    expect(() => webHumanSocketProtocols(''), throwsStateError);
    expect(
      () => webHumanSocketProtocols('Bearer synthetic-token'),
      throwsStateError,
    );
    expect(
      webHumanSocketProtocols(List.filled(6135, 'x').join()).last.length,
      8191,
    );
    expect(
      () => webHumanSocketProtocols(List.filled(6136, 'x').join()),
      throwsStateError,
    );
  });

  test(
    'production WS URL boundary rejects alternate authentication carriers',
    () {
      const good = 'wss://human-api.example.invalid/api/v1/web/ws';
      expect(webHumanSocketUri(good).toString(), good);
      for (final bad in [
        'https://human-api.example.invalid/api/v1/web/ws',
        'wss://human-api.example.invalid/ws',
        '$good?token=synthetic',
        '$good?',
        '$good#synthetic',
        'wss://synthetic@human-api.example.invalid/api/v1/web/ws',
      ]) {
        expect(() => webHumanSocketUri(bad), throwsStateError);
      }
    },
  );

  test('existing v2 outbound codec remains the actual framing path', () {
    WebSocketService.resetForTest();
    final socket = WebSocketService.to;
    const message =
        '{"id":"synthetic-id","type":"C2C","from":"910000000001","to":"910000000002","msg_type":"text","payload":"synthetic"}';
    final result = ImboyFrame.tryDecode(
      socket.encodeV2BusinessFrameForTest(message),
    );
    expect(result, isNotNull);
    expect(result!.frame.type, FrameType.msgC2C);
    final decoded = jsonDecode(utf8.decode(result.frame.payload)) as Map;
    expect(decoded['id'], 'synthetic-id');
    WebSocketService.resetForTest();
  });
}
