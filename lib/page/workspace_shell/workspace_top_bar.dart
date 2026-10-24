import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 企业壳顶栏 — 对齐 DESIGN.md 8.1：44pt 行高、毛玻璃背景、底部 0.33pt
/// separator、标题 Body(17pt) w600（letterSpacing -0.4），规格与
/// [IosPageTemplate] 的 CupertinoNavigationBar 一致。
///
/// 企业壳内容区是 IndexedStack（各 tab 自带滚动体），不能整体套
/// Scaffold appBar，故以独立 widget 挂在壳 Column 顶部；消息/通讯录/
/// 工作台三个 tab 共用，保证壳内顶栏形态唯一（「我」tab 不挂顶栏——
/// 页面自身就是身份区，只留状态栏安全区占位）。
///
/// [subtitle] 非空时中央为双行（标题 + caption 副行），行高扩至 52pt，
/// 用于「企业名 · 工作区名」上下文（spec D1：挂顶栏的 tab 稳定可见、
/// 分层两级不拼第三段）；为空时行为与单行版本完全一致。
class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
  });

  final String title;

  /// 中央标题下方的一行上下文（如 企业名 · 工作区名）；null/空 = 单行。
  final String? subtitle;

  /// 左侧元素（企业壳挂汉堡菜单按钮）。
  final Widget? leading;

  /// 右侧动作（如通讯录 Tab 挂「邀请同事」入口；为空时标题仍绝对居中）。
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor =
        (isDark ? AppColors.darkSurfaceGrouped : AppColors.lightSurface)
            .withValues(alpha: 0.8);
    // leading 保留 8px（chip/返回键文字无内缩）；trailing 0 —— 44px 按钮
    // 盒已自带内缩，与 IosPageTemplate 的导航栏边距策略相同。
    final hasSubtitle = (subtitle ?? '').isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: barColor,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: hasSubtitle ? 52 : 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: AppSpacing.small,
                            ),
                            child: leading,
                          ),
                        ),
                      ),
                      // 中央标题必须是 tight 槽位：曾用 loose Flexible，其未用满的
                      // 宽度不会回流给两侧，而是按 mainAxisAlignment.start 堆在 Row
                      // 末尾——右上角动作离屏缘多出 ~28pt、标题整体左偏（Android
                      // 字形更窄时更明显）。两侧 1 : 中央 2，标题区可用宽度更大。
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
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
                            if (hasSubtitle)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  subtitle!,
                                  style: context.textStyle(
                                    FontSizeType.caption2,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: actions == null
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions!,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 0.33,
          color: AppColors.getIosSeparator(theme.brightness)
              .withValues(alpha: 0.4),
        ),
      ],
    );
  }
}
