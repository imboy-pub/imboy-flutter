import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// iOS 风格页面模板
/// 支持标准/大标题导航栏、毛玻璃效果、统一背景色
class IosPageTemplate extends StatelessWidget {
  const IosPageTemplate({
    super.key,
    required this.title,
    this.child,
    this.slivers,
    this.actions,
    this.useLargeTitle = true,
    this.backgroundColor,
    this.bottomWidget,
  });

  final String title;
  final Widget? child;
  final List<Widget>? slivers;
  final List<Widget>? actions;
  final bool useLargeTitle;
  final Color? backgroundColor;
  final Widget? bottomWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 背景色：亮色用 iosGray6 (#F2F2F7)，暗色用 darkSurfaceGrouped (#1C1C1E)
    final bgColor = backgroundColor ??
        (isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurfaceGrouped);

    final List<Widget> allSlivers = [
      CupertinoSliverNavigationBar(
        largeTitle: Text(
          title,
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            letterSpacing: -1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        middle: !useLargeTitle
            ? Text(
                title,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              )
            : null,
        backgroundColor: (isDark ? AppColors.darkSurfaceGrouped : Colors.white).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: AppColors.getIosSeparator(theme.brightness).withValues(alpha: 0.4),
            width: 0.33,
          ),
        ),
        trailing: actions != null ? Row(mainAxisSize: MainAxisSize.min, children: actions!) : null,
        stretch: true,
      ),
    ];

    if (slivers != null) {
      allSlivers.addAll(slivers!);
    } else if (child != null) {
      allSlivers.add(SliverToBoxAdapter(child: child!));
    }

    if (bottomWidget == null) {
      allSlivers.add(const SliverToBoxAdapter(child: SizedBox(height: 60)));
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: allSlivers,
      ),
      bottomNavigationBar: bottomWidget,
    );
  }
}

/// iOS 风格设置分组
class ImBoySettingsSection extends StatelessWidget {
  const ImBoySettingsSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: isDark ? AppColors.darkTextSecondary.withValues(alpha: 0.5) : AppColors.lightTextSecondary.withValues(alpha: 0.5),
      letterSpacing: -0.05,
    );

    return CupertinoListSection.insetGrouped(
      header: header is Text 
          ? Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text((header as Text).data!, style: headerStyle.merge((header as Text).style)),
            )
          : header,
      footer: footer is Text
          ? Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text((footer as Text).data!, style: headerStyle.copyWith(fontSize: 12).merge((footer as Text).style)),
            )
          : footer,
      margin: margin ?? const EdgeInsets.fromLTRB(16, 24, 16, 0),
      backgroundColor: Colors.transparent,
      dividerMargin: 56,
      children: children,
    );
  }
}

/// iOS 风格设置列表项
class ImBoySettingsTile extends StatelessWidget {
  const ImBoySettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.backgroundColor,
    this.padding,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w400,
      color: destructive 
          ? AppColors.getIosRed(theme.brightness)
          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
    );

    final subtitleStyle = TextStyle(
      fontSize: 15,
      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
    );

    return CupertinoListTile.notched(
      title: title is Text 
          ? Text((title as Text).data!, style: titleStyle.merge((title as Text).style))
          : title,
      subtitle: subtitle is Text
          ? Text((subtitle as Text).data!, style: subtitleStyle.merge((subtitle as Text).style))
          : subtitle,
      leading: leading,
      trailing: trailing ?? (onTap != null ? const CupertinoListTileChevron() : null),
      onTap: onTap,
      backgroundColor: backgroundColor ?? (isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}

/// iOS 风格普通列表项 (用于消息列表、联系人列表)
class ImBoyListTile extends StatelessWidget {
  const ImBoyListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.height,
    this.padding,
    this.backgroundColor,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        color: backgroundColor ?? (isDark ? AppColors.darkSurface : Colors.white),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      letterSpacing: -0.4,
                    ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        letterSpacing: -0.2,
                      ),
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
