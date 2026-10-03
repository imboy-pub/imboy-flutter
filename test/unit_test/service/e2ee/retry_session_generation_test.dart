/// Synthetic manual retry session-start race, no real login or transport.
library;

import 'dart:async';
import 'dart:convert';

import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/events/events.dart';

import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart' as imboy_http;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _UnexpectedTransport implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw StateError('Unexpected transport in synthetic retry fixture');
  }

  @override
  void close({bool force = false}) {}
}

const String _msgC2cDdl = '''
  CREATE TABLE msg_c2c (
    auto_id INTEGER PRIMARY KEY AUTOINCREMENT,
    id INTEGER,
    type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    payload TEXT,
    created_at INTEGER,
    is_author INTEGER,
    status INTEGER,
    conversation_uk3 TEXT,
    topic_id INTEGER,
    msg_type TEXT,
    action TEXT,
    e2ee TEXT,
    sender_did TEXT
  )
''';
const String _contactDdl = '''
  CREATE TABLE contact (
    user_id INTEGER,
    peer_id INTEGER,
    nickname TEXT,
    avatar TEXT,
    account TEXT,
    status INTEGER,
    remark TEXT,
    tag TEXT,
    region TEXT,
    sign TEXT,
    source TEXT,
    gender INTEGER,
    is_friend INTEGER,
    is_from INTEGER,
    category_id INTEGER,
    account_type TEXT,
    last_seen_at INTEGER,
    updated_at INTEGER
  )
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late _UnexpectedTransport transport;
  setUpAll(() async {
    sqfliteFfiInit();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    transport = _UnexpectedTransport();
    imboy_http.HttpClient.adapterForTest = transport;
    final encode = base64Url.encode;
    final secure = <String, String?>{
      'secure_token':
          '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.'
          '${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.'
          '${encode(utf8.encode('synthetic-signature'))}',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final key = (call.arguments as Map)['key'] as String?;
          if (call.method == 'write') {
            if (key == 'secure_token') {
              throw PlatformException(code: 'synthetic-login-stop');
            }
            secure[key!] = call.arguments['value'] as String?;
          }
          if (call.method == 'read') return secure[key];
          return null;
        });
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
  });
  tearDown(() async {
    final calls = transport.calls;
    imboy_http.HttpClient.adapterForTest = null;
    SqliteService.setDbForTest(null);
    try {
      await db.close();
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    }
    expect(calls, 0, reason: 'No unsimulated transport may run');
  });
  for (final stage in [
    'manual-normal',
    'manual-stale',
    'auto-normal',
    'auto-queued',
    'auto-inflight',
    'auto-clear',
  ]) {
    final stale = !stage.endsWith('normal');
    test('retry stage=$stage', () async {
      for (final table in ['msg_c2c', 'msg_c2g', 'msg_c2s']) {
        await db.execute(_msgC2cDdl.replaceFirst('msg_c2c', table));
      }
      await db.execute(_contactDdl);
      final retry = MessageRetry.instance;
      await retry.debugWaitForIdle();
      final sends = <WebSocketMessageSendRequestEvent>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        sends.add,
      );
      try {
        await db.insert('msg_c2c', {
          'id': 'retry-synthetic',
          'type': 'C2C',
          'from_id': 100,
          'to_id': 200,
          'payload': '',
          'created_at': 1000,
          'is_author': 1,
          'status': 41,
          'conversation_uk3': 'C2C_100_200',
          'topic_id': 0,
          'msg_type': 'text',
          'action': '',
          'e2ee': jsonEncode({'protocol': 'olm', 'ciphertext': 'synthetic'}),
        });
        Future<void> invalidateSession() async {
          final repo = UserRepoLocal.to;
          final generation = repo.sessionGeneration;
          await expectLater(
            repo.loginAfter('synthetic-session', {
              'uid': '101',
              'token': 'synthetic-access-value',
              'refreshtoken': 'synthetic-refresh-value',
            }),
            throwsA(isA<PlatformException>()),
          );
          expect(repo.sessionGeneration, generation + 1);
          expect(repo.currentUid, '100');
        }

        if (stage.startsWith('manual')) {
          final sending = retry.retryMessage('retry-synthetic', 'C2C');
          if (stale) await invalidateSession();
          expect(await sending, !stale);
        } else {
          retry.addToRetryQueue('retry-synthetic', 'C2C');
          await pumpEventQueue();
          retry.getRetryInfo('retry-synthetic')!.lastRetryTime -= 100000;
          if (stage == 'auto-queued') await invalidateSession();
          final sending = retry.retryFailedMessages();
          if (stage == 'auto-inflight') await invalidateSession();
          if (stage == 'auto-clear') retry.clearRetryQueue();
          await sending;
        }
        await pumpEventQueue();
        expect(sends, stale ? isEmpty : hasLength(1));
      } finally {
        await retry.debugWaitForIdle();
        retry.dispose();
        await sub.cancel();
      }
    });
  }
}
