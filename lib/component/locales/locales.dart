import 'dart:ui' as ui;

import 'package:get/get.dart';
import 'package:imboy/component/locales/locales.g.dart';

class IMBoyTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => AppTranslation.translations;
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
  String? local = ui.window.locale.toString();
  // debugPrint("> on main $local");
  // zh_Hans_CN ui.window.locale.toString();
  if (pkg == 'jiffy') {
    // from ./jiffy-6.1.0/lib/src/locale/available_locales.dart
    // 'zh_cn': ZhCnLocale(),
    // 'zh_hk': ZhHkLocale(),
    // 'zh_tw': ZhTwLocale(),
    if (local == 'zh_Hans_CN' || local == 'zh-Hans-SG') {
      return 'zh_cn';
    } else if (local == 'zh-Hant-HK') {
      return 'zh_hk';
    } else if (local == 'zh-Hant-TW') {
      return 'zh_tw';
    }
  }
  return local;
}
