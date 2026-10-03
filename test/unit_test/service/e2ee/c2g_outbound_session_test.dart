/// Synthetic C2G session-start race, no real login or transport.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart' as imboy_http;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as app_init;
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/e2ee_service.dart' show E2EEService;
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../vodozemac_native_lib.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _gid = '9900';
final _members = [
  {
    'uid': '100',
    'devices': [
      {'device_id': 'sender', 'public_key': 'synthetic-sender'},
    ],
  },
  {
    'uid': '200',
    'devices': [
      {'device_id': 'peer', 'public_key': 'synthetic-peer'},
    ],
  },
];

class _UnexpectedTransport implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw StateError('Unexpected transport in synthetic C2G fixture');
  }

  @override
  void close({bool force = false}) {}
}

class _DeferredMegolm extends MegolmProtocol {
  final observed = Completer<void>();
  final release = Completer<void>();
  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async {
    final encrypted = await super.encrypt(
      plaintext: plaintext,
      recipients: recipients,
      context: context,
    );
    observed.complete();
    await release.future;
    return encrypted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late _UnexpectedTransport transport;
  setUpAll(() async {
    await ensureVodozemac();
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
    await CryptoStore(db).ensureSchema();
    SqliteService.setDbForTest(db);
    app_init.deviceId = 'sender';
    GroupSessionService.to.clearMemory();
    GroupSessionService.to.debugHistoryGrantLoader = (gid, sid) async =>
        throw StateError('Synthetic unavailable history grant');
    GroupSessionService.debugMarkVodReady();
    E2eeBootstrap.debugMarkReadyForTest('100');
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(MegolmProtocol());
    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    await GroupSessionService.to.setGroupE2EEMode(_gid, 1);
    GroupSessionService.to.debugRoomKeySender = (chatType, to, payload) {};
    GroupSessionService.to.debugOlmWrap = (did, key) async =>
        (type: 0, body: 'synthetic-wrap');
    GroupSessionService.to.debugGroupSuiteDeviceListLoader = (uid) async => [
      {'device_id': uid == '100' ? 'sender' : 'peer'},
    ];
  });
  tearDown(() async {
    final calls = transport.calls;
    imboy_http.HttpClient.adapterForTest = null;
    GroupSessionService.to.debugHistoryGrantLoader = null;
    GroupSessionService.to.clearMemory();
    GroupSessionService.to.debugRoomKeySender = null;
    GroupSessionService.to.debugOlmWrap = null;
    GroupSessionService.to.debugGroupSuiteDeviceListLoader = null;
    E2EEService.debugGroupMemberKeysLoader = null;
    E2EEService.clearKeyCacheForTest();
    E2eeProtocolRegistry.resetForTest();
    SqliteService.setDbForTest(null);
    try {
      await db.close();
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    }
    expect(calls, 0, reason: 'No unsimulated transport may run');
  });
  for (final stage in ['normal', 'recipients', 'encrypted']) {
    final stale = stage != 'normal';
    test(
      'C2G $stage ${stale ? "rejects old session" : "normal encrypts"}',
      () async {
        final deferred = _DeferredMegolm();
        if (stage == 'encrypted') {
          E2eeProtocolRegistry.resetForTest();
          E2eeProtocolRegistry.register(deferred);
        }
        final observed = Completer<void>();
        final pending = Completer<List<Map<String, dynamic>>>();
        E2EEService.debugGroupMemberKeysLoader = (gid) async {
          if (stage == 'encrypted') return _members;
          if (!observed.isCompleted) {
            observed.complete();
            return pending.future;
          }
          return _members;
        };
        final send = ChatNetworkService().encryptPayload(
          chatType: 'C2G',
          toId: _gid,
          plaintextMap: const {
            'msg_type': 'text',
            'body': 'synthetic-group-canary',
          },
          action: '',
          messageId: 'c2g-session-$stale',
          messageType: 'text',
        );
        await (stage == 'encrypted'
                ? deferred.observed.future
                : observed.future)
            .timeout(const Duration(seconds: 3));
        if (stale) {
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
          final rejected = expectLater(
            send,
            throwsA(
              isA<E2eeSecurityException>().having(
                (e) => e.toString(),
                'code',
                contains('outbound_session_changed'),
              ),
            ),
          );
          if (stage == 'encrypted') {
            deferred.release.complete();
          } else {
            pending.complete(_members);
          }
          await rejected;
        } else {
          pending.complete(_members);
          final result = await send;
          expect(result, isNotNull);
          final envelope = result!['e2ee'] as Map;
          expect(envelope['meta_version'], 3);
          expect(envelope['ciphertext'], isNotEmpty);
          expect((envelope['protocol_metadata'] as Map)['protocol'], 'megolm');
        }
      },
    );
  }
}
