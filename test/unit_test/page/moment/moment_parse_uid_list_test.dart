import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// `parseMomentUidList` 契约：
/// - 逗号分隔（半角 `,`，不兼容全角 `，` —— 前端 UI 限制用户只能输半角）
/// - 每项 trim
/// - 丢弃空项（连续逗号、尾随逗号、纯空白）
/// - 保序，不去重（重复 UID 由后端幂等处理，前端不私自裁剪）
/// - 输入空串 / 纯空白 → const []（不产生无效网络负载）
void main() {
  group('parseMomentUidList', () {
    test('returns empty list for empty string', () {
      expect(parseMomentUidList(''), const <String>[]);
    });

    test('returns empty list for whitespace-only string', () {
      expect(parseMomentUidList('   \t\n  '), const <String>[]);
    });

    test('splits simple comma-separated list', () {
      expect(parseMomentUidList('a,b,c'), ['a', 'b', 'c']);
    });

    test('trims whitespace around each uid', () {
      expect(parseMomentUidList(' a , b ,  c '), ['a', 'b', 'c']);
    });

    test('drops empty segments from consecutive / trailing commas', () {
      expect(parseMomentUidList('a,,b,'), ['a', 'b']);
      expect(parseMomentUidList(',a,'), ['a']);
    });

    test('preserves order and keeps duplicates (caller/server dedup)', () {
      expect(parseMomentUidList('a,b,a'), ['a', 'b', 'a']);
    });

    test('single uid without commas still parsed', () {
      expect(parseMomentUidList('uid_123'), ['uid_123']);
    });

    test('returns unmodifiable-friendly fixed list (no growable)', () {
      final result = parseMomentUidList('a,b');
      expect(() => result.add('c'), throwsUnsupportedError);
    });
  });
}
