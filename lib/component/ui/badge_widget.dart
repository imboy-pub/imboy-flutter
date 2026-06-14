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

  @override
  Widget build(BuildContext context) {
    if (!showBadge) return child;

    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(99),
        border: borderSide != null ? Border.fromBorderSide(borderSide!) : null,
      ),
      child: content,
    );

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
