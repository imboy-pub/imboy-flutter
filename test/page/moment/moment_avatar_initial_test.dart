import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 14: moment cards & comments fall back to
/// `displayName.substring(0, 1)` when no avatar image is available. That
/// split is surrogate-unsafe — an emoji name would crash with
/// `RangeError: Invalid UTF-16 code unit`. This helper returns the first
/// Unicode code point instead, with defensive trimming.
void main() {
  group('avatarInitialFrom', () {
    test('returns first ASCII character of a plain name', () {
      expect(avatarInitialFrom('John'), 'J');
    });

    test('returns first character of a CJK name', () {
      expect(avatarInitialFrom('老王'), '老');
    });

    test('returns "?" for empty string', () {
      expect(avatarInitialFrom(''), '?');
    });

    test('returns "?" for whitespace-only string', () {
      expect(avatarInitialFrom('   '), '?');
    });

    test('handles supplementary-plane codepoints (emoji) without splitting', () {
      // '🍎apple' starts with U+1F34E which is a surrogate pair in UTF-16.
      // substring(0, 1) would slice off the high surrogate alone; we want the
      // full code point.
      final result = avatarInitialFrom('🍎apple');
      expect(result, '🍎');
      expect(result.runes.length, 1);
    });

    test('trims leading whitespace before picking first character', () {
      expect(avatarInitialFrom('  Alice'), 'A');
    });
  });
}
