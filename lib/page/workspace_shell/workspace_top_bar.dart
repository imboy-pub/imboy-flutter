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
/// 工作台/我 四个 tab 共用，保证壳内顶栏形态唯一。
class WorkspaceTopBar extends StatelessWidget {
  const WorkspaceTopBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  final String title;

  /// 左侧元素（企业壳挂 WorkspaceSwitcherChip）。
  final Widget? leading;

  /// 右侧动作（企业壳挂 WorkspaceAccountButton；为空时标题仍绝对居中）。
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
                  height: 44,
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
                      Text(
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
