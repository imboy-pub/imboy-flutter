import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 16: detail page should surface the post's visibility so the
/// author can confirm "yes, I did post this as friends-only". Needs two pure
/// helpers: one to read visibility out of the payload defensively, one to
/// translate the int → localized label.
void main() {
  group('parseMomentVisibility', () {
    test('returns visibility int when present', () {
      final moment = {'visibility': 2};
      expect(parseMomentVisibility(moment), momentVisibilityPrivate);
    });

    test('parses string-encoded visibility (defensive for loose backends)', () {
      final moment = {'visibility': '3'};
      expect(parseMomentVisibility(moment), momentVisibilityAllowList);
    });

    test('returns friends fallback when field is missing', () {
      // Friends-only is the safest default: a missing value should not
      // accidentally expose a private moment as public.
      expect(parseMomentVisibility(const {}), momentVisibilityFriends);
    });

    test('returns friends fallback when field is null', () {
      final moment = {'visibility': null};
      expect(parseMomentVisibility(moment), momentVisibilityFriends);
    });

    test('clamps unknown codes to friends fallback (defensive)', () {
      final moment = {'visibility': 99};
      expect(parseMomentVisibility(moment), momentVisibilityFriends);
    });

    test('negative codes also clamp to friends fallback', () {
      final moment = {'visibility': -1};
      expect(parseMomentVisibility(moment), momentVisibilityFriends);
    });
  });

  group('momentVisibilityLabel', () {
    late Translations t;

    setUpAll(() async {
      t = await AppLocale.zhCn.build();
    });

    test('maps each known code to its existing i18n label', () {
      expect(
        momentVisibilityLabel(momentVisibilityPublic, t),
        t.discovery.momentsVisibilityPublic,
      );
      expect(
        momentVisibilityLabel(momentVisibilityFriends, t),
        t.contact.momentsVisibilityFriends,
      );
      expect(
        momentVisibilityLabel(momentVisibilityPrivate, t),
        t.chat.momentsVisibilityPrivate,
      );
      expect(
        momentVisibilityLabel(momentVisibilityAllowList, t),
        t.discovery.momentsVisibilityPartial,
      );
      expect(
        momentVisibilityLabel(momentVisibilityDenyList, t),
        t.discovery.momentsVisibilityExclude,
      );
    });

    test('unknown code falls back to friends label', () {
      expect(momentVisibilityLabel(99, t), t.contact.momentsVisibilityFriends);
    });
  });
}
