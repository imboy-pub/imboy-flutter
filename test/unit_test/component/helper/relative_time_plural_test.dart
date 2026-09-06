import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 回归：英文相对时间的单复数。
///
/// 三个 key（timeDaysAgo / timeHoursAgo / timeMinutesAgo）原本是无复数的平铺
/// 字符串 `$param days ago`，数量为 1 时英文界面显示 `1 days ago`。
/// 改为 slang plural 后由各语言的 cardinal resolver 选 one/other。
///
/// `lastSeen*Ago` 是这三个 key 的别名（`@:common.timeDaysAgo`），
/// slang 会让别名跟着变成 plural —— 一并锁住，防止哪天别名被改回平铺字符串。
void main() {
  group('英文相对时间单复数', () {
    late Translations en;
    setUpAll(() async => en = await AppLocale.enUs.build());

    test('1 用单数形式', () {
      expect(en.common.timeDaysAgo(n: 1), '1 day ago');
      expect(en.common.timeHoursAgo(n: 1), '1 hour ago');
      expect(en.common.timeMinutesAgo(n: 1), '1 minute ago');
    });

    test('2 及以上用复数形式', () {
      expect(en.common.timeDaysAgo(n: 2), '2 days ago');
      expect(en.common.timeHoursAgo(n: 5), '5 hours ago');
      expect(en.common.timeMinutesAgo(n: 30), '30 minutes ago');
    });

    test('0 用复数形式（英语 cardinal 规则）', () {
      expect(en.common.timeMinutesAgo(n: 0), '0 minutes ago');
    });

    test('lastSeen* 别名同样走复数解析', () {
      expect(en.common.lastSeenDaysAgo(n: 1), '1 day ago');
      expect(en.common.lastSeenHoursAgo(n: 3), '3 hours ago');
      expect(en.common.lastSeenMinutesAgo(n: 1), '1 minute ago');
    });
  });

  group('无复数变化的语言保持单一形式', () {
    test('中文 1 与 2 只差数字', () async {
      final zh = await AppLocale.zhCn.build();
      expect(zh.common.timeDaysAgo(n: 1), '1天前');
      expect(zh.common.timeDaysAgo(n: 2), '2天前');
    });
  });

  group('俄语 CLDR 四分支选择（a2ab55d4 resolver 修复的回归锁）', () {
    test('one/few/many/other 按 CLDR 规则命中', () async {
      final ru = await AppLocale.ruRu.build();
      // one：n%10=1 且 n%100≠11（含 21）
      expect(ru.common.timeDaysAgo(n: 1), '1 день назад');
      expect(ru.common.timeMinutesAgo(n: 21), '21 минуту назад');
      // few：n%10=2..4 且 n%100≠12..14
      expect(ru.common.timeHoursAgo(n: 2), '2 часа назад');
      // many：n%10=0 或 5..9 或 n%100=11..14
      expect(ru.common.timeDaysAgo(n: 5), '5 дней назад');
      expect(ru.common.timeMinutesAgo(n: 11), '11 минут назад');
    });
  });

  group('阿拉伯语 CLDR 分支选择（Round-3 补分支的回归锁）', () {
    test('one/two/few/many/other 按 CLDR 规则命中', () async {
      final ar = await AppLocale.arSa.build();
      expect(ar.common.timeDaysAgo(n: 1), 'منذ يوم واحد'); // one
      expect(ar.common.timeHoursAgo(n: 2), 'منذ ساعتين'); // two（双数）
      expect(ar.common.timeMinutesAgo(n: 7), 'منذ 7 دقائق'); // few（3-10 复数）
      expect(ar.common.timeDaysAgo(n: 11), 'منذ 11 يومًا'); // many（11-99 宾格单数）
      expect(ar.common.timeHoursAgo(n: 100), 'منذ 100 ساعة'); // other（整百）
    });
  });
}
