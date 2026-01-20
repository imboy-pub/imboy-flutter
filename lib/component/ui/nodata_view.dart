import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 无数据视图组件 - 使用优化后的主题系统
class NoDataView extends StatelessWidget {
  final String text;
  final VoidCallback? onTop;
  final IconData? icon;
  final String? description;

  const NoDataView({
    super.key,
    required this.text,
    this.onTop,
    this.icon,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTop,
        borderRadius: BorderRadius.circular(12), // 添加圆角点击效果
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标 - 使用主题色
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon!,
                    size: 48,
                    color: AppColors.textSecondary, // 使用主题次要文字色
                  ),
                ),
              if (icon != null) const SizedBox(height: 16),

              // 主要文本 - 使用优化后的主题样式
              Text(
                text,
                style: ThemeManager.instance.getTextStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary, // 使用主题次要文字色
                ),
                textAlign: TextAlign.center,
              ),

              // 描述文本 - 使用优化后的主题样式
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(
                  description!,
                  style: ThemeManager.instance.getTextStyle(
                    FontSizeType.small,
                    color: AppColors.textSecondary.withValues(
                      alpha: 0.7,
                    ), // 使用更淡的次要文字色
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // 点击提示 - 如果有点击事件
              if (onTop != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    t.buttonRetry,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      color: AppColors.primary, // 使用主题主色
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
