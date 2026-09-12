import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/e2ee_api.dart';
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
    await ensureVodozemac();
    GroupSessionService.debugMarkVodReady();

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
}
