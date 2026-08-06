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
      expect(zh.common.momentsContentHint, isNotEmpty);
      expect(en.common.momentsContentHint, isNotEmpty);
    });

    test('momentsAddMedia is populated in zh/en', () {
      expect(zh.common.momentsAddMedia, isNotEmpty);
      expect(en.common.momentsAddMedia, isNotEmpty);
    });

    test('momentsAllowUidsLabel is populated in zh/en', () {
      expect(zh.common.momentsAllowUidsLabel, isNotEmpty);
      expect(en.common.momentsAllowUidsLabel, isNotEmpty);
    });

    test('momentsDenyUidsLabel is populated in zh/en', () {
      expect(zh.discovery.momentsDenyUidsLabel, isNotEmpty);
      expect(en.discovery.momentsDenyUidsLabel, isNotEmpty);
    });
  });
}
