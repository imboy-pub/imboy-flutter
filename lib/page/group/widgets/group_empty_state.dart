import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群聊模块统一空状态组件。
///
/// 替代 NoDataView，支持图标+文案+可选 CTA 按钮。
/// 用法：
/// ```dart
/// GroupEmptyState(
///   icon: CupertinoIcons.person_2,
///   title: '暂无群聊',
///   subtitle: '创建一个群聊开始聊天',
///   actionLabel: '创建群聊',
///   onAction: () => ...,
/// )
/// ```
class GroupEmptyState extends StatelessWidget {
  const GroupEmptyState({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// 空状态图标（默认群图标）
  final IconData? icon;

  /// 主标题
  final String? title;

  /// 副标题
  final String? subtitle;

  /// 操作按钮文案
  final String? actionLabel;

  /// 操作按钮回调
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: AppSpacing.allXXLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? CupertinoIcons.person_2,
              size: 64,
              color: isDark ? AppColors.darkTextDisabled : AppColors.iosGray,
            ),
            AppSpacing.verticalLarge,
            if (title != null)
              Text(
                title!,
                style: TextStyle(
                  fontSize: FontSizeType.large.size,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            if (subtitle != null) ...[
              AppSpacing.verticalSmall,
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: FontSizeType.normal.size,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.iosGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.verticalXLarge,
              CupertinoButton.filled(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
