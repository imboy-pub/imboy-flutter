import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
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
  final bool valueChanged;
  final AppLocale currentLocale;
  final AppLocale? selectedLocale;
  final String? selectedLocaleId; // 添加语言 ID 字段
  final List<LanguageModel> languageList;

  const LanguageState({
    this.valueChanged = false,
    this.currentLocale = AppLocale.zhCn,
    this.selectedLocale,
    this.selectedLocaleId, // 添加语言 ID 字段
    this.languageList = const [],
  });

  LanguageState copyWith({
    bool? valueChanged,
    AppLocale? currentLocale,
    AppLocale? selectedLocale,
    String? selectedLocaleId, // 添加语言 ID 字段
    List<LanguageModel>? languageList,
  }) {
    return LanguageState(
      valueChanged: valueChanged ?? this.valueChanged,
      currentLocale: currentLocale ?? this.currentLocale,
      selectedLocale: selectedLocale ?? this.selectedLocale,
      selectedLocaleId: selectedLocaleId ?? this.selectedLocaleId, // 添加语言 ID 字段
      languageList: languageList ?? this.languageList,
    );
  }
}

@riverpod
class LanguageNotifier extends _$LanguageNotifier {
  @override
  LanguageState build() {
    // 从存储中读取当前语言（使用枚举名称如 'zhCn'）
    final savedLocaleName = StorageService.to.getString(
      Keys.currentLanguageCode,
    );

    AppLocale currentLocale = AppLocale.zhCn; // 默认值
    if (savedLocaleName.isNotEmpty) {
      try {
        // 通过枚举名称查找 AppLocale（如 'zhCn' -> AppLocale.zhCn）
        currentLocale = AppLocale.values.firstWhere(
          (locale) => locale.name == savedLocaleName,
          orElse: () => AppLocale.zhCn,
        );
      } catch (e) {
        debugPrint('LanguageNotifier: 解析保存的语言失败 - $e');
      }
    }

    // 根据 AppLocale 查找对应的语言 ID
    String? selectedLocaleId;
    try {
      selectedLocaleId = localeIdMap.entries
          .firstWhere((entry) => entry.value == currentLocale)
          .key;
    } catch (e) {
      debugPrint('LanguageNotifier: 查找语言 ID 失败 - $e');
    }

    return LanguageState(
      currentLocale: currentLocale,
      selectedLocale: currentLocale,
      selectedLocaleId: selectedLocaleId,
      languageList: _buildLanguageList(),
    );
  }

  /// 构建语言列表
  List<LanguageModel> _buildLanguageList() {
    return [
      LanguageModel(
        id: "zh_CN",
        languageCode: "zh",
        regionCode: "CN",
        title: t.zhCn,
      ),
      LanguageModel(
        id: "zh_TW",
        languageCode: "zh",
        regionCode: "TW",
        title: t.zhHant,
      ),
      LanguageModel(
        id: "ru_RU",
        languageCode: "ru",
        regionCode: "RU",
        title: t.ruRu,
      ),
      LanguageModel(
        id: "en_US",
        languageCode: "en",
        regionCode: "US",
        title: t.enUs,
      ),
      LanguageModel(
        id: "fr_FR",
        languageCode: "fr",
        regionCode: "FR",
        title: t.frFr,
      ),
      LanguageModel(
        id: "de_DE",
        languageCode: "de",
        regionCode: "DE",
        title: t.deDd,
      ),
      LanguageModel(
        id: "ja_JP",
        languageCode: "ja",
        regionCode: "JP",
        title: t.jaJp,
      ),
      LanguageModel(
        id: "ko_KR",
        languageCode: "ko",
        regionCode: "KR",
        title: t.koKr,
      ),
      LanguageModel(
        id: "ar_SA",
        languageCode: "ar",
        regionCode: "SA",
        title: t.arSa,
      ),
      LanguageModel(
        id: "it_IT",
        languageCode: "it",
        regionCode: "IT",
        title: t.itIt,
      ),
    ];
  }

  /// 切换语言
  Future<void> changeLanguage(String langId) async {
    // 从映射中获取 AppLocale
    final locale = localeIdMap[langId];
    if (locale == null) {
      debugPrint('LanguageNotifier: 未找到语言 - $langId');
      return;
    }

    // 保存语言设置到本地存储（使用枚举名称如 'zhCn'）
    await StorageService.to.setString(Keys.currentLanguageCode, locale.name);

    // 使用 slang 的 LocaleSettings.setLocale 方法切换语言
    await LocaleSettings.setLocale(locale);

    // 更新状态
    state = state.copyWith(
      currentLocale: locale,
      selectedLocale: locale,
      valueChanged: false,
    );
  }

  /// 更新选中的语言
  void updateSelectedLanguage(String langId) {
    final locale = localeIdMap[langId];
    if (locale == null) return;

    state = state.copyWith(
      selectedLocale: locale,
      selectedLocaleId: langId,
      valueChanged: locale != state.currentLocale,
    );
  }

  /// 获取系统支持的 regionCode 列表
  List<String> getRegionCodeList() {
    return state.languageList.map((lang) => lang.regionCode).toList();
  }
}

class LanguagePage extends ConsumerWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final t = context.t;
    final state = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.languageSetting,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RadioGroup<AppLocale>(
                groupValue: state.selectedLocale,
                onChanged: (val) {
                  if (val == null) return;
                  // 根据选中的 AppLocale 查找对应的语言 ID
                  final langId = localeIdMap.entries
                      .firstWhere(
                        (entry) => entry.value == val,
                        orElse: () => localeIdMap.entries.first,
                      )
                      .key;
                  ref
                      .read(languageProvider.notifier)
                      .updateSelectedLanguage(langId);
                },
                child: ListView.builder(
                  itemCount: state.languageList.length,
                  itemBuilder: (context, index) {
                    final item = state.languageList[index];
                    final locale = localeIdMap[item.id]!;
                    return InkWell(
                      onTap: () {
                        ref
                            .read(languageProvider.notifier)
                            .updateSelectedLanguage(item.id);
                      },
                      child: ListTile(
                        title: Text(item.title),
                        trailing: Radio<AppLocale>(value: locale),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      state.valueChanged && state.selectedLocaleId != null
                      ? () async {
                          await ref
                              .read(languageProvider.notifier)
                              .changeLanguage(state.selectedLocaleId!);
                          if (context.mounted) {
                            Navigator.of(context).maybePop();
                          }
                        }
                      : null,
                  child: Text(t.buttonSave),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
