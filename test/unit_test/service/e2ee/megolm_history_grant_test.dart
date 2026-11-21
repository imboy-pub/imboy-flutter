import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/vodozemac_init.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../../vodozemac_native_lib.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final store = <String, String?>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              store[call.arguments['key'] as String] =
                  call.arguments['value'] as String?;
              return null;
            case 'read':
              return store[call.arguments['key'] as String];
            case 'delete':
              store.remove(call.arguments['key'] as String);
              return null;
            case 'readAll':
              return Map<String, String?>.from(store);
          }
          return null;
        });
  });

  setUp(() {
    store.clear();
    E2eeBootstrap.resetForTest();
    GroupSessionService.to.clearMemory();
    GroupSessionService.to.debugHistoryGrantLoader = null;
  });

  tearDown(() {
    E2eeBootstrap.resetForTest();
    GroupSessionService.to.clearMemory();
    GroupSessionService.to.debugHistoryGrantLoader = null;
  });

  test('room key 只保存后端返回的权威 grant', () async {
    GroupSessionService.to.debugHistoryGrantLoader = (gid, sessionId) async {
      expect(gid, '100');
      expect(sessionId, 'session-a');
      return const E2EEGroupHistoryGrant(
        gid: '100',
        sessionId: 'session-a',
        generationNo: 3,
        startSeq: 900,
        endSeq: 950,
      );
    };

    await GroupSessionService.to.debugStoreAuthoritativeHistoryGrant(
      '100',
      'session-a',
    );

    final raw = store['megolm_history_grant_100:session-a'];
    final grant = MegolmHistoryGrant.parse(
      raw,
      expectedScope: '100',
      expectedSessionId: 'session-a',
    );
    expect(grant, isNotNull);
    expect(grant!.generationNo, 3);
    expect(grant.startSeq, 900);
    expect(grant.endSeq, 950);
  });

  test('非正 gid 不请求或保存历史授权', () async {
    GroupSessionService.to.debugHistoryGrantLoader = (_, _) async =>
        throw StateError('非正 gid 不应请求后端');

    await GroupSessionService.to.debugStoreAuthoritativeHistoryGrant(
      '0',
      'session-a',
    );
    await GroupSessionService.to.debugStoreAuthoritativeHistoryGrant(
      '-1',
      'session-b',
    );

    expect(
      store.keys.where((key) => key.startsWith(kMegolmHistoryGrantPrefix)),
      isEmpty,
    );
  });

  test('恢复 session 缺 conv_seq 或超出 grant 范围时 fail-closed', () async {
    const grant = MegolmHistoryGrant(
      scope: '100',
      sessionId: 'session-a',
      generationNo: 2,
      startSeq: 481,
      endSeq: 500,
    );
    store['megolm_restored_history_grant_100:session-a'] = jsonEncode(
      grant.toJson(),
    );

    await GroupSessionService.to.debugEnforceRestoredHistoryGrant(
      '100',
      'session-a',
      481,
    );
    await GroupSessionService.to.debugEnforceRestoredHistoryGrant(
      '100',
      'session-a',
      500,
    );
    GroupSessionService.to.debugHistoryGrantLoader = (_, _) async =>
        throw StateError('forbidden');
    for (final convSeq in <int?>[null, 480, 501]) {
      await expectLater(
        GroupSessionService.to.debugEnforceRestoredHistoryGrant(
          '100',
          'session-a',
          convSeq,
        ),
        throwsA(isA<StateError>()),
      );
    }
  });

  test('同 generation 与 start 的有限 grant 可在线延展 end_seq', () async {
    const grant = MegolmHistoryGrant(
      scope: '100',
      sessionId: 'session-a',
      generationNo: 2,
      startSeq: 481,
      endSeq: 500,
    );
    store['megolm_restored_history_grant_100:session-a'] = jsonEncode(
      grant.toJson(),
    );
    var loaderCalls = 0;
    GroupSessionService.to.debugHistoryGrantLoader = (gid, sessionId) async {
      loaderCalls++;
      return E2EEGroupHistoryGrant(
        gid: gid,
        sessionId: sessionId,
        generationNo: 2,
        startSeq: 481,
        endSeq: 520,
      );
    };

    await GroupSessionService.to.debugEnforceRestoredHistoryGrant(
      '100',
      'session-a',
      501,
    );
    await GroupSessionService.to.debugEnforceRestoredHistoryGrant(
      '100',
      'session-a',
      520,
    );

    expect(loaderCalls, 1);
    for (final prefix in [
      kMegolmRestoredGrantPrefix,
      kMegolmHistoryGrantPrefix,
    ]) {
      final refreshed = MegolmHistoryGrant.parse(
        store['${prefix}100:session-a'],
        expectedScope: '100',
        expectedSessionId: 'session-a',
      );
      expect(refreshed?.endSeq, 520);
    }
  });

  test('generation 或 start 改变时拒绝延展恢复 grant', () async {
    for (final remote in const [
      E2EEGroupHistoryGrant(
        gid: '100',
        sessionId: 'session-a',
        generationNo: 3,
        startSeq: 481,
        endSeq: 520,
      ),
      E2EEGroupHistoryGrant(
        gid: '100',
        sessionId: 'session-a',
        generationNo: 2,
        startSeq: 482,
        endSeq: 520,
      ),
    ]) {
      GroupSessionService.to.clearMemory();
      const grant = MegolmHistoryGrant(
        scope: '100',
        sessionId: 'session-a',
        generationNo: 2,
        startSeq: 481,
        endSeq: 500,
      );
      final encoded = jsonEncode(grant.toJson());
      store['megolm_restored_history_grant_100:session-a'] = encoded;
      GroupSessionService.to.debugHistoryGrantLoader = (_, _) async => remote;

      await expectLater(
        GroupSessionService.to.debugEnforceRestoredHistoryGrant(
          '100',
          'session-a',
          501,
        ),
        throwsA(isA<StateError>()),
      );
      expect(store['megolm_restored_history_grant_100:session-a'], encoded);
    }
  });

  test('实时 session 没有恢复 marker 时维持现有解密边界', () async {
    await GroupSessionService.to.debugEnforceRestoredHistoryGrant(
      '100',
      'live-session',
      null,
    );
  });

  test('可信 conv_seq 贯穿解密链并覆盖 e2ee 元数据中的伪造范围', () async {
    if (!hasVodozemacTestLib()) {
      markTestSkipped('vodozemac 测试原生库缺失');
      return;
    }
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    // Exercise the real secure-storage restore without a SQLCipher plugin.
    SqliteService.setDbUnavailableForTest();
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
    });
    await ensureVodozemac();
    GroupSessionService.debugMarkVodReady();
    // Skip unrelated device/Olm registration; Megolm import/decrypt stays native.
    E2eeBootstrap.debugMarkReadyForTest('100');

    final outbound = vod.GroupSession();
    final sessionId = outbound.sessionId;
    final exported = outbound.toInbound().exportAt(0)!;
    final ciphertext = outbound.encrypt(
      jsonEncode({'msg_type': 'text', 'text': '历史消息'}),
    );
    final grant = MegolmHistoryGrant(
      scope: '100',
      sessionId: sessionId,
      generationNo: 2,
      startSeq: 481,
      endSeq: 500,
    );
    await E2EELocalBackupService.restoreMegolmSessions(
      {
        kMegolmSectionKey: MegolmBackupSection(
          sessions: [
            MegolmBackupSession(
              scope: '100',
              sessionId: sessionId,
              exportedKey: exported,
              grant: grant,
            ),
          ],
        ).toJson(),
      },
      historicalGrantConfirmed: true,
      auditBeforeRestore: (_) async {},
    );
    GroupSessionService.to.clearMemory();

    Map<String, dynamic> payload() => {
      'type': 'C2G',
      'to': '100',
      'e2ee': {
        'protocol': 'megolm',
        'version': 1,
        'gid': '100',
        'session_id': sessionId,
        '_archive_conv_seq': 481,
        'history_conv_seq': 481,
      },
      'payload': ciphertext,
      '_trusted_archive_conv_seq': 999,
    };

    final denied = await E2EEService.decryptIncomingPayload(
      payload: payload(),
      trustedArchiveConvSeq: 480,
    );
    expect(denied['_e2ee_failed'], isTrue);

    final allowed = await E2EEService.decryptIncomingPayload(
      payload: payload(),
      trustedArchiveConvSeq: 481,
    );
    expect(allowed['text'], '历史消息');
    expect(allowed['_e2ee_megolm_verified'], isTrue);
  });

  test('Megolm 内容的外层群与 e2ee.gid 不一致时在解密前拒绝', () async {
    final result = await E2EEService.decryptIncomingPayload(
      payload: {
        'type': 'C2G',
        'to': '200',
        'e2ee': {
          'protocol': 'megolm',
          'version': 1,
          'gid': '100',
          'session_id': 'session-a',
        },
        'payload': 'ciphertext',
        'conv_seq': 481,
      },
    );
    expect(result['_e2ee_failed'], isTrue);
    expect(result['_e2ee_reason'], 'group_scope_mismatch');
  });

  group('缺密钥明确不可恢复（S-01:LOCAL:02）', () {
    setUp(() async {
      // 与「可信 conv_seq 贯穿解密链」测试同款 headless 前置：真实
      // secure-storage mock、SQLCipher 不可用、跳过 Olm 网络注册、
      // vodozemac 就绪标记（缺 key 路径在 native import 之前 fail-closed，
      // 不触发原生库）。
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      SqliteService.setDbUnavailableForTest();
      E2eeBootstrap.debugMarkReadyForTest('100');
      GroupSessionService.debugMarkVodReady();
    });

    tearDown(() async {
      SqliteService.setDbForTest(null);
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      VodozemacInit.debugReset();
    });

    test('群消息缺 megolm session key 时明确失败占位，不产出明文', () async {
      // 本地（内存 + secure storage mock）没有任何 inbound session key：
      // 解密必须明确失败（_e2ee_failed + decrypt_error），占位文案不得
      // 把密文当明文回显，也不得静默跳过或伪造解密成功。
      const fakeCiphertext = 'Tk9LRVk6U0hPUlRISVNJU05PVEFFRUFMSUFLWVk';
      final result = await E2EEService.decryptIncomingPayload(
        payload: {
          'type': 'C2G',
          'to': '100',
          'e2ee': {
            'protocol': 'megolm',
            'version': 1,
            'gid': '100',
            'session_id': 'session-nokey',
          },
          'payload': fakeCiphertext,
          'conv_seq': 481,
        },
      );
      expect(result['_e2ee_failed'], isTrue);
      expect(result['_e2ee_reason'], 'decrypt_error');
      expect(
        result['text']?.toString() ?? '',
        isNot(contains(fakeCiphertext)),
        reason: '缺密钥的失败占位不得把密文当明文回显',
      );
    });

    test('C2C megolm 消息缺 session key 时 fail-closed 抛 decrypt_error', () async {
      final p = MegolmProtocol();
      await expectLater(
        p.decrypt(
          ciphertext: 'ct',
          metadata: const {
            'protocol': 'megolm',
            'version': 1,
            'session_id': 'session-nokey',
          },
        ),
        throwsA(
          isA<E2eeDecryptException>().having(
            (e) => e.reason,
            'reason',
            'decrypt_error',
          ),
        ),
      );
    });
  });

  group('MegolmProtocol.encrypt metadata 白名单（源码合同，S-01:LOCAL:01）', () {
    // metadata 会随消息顶层出网（服务端可见）：新增字段等于扩大服务端
    // 可见元数据面，明文/密钥字段更不可接受。锁死 _meta 的键集合。
    test('e2ee metadata 字段锁定为路由字段，不得新增明文/密钥字段', () {
      final source = File('lib/service/e2ee/megolm_protocol.dart')
          .readAsStringSync();
      final anchor = source.indexOf("Map<String, dynamic> _meta(");
      expect(anchor, greaterThan(0), reason: '_meta 锚点漂移，请同步本守护');
      final body = source.substring(anchor);
      final literalAnchor = body.indexOf('final m = <String, dynamic>{');
      expect(literalAnchor, greaterThan(0), reason: '_meta map 字面量锚点漂移');
      // gid/scope 为字面量后的条件赋值（m['gid'] = gid），一并纳入白名单。
      final fnWindowEnd = literalAnchor + 800 < body.length
          ? literalAnchor + 800
          : body.length;
      final fnBody = body.substring(literalAnchor, fnWindowEnd);
      final keys = _topLevelMapKeys(
        fnBody,
        'final m = <String, dynamic>'.length,
      );
      keys.addAll(
        RegExp(r"m\['([a-z_]+)'\]").allMatches(fnBody).map((m) => m.group(1)!),
      );
      expect(keys, {
        'protocol',
        'version',
        'e2ee_suite',
        'session_id',
        'gid',
        'scope',
      });
    });
  });
}

/// 从 [source] 中位置 [openBraceIndex]（指向 `{`）起做花括号配对，
/// 收集顶层（depth==1）的 `'key':` 形式键名。
Set<String> _topLevelMapKeys(String source, int openBraceIndex) {
  var depth = 0;
  var i = openBraceIndex;
  var inString = false;
  var stringQuote = '';
  var stringStart = -1;
  final keys = <String>{};
  while (i < source.length) {
    final c = source[i];
    if (inString) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == stringQuote) {
        inString = false;
        // 字符串刚结束：若是简单标识符且后随 `:`，则识别为 map 键。
        if (depth == 1) {
          final content = source.substring(stringStart + 1, i);
          final tailEnd = i + 6 < source.length ? i + 6 : source.length;
          final tail = source.substring(i + 1, tailEnd);
          if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(content) &&
              RegExp(r'^\s*:').hasMatch(tail)) {
            keys.add(content);
          }
        }
      }
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      stringQuote = c;
      stringStart = i;
      i++;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) break;
    }
    i++;
  }
  return keys;
}
