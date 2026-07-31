import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// Badge overlay widget — replaces package:badges.
///
/// Usage:
/// ```dart
/// BadgeWidget(
///   content: Text('3'),
///   color: Colors.red,
///   top: -4, right: -4,
///   child: Icon(Icons.chat),
/// )
/// // Dot badge (no content):
/// BadgeWidget(color: statusColor, padding: EdgeInsets.all(4), child: icon)
/// ```
class BadgeWidget extends StatelessWidget {
  const BadgeWidget({
    super.key,
    required this.child,
    this.content,
    this.showBadge = true,
    this.color = AppColors.iosRed,
    this.padding = const EdgeInsets.all(5),
    this.borderRadius,
    this.borderSide,
    this.top = -4.0,
    this.bottom,
    this.left,
    this.right = -4.0,
    this.semanticLabel,
  });

  final Widget child;
  final Widget? content;
  final bool showBadge;
  final Color color;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final BorderSide? borderSide;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  /// 读屏标签，如「5 条未读」（DESIGN.md 11.4）。
  ///
  /// 不传的话读屏只会念出一个孤零零的数字——接在昵称和消息预览后面，
  /// 「张三 晚点聊 5」完全看不出这个 5 是什么。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child;

    final decoration = BoxDecoration(
      color: color,
      borderRadius: borderRadius ?? BorderRadius.circular(99),
      border: borderSide != null ? Border.fromBorderSide(borderSide!) : null,
    );

    // 无 content 的圆点角标：尺寸只由 padding 决定，本来就是正方 → 正圆。
    if (content == null) {
      return _stack(
        _withSemantics(Container(padding: padding, decoration: decoration)),
      );
    }

    // 有 content（未读数）时不能只靠 padding：数字的字宽比行高窄，
    // 上下 padding 又把高度再撑一截，结果是竖椭圆
    // （实测 caption2 + padding:5 → 21.3 × 26.0）。
    //
    // 改为「固定直径 + 只留水平内边距」：
    //   - 高度锁定 diameter，不再被行高撑开
    //   - 宽度 minWidth == diameter，1~2 位数正好是正圆
    //   - "99+" 这类超宽内容自然长成胶囊（borderRadius 99 两端仍是半圆）
    // diameter 跟随系统字号缩放，大字体下不会把数字挤掉。
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final diameter = _baseDiameter * scale;

    return _stack(
      _withSemantics(
        Container(
          height: diameter,
          constraints: BoxConstraints(minWidth: diameter),
          // 水平内边距固定且很小：不沿用调用方的 padding（那是给旧的
          // 「靠 padding 撑圆」写法用的，10pt 会把 1 位数也顶出 diameter）。
          // 只服务多位数不贴边，1~2 位数由 minWidth 兜成正圆。
          padding: const EdgeInsets.symmetric(horizontal: _contentHPadding),
          alignment: Alignment.center,
          decoration: decoration,
          child: content,
        ),
      ),
    );
  }

  /// 有标签时把数字本身挡掉，避免读屏把「5 条未读」和「5」念两遍。
  Widget _withSemantics(Widget badge) {
    if (semanticLabel == null) return badge;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: badge),
    );
  }

  /// iOS 未读角标基准直径（默认字号下）。
  static const double _baseDiameter = 18.0;

  /// 有内容时的水平内边距（单侧）。只为多位数留出呼吸位；
  /// 1~2 位数的宽度由 minWidth == diameter 兜底成正圆。
  static const double _contentHPadding = 4.0;

  Widget _stack(Widget badge) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: top,
          bottom: bottom,
          left: left,
          right: right,
          child: badge,
        ),
      ],
    );
  }
}
