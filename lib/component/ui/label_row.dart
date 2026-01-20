import 'package:flutter/material.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 标签行组件 - 使用优化后的主题系统
class LabelRow extends StatelessWidget {
  final String? title;
  final String? label;
  final String? rValue;
  final Widget? trailing;
  final bool isLine;
  final double? lineWidth;
  final bool isRight;
  final bool isSpacer;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final bool showRipple;

  const LabelRow({
    super.key,
    this.title,
    this.label,
    this.rValue,
    this.trailing,
    this.isLine = true,
    this.lineWidth,
    this.isRight = true,
    this.isSpacer = true,
    this.margin,
    this.padding,
    this.onPressed,
    this.leadingIcon,
    this.leadingIconColor,
    this.showRipple = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      child: Column(
        children: [
          // 使用优化后的主题样式
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface, // 使用主题表面色
              borderRadius: BorderRadius.circular(0), // 保持原有的方形设计
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(0),
                splashColor: showRipple
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                highlightColor: showRipple
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : Colors.transparent,
                child: Container(
                  padding:
                      padding ??
                      const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 16.0,
                      ),
                  child: Row(
                    children: [
                      // 前导图标 - 使用优化后的主题样式
                      if (leadingIcon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (leadingIconColor ?? AppColors.primary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            leadingIcon!,
                            color: leadingIconColor ?? AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // 主要内容区域
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 标题 - 使用优化后的主题样式
                            Text(
                              title ?? label ?? ' ',
                              style: ThemeManager.instance.getTextStyle(
                                FontSizeType.normal,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface, // 使用主题文字色
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            // 副标题/值 - 使用优化后的主题样式
                            if (rValue != null && rValue!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                rValue!,
                                style: ThemeManager.instance.getTextStyle(
                                  FontSizeType.small,
                                  color: AppColors.textSecondary, // 使用主题次要文字色
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 尾部内容 - 使用优化后的主题样式
                      if (trailing != null)
                        trailing!
                      else if (isRight)
                        Icon(
                          Icons.navigate_next,
                          color: AppColors.textSecondary, // 使用主题次要文字色
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 分割线 - 使用优化后的主题样式
          if (isLine)
            Padding(
              padding: EdgeInsets.only(
                left: leadingIcon != null ? 56.0 : 16.0, // 如果有前导图标，分割线从内容开始
              ),
              child: HorizontalLine(
                height: lineWidth ?? 0.5,
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2), // 使用更淡的分割线
              ),
            ),
        ],
      ),
    );
  }
}

/// 现代化的设置项组件 - 使用优化后的主题系统
class ModernSettingItem extends StatelessWidget {
  const ModernSettingItem({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // 前导组件
                if (leading != null) ...[leading!, const SizedBox(width: 16)],

                // 主要内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: ThemeManager.instance.getTextStyle(
                            FontSizeType.small,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 值显示
                if (value != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.normal,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                // 尾部组件
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.navigate_next,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
