import 'package:get/get.dart';

class LanguageState {
  RxBool valueChanged = false.obs;
  Rx<String> currentLanguage = ''.obs;
  Rx<String> selectedLanguage = ''.obs;

  //
  // 俄语的 languageCode 是 "ru"，而 countryCode 则有一些不同的选择取决于具体的地区：
  //
  // 在俄罗斯，countryCode 通常是 "RU"（表示俄罗斯）。
  // 在乌克兰，countryCode 可能是 "UA"（表示乌克兰）。
  // 在白俄罗斯，countryCode 是 "BY"（表示白俄罗斯）。

  //  在美国，countryCode 通常是 "US"（表示美国）。
  //  在英国，countryCode 可能是 "GB"（表示英国）。
  //  在加拿大，countryCode 是 "CA"（表示加拿大）。

  //  简体中文 的 countryCode 通常是 "CN"，表示中国。
  //  繁体中文 的 countryCode 可能是 "TW"，表示台湾，或者 "HK"，表示香港。
  List<Map<String, String>> languageList = [
    {
      "id": "zh_CN",
      "languageCode": "zh",
      "regionCode": "CN",
      "title": 'zhCn'.tr // 简体中文
    },
    {
      "id": "zh_TW",
      "languageCode": "zh",
      "regionCode": "TW",
      "title": 'zhHant'.tr, // 繁体中文
    },
    {
      "id": "ru_RU",
      "languageCode": "ru",
      "regionCode": "RU",
      "title": 'ruRu'.tr, // 俄罗斯俄语
    },
    // {
    //   "id": "en_GB",
    //   "languageCode": "en",
    //   "regionCode": "GB",
    //   "title": 'enGb'.tr "英国英语"
    // },
    {
      "id": "en_US",
      "languageCode": "en",
      "regionCode": "US",
      "title": 'enUs'.tr //美国英语
    },
    {
      "id": "fr_FR",
      "languageCode": "fr",
      "regionCode": "FR",
      "title": 'frFr'.tr // 法语
    },
    {
      "id": "de_DE",
      "languageCode": "de",
      "regionCode": "DE",
      "title": 'deDd'.tr // 德语
    },
    {
      "id": "ja_JP",
      "languageCode": "ja",
      "regionCode": "JP",
      "title": 'jaJp'.tr // 日语
    },
    {
      "id": "ko_KR",
      "languageCode": "ko",
      "regionCode": "KR",
      "title": 'koKr'.tr // 韩语
    },
    {
      "id": "ar_SA",
      "languageCode": "ar",
      "regionCode": "SA",
      "title": 'arSa'.tr // 阿拉伯语
    },
    {
      "id": "it_IT",
      "languageCode": "it",
      "regionCode": "IT",
      "title": 'itIt'.tr // 意大利语
    }
  ];

  LanguageState() {
    ///Initialize variables
  }
}
