import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'language_logic.dart';
import 'language_state.dart';

class LanguagePage extends StatelessWidget {
  final LanguageLogic logic = Get.put(LanguageLogic());
  final LanguageState state = Get.find<LanguageLogic>().state;

  LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    state.currentLanguage.value =
        StorageService.to.getString(Keys.currentLang) ?? 'zh_CN';
    state.selectedLanguage.value =
        StorageService.to.getString(Keys.currentLang) ?? 'zh_CN';

    return Scaffold(
      appBar: AppBar(
        title: Text('language_setting'.tr),
        actions: [
          Obx(
            () => TextButton(
              onPressed: state.valueChanged.isTrue
                  ? () async {
                      logic.changeLanguage(state.selectedLanguage.value);
                    }
                  : null,
              child: Text(
                'button_accomplish'.tr,
                style: TextStyle(
                  color: state.valueChanged.isTrue
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: colorScheme.surface,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemBuilder: (BuildContext context, int index) {
          var model = state.languageList[index];
          return _buildLanguageItem(context, model);
        },
        itemCount: state.languageList.length,
      ),
    );
  }

  /// 构建语言选项
  Widget _buildLanguageItem(BuildContext context, Map<String, String> model) {
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(() {
      final isSelected = state.selectedLanguage.value == model['id'];

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(
            model['title'] ?? '',
            style: TextStyle(
              fontSize: 16,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          trailing: isSelected
              ? Icon(Icons.check, color: colorScheme.primary, size: 20)
              : null,
          onTap: () {
            state.selectedLanguage.value = model['id'] ?? 'zh_CN';
            state.valueChanged.value =
                state.selectedLanguage.value != state.currentLanguage.value;
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
      );
    });
  }
}
