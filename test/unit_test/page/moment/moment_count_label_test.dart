import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 8: truncate large like/comment counts (>999) to "999+" so
/// row layouts don't explode when a post goes viral. 0 collapses to empty
/// string so the UI can decide whether to render anything at all.
void main() {
  group('formatMomentCountLabel', () {
    test('returns empty string for 0', () {
      expect(formatMomentCountLabel(0), '');
    });

    test('returns the raw string for 1..999', () {
      expect(formatMomentCountLabel(1), '1');
      expect(formatMomentCountLabel(42), '42');
      expect(formatMomentCountLabel(999), '999');
    });

    test('collapses 1000 and beyond to "999+"', () {
      expect(formatMomentCountLabel(1000), '999+');
      expect(formatMomentCountLabel(12345), '999+');
      expect(formatMomentCountLabel(1000000), '999+');
    });

    test('treats negative counts as 0 (empty string)', () {
      expect(formatMomentCountLabel(-1), '');
      expect(formatMomentCountLabel(-999), '');
    });
  });
}
