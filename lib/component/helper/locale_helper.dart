import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:imboy/service/storage.dart';

import 'package:imboy/config/const.dart';

/// 语言辅助工具类
///
/// 提供系统语言获取和格式转换功能
/// 用于不同第三方库的语言代码适配
class LocaleHelper {
  // 私有构造函数，防止实例化
  LocaleHelper._();

  /// 获取系统语言代码
  ///
  /// [pkg] 可选参数，用于适配不同第三方库的语言代码格式：
  /// - 'jiffy': 返回 Jiffy 库支持的语言代码（如 zh_CN）
  /// - 'intl_phone_number_input': 返回国际电话输入库支持的语言代码（如 zh）
  /// - '': 返回原始系统语言代码（如 zh_CN）
  ///
  /// 返回值优先使用用户设置的语言，否则返回系统语言
  static String sysLang(String pkg) {
    /// The result usually consists of
    ///  - a language (e.g., "en"), or
    ///  - a language and country code (e.g. "en_US", "de_AT"), or
    ///  - a language, country code and character set (e.g. "en_US.UTF-8").
    /// See https://en.wikipedia.org/wiki/Locale_(computer_software)
    String local = Platform.localeName;
    debugPrint("> LocaleHelper.sysLang $local");

    if (pkg == 'jiffy') {
      local = jiffyLocal(local);
    } else if (pkg == 'intl_phone_number_input') {
      local = intlPhoneNumberInput(local);
    }

    return StorageService.to.getString(Keys.currentLang) ?? local;
  }

  /// 转换为国际电话输入库支持的语言代码
  ///
  /// 参考: https://github.com/natintosh/intl_phone_number_input/blob/develop/lib/src/models/country_list.dart
  static String intlPhoneNumberInput(String local) {
    if (local.startsWith('zh_Hans') || local.startsWith('zh-Hans')) {
      // Hans：代表简体中文（Simplified Chinese）
      local = 'zh';
    } else if (local.startsWith('zh-Hant')) {
      // Hant，代表繁体中文（Traditional Chinese）
      local = 'zh_TW';
    } else if (local.startsWith('zh_')) {
      local = 'zh';
    } else if (local.startsWith('ru_')) {
      local = 'ru';
    } else if (local.startsWith('fr_')) {
      local = 'fr';
    } else if (local.startsWith('de_')) {
      local = 'de';
    } else if (local.startsWith('ja_')) {
      local = 'ja';
    } else if (local.startsWith('ko_')) {
      local = 'ko';
    } else if (local.startsWith('ar_')) {
      local = 'ar';
    } else if (local.startsWith('it_')) {
      local = 'it';
    }
    return local;
  }

  /// 转换为 Jiffy 库支持的语言代码
  ///
  /// Jiffy 支持的语言代码参考：./jiffy-6.3.1/lib/src/locale/supported_locales.dart
  /// 支持的语言包括：en, zh_CN, zh_Hant, zh_HK, zh_TW, ru, fr, de, ja, ko, ar, it 等
  static String jiffyLocal(String local) {
    if (local.startsWith('zh_Hans') || local.startsWith('zh-Hans')) {
      // Hans：代表简体中文（Simplified Chinese）
      local = 'zh_CN';
    } else if (local.startsWith('zh-Hant')) {
      // Hant，代表繁体中文（Traditional Chinese）
      local = 'zh_Hant';
    } else if (local.startsWith('ru_')) {
      local = 'ru';
    } else if (local.startsWith('fr_')) {
      local = 'fr';
    } else if (local.startsWith('de_')) {
      local = 'de';
    } else if (local.startsWith('ja_')) {
      local = 'ja';
    } else if (local.startsWith('ko_')) {
      local = 'ko';
    } else if (local.startsWith('ar_')) {
      local = 'ar';
    } else if (local.startsWith('it_')) {
      local = 'it';
    }
    return local;
  }
}
