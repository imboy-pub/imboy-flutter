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
      "title": "简体中文".tr
    },
    // {
    //   "id": "zh_TW",
    //   "languageCode": "zh",
    //   "regionCode": "TW",
    //   "title": "繁体中文".tr
    // },
    // {
    //   "id": "ru_RU",
    //   "languageCode": "ru",
    //   "regionCode": "RU",
    //   "title": "俄罗斯俄语".tr
    // },
    // {
    //   "id": "en_GB",
    //   "languageCode": "en",
    //   "regionCode": "GB",
    //   "title": "英国英语".tr
    // },
    {
      "id": "en_US",
      "languageCode": "en",
      "regionCode": "US",
      "title": "美国英语".tr
    }
  ];
  LanguageState() {
    ///Initialize variables
  }
}
