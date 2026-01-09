import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/service/storage.dart';

import 'language_logic.dart';
import 'language_state.dart';

class LanguagePage extends StatelessWidget {
  final LanguageLogic logic = Get.put(LanguageLogic());
  final LanguageState state = Get.find<LanguageLogic>().state;

  LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    state.currentLanguage.value =
        StorageService.to.getString(Keys.currentLang) ?? 'zh_CN';
    state.selectedLanguage.value =
        StorageService.to.getString(Keys.currentLang) ?? 'zh_CN';

    return Scaffold(
      appBar: GlassAppBar(
        title: 'languageSetting'.tr,
        automaticallyImplyLeading: true,
        rightDMActions: [
          Obx(
            () => TextButton(
              onPressed: state.valueChanged.isTrue
                  ? () async {
                      logic.changeLanguage(state.selectedLanguage.value);
                    }
                  : null,
              child: Text(
                'buttonAccomplish'.tr,
                style: TextStyle(
                  color: state.valueChanged.isTrue
                      ? AppColors.primaryGreen
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? colorScheme.shadow.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: isDark
                ? Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.15),
                    width: 0.5,
                  )
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (BuildContext context, int index) {
              var model = state.languageList[index];
              return _buildLanguageItem(context, model);
            },
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              indent: 16,
              endIndent: 16,
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
            itemCount: state.languageList.length,
          ),
        ),
      ),
    );
  }

  /// 构建语言选项
  Widget _buildLanguageItem(BuildContext context, Map<String, String> model) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isSelected = state.selectedLanguage.value == model['id'];

      return Material(
        color: isSelected
            ? (isDark
                ? AppColors.primaryGreen.withValues(alpha: 0.15)
                : const Color(0xFFE8F5E9))
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            state.selectedLanguage.value = model['id'] ?? 'zh_CN';
            state.valueChanged.value =
                state.selectedLanguage.value != state.currentLanguage.value;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    model['title'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? AppColors.primaryGreen : AppColors.primaryGreen)
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    color: isDark ? AppColors.primaryGreen : AppColors.primaryGreen,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
