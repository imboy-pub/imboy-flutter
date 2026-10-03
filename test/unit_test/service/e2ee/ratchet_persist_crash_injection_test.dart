/// AC-16 原子性 — ratchet 持久化失败的崩溃注入测试。
///
/// 不变量（ADR 14 §4.2 6/7 + 任务 AC-16 任务5）：
/// - **先持久化后交付**：`encryptC2CMessage` 的密文在 ratchet 状态成功落入
///   事务存储**之前**不得返回给调用方（返回即「已发送」）；
/// - **不复用危险 ratchet state**：session pickle 写失败 → 中止而非继续用
///   内存态——内存中的 ratchet 已被 `session.encrypt` 就地推进，若保留在
///   缓存，后续调用会基于「未持久化的推进态」继续（内存/磁盘分叉，重启后
///   回滚重用已消费 message key，PFS 失效）。
///
/// 注入方式：DROP 掉 `crypto_olm_sessions` 表使 `persistSession` 的 INSERT
/// 抛 DatabaseException（模拟存储层崩溃）。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/vodozemac_session_config.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

import '../../vodozemac_native_lib.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const peerUid = '200';
  const peerDid = 'b-1';

  late Database db;
  late CryptoStore store;
  final pickleKey = Uint8List.fromList(
    List<int>.generate(32, (i) => (i * 7 + 3) % 256),
  );

  Future<void> seedSession() async {
    final peerAccount = vod.Account();
    peerAccount.generateOneTimeKeys(1);
    final myAccount = vod.Account();
    final outbound = myAccount.createOutboundSession(
      identityKey: peerAccount.identityKeys.curve25519,
      oneTimeKey: peerAccount.oneTimeKeys.entries.first.value,
      config: legacyOlmSessionConfig(),
    );
    // 消费 bootstrap prekey message，使双方 ratchet 对齐
    final bootstrap = outbound.encrypt('bootstrap');
    peerAccount.createInboundSession(
      theirIdentityKey: myAccount.identityKeys.curve25519,
      preKeyMessageBase64: bootstrap.ciphertext,
      config: legacyOlmSessionConfig(),
    );
    await store.persistSession(
      peerUid: peerUid,
      peerDeviceId: peerDid,
      pickle: outbound.toPickleEncrypted(pickleKey),
    );
  }

  setUpAll(() async {
    await ensureVodozemac();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    const storageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final secureStore = <String, String>{};
    secureStore['olm_pickle_key'] = base64.encode(pickleKey);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          final args = call.arguments as Map?;
          final key = args?['key'] as String?;
          switch (call.method) {
            case 'write':
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
    OlmSessionService.to.resetForTest();
    OlmSessionService.debugMarkVodReady();
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    store = CryptoStore(db);
    await store.ensureSchema();
    SqliteService.setDbForTest(db);
    await seedSession();
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
    OlmSessionService.to.resetForTest();
  });

  test('RED→GREEN: session pickle 写失败 → 异常上抛、无密文交付、内存 ratchet 态被驱逐', () async {
    // 第一次加密：正常路径热身（session 载入内存缓存并成功持久化）
    final first = await OlmSessionService.to.encryptC2CMessage(
      peerUid: peerUid,
      peerDeviceId: peerDid,
      plaintext: '{"warm":"up"}',
    );
    expect(first.ciphertext, isNotEmpty);
    expect(
      OlmSessionService.to.debugHasCachedSession(peerUid, peerDid),
      isTrue,
    );

    // 崩溃注入前捕获两样东西：
    // 1. 最后一次**成功提交**的磁盘 ratchet 态（真实存储故障不会吞掉已提交
    //    行——存储恢复后磁盘上仍在的是这份）；
    // 2. 表的原始 DDL（恢复时按原样重建，防手写 schema 与生产漂移）。
    final lastCommittedPickle = await store.loadSession(
      peerUid: peerUid,
      peerDeviceId: peerDid,
    );
    expect(lastCommittedPickle, isNotNull, reason: 'warm-up 必须已落盘 ratchet');
    final ddlRows = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='table' AND name='crypto_olm_session'",
    );

    // 崩溃注入：DROP 会话表，使后续 persistSession 的 INSERT 失败
    await db.execute('DROP TABLE crypto_olm_session');

    // 第二次加密：session.encrypt 已推进内存 ratchet，但持久化失败
    // → 必须 fail-closed：异常上抛（调用方拿不到密文 = 不会「已发送」）
    await expectLater(
      OlmSessionService.to.encryptC2CMessage(
        peerUid: peerUid,
        peerDeviceId: peerDid,
        plaintext: '{"crash":"here"}',
      ),
      throwsA(isA<DatabaseException>()),
    );

    // 核心断言（AC-16 任务5）：已推进但未持久化的内存 ratchet 态必须被
    // 驱逐——继续使用它与磁盘分叉，重启后重用已消费 message key（PFS 失效）。
    expect(
      OlmSessionService.to.debugHasCachedSession(peerUid, peerDid),
      isFalse,
      reason: 'persist 失败后内存中的推进态 ratchet 不得驻留缓存',
    );

    // 存储恢复：按原 DDL 重建表，并回插**最后已提交**的 ratchet 态
    // （DROP 掉的只是故障窗口内的写入；此前成功提交的行在真实故障中仍在）。
    await db.execute(ddlRows.first['sql'] as String);
    await store.persistSession(
      peerUid: peerUid,
      peerDeviceId: peerDid,
      pickle: lastCommittedPickle!,
    );

    // 恢复后，下一次加密必须从**磁盘**（最后提交态）重新加载，而不是复用
    // 被驱逐前的内存推进态。
    final third = await OlmSessionService.to.encryptC2CMessage(
      peerUid: peerUid,
      peerDeviceId: peerDid,
      plaintext: '{"after":"recovery"}',
    );
    expect(third.ciphertext, isNotEmpty);
    // 重新加载后缓存恢复
    expect(
      OlmSessionService.to.debugHasCachedSession(peerUid, peerDid),
      isTrue,
    );
    // 恢复后磁盘态相对最后提交态推进（从磁盘态继续 ratchet，而非停滞）
    final recoveredPickle = await store.loadSession(
      peerUid: peerUid,
      peerDeviceId: peerDid,
    );
    expect(recoveredPickle, isNot(equals(lastCommittedPickle)));
  });

  test('正常路径顺序：密文返回前 ratchet 状态已在事务存储（先持久化后交付）', () async {
    final before = await store.loadSession(
      peerUid: peerUid,
      peerDeviceId: peerDid,
    );
    final result = await OlmSessionService.to.encryptC2CMessage(
      peerUid: peerUid,
      peerDeviceId: peerDid,
      plaintext: '{"order":"proof"}',
    );
    final after = await store.loadSession(
      peerUid: peerUid,
      peerDeviceId: peerDid,
    );

    expect(result.ciphertext, isNotEmpty);
    expect(before, isNotNull);
    expect(after, isNot(equals(before)), reason: '密文交付时磁盘 ratchet 必须已推进');
  });
}
