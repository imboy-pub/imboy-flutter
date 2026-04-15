import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// `momentFailedDraftKey` 契约：
/// - 正常 uid → `moment_failed_draft_{uid}`（按用户隔离，防跨账号泄漏）
/// - 空 / 纯空白 uid → `''`（调用方据此跳过读写，不产生 kv 噪音）
/// - 对 uid 做 trim，避免 `' 123'` 和 `'123'` 生成两个 key
void main() {
  group('momentFailedDraftKey', () {
    test('builds key with uid suffix', () {
      expect(momentFailedDraftKey('u_42'), 'moment_failed_draft_u_42');
    });

    test('empty uid yields empty string', () {
      expect(momentFailedDraftKey(''), '');
    });

    test('whitespace-only uid yields empty string', () {
      expect(momentFailedDraftKey('   '), '');
    });

    test('trims surrounding whitespace before composing', () {
      expect(momentFailedDraftKey('  u_7  '), 'moment_failed_draft_u_7');
    });

    test('different uids produce distinct keys (isolation)', () {
      expect(
        momentFailedDraftKey('alice'),
        isNot(momentFailedDraftKey('bob')),
      );
    });
  });
}
