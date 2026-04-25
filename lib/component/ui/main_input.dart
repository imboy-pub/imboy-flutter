import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 主输入容器组件 - 使用优化后的主题系统
class MainInputBody extends StatefulWidget {
  const MainInputBody({
    super.key,
    this.child,
    this.color,
    this.decoration,
    this.onTap,
    this.borderRadius,
    this.padding,
  });

  final Widget? child;
  final Color? color;
  final Decoration? decoration;
  final GestureTapCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  State<StatefulWidget> createState() => MainInputBodyState();
}

class MainInputBodyState extends State<MainInputBody> {
  @override
  Widget build(BuildContext context) {
    // 使用主题色作为默认背景色
    final defaultColor = widget.color ?? Theme.of(context).colorScheme.surface;

    return Container(
      decoration:
          widget.decoration ??
          BoxDecoration(
            color: defaultColor,
            borderRadius: widget.borderRadius ?? AppRadius.borderRadiusSmall,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.02),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
      height: double.infinity,
      width: double.infinity,
      padding: widget.padding,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: widget.borderRadius ?? AppRadius.borderRadiusSmall,
          onTap: () {
            // 隐藏键盘
            FocusScope.of(context).requestFocus(FocusNode());
            if (widget.onTap != null) {
              widget.onTap!();
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: widget.padding ?? const EdgeInsets.all(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 现代化的输入容器组件 - 使用优化后的主题系统
class ModernInputContainer extends StatelessWidget {
  const ModernInputContainer({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 12.0,
    this.padding,
    this.margin,
    this.elevation = 0,
    this.isEnabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double elevation;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).colorScheme.surface;
    final effectiveBorderColor =
        borderColor ??
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorderColor, width: 1),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: isEnabled ? onTap : null,
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
