import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/personal_info/personal_info/avatar_fallback_rules.dart';

void main() {
  group('extractAvatarInitial', () {
    test('returns "?" for empty string', () {
      expect(extractAvatarInitial(''), '?');
    });

    test('returns "?" for whitespace-only string', () {
      expect(extractAvatarInitial('   '), '?');
      expect(extractAvatarInitial('\t\n  '), '?');
    });

    test('uppercases lowercase ASCII letter', () {
      expect(extractAvatarInitial('alice'), 'A');
      expect(extractAvatarInitial('z'), 'Z');
    });

    test('keeps already-uppercase ASCII letter', () {
      expect(extractAvatarInitial('Bob'), 'B');
      expect(extractAvatarInitial('XYZ'), 'X');
    });

    test('trims leading/trailing whitespace before extracting', () {
      expect(extractAvatarInitial(' bob '), 'B');
      expect(extractAvatarInitial('\n  carol'), 'C');
      expect(extractAvatarInitial('dave\t'), 'D');
    });

    test('returns CJK first character intact (single rune)', () {
      expect(extractAvatarInitial('张三'), '张');
      expect(extractAvatarInitial('李四 王五'), '李');
      expect(extractAvatarInitial('日本語'), '日');
      expect(extractAvatarInitial('한국'), '한');
    });

    test('returns emoji intact (surrogate pair handled correctly)', () {
      // 😀 = U+1F600（超出 BMP，UTF-16 编码为 surrogate pair 占 2 个 char unit），
      // 这是 String[0] 切断 bug 的反例 —— 必须用 runes
      expect(extractAvatarInitial('😀hi'), '😀');
      expect(extractAvatarInitial('🎉 party'), '🎉');
      expect(extractAvatarInitial('🚀'), '🚀');
    });

    test('handles digits and symbols as-is (no uppercase mutation)', () {
      expect(extractAvatarInitial('123'), '1');
      expect(extractAvatarInitial('@user'), '@');
      expect(extractAvatarInitial('#tag'), '#');
    });

    test('handles single character input', () {
      expect(extractAvatarInitial('a'), 'A');
      expect(extractAvatarInitial('A'), 'A');
      expect(extractAvatarInitial('张'), '张');
      expect(extractAvatarInitial('5'), '5');
    });

    test('counter-example: String[0] would break on emoji', () {
      // 这个测试钉死实现选择：用 runes 而非 String[0]
      // 如果 future maintainer 误改回 text[0]，这个测会爆炸
      const emoji = '😀';
      expect(emoji.length, 2); // UTF-16 视角是 2 个 char unit
      expect(emoji.runes.length, 1); // Unicode code point 视角是 1 个
      expect(extractAvatarInitial(emoji), emoji);
      // 反向验证：如果实现写成 emoji[0].toUpperCase()，结果是半个 surrogate，
      // 与原 emoji 不相等
      expect(extractAvatarInitial(emoji), isNot(emoji[0].toUpperCase()));
    });
  });
}
