import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 通用锚定气泡菜单（iOS popover 语言），企业壳内「筛选下拉」与「+ 菜单」
/// 共用；个人模式的 RightButton 弹层暂不迁移，避免回归面扩大。
///
/// 视觉规格沿用 `_AddMenuPanel`（DESIGN.md §5.2 单层柔光投影、0.5pt 渐变
/// hairline、44pt 行高、0.618 屏宽封顶），可选项：顶部箭头缺口（锚定
/// 右上按钮时）、行尾 trailing（计数胶囊/红点）、选中态高亮。
enum PopoverMenuSide { topLeft, topRight }

class PopoverMenuEntry {
  const PopoverMenuEntry({
    required this.icon,
    required this.title,
    required this.action,
    this.foreground,
    this.selected = false,
    this.trailing,
    this.showDot = false,
  });

  /// 20-24pt 的行首图标（调用方决定着色）。
  final Widget icon;
  final String title;
  final VoidCallback action;

  /// 行首图标与文字的着色（空 = 常规 onSurface；选中/强调态传主色）。
  final Color? foreground;

  /// 选中态：整行按 [foreground] 高亮（筛选下拉的当前项）。
  final bool selected;

  /// 行尾元素（计数胶囊等），紧贴行末。
  final Widget? trailing;

  /// 行尾红点（新功能角标）。
  final bool showDot;
}

/// 弹出锚定于 [anchor]（全局坐标）下方的气泡菜单并阻塞至关闭。
///
/// 文案在弹出时快照（菜单是瞬时浮层）；动作捕获页面级 context，
/// 由本函数先 pop 再执行（顺序反了会把刚 push 的页面反手弹掉）。
Future<void> showPopoverMenu(
  BuildContext context, {
  required Rect anchor,
  required List<PopoverMenuEntry> entries,
  PopoverMenuSide side = PopoverMenuSide.topRight,
  bool showArrow = false,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    _PopoverMenuRoute(
      anchor: anchor,
      entries: entries,
      side: side,
      showArrow: showArrow,
    ),
  );
}

class _PopoverMenuRoute extends PopupRoute<void> {
  _PopoverMenuRoute({
    required this.anchor,
    required this.entries,
    required this.side,
    required this.showArrow,
  });

  final Rect anchor;
  final List<PopoverMenuEntry> entries;
  final PopoverMenuSide side;
  final bool showArrow;

  @override
  Color? get barrierColor => AppColors.overlayBlack10;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => t.common.buttonCancel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final size = MediaQuery.of(context).size;
    final alignRight = side == PopoverMenuSide.topRight;
    return Align(
      alignment: alignRight ? Alignment.topRight : Alignment.topLeft,
      child: Padding(
        // 右/左缘与锚点对齐、顶部距锚点底部 6pt（有箭头时给缺口留位）。
        // anchor 是全局坐标，route 页层同样从屏幕原点铺满。
        padding: EdgeInsets.only(
          top: anchor.bottom + 6,
          right: alignRight ? size.width - anchor.right : 0,
          left: alignRight ? 0 : anchor.left,
        ),
        child: _PopoverMenuPanel(
          entries: entries,
          showArrow: showArrow,
          arrowInset: 18,
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.72, end: 1.0).animate(curved),
        alignment: side == PopoverMenuSide.topRight
            ? Alignment.topRight
            : Alignment.topLeft,
        child: child,
      ),
    );
  }
}

class _PopoverMenuPanel extends StatelessWidget {
  const _PopoverMenuPanel({
    required this.entries,
    required this.showArrow,
    required this.arrowInset,
  });

  final List<PopoverMenuEntry> entries;
  final bool showArrow;
  final double arrowInset;

  // 宽度自适应上限：最长文案撑多宽面板就多宽，封顶 0.618 屏宽
  // （同 _AddMenuPanel 的取值依据：换行优于省略号）。
  static const double _kMaxPanelScreenWidthRatio = 0.618;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) children.add(_hairline(context));
      children.add(_menuItem(context, entries[i]));
    }
    final panel = Container(
      width: _panelWidth(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusLarge,
        boxShadow: [
          BoxShadow(
            color: AppColors.overlayBlack8,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    if (!showArrow) return panel;
    // 顶部箭头缺口：45° 旋转方块，与面板同色、同投影色（被面板压住的
    // 半边藏在面板后面，只露出上半个菱形）。
    return Stack(
      clipBehavior: Clip.none,
      children: [
        panel,
        Positioned(
          top: -5,
          right: arrowInset,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _panelWidth(BuildContext context) {
    // 菜单项内固定宽：水平内边距 16×2 + 图标区 24 + 图标文字间距 12。
    const rowFixedWidth = AppSpacing.regular * 2 + 24.0 + AppSpacing.medium;
    final style = context.textStyle(
      FontSizeType.medium,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var longest = 0.0;
    for (final entry in entries) {
      final tp = TextPainter(
        text: TextSpan(text: entry.title, style: style),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: scaler,
      )..layout();
      longest = math.max(longest, tp.width);
      tp.dispose();
    }
    // trailing（计数胶囊）约占 44pt：有 trailing 的行按最长文案 + 预留计。
    final hasTrailing = entries.any((entry) => entry.trailing != null);
    final screenWidth = MediaQuery.of(context).size.width;
    return math.min(
      rowFixedWidth + longest + (hasTrailing ? 44.0 : 0),
      screenWidth * _kMaxPanelScreenWidthRatio,
    );
  }

  Widget _menuItem(BuildContext context, PopoverMenuEntry entry) {
    final tint = entry.foreground ?? Theme.of(context).colorScheme.onSurface;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      // iOS HIG：可点击元素最小触达 44pt（DESIGN.md §13.2 Hard Rule 1）。
      minimumSize: const Size(0, 44),
      pressedOpacity: 0.55,
      onPressed: () {
        HapticFeedback.lightImpact();
        // 先关菜单再执行动作（MessageActionMenu 踩过的真机坑）。
        Navigator.of(context).pop();
        entry.action();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, height: 24, child: entry.icon),
          AppSpacing.horizontalMedium,
          Expanded(
            child: Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context
                  .textStyle(FontSizeType.medium, color: tint)
                  .copyWith(
                    fontWeight: entry.selected ? FontWeight.w600 : null,
                  ),
            ),
          ),
          if (entry.trailing != null) ...[
            AppSpacing.horizontalSmall,
            entry.trailing!,
          ],
          if (entry.showDot) ...[
            AppSpacing.horizontalSmall,
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: AppColors.iosRed,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hairline(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.transparent,
            Theme.of(context).dividerColor.withValues(alpha: 0.5),
            AppColors.transparent,
          ],
        ),
      ),
    );
  }
}

/// 计数胶囊（筛选下拉「全部/未读」行尾）。
class PopoverCountBadge extends StatelessWidget {
  const PopoverCountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      constraints: const BoxConstraints(minWidth: 24),
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHighest
            : AppColors.lightSurfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
