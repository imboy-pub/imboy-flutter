import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';

/// 「跟随系统语言」的存储值判定。
///
/// 关键约束：哨兵值 "system" **不是** AppLocale 的枚举名。run.dart 恢复语言时
/// 若没先判这一支，就会落进 `AppLocale.values.firstWhere(...)`，被 orElse
/// 兜成简体中文 —— 用户选的「跟随系统」一重启就失效。
void main() {
  group('Keys.isFollowSystemLanguage', () {
    test('哨兵值判为跟随系统', () {
      expect(Keys.isFollowSystemLanguage(Keys.systemLanguageCode), isTrue);
    });

    test('空值（从未设置）判为跟随系统 —— 新装默认', () {
      expect(Keys.isFollowSystemLanguage(''), isTrue);
    });

    test('具体语言枚举名不判为跟随系统', () {
      expect(Keys.isFollowSystemLanguage('zhCn'), isFalse);
      expect(Keys.isFollowSystemLanguage('enUs'), isFalse);
    });

    // 哨兵值必须与任何 AppLocale 枚举名都不冲突，否则用户永远选不中那门语言。
    test('哨兵值不与任何语言枚举名冲突', () {
      expect(localeIdMapValueNames, isNot(contains(Keys.systemLanguageCode)));
    });
  });
}

/// 与 language_page 的 localeIdMap 对应的枚举名集合，硬编码避免为一条断言
/// 把整个 page（连带 riverpod/StorageService）拖进无头测试。
const localeIdMapValueNames = <String>{
  'zhCn',
  'zhHant',
  'ruRu',
  'enUs',
  'frFr',
  'deDe',
  'jaJp',
  'koKr',
  'arSa',
  'itIt',
};
