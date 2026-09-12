import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/store/api/e2ee_api.dart';

const String _pw = 'TestPass123';
const String _priv =
    '-----BEGIN PRIVATE KEY-----\nFAKE\n-----END PRIVATE KEY-----'; // gitleaks:allow
const String _pub =
    '-----BEGIN PUBLIC KEY-----\nFAKE\n-----END PUBLIC KEY-----'; // gitleaks:allow

String _grant(
  String gid,
  String sessionId, {
  int generationNo = 2,
  int startSeq = 481,
  int endSeq = 900,
}) => jsonEncode(
  MegolmHistoryGrant(
    scope: gid,
    sessionId: sessionId,
    generationNo: generationNo,
    startSeq: startSeq,
    endSeq: endSeq,
  ).toJson(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Megolm backup section v2', () {
    test('只收有权威 grant 的群 session；C2C、缺 grant 和非法 grant 均省略', () {
      final section = collectMegolmSection({
        'megolm_inbound_100:session-ok': 'key-ok',
        'megolm_history_grant_100:session-ok': _grant('100', 'session-ok'),
        'megolm_inbound_c2c:session-c2c': 'key-c2c',
        'megolm_inbound_101:session-no-grant': 'key-no-grant',
        'megolm_inbound_102:session-mismatch': 'key-mismatch',
        'megolm_history_grant_102:session-mismatch': _grant(
          '999',
          'session-mismatch',
        ),
        'olm_account_pickle': 'must-not-appear',
      });

      expect(section.sessions, hasLength(1));
      expect(section.sessions.single.scope, '100');
      expect(section.sessions.single.exportedKey, 'key-ok');
      expect(section.omittedSessionCount, 3);
      expect(jsonEncode(section.toJson()), isNot(contains('key-c2c')));
      expect(jsonEncode(section.toJson()), isNot(contains('must-not-appear')));
    });

    test('grant 严格绑定 scope/session/epoch 与有效范围', () {
      final valid = MegolmHistoryGrant.parse(
        _grant('100', 'session-a', startSeq: 5, endSeq: 8),
        expectedScope: '100',
        expectedSessionId: 'session-a',
      );
      expect(valid, isNotNull);
      expect(valid!.allows(4), isFalse);
      expect(valid.allows(5), isTrue);
      expect(valid.allows(8), isTrue);
      expect(valid.allows(9), isFalse);
      expect(valid.allows(null), isFalse);

      final invalid = jsonDecode(_grant('100', 'session-a'))
        ..['epoch_id'] = 'other-session';
      expect(
        MegolmHistoryGrant.parse(
          invalid,
          expectedScope: '100',
          expectedSessionId: 'session-a',
        ),
        isNull,
      );
    });

    test('旧字符串 map 不恢复 session，只统计省略数', () {
      final section = parseMegolmSection({
        '100:session-a': 'legacy-key-a',
        'c2c:session-b': 'legacy-key-b',
      });
      expect(section.sessions, isEmpty);
      expect(section.omittedSessionCount, 2);
    });

    test('v2 sessions 缺失或类型错误时明确拒绝损坏备份', () {
      for (final raw in [
        {'format_version': kMegolmSectionFormatVersion},
        {
          'format_version': kMegolmSectionFormatVersion,
          'sessions': <String, dynamic>{},
        },
      ]) {
        expect(() => parseMegolmSection(raw), throwsA(isA<FormatException>()));
      }
    });

    test('超上限截断并计入省略数', () {
      final entries = <String, String>{};
      for (var i = 0; i < kMaxMegolmSessions + 2; i++) {
        entries['megolm_inbound_100:s$i'] = 'key-$i';
        entries['megolm_history_grant_100:s$i'] = _grant('100', 's$i');
      }
      final section = collectMegolmSection(entries);
      expect(section.sessions, hasLength(kMaxMegolmSessions));
      expect(section.omittedSessionCount, 2);
    });
  });

  group('restoreMegolmSessions', () {
    final backup = {
      kMegolmSectionKey: MegolmBackupSection(
        sessions: [
          MegolmBackupSession(
            scope: '100',
            sessionId: 'session-a',
            exportedKey: 'key-a',
            grant: const MegolmHistoryGrant(
              scope: '100',
              sessionId: 'session-a',
              generationNo: 2,
              startSeq: 481,
              endSeq: 900,
            ),
          ),
        ],
      ).toJson(),
    };

    test('没有独立授权时底层 API 拒绝且零写入', () async {
      final written = <String>[];
      await expectLater(
        E2EELocalBackupService.restoreMegolmSessions(
          backup,
          historicalGrantConfirmed: false,
          auditBeforeRestore: (_) async {},
          writeForTest: (key, value) async => written.add(key),
        ),
        throwsA(isA<StateError>()),
      );
      expect(written, isEmpty);
    });

    test('授权后先写恢复 grant marker，最后写入 key', () async {
      final written = <String, String>{};
      final order = <String>[];
      final restored = await E2EELocalBackupService.restoreMegolmSessions(
        backup,
        historicalGrantConfirmed: true,
        auditBeforeRestore: (_) async {},
        writeForTest: (key, value) async {
          order.add(key);
          written[key] = value;
        },
      );

      expect(restored, 1);
      expect(order, [
        'megolm_restored_history_grant_100:session-a',
        'megolm_history_grant_100:session-a',
        'megolm_inbound_100:session-a',
      ]);
      expect(written['megolm_inbound_100:session-a'], 'key-a');
    });

    test('审计失败时历史 key 零写入', () async {
      final written = <String>[];
      await expectLater(
        E2EELocalBackupService.restoreMegolmSessions(
          backup,
          historicalGrantConfirmed: true,
          auditBeforeRestore: (_) async => throw StateError('audit_failed'),
          writeForTest: (key, value) async => written.add(key),
        ),
        throwsA(isA<StateError>()),
      );
      expect(written, isEmpty);
    });

    test('任一安全存储写入失败时立即失败，不报告完整恢复', () async {
      final attempted = <String>[];
      await expectLater(
        E2EELocalBackupService.restoreMegolmSessions(
          backup,
          historicalGrantConfirmed: true,
          auditBeforeRestore: (_) async {},
          writeForTest: (key, value) async {
            attempted.add(key);
            throw StateError('secure_storage_write_failed');
          },
        ),
        throwsA(isA<StateError>()),
      );
      expect(attempted, ['megolm_restored_history_grant_100:session-a']);
    });
  });

  group('pack/unpack', () {
    test('导出前按 session 刷新服务端有限授权快照', () async {
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _pw,
        privateKey: _priv,
        publicKey: _pub,
        deviceId: 'dev-EXAMPLE',
        keyId: 'key-EXAMPLE',
        secureEntriesForTest: {
          'megolm_inbound_100:session-a': 'exported-key-a',
        },
        historyGrantLoaderForTest: (gid, sessionId) async {
          expect(gid, '100');
          expect(sessionId, 'session-a');
          return const E2EEGroupHistoryGrant(
            gid: '100',
            sessionId: 'session-a',
            generationNo: 2,
            startSeq: 481,
            endSeq: 900,
          );
        },
      );

      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: _pw,
      );
      final section = E2EELocalBackupService.megolmBackupSection(restored);
      expect(section.sessions, hasLength(1));
      expect(section.sessions.single.grant.endSeq, 900);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('授权刷新失败时中止备份，不静默生成缺群历史的成功包', () async {
      await expectLater(
        E2EELocalBackupService.packBackupBytes(
          password: _pw,
          privateKey: _priv,
          publicKey: _pub,
          deviceId: 'dev-EXAMPLE',
          keyId: 'key-EXAMPLE',
          secureEntriesForTest: {
            'megolm_inbound_100:session-a': 'must-not-appear',
            'megolm_history_grant_100:session-a': _grant('100', 'session-a'),
          },
          historyGrantLoaderForTest: (_, _) async =>
              throw StateError('forbidden'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'backup_secret_collection_failed',
          ),
        ),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('非法和 C2C 条目不占群 session 刷新上限', () async {
      final entries = <String, String>{};
      for (var i = 0; i < kMaxMegolmSessions; i++) {
        entries['megolm_inbound_c2c:session-$i'] = 'c2c-key-$i';
      }
      entries['megolm_inbound_100:session-valid'] = 'group-key';

      var loaderCalls = 0;
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _pw,
        privateKey: _priv,
        publicKey: _pub,
        deviceId: 'dev-EXAMPLE',
        keyId: 'key-EXAMPLE',
        secureEntriesForTest: entries,
        historyGrantLoaderForTest: (gid, sessionId) async {
          loaderCalls++;
          return E2EEGroupHistoryGrant(
            gid: gid,
            sessionId: sessionId,
            generationNo: 2,
            startSeq: 481,
            endSeq: 900,
          );
        },
      );

      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: _pw,
      );
      final section = E2EELocalBackupService.megolmBackupSection(restored);

      expect(loaderCalls, 1);
      expect(section.sessions, hasLength(1));
      expect(section.sessions.single.sessionId, 'session-valid');
      expect(section.omittedSessionCount, kMaxMegolmSessions);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('v2 group session 与 grant 往返；C2C 和 Olm pickle 不进入包', () async {
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _pw,
        privateKey: _priv,
        publicKey: _pub,
        deviceId: 'dev-EXAMPLE',
        keyId: 'key-EXAMPLE',
        secureEntriesForTest: {
          'megolm_inbound_100:session-a': 'exported-key-a',
          'megolm_history_grant_100:session-a': _grant('100', 'session-a'),
          'megolm_inbound_c2c:session-b': 'must-not-appear',
          'olm_account_pickle': 'must-not-appear-either',
        },
      );

      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: _pw,
      );
      final section = E2EELocalBackupService.megolmBackupSection(restored);

      expect(restored['private_key'], _priv);
      expect(section.sessions, hasLength(1));
      expect(section.sessions.single.scope, '100');
      expect(section.sessions.single.grant.startSeq, 481);
      expect(section.omittedSessionCount, 1);
      expect(jsonEncode(restored), isNot(contains('must-not-appear')));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
