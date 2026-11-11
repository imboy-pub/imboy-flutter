import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 桌面导航收起宽度：图标、角标和 48pt 触达区均可完整容纳。
const double kDesktopNavigationCollapsedWidth = 72;

/// 常规桌面/Web 展开宽度。
const double kDesktopNavigationExpandedWidth = 176;

/// 600–900pt 紧凑桌面窗口展开宽度，避免侧栏侵占消息主区。
const double kCompactDesktopNavigationExpandedWidth = 144;

/// 桌面导航展开偏好的跨壳共享本地键。
const String kDesktopNavigationExpandedPreferenceKey =
    'desktop_navigation_expanded';

Color _desktopNavigationRailBackground(Brightness brightness) {
  return brightness == Brightness.dark
      ? AppColors.darkSurfaceGroupedTertiary
      : AppColors.lightAppBarBackground;
}

/// Desktop/Web 左侧导航的布局上下文。
///
/// 需要随导航展开态调整的子组件（例如空间切换器）可读取 [expanded]，
/// 无需与具体壳页面或状态管理实现耦合。
class DesktopNavigationScope extends InheritedWidget {
  const DesktopNavigationScope({
    super.key,
    required this.expanded,
    required super.child,
  });

  final bool expanded;

  static DesktopNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopNavigationScope>();
  }

  @override
  bool updateShouldNotify(DesktopNavigationScope oldWidget) {
    return oldWidget.expanded != expanded;
  }
}

/// 桌面导航项的纯展示数据。
class DesktopNavigationItem {
  const DesktopNavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
    this.statusColor,
    this.controlKey,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  /// 在线/连接状态点；与未读数字角标语义区分。
  final Color? statusColor;

  /// 稳定测试与自动化入口，展开/收起状态下保持不变。
  final Key? controlKey;
}

/// macOS / Windows / Linux / Web 共用的可折叠桌面导航条。
///
/// 设计约束：
/// - 收起 72px，常规展开 176px；紧凑窗口可由宿主传 144px；
/// - 最后一个目的地默认固定到底部，与账号/“我”的信息架构一致；
/// - 选中、hover、焦点和宽度变化均使用同一套轻量动效；
/// - 导航层级由背景色阶和留白表达，不绘制横向分隔线或右侧描边；
/// - 展开态显示文案，收起态保留 Tooltip 与完整语义；
/// - 使用现有 Token，不引入平台专属图片或重复图标资产。
class DesktopNavigationRail extends StatelessWidget {
  const DesktopNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.expanded,
    required this.onToggleExpanded,
    required this.collapseLabel,
    required this.expandLabel,
    this.leading,
    this.collapsedWidth = kDesktopNavigationCollapsedWidth,
    this.expandedWidth = kDesktopNavigationExpandedWidth,
    this.pinLastItemToBottom = true,
  }) : assert(items.length >= 2, 'DesktopNavigationRail 至少需要 2 个 items'),
       assert(
         selectedIndex >= 0 && selectedIndex < items.length,
         'selectedIndex 越界',
       ),
       assert(collapsedWidth >= AppSizes.buttonHeightXLarge),
       assert(expandedWidth > collapsedWidth);

  final List<DesktopNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final String collapseLabel;
  final String expandLabel;
  final Widget? leading;
  final double collapsedWidth;
  final double expandedWidth;
  final bool pinLastItemToBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final railBackground = _desktopNavigationRailBackground(theme.brightness);
    final duration = AppDuration.respectReducedMotion(
      MediaQuery.disableAnimationsOf(context),
      AppDuration.slow,
    );

    return DesktopNavigationScope(
      expanded: expanded,
      child: AnimatedContainer(
        key: const ValueKey('desktop-navigation-rail'),
        duration: duration,
        curve: Curves.easeOutCubic,
        width: expanded ? expandedWidth : collapsedWidth,
        decoration: BoxDecoration(color: railBackground),
        clipBehavior: Clip.hardEdge,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 极矮窗口无法同时固定空间入口、“我”和收起按钮；此时让
              // 目的地与收起按钮进入滚动区，空间入口仍固定且所有操作可达。
              final pinFooter =
                  pinLastItemToBottom &&
                  constraints.maxHeight >=
                      AppSizes.drawerWidth + AppSizes.buttonHeightXLarge;
              final primaryCount = pinFooter ? items.length - 1 : items.length;

              return Column(
                children: [
                  AppSpacing.verticalSmall,
                  if (leading != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.small,
                      ),
                      child: SizedBox(width: double.infinity, child: leading!),
                    ),
                    AppSpacing.verticalRegular,
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('desktop-navigation-primary-scroll'),
                      primary: false,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var index = 0; index < primaryCount; index++)
                            _DesktopNavigationTile(
                              item: items[index],
                              expanded: expanded,
                              selected: selectedIndex == index,
                              onTap: () => onSelected(index),
                            ),
                          if (!pinFooter) ...[
                            AppSpacing.verticalRegular,
                            _collapseButton(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (pinFooter) ...[
                    AppSpacing.verticalRegular,
                    _DesktopNavigationTile(
                      item: items.last,
                      expanded: expanded,
                      selected: selectedIndex == items.length - 1,
                      onTap: () => onSelected(items.length - 1),
                    ),
                    _collapseButton(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _collapseButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.small,
        AppSpacing.tiny,
        AppSpacing.small,
        AppSpacing.small,
      ),
      child: _RailCollapseButton(
        expanded: expanded,
        label: expanded ? collapseLabel : expandLabel,
        onPressed: onToggleExpanded,
      ),
    );
  }
}

class _DesktopNavigationTile extends StatefulWidget {
  const _DesktopNavigationTile({
    required this.item,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final DesktopNavigationItem item;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DesktopNavigationTile> createState() => _DesktopNavigationTileState();
}

class _DesktopNavigationTileState extends State<_DesktopNavigationTile> {
  // 展开内容至少需要：40pt 图标槽 + 间距 + 可读文字/角标区域。
  static const double _expandedContentThreshold = 96;

  bool _hovered = false;

  Widget _glyph(BuildContext context, Color iconColor) {
    final theme = Theme.of(context);
    final railBackground = _desktopNavigationRailBackground(theme.brightness);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          widget.selected ? widget.item.activeIcon : widget.item.icon,
          color: iconColor,
          size: AppSizes.iconSizeMedium,
        ),
        if (widget.item.statusColor != null)
          Positioned(
            right: -AppSpacing.tiny,
            bottom: -AppSpacing.tiny,
            child: Container(
              width: AppSpacing.small,
              height: AppSpacing.small,
              decoration: BoxDecoration(
                color: widget.item.statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: railBackground, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _expandedContent(BuildContext context, Color iconColor) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: AppSizes.buttonHeightMedium,
          height: AppSizes.buttonHeightMedium,
          child: Center(child: _glyph(context, iconColor)),
        ),
        AppSpacing.horizontalSmall,
        Expanded(
          child: Text(
            widget.item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.medium,
              color: widget.selected ? scheme.primary : scheme.onSurface,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (widget.item.badgeCount > 0) ...[
          AppSpacing.horizontalSmall,
          _RailBadge(count: widget.item.badgeCount),
        ],
        AppSpacing.horizontalSmall,
      ],
    );
  }

  Widget _collapsedContent(BuildContext context, Color iconColor) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _glyph(context, iconColor),
          if (widget.item.badgeCount > 0)
            Positioned(
              top: -AppSpacing.small,
              right: -AppSpacing.medium,
              child: _RailBadge(count: widget.item.badgeCount),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = AppDuration.respectReducedMotion(
      MediaQuery.disableAnimationsOf(context),
      AppDuration.normal,
    );
    final iconColor = widget.selected
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final selectedBackground = theme.brightness == Brightness.dark
        ? AppColors.primaryAlpha20
        : AppColors.primaryLight;
    final background = widget.selected
        ? selectedBackground
        : _hovered
        ? scheme.surfaceContainerHighest
        : AppColors.transparent;

    return Tooltip(
      message: widget.item.label,
      excludeFromSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.tiny,
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: ClipRRect(
            borderRadius: AppRadius.borderRadiusMedium,
            child: Semantics(
              key: widget.item.controlKey,
              label: widget.item.label,
              button: true,
              selected: widget.selected,
              onTap: widget.onTap,
              child: ExcludeSemantics(
                child: CellPressable(
                  onTap: widget.onTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // expanded 在动画首帧会先于 rail 宽度变大；若立即渲染
                      // 展开 Row，72pt 旧宽度会产生 0.5px RenderFlex overflow。
                      // 以真实可用宽度决定内容形态，收起时立即移除宽布局，
                      // 展开时待空间足够再显示文案。
                      final showExpanded =
                          widget.expanded &&
                          constraints.maxWidth >= _expandedContentThreshold;

                      return AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        height: AppSizes.buttonHeightLarge,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: AppRadius.borderRadiusMedium,
                        ),
                        child: showExpanded
                            ? _expandedContent(context, iconColor)
                            : _collapsedContent(context, iconColor),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailBadge extends StatelessWidget {
  const _RailBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(
        minWidth: AppSizes.iconSizeXSmall,
        minHeight: AppSizes.iconSizeXSmall,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context
            .textStyle(
              FontSizeType.tiny,
              color: scheme.onError,
              fontWeight: FontWeight.w600,
            )
            .copyWith(height: 1.1),
      ),
    );
  }
}

/// 不使用 GestureDetector，避免给导航项测试与语义树额外引入匿名手势节点；
/// 键盘、指针、hover、焦点反馈在此显式处理。
class _RailCollapseButton extends StatefulWidget {
  const _RailCollapseButton({
    required this.expanded,
    required this.label,
    required this.onPressed,
  });

  final bool expanded;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_RailCollapseButton> createState() => _RailCollapseButtonState();
}

class _RailCollapseButtonState extends State<_RailCollapseButton> {
  // 24pt 图标 + 8pt 间距 + 最小文字区域，再加展开态 12pt×2 内边距。
  static const double _expandedControlThreshold = 72;

  bool _hovered = false;
  bool _focused = false;
  bool _primaryPointerDown = false;

  void _activate() {
    HapticFeedback.selectionClick();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = AppDuration.respectReducedMotion(
      MediaQuery.disableAnimationsOf(context),
      AppDuration.normal,
    );

    final control = Semantics(
      key: const ValueKey('desktop-navigation-collapse-toggle'),
      label: widget.label,
      button: true,
      onTap: _activate,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) {
          if (_focused == value) return;
          setState(() => _focused = value);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _primaryPointerDown =
                  (event.buttons & kPrimaryMouseButton) != 0 ||
                  event.kind != PointerDeviceKind.mouse;
            },
            onPointerCancel: (_) => _primaryPointerDown = false,
            onPointerUp: (_) {
              final shouldActivate = _primaryPointerDown;
              _primaryPointerDown = false;
              if (shouldActivate) _activate();
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 与导航项相同，展开布尔值会先于父 rail 宽度动画生效。
                // 只有实际空间足够时才加入文字与水平内边距。
                final showLabel =
                    widget.expanded &&
                    constraints.maxWidth >= _expandedControlThreshold;

                return AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  height: AppSizes.touchTarget,
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: showLabel ? AppSpacing.medium : AppSpacing.none,
                  ),
                  decoration: BoxDecoration(
                    color: _hovered
                        ? scheme.surfaceContainerHighest
                        : AppColors.transparent,
                    borderRadius: AppRadius.borderRadiusMedium,
                    border: _focused
                        ? Border.all(color: scheme.primary, width: 1.5)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: showLabel
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      AnimatedRotation(
                        duration: duration,
                        turns: widget.expanded ? 0 : 0.5,
                        child: Icon(
                          Icons.keyboard_double_arrow_left_rounded,
                          size: AppSizes.iconSizeMedium,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (showLabel) ...[
                        AppSpacing.horizontalSmall,
                        Expanded(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyle(
                              FontSizeType.small,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (widget.expanded) return control;
    return Tooltip(
      message: widget.label,
      excludeFromSemantics: true,
      child: control,
    );
  }
}
