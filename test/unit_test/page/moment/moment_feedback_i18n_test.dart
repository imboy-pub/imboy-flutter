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
      expect(zh.common.momentsCommentFailed, isNotEmpty);
      expect(en.common.momentsCommentFailed, isNotEmpty);
    });

    test('momentsDeleteFailed is populated in zh/en', () {
      expect(zh.common.momentsDeleteFailed, isNotEmpty);
      expect(en.common.momentsDeleteFailed, isNotEmpty);
    });

    test('momentsReportSubmitted is populated in zh/en', () {
      expect(zh.common.momentsReportSubmitted, isNotEmpty);
      expect(en.common.momentsReportSubmitted, isNotEmpty);
    });

    test('momentsReportFailed is populated in zh/en', () {
      expect(zh.common.momentsReportFailed, isNotEmpty);
      expect(en.common.momentsReportFailed, isNotEmpty);
    });

    test('momentsLoadMoreComments is populated in zh/en', () {
      expect(zh.common.momentsLoadMoreComments, isNotEmpty);
      expect(en.common.momentsLoadMoreComments, isNotEmpty);
    });

    test('momentsUploadFailed is populated in zh/en', () {
      expect(zh.common.momentsUploadFailed, isNotEmpty);
      expect(en.common.momentsUploadFailed, isNotEmpty);
    });

    test('momentsReplyPrefix is populated in zh/en', () {
      expect(zh.chat.momentsReplyPrefix, isNotEmpty);
      expect(en.chat.momentsReplyPrefix, isNotEmpty);
    });

    test('momentsReplySeparator is populated in zh/en', () {
      expect(zh.chat.momentsReplySeparator, isNotEmpty);
      expect(en.chat.momentsReplySeparator, isNotEmpty);
    });

    test('momentsReplyingTo is populated in zh/en', () {
      expect(zh.chat.momentsReplyingTo, isNotEmpty);
      expect(en.chat.momentsReplyingTo, isNotEmpty);
    });
  });
}
