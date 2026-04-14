import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';

/// Feature point 3: moment detail page currently swallows failures silently
/// (add comment / delete comment / delete post / report post). We add three
/// user-visible feedback strings so the UI can toast via EasyLoading.
void main() {
  group('Moment feedback i18n keys', () {
    late Translations zh;
    late Translations en;

    setUpAll(() async {
      zh = await AppLocale.zhCn.build();
      en = await AppLocale.enUs.build();
    });

    test('momentsCommentFailed is populated in zh/en', () {
      expect(zh.momentsCommentFailed, isNotEmpty);
      expect(en.momentsCommentFailed, isNotEmpty);
    });

    test('momentsDeleteFailed is populated in zh/en', () {
      expect(zh.momentsDeleteFailed, isNotEmpty);
      expect(en.momentsDeleteFailed, isNotEmpty);
    });

    test('momentsReportSubmitted is populated in zh/en', () {
      expect(zh.momentsReportSubmitted, isNotEmpty);
      expect(en.momentsReportSubmitted, isNotEmpty);
    });

    test('momentsReportFailed is populated in zh/en', () {
      expect(zh.momentsReportFailed, isNotEmpty);
      expect(en.momentsReportFailed, isNotEmpty);
    });

    test('momentsLoadMoreComments is populated in zh/en', () {
      expect(zh.momentsLoadMoreComments, isNotEmpty);
      expect(en.momentsLoadMoreComments, isNotEmpty);
    });
  });
}
