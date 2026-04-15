import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// `buildReplyTarget` 契约：
/// - 从 comment map 解析出 `(uid, name)` 对，用于回复预填
/// - uid 缺失 / 空 → `MomentReplyTarget.none`（调用方据此不进入回复态）
/// - name 优先级：`user_remark` > `user_nickname` > uid，与
///   `resolveMomentDisplayName` 一致，避免两处命名漂移
/// - 不抛异常，脏数据一律回落
void main() {
  group('buildReplyTarget', () {
    test('returns none when uid missing or empty', () {
      expect(buildReplyTarget(<String, dynamic>{}).isNone, isTrue);
      expect(
        buildReplyTarget(<String, dynamic>{'user_id': ''}).isNone,
        isTrue,
      );
    });

    test('prefers user_remark over nickname and uid', () {
      final target = buildReplyTarget(<String, dynamic>{
        'user_id': 'u1',
        'user_remark': '备注名',
        'user_nickname': 'nickname',
      });
      expect(target.uid, 'u1');
      expect(target.name, '备注名');
      expect(target.isNone, isFalse);
    });

    test('falls back to nickname when remark empty', () {
      final target = buildReplyTarget(<String, dynamic>{
        'user_id': 'u2',
        'user_remark': '',
        'user_nickname': 'Alice',
      });
      expect(target.name, 'Alice');
    });

    test('falls back to uid when both remark and nickname empty', () {
      final target = buildReplyTarget(<String, dynamic>{
        'user_id': 'u3',
        'user_remark': '',
        'user_nickname': '',
      });
      expect(target.name, 'u3');
    });

    test('numeric user_id coerced via parseModelString', () {
      final target = buildReplyTarget(<String, dynamic>{
        'user_id': 42,
        'user_nickname': 'Bob',
      });
      expect(target.uid, '42');
      expect(target.name, 'Bob');
    });

    test('MomentReplyTarget.none exposes empty strings for setState safety',
        () {
      const none = MomentReplyTarget.none;
      expect(none.uid, '');
      expect(none.name, '');
      expect(none.isNone, isTrue);
    });
  });
}
