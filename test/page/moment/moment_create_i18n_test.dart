import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';

/// i18n keys required by MomentCreatePage.
///
/// Feature point 1: replace hardcoded CJK strings in moment_create_page.dart
/// with slang-managed translation keys. This test is the RED anchor.
void main() {
  group('MomentCreatePage i18n keys', () {
    late Translations zh;
    late Translations en;

    setUpAll(() async {
      zh = await AppLocale.zhCn.build();
      en = await AppLocale.enUs.build();
    });

    test('momentsContentHint is populated in zh/en', () {
      expect(zh.momentsContentHint, isNotEmpty);
      expect(en.momentsContentHint, isNotEmpty);
    });

    test('momentsAddMedia is populated in zh/en', () {
      expect(zh.momentsAddMedia, isNotEmpty);
      expect(en.momentsAddMedia, isNotEmpty);
    });

    test('momentsAllowUidsLabel is populated in zh/en', () {
      expect(zh.momentsAllowUidsLabel, isNotEmpty);
      expect(en.momentsAllowUidsLabel, isNotEmpty);
    });

    test('momentsDenyUidsLabel is populated in zh/en', () {
      expect(zh.momentsDenyUidsLabel, isNotEmpty);
      expect(en.momentsDenyUidsLabel, isNotEmpty);
    });
  });
}
