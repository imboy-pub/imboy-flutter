import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/config/const.dart';

part 'language_page.g.dart';

/// 语言 ID 到 AppLocale 的映射
const Map<String, AppLocale> localeIdMap = {
  'zh_CN': AppLocale.zhCn,
  'zh_TW': AppLocale.zhHant,
  'ru_RU': AppLocale.ruRu,
  'en_US': AppLocale.enUs,
  'fr_FR': AppLocale.frFr,
  'de_DE': AppLocale.deDe,
  'ja_JP': AppLocale.jaJp,
  'ko_KR': AppLocale.koKr,
  'ar_SA': AppLocale.arSa,
  'it_IT': AppLocale.itIt,
};

/// 语言模型
class LanguageModel {
  final String id;
  final String languageCode;
  final String regionCode;
  final String title;

  LanguageModel({
    required this.id,
    required this.languageCode,
    required this.regionCode,
    required this.title,
  });

  Map<String, String> toMap() {
    return {
      'id': id,
      'languageCode': languageCode,
      'regionCode': regionCode,
      'title': title,
    };
  }
}

/// Language 模块的状态
class LanguageState {
  final AppLocale currentLocale;
  final List<LanguageModel> languageList;

  const LanguageState({
    this.currentLocale = AppLocale.zhCn,
    this.languageList = const [],
  });

  LanguageState copyWith({
    AppLocale? currentLocale,
    List<LanguageModel>? languageList,
  }) {
    return LanguageState(
      currentLocale: currentLocale ?? this.currentLocale,
      languageList: languageList ?? this.languageList,
    );
  }
}

@riverpod
class LanguageNotifier extends _$LanguageNotifier {
  @override
  LanguageState build() {
    final savedLocaleName = StorageService.to.getString(
      Keys.currentLanguageCode,
    );
    AppLocale currentLocale = AppLocale.zhCn;
    if (savedLocaleName.isNotEmpty) {
      try {
        currentLocale = AppLocale.values.firstWhere(
          (locale) => locale.name == savedLocaleName,
          orElse: () => AppLocale.zhCn,
        );
      } catch (_) {}
    }

    return LanguageState(
      currentLocale: currentLocale,
      languageList: _buildLanguageList(),
    );
  }

  List<LanguageModel> _buildLanguageList() {
    // title 刻意硬编码为各语言的 endonym（自称），不走 i18n：语言名应恒显
    // 自身语言，外语用户才能在列表里认出自己的语言（QA#22）。
    return [
      LanguageModel(
        id: "zh_CN",
        languageCode: "zh",
        regionCode: "CN",
        title: '简体中文',
      ),
      LanguageModel(
        id: "zh_TW",
        languageCode: "zh",
        regionCode: "TW",
        title: '繁體中文',
      ),
      LanguageModel(
        id: "ru_RU",
        languageCode: "ru",
        regionCode: "RU",
        title: 'Русский',
      ),
      LanguageModel(
        id: "en_US",
        languageCode: "en",
        regionCode: "US",
        title: 'English',
      ),
      LanguageModel(
        id: "fr_FR",
        languageCode: "fr",
        regionCode: "FR",
        title: 'Français',
      ),
      LanguageModel(
        id: "de_DE",
        languageCode: "de",
        regionCode: "DE",
        title: 'Deutsch',
      ),
      LanguageModel(
        id: "ja_JP",
        languageCode: "ja",
        regionCode: "JP",
        title: '日本語',
      ),
      LanguageModel(
        id: "ko_KR",
        languageCode: "ko",
        regionCode: "KR",
        title: '한국어',
      ),
      LanguageModel(
        id: "ar_SA",
        languageCode: "ar",
        regionCode: "SA",
        title: 'العربية',
      ),
      LanguageModel(
        id: "it_IT",
        languageCode: "it",
        regionCode: "IT",
        title: 'Italiano',
      ),
    ];
  }

  Future<void> changeLanguage(String langId) async {
    final locale = localeIdMap[langId];
    if (locale == null) return;
    await StorageService.to.setString(Keys.currentLanguageCode, locale.name);
    await LocaleSettings.setLocale(locale);
    state = state.copyWith(currentLocale: locale);
  }
}

/// 语言设置页面 - 像素级对齐 iOS 设置风
class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final state = ref.watch(languageProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.languageSetting,
      useLargeTitle: false,
      child: ImBoySettingsSection(
        header: Text(t.common.selectLanguage.toUpperCase()),
        children: [
          for (var item in state.languageList)
            ImBoySettingsTile(
              title: Text(item.title),
              trailing: state.currentLocale == localeIdMap[item.id]
                  ? Icon(
                      CupertinoIcons.check_mark,
                      size: 18,
                      color: AppColors.getIosBlue(brightness),
                    )
                  : const SizedBox.shrink(),
              onTap: () =>
                  ref.read(languageProvider.notifier).changeLanguage(item.id),
            ),
        ],
      ),
    );
  }
}
