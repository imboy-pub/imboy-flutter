import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/config/const.dart';

import 'package:imboy/component/locales/locales.g.dart';
import 'package:imboy/service/storage.dart';

class IMBoyTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => AppTranslation.translations;

  static List langList = [];
}

/* 使用window.locale读取系统语言
en-US ,en代表英语区， US 美国。前面为小写，后面为大写，区分地区和方言用的。
zh-CN，zh代表华语区，CN代表中国大陆。
zh-HK，zh代表华语区，HK代表中国香港。
zh-TW，zh代表华语区，TW代表中国台湾。
zh-Hans-CN，华语区，Han 汉字 s简体，CN普通话使用
zh-Hant-HK，华语区，Han 汉字 t繁体，HK粤语使用
zh-Hant-TW，华语区，Han汉字，t繁体，TW台语使用
zh-Hans-SG，华语区，han汉字, s简体，SG新加坡语使用。
作者：贝尔加湖畔的鱼
链接：https://www.zhihu.com/question/21980689/answer/2643674176
*/
String sysLang(String pkg) {
  /// The result usually consists of
  ///  - a language (e.g., "en"), or
  ///  - a language and country code (e.g. "en_US", "de_AT"), or
  ///  - a language, country code and character set (e.g. "en_US.UTF-8").
  /// See https://en.wikipedia.org/wiki/Locale_(computer_software)
  /// LANG=kitten dart myfile.dart  # localeName is "kitten"
  String local = Platform.localeName;
  debugPrint("> sysLang $local");
  // zh_Hans_CN ui.window.locale.toString();
  if (pkg == 'jiffy') {
    local = jiffyLocal(local);
  } else if (pkg == 'intl_phone_number_input') {
    local = intlPhoneNumberInput(local);
  }
  return StorageService.to.getString(Keys.currentLang) ?? local;
}


// https://github.com/natintosh/intl_phone_number_input/blob/develop/lib/src/models/country_list.dart
String intlPhoneNumberInput(String local) {
  iPrint('intlPhoneNumberInput 1 $local');
  if (local.startsWith('zh_Hans') || local.startsWith('zh-Hans')) { // Hans：代表简体中文（Simplified Chinese）
    local = 'zh';
  } else if (local.startsWith('zh-Hant')) { // Hant，代表繁体中文（Traditional Chinese）
    local = 'zh_TW';
  } else if (local.startsWith('zh_')) {
    local = 'zh';
  } else if (local.startsWith('ru_')) {
    local = 'ru';
  }
  iPrint('intlPhoneNumberInput 2 $local');
  return local;
}


String jiffyLocal(String local) {
  // from ./jiffy-6.1.0/lib/src/locale/available_locales.dart
  // 'zh_cn': ZhCnLocale(),
  // 'zh_hk': ZhHkLocale(),
  // 'zh_tw': ZhTwLocale(),

  // from ./jiffy-6.3.1/lib/src/locale/supported_locales.dart
  // 'en': EnLocale(),
  // 'en_us': EnUsLocale(),
  // 'en_sg': EnSgLocale(),
  // 'en_au': EnAuLocale(),
  // 'en_ca': EnCaLocale(),
  // 'en_gb': EnGbLocale(),
  // 'en_ie': EnIeLocale(),
  // 'en_il': EnIlLocale(),
  // 'en_nz': EnNzLocale(),
  // ...
  // 'zh': ZhLocale(),
  // 'zh_cn': ZhCnLocale(),
  // 'zh_hk': ZhHkLocale(),
  // 'zh_tw': ZhTwLocale(),
  // ...
  // 'ru': RuLocale(),

  if (local.startsWith('zh_Hans') || local.startsWith('zh-Hans')) { // Hans：代表简体中文（Simplified Chinese）
    local = 'zh_CN';
  } else if (local.startsWith('zh-Hant')) { // Hant，代表繁体中文（Traditional Chinese）
    local = 'zh_Hant';
  } else if (local.startsWith('ru_')) {
    local = 'ru';
  }
  return local;
}
