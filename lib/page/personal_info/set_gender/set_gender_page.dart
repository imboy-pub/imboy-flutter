import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'set_gender_provider.dart';

/// 设置性别页面
class SetGenderPage extends ConsumerWidget {
  const SetGenderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 性别选项列表
    final genderOptions = [
      {'id': '1', 'title': t.male, 'icon': Icons.male},
      {'id': '2', 'title': t.female, 'icon': Icons.female},
      {'id': '3', 'title': t.keepSecret, 'icon': Icons.help_outline},
    ];

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(title: t.gender, automaticallyImplyLeading: true),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.regular * 2,
          vertical: AppSpacing.regular * 2,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: AppRadius.borderRadiusRegular,
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
          padding: EdgeInsets.all(AppSpacing.regular),
          child: Column(
            children: genderOptions
                .map((option) => _buildGenderItem(context, ref, option))
                .toList(),
          ),
        ),
      ),
    );
  }

  /// 构建性别选项
  Widget _buildGenderItem(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> option,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(setGenderProvider);

    final isSelected = state.selectedGender == option['id'];
    final isPending = state.pendingGender == option['id'] && state.isSaving;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.regular),
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.2)
            : (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surfaceContainerLowest),
        borderRadius: AppRadius.borderRadiusMedium,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusMedium,
          onTap: state.isSaving
              ? null
              : () async {
                  final success = await ref
                      .read(setGenderProvider.notifier)
                      .selectGender(option['id'], ref);
                  if (success && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.regular * 1.6,
              vertical: AppSpacing.regular * 1.4,
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
                    borderRadius: AppRadius.borderRadiusLarge,
                  ),
                  child: Icon(
                    option['icon'],
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ),

                SizedBox(width: AppSpacing.regular * 1.2),

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
  }
}
