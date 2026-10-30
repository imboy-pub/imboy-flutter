/// AC-16 — C2C own-device fan-out：发送者给自己的每个其他设备发独立密文。
///
/// 现状缺口（RED 证据）：`_encryptC2COlmFanOut` 只向**对端** uid 的设备
/// fan-out；发送者的其他设备靠服务端 echo 收到副本，但在
/// `e2ee.devices` 里找不到自己的信封 → `fan_out_missing_devices` →
/// 不可恢复占位（isUnrecoverableDecryptFailure），多端消息不可读。
///
/// 本文件用真实 vodozemac + 播种 session pickle（olm_pfs_production_path
/// 同款基建）驱动**生产链** `ChatNetworkService.encryptPayload`：
/// 1. self 其他设备进入 fan-out 且产出**独立**密文（与 peer 设备互不相同）；
/// 2. 当前设备不进入 fan-out（本地已有明文行，无需密文副本）；
/// 3. peer 与 self 各目标信封**各自可解**（inbound session 解出同一 payload）；
/// 4. 缺钥设备（Olm 列表在、claim 瞬态失败）→ 明确跳过（元数据记录），
///    不阻塞其他设备；密文仍先持久化 outbox 再交付。
library;

import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart'
    show DioException, HttpClientAdapter, RequestOptions, ResponseBody;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart' as app_init;
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/e2ee/capability_guard.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/protected_frame_v3.dart' show CanonicalCbor;
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/component/http/http_client.dart' show HttpClient;
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../vodozemac_native_lib.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// claim 连接层失败 adapter：模拟离线设备 claim 不上 OTK 的瞬态网络错误
/// （避免测试环境真实网络请求触发 token 过期登出等副作用）。
class _ClaimConnFailAdapter implements HttpClientAdapter {
  final requests = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'connection refused (test)',
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const myUid = '100';
  const peerUid = '200';
  const myDid = 'a-1';
  const selfOtherDid = 'a-2';
  const peerDid = 'b-1';

  late Database db;
  late vod.Account senderAccount;
  final Map<String, vod.Session> targetInbound = {};

  /// 为 sender→target 建立双向会话并把 outbound pickle 播种进 CryptoStore
  /// （OlmSessionService 生产路径随后 _loadSession 命中，不再走网络 claim）。
  Future<void> seedSession(String targetUid, String targetDid) async {
    final target = vod.Account();
    target.generateOneTimeKeys(1);
    final otk = target.oneTimeKeys.entries.first.value;

    final outbound = senderAccount.createOutboundSession(
      identityKey: target.identityKeys.curve25519,
      oneTimeKey: otk,
      config: legacyOlmSessionConfig(),
    );
    // 对端用首条 prekey message 建立 inbound（消费掉 bootstrap 消息）
    final bootstrap = outbound.encrypt('bootstrap');
    final inboundResult = target.createInboundSession(
      theirIdentityKey: senderAccount.identityKeys.curve25519,
      preKeyMessageBase64: bootstrap.ciphertext,
      config: legacyOlmSessionConfig(),
    );
    // inboundResult.session 已解出 bootstrap 明文；保留该 session 供断言解密
    targetInbound['$targetUid:$targetDid'] = inboundResult.session;

    final pickleKey = Uint8List.fromList(
      List<int>.generate(32, (i) => (i * 7 + 3) % 256),
    );
    await CryptoStore(db).persistSession(
      peerUid: targetUid,
      peerDeviceId: targetDid,
      pickle: outbound.toPickleEncrypted(pickleKey),
    );
  }

  setUpAll(() async {
    await ensureVodozemac();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, myUid);

    // pickleKey 与 OlmSessionService._pickleKeyStorageKey 一致
    const storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final secureStore = <String, String>{};
    secureStore['olm_pickle_key'] = base64.encode(
      List<int>.generate(32, (i) => (i * 7 + 3) % 256),
    );
    // 有效未过期 JWT：claimKey 前置的 _setDefaultConfig 会因「已登录但
    // token 为空」触发 _handleTokenExpired→quitLogin（清库），必须避免。
    secureStore['secure_token'] =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjQxMDI0NDQ4MDB9.sig';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = call.arguments as Map?;
          final key = args?['key'] as String?;
          switch (call.method) {
            case 'write':
              if (key == 'secure_token') {
                throw PlatformException(code: 'synthetic-login-commit-stop');
              }
              if (key != null) {
                secureStore[key] = args?['value']?.toString() ?? '';
              }
              return null;
            case 'read':
              return secureStore[key];
            case 'delete':
              secureStore.remove(key);
              return null;
          }
          return null;
        });
  });

  setUp(() async {
    app_init.deviceId = myDid;
    senderAccount = vod.Account();
    targetInbound.clear();
    OlmSessionService.to.resetForTest();
    OlmSessionService.debugMarkVodReady(); // 测试进程已自行 vod.init(libraryPath)
    db = await openFixtureDatabaseAtVersion(version: 32);
    await CryptoStore(db).ensureSchema();
    SqliteService.setDbForTest(db);

    EncryptionModeService.debugSet(
      mode: EncryptionMode.strictE2ee,
      initialized: true,
    );
    E2eeBootstrap.debugMarkReadyForTest(myUid);
    E2EEService.clearKeyCacheForTest();

    await seedSession(peerUid, peerDid);
    await seedSession(myUid, selfOtherDid);
  });

  tearDown(() async {
    HttpClient.adapterForTest = null;
    E2EEService.debugOlmDeviceListLoader = null;
    E2EEService.clearKeyCacheForTest();
    SqliteService.setDbForTest(null);
    await db.close();
    OlmSessionService.to.resetForTest();
  });

  Map<String, dynamic> envelopeFor(Map<String, dynamic> e2ee, String did) =>
      (e2ee['devices'] as Map)[did] as Map<String, dynamic>;

  test('AC-16: self 其他设备进入 fan-out，密文独立且与 peer 设备互不相同', () async {
    final anomalies = <E2eeDeviceSetAnomalyEvent>[];
    final subscription = AppEventBus.on<E2eeDeviceSetAnomalyEvent>().listen(
      anomalies.add,
    );
    addTearDown(subscription.cancel);
    E2EEService.setUserDeviceKeyCacheForTest(peerUid, {peerDid: 'PEM-B1'});
    E2EEService.setUserDeviceKeyCacheForTest(myUid, {
      myDid: 'PEM-A1',
      selfOtherDid: 'PEM-A2',
    });
    E2EEService.debugOlmDeviceListLoader = (uid) async => uid == peerUid
        ? [
            {'device_id': peerDid},
          ]
        : [
            {'device_id': myDid},
            {'device_id': selfOtherDid},
          ];

    final result = await ChatNetworkService().encryptPayload(
      chatType: 'C2C',
      toId: peerUid,
      plaintextMap: const {'msg_type': 'text', 'body': 'own-device hello'},
      action: '',
      messageId: 'msg-ac16-001',
      messageType: 'text',
    );

    await pumpEventQueue();
    expect(
      anomalies,
      isEmpty,
      reason:
          'Current sender is intentionally excluded from ciphertext targets',
    );
    expect(result, isNotNull);
    final e2ee = result!['e2ee'] as Map<String, dynamic>;
    expect(e2ee['fan_out'], 'per_device');
    final devices = (e2ee['devices'] as Map).cast<String, dynamic>();
    expect(devices.keys, contains(peerDid), reason: '对端设备必须收到密文');
    expect(
      devices.keys,
      contains(selfOtherDid),
      reason: '发送者的其他设备必须收到独立密文（own-device fan-out）',
    );
    expect(devices.keys, isNot(contains(myDid)), reason: '当前设备本地已有明文行，不需要密文副本');

    final peerEnvelope = envelopeFor(e2ee, peerDid);
    final selfEnvelope = envelopeFor(e2ee, selfOtherDid);
    expect(
      peerEnvelope['ciphertext'],
      isNot(equals(selfEnvelope['ciphertext'])),
      reason: '不同目标设备的密文必须互不相同（独立 Olm 会话）',
    );

    // 密文先持久化 outbox（AC-16 原子性：不发未持久密文）
    final pending = await CryptoStore(db).pendingOutbox();
    expect(pending, isNotEmpty);
  });

  test('加密编辑 outbox 保留与发送载荷一致的路由元数据', () async {
    E2EEService.setUserDeviceKeyCacheForTest(peerUid, {peerDid: 'PEM-B1'});
    E2EEService.setUserDeviceKeyCacheForTest(myUid, {
      myDid: 'PEM-A1',
      selfOtherDid: 'PEM-A2',
    });
    E2EEService.debugOlmDeviceListLoader = (uid) async => [
      {'device_id': uid == peerUid ? peerDid : selfOtherDid},
    ];

    final result = await ChatNetworkService().encryptPayload(
      chatType: 'C2C',
      toId: peerUid,
      plaintextMap: const {
        'original_msg_id': 'original-edit-id',
        'content': 'synthetic edit',
      },
      action: 'message_edit',
      messageId: 'msg-edit-outbox',
      messageType: 'text',
    );
    final stored = await CryptoStore(db).getOutboxEntry('msg-edit-outbox');
    final saved = jsonDecode(stored!['payload'] as String);
    expect(saved, equals(result));
    expect(saved['e2ee']['edit_of'], 'original-edit-id');
    expect(saved['e2ee']['relay_action'], 'message_edit');
    final senderEcho = await E2EEService.decryptIncomingPayload(
      payload: {
        'id': 'msg-edit-outbox',
        'type': 'C2C',
        'from': myUid,
        'to': peerUid,
        'action': 'message_edit',
        ...result!,
      },
    );
    expect(senderEcho['_e2ee_failed'], isTrue);
    expect(senderEcho['_e2ee_reason'], 'no_device_envelope');
  });

  test('AC-16: peer 与 self 各目标信封各自可解出同一 payload', () async {
    E2EEService.setUserDeviceKeyCacheForTest(peerUid, {peerDid: 'PEM-B1'});
    E2EEService.setUserDeviceKeyCacheForTest(myUid, {
      myDid: 'PEM-A1',
      selfOtherDid: 'PEM-A2',
    });
    E2EEService.debugOlmDeviceListLoader = (uid) async => [
      {'device_id': uid == peerUid ? peerDid : selfOtherDid},
    ];

    final result = await ChatNetworkService().encryptPayload(
      chatType: 'C2C',
      toId: peerUid,
      plaintextMap: const {'msg_type': 'text', 'body': 'decrypt me'},
      action: '',
      messageId: 'msg-ac16-002',
      messageType: 'text',
    );
    final e2ee = (result!['e2ee'] as Map).cast<String, dynamic>();

    Future<Map<String, dynamic>> decryptWith(String targetKey) async {
      final did = targetKey.split(':')[1];
      final envelope = envelopeFor(e2ee, did);
      final metadata = (envelope['protocol_metadata'] as Map)
          .cast<String, dynamic>();
      // outer envelope ciphertext = base64url(utf8(protocol ciphertext))，
      // protocol ciphertext 即 Olm wire 密文字符串（PFv3 §3.3）。
      final olmCiphertext = utf8.decode(
        base64Url.decode(envelope['ciphertext'] as String),
      );
      final olmPlaintext = targetInbound[targetKey]!.decrypt(
        messageType: metadata['message_type'] as int,
        ciphertext: olmCiphertext,
      );
      // olmPlaintext 是 inner_frame 的 base64url（PFv3）；解码得 canonical CBOR
      final inner = CanonicalCbor.decode(
        Uint8List.fromList(base64Url.decode(olmPlaintext)),
      ) as Map<String, dynamic>;
      return (inner['payload'] as Map).cast<String, dynamic>();
    }

    final peerPayload = await decryptWith('$peerUid:$peerDid');
    final selfPayload = await decryptWith('$myUid:$selfOtherDid');
    expect(peerPayload['body'], 'decrypt me');
    expect(selfPayload['body'], 'decrypt me');
  });

  test('AC-16: 缺钥设备（瞬态 claim 失败）明确跳过，不阻塞其他设备', () async {
    // b-offline 在 userKeys 与 Olm 列表中（能力合规），但无播种 session，
    // claim 由测试适配器模拟瞬态失败，必须被明确跳过。
    const offlineDid = 'b-offline';
    E2EEService.setUserDeviceKeyCacheForTest(peerUid, {
      peerDid: 'PEM-B1',
      offlineDid: 'PEM-BOFF',
    });
    E2EEService.setUserDeviceKeyCacheForTest(myUid, {
      myDid: 'PEM-A1',
      selfOtherDid: 'PEM-A2',
    });
    E2EEService.debugOlmDeviceListLoader = (uid) async => [
      {'device_id': peerDid},
      {'device_id': offlineDid},
      {'device_id': selfOtherDid},
    ];
    final adapter = _ClaimConnFailAdapter();
    HttpClient.adapterForTest = adapter;

    final result = await ChatNetworkService().encryptPayload(
      chatType: 'C2C',
      toId: peerUid,
      plaintextMap: const {'msg_type': 'text', 'body': 'skip offline'},
      action: '',
      messageId: 'msg-ac16-003',
      messageType: 'text',
    );

    expect(adapter.requests, isNotEmpty);
    expect(
      adapter.requests.every((uri) => uri.path == '/api/v1/e2ee/olm/claim'),
      isTrue,
    );

    // 其他设备正常投递
    expect(result, isNotNull);
    final e2ee = (result!['e2ee'] as Map).cast<String, dynamic>();
    final devices = (e2ee['devices'] as Map).cast<String, dynamic>();
    expect(devices.keys, containsAll([peerDid, selfOtherDid]));

    // 缺钥设备被**显式**记录（不静默消失）：fan-out 元数据带 skipped_devices
    final skipped = e2ee['skipped_devices'];
    expect(skipped, isA<Map<dynamic, dynamic>>(), reason: '跳过必须显式记录，不得静默');
    expect(skipped.keys, contains(offlineDid));

    // AC-16 补投策略：跳过只对本条消息生效——设备恢复（会话可达）后，
    // 下一条消息的 fan-out 重新包含它，投递收敛；skipped_devices 不再出现。
    await seedSession(peerUid, offlineDid);
    final retryResult = await ChatNetworkService().encryptPayload(
      chatType: 'C2C',
      toId: peerUid,
      plaintextMap: const {'msg_type': 'text', 'body': 're-deliver'},
      action: '',
      messageId: 'msg-ac16-004',
      messageType: 'text',
    );
    final retryE2ee = (retryResult!['e2ee'] as Map).cast<String, dynamic>();
    final retryDevices = (retryE2ee['devices'] as Map).cast<String, dynamic>();
    expect(
      retryDevices.keys,
      contains(offlineDid),
      reason: '会话可达后，先前跳过的设备必须重新收到密文（补投收敛）',
    );
    expect(
      retryE2ee.containsKey('skipped_devices'),
      isFalse,
      reason: '全部目标可达时不再有 skipped_devices 记录',
    );
  });
  for (final includeCurrentDevice in [false, true]) {
    test(
      'cached self session absent from active Olm directory rejects before outbox (current=$includeCurrentDevice)',
      () async {
        E2EEService.setUserDeviceKeyCacheForTest(peerUid, {peerDid: 'PEM-B1'});
        E2EEService.setUserDeviceKeyCacheForTest(myUid, {
          myDid: 'PEM-A1',
          selfOtherDid: 'PEM-A2',
        });
        E2EEService.debugOlmDeviceListLoader = (uid) async => uid == peerUid
            ? [
                {'device_id': peerDid},
              ]
            : includeCurrentDevice
            ? [
                {'device_id': myDid},
              ]
            : [];
        final messageId = 'self-directory-reject-$includeCurrentDevice';
        await expectLater(
          ChatNetworkService().encryptPayload(
            chatType: 'C2C',
            toId: peerUid,
            plaintextMap: const {
              'msg_type': 'text',
              'body': 'synthetic directory canary',
            },
            action: '',
            messageId: messageId,
            messageType: 'text',
          ),
          throwsA(isA<FixedSuiteIncompatibleException>()),
        );
        expect(await CryptoStore(db).getOutboxEntry(messageId), isNull);
      },
    );
  }
  for (final pendingUid in [peerUid, myUid]) {
    test(
      'session generation changes during directory query ($pendingUid) rejects old send',
      () async {
        E2EEService.setUserDeviceKeyCacheForTest(peerUid, {peerDid: 'PEM-B1'});
        E2EEService.setUserDeviceKeyCacheForTest(myUid, {
          myDid: 'PEM-A1',
          selfOtherDid: 'PEM-A2',
        });
        final pending = Completer<List<Map<String, dynamic>>>();
        final observed = Completer<void>();
        E2EEService.debugOlmDeviceListLoader = (uid) async {
          if (uid == pendingUid) {
            observed.complete();
            return pending.future;
          }
          return [
            {'device_id': uid == peerUid ? peerDid : selfOtherDid},
          ];
        };
        final messageId = 'stale-send-directory-$pendingUid';
        final send = ChatNetworkService().encryptPayload(
          chatType: 'C2C',
          toId: peerUid,
          plaintextMap: const {
            'msg_type': 'text',
            'body': 'synthetic old-session canary',
          },
          action: '',
          messageId: messageId,
          messageType: 'text',
        );
        await observed.future.timeout(const Duration(seconds: 3));
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
        expect(repo.currentUid, myUid);
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
        pending.complete([
          {'device_id': pendingUid == peerUid ? peerDid : selfOtherDid},
        ]);
        await rejected;
        expect(await CryptoStore(db).getOutboxEntry(messageId), isNull);
      },
    );
  }
}
