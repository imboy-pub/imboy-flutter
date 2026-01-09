import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'set_gender_logic.dart';

/// 设置性别页面
class SetGenderPage extends StatelessWidget {
  const SetGenderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(SetGenderLogic());
    final colorScheme = Theme.of(context).colorScheme;
    final themeManager = ThemeManager.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 性别选项列表
    final genderOptions = [
      {'id': '1', 'title': 'male'.tr, 'icon': Icons.male},
      {'id': '2', 'title': 'female'.tr, 'icon': Icons.female},
      {'id': '3', 'title': 'keepSecret'.tr, 'icon': Icons.help_outline},
    ];

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: 'gender'.tr,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: themeManager.mainSpace * 2,
          vertical: themeManager.mainSpace * 2,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(themeManager.mainSpace),
          child: Column(
            children: genderOptions.map((option) {
              return _buildGenderItem(context, option, logic);
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// 构建性别选项
  Widget _buildGenderItem(
    BuildContext context,
    Map<String, dynamic> option,
    SetGenderLogic logic,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeManager = ThemeManager.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isSelected = logic.selectedGender.value == option['id'];
      final isPending =
          logic.pendingGender.value == option['id'] && logic.isSaving.value;

      return Container(
        margin: EdgeInsets.only(bottom: themeManager.mainSpace),
        child: Material(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.2)
              : (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLowest),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: logic.isSaving.value
                ? null
                : () => logic.selectGender(option['id']),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: themeManager.mainSpace * 1.6,
                vertical: themeManager.mainSpace * 1.4,
              ),
              child: Row(
                children: [
                  // 性别图标
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.1)
                          : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      option['icon'],
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),

                  SizedBox(width: themeManager.mainSpace * 1.2),

                  // 性别文本
                  Expanded(
                    child: Text(
                      option['title'],
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.medium,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),

                  // 选中状态指示器 或 正在保存的 loading
                  if (isPending)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    )
                  else if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
