import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/scanner/scanner_page.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class RightButton extends StatefulWidget {
  const RightButton({super.key});

  @override
  State<RightButton> createState() => _RightButtonState();
}

/// 导航栏图标尺寸，与 contact_page / group_list 的 action 图标对齐。
const double _navIconSize = 22;

class _RightButtonState extends State<RightButton> {
  final _addKey = GlobalKey();

  void _showAddMenu() {
    final renderBox = _addKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    // 菜单是瞬时浮层，i18n 文案在弹出时快照即可；导航动作捕获页面级
    // context（route 存活期内始终有效），避免依赖菜单自己的 context。
    final pageContext = context;
    Navigator.of(context, rootNavigator: true).push(
      _AddMenuRoute(
        anchor: renderBox.localToGlobal(Offset.zero) & renderBox.size,
        items: [
          _AddMenuEntry(
            icon: CupertinoIcons.chat_bubble,
            title: t.chat.initiateChat,
            action: () => pageContext.push('/launch_chat'),
          ),
          _AddMenuEntry(
            icon: CupertinoIcons.person_add,
            title: t.common.addFriend,
            action: () => pageContext.push('/contact/add_friend'),
          ),
          _AddMenuEntry(
            icon: CupertinoIcons.person,
            title: t.account.newlyRegisteredPeople,
            action: () => pageContext.push('/contact/recently_registered_user'),
          ),
          _AddMenuEntry(
            icon: CupertinoIcons.qrcode,
            title: t.account.myQrcode,
            action: () => pageContext.push('/qrcode'),
          ),
          _AddMenuEntry(
            icon: CupertinoIcons.qrcode_viewfinder,
            title: t.account.scanQrCode,
            action: () => Navigator.of(pageContext, rootNavigator: true).push(
              CupertinoPageRoute<dynamic>(builder: (_) => const ScannerPage()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 用 CupertinoIcons 而不是 Icons：Material 图标笔画明显更重，
        // 摆在导航栏上显得又粗又脏。DESIGN.md 7.1 规定 iOS 侧用 SF Symbols
        // （即 CupertinoIcons），仓里其他导航栏按钮也都是 CupertinoIcons + 22pt
        // （contact_page 的 person_add、group_list 的 refresh）。
        // CupertinoButton(padding: zero)：与 contact_page 导航栏按钮同款。
        // 此前 IconButton 默认内边距叠加外层 Padding，图标字面浮在距屏缘
        // ~37px 处（SDK trailing 16 + 外层 8 + 按钮内边距 13），比其他页面
        // 多出 10px；44px 点击热区不缩水。
        // 图标不显式指定颜色：继承 CupertinoButton 默认色调（iOS 系统蓝），
        // 与频道页导航按钮同款（曾显式 onSurface 黑色，两页不一致）。
        CupertinoButton(
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          onPressed: () => context.push('/message_search'),
          child: const Icon(CupertinoIcons.search, size: _navIconSize),
        ),
        CupertinoButton(
          key: _addKey,
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          onPressed: _showAddMenu,
          child: const Icon(CupertinoIcons.plus_circle, size: _navIconSize),
        ),
      ],
    );
  }
}

/// 弹层菜单项数据。action 已捕获页面级 context，菜单负责先 pop 再执行。
class _AddMenuEntry {
  const _AddMenuEntry({
    required this.icon,
    required this.title,
    required this.action,
  });

  final IconData icon;
  final String title;
  final VoidCallback action;
}

/// 「+」号弹层路由。
///
/// 替换 Material showMenu 的原因（2026-08-27 真机截图取证）：
/// - constraints maxWidth 160 把「新注册的人」「我的二维码」「扫描二维码」
///   挤成两行，图标与文字基线错位；
/// - showMenu 的 Material 菜单动画与全 app 的 Cupertino 视觉不统一。
/// iOS popover 语言：右上锚点 scale+fade 入场、轻遮罩点按关闭、
/// 单行菜单项 + 0.5pt 渐变 hairline 分隔线（与 MessageActionMenu 同款）。
class _AddMenuRoute extends PopupRoute<void> {
  _AddMenuRoute({required this.anchor, required this.items});

  /// 「+」按钮在屏幕（全局）坐标系下的位置。
  final Rect anchor;
  final List<_AddMenuEntry> items;

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
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        // 右缘与「+」按钮右缘对齐、顶部距按钮底部 6pt。
        // anchor 是全局坐标，route 页层同样从屏幕原点铺满，无需减安全区。
        padding: EdgeInsets.only(
          top: anchor.bottom + 6,
          right: size.width - anchor.right,
        ),
        child: _AddMenuPanel(items: items),
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
        alignment: Alignment.topRight,
        child: child,
      ),
    );
  }
}

class _AddMenuPanel extends StatelessWidget {
  const _AddMenuPanel({required this.items});

  final List<_AddMenuEntry> items;

  // 宽度自适应上限：最长文案撑多宽面板就多宽，但不超过 0.618（黄金
  // 分割）屏宽。超限文案在面板内流式换行（2026-08-27 用户拍板：换行
  // 优于省略号）；maxLines 2 + ellipsis 仅作极端长词的破版兜底。
  static const double _kMaxPanelScreenWidthRatio = 0.618;

  // 测试与调试定位面板用。
  static const Key _panelKey = ValueKey('add_menu_panel');

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(_hairline(context));
      }
      children.add(_menuItem(context, items[i]));
    }

    return Container(
      key: _panelKey,
      width: _panelWidth(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusLarge,
        // DESIGN.md §5.2：浮起 UI 单层柔光投影，与 MessageActionMenu 同参数。
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
  }

  /// 面板宽度 = 最长菜单文案的单行实测宽 + 行内固定元素，封顶 0.618 屏宽。
  ///
  /// 不用 IntrinsicWidth：内容固有宽超过 maxWidth 时，它给 child 的仍是
  /// 完整固有宽的 tight 约束、只缩小自己对外暴露的 size，面板会带着整行
  /// 文字静默溢出（2026-08-27 德语真机截图取证）。TextPainter 测量与最终
  /// 渲染同 style / textScaler，宽度以单行固有宽计量，与渲染是否换行无关。
  double _panelWidth(BuildContext context) {
    // 菜单项内固定宽：水平内边距 16×2 + 图标区 24 + 图标文字间距 12
    const rowFixedWidth = AppSpacing.regular * 2 + 24.0 + AppSpacing.medium;
    final style = context.textStyle(
      FontSizeType.medium,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var longest = 0.0;
    for (final item in items) {
      final tp = TextPainter(
        text: TextSpan(text: item.title, style: style),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: scaler,
      )..layout();
      longest = math.max(longest, tp.width);
      tp.dispose();
    }
    final screenWidth = MediaQuery.of(context).size.width;
    return math.min(
      rowFixedWidth + longest,
      screenWidth * _kMaxPanelScreenWidthRatio,
    );
  }

  Widget _menuItem(BuildContext context, _AddMenuEntry entry) {
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
        // 先关菜单再执行动作：反过来时 pop 会把 action 刚 push 的页面
        // 反手弹掉（MessageActionMenu 踩过的真机坑）。
        Navigator.of(context).pop();
        entry.action();
      },
      child: Row(
        // 两行文案时图标与首行文字顶对齐（center 会让图标悬在两行中间）。
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Icon(
              entry.icon,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          AppSpacing.horizontalMedium,
          // 面板宽度已由 _panelWidth 定死；超宽文案在此处换行（最多
          // 两行，ellipsis 只防极端长词破版），语义保持完整可读。
          Expanded(
            child: Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.medium,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hairline(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      // 两端渐隐的分隔线比通栏实线更轻，与 MessageActionMenu 保持一致。
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
