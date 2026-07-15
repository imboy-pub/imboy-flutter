import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// iOS 风格页面模板
/// 采用紧凑型设计，确保标题与动作按钮在同一行，最大化屏幕利用率
class IosPageTemplate extends StatelessWidget {
  const IosPageTemplate({
    super.key,
    required this.title,
    this.child,
    this.slivers,
    this.actions,
    this.useLargeTitle = false, // 默认改为紧凑模式
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

    // 强制背景色逻辑：亮色 F2F2F7，暗色 1C1C1E
    final bgColor =
        backgroundColor ??
        (isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurfaceGrouped);

    final navBarColor =
        (isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurface)
            .withValues(alpha: 0.8);

    final navBar = CupertinoNavigationBar(
      middle: Text(
        title,
        style: context
            .textStyle(
              FontSizeType.body,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            )
            .copyWith(letterSpacing: -0.4),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: navBarColor,
      border: Border(
        bottom: BorderSide(
          color: AppColors.getIosSeparator(
            theme.brightness,
          ).withValues(alpha: 0.4),
          width: 0.33,
        ),
      ),
      trailing: actions != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions!,
            )
          : null,
    );

    // 核心重构：即便有 slivers，我们也使用固定高度的 appBar，确保 title 和返回键永远在同一行
    return Scaffold(
      backgroundColor: bgColor,
      appBar: navBar,
      body: _buildBody(context, bgColor),
      bottomNavigationBar: bottomWidget,
    );
  }

  Widget _buildBody(BuildContext context, Color bgColor) {
    if (slivers != null) {
      return CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: slivers!,
      );
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Column(
        children: [
          ?child,
          // 如果没有 bottomWidget，给底部留点呼吸空间
          if (bottomWidget == null) const SizedBox(height: 40),
        ],
      ),
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

    final headerColor = isDark
        ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
        : AppColors.lightTextSecondary.withValues(alpha: 0.5);
    final headerStyle = context
        .textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w400,
          color: headerColor,
        )
        .copyWith(letterSpacing: -0.05);
    final footerStyle = context
        .textStyle(
          FontSizeType.small,
          fontWeight: FontWeight.w400,
          color: headerColor,
        )
        .copyWith(letterSpacing: -0.05);

    return CupertinoListSection.insetGrouped(
      header: header is Text
          ? Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                (header as Text).data!,
                style: headerStyle.merge((header as Text).style),
              ),
            )
          : header,
      footer: footer is Text
          ? Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(
                (footer as Text).data!,
                style: footerStyle.merge((footer as Text).style),
              ),
            )
          : footer,
      margin: margin ?? const EdgeInsets.fromLTRB(16, 24, 16, 0),
      backgroundColor: AppColors.transparent,
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

    final titleStyle = context
        .textStyle(
          FontSizeType.body,
          fontWeight: FontWeight.w400,
          color: destructive
              ? AppColors.getIosRed(theme.brightness)
              : (isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary),
        )
        .copyWith(letterSpacing: -0.4);

    final subtitleStyle = context.textStyle(
      FontSizeType.subheadline,
      color: isDark
          ? AppColors.darkTextSecondary.withValues(alpha: 0.6)
          : AppColors.lightTextSecondary.withValues(alpha: 0.6),
    );

    return CupertinoListTile.notched(
      title: title is Text
          ? Text(
              (title as Text).data!,
              style: titleStyle.merge((title as Text).style),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : title,
      subtitle: subtitle is Text
          ? Text(
              (subtitle as Text).data!,
              style: subtitleStyle.merge((subtitle as Text).style),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : subtitle,
      leading: leading,
      trailing:
          trailing ?? (onTap != null ? const CupertinoListTileChevron() : null),
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      backgroundColor:
          backgroundColor ??
          (isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

/// iOS 风格普通列表项
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
        color:
            backgroundColor ??
            (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: context
                        .textStyle(
                          FontSizeType.body,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        )
                        .copyWith(letterSpacing: -0.4),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    DefaultTextStyle(
                      style: context
                          .textStyle(
                            FontSizeType.normal,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? AppColors.darkTextSecondary.withValues(
                                    alpha: 0.7,
                                  )
                                : AppColors.lightTextSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                          )
                          .copyWith(letterSpacing: -0.2, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}
