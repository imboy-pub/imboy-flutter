import 'package:flutter/material.dart';
import 'package:imboy/config/theme.dart';
import 'package:niku/namespace.dart' as n;

class ButtonRow extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final String? text;
  final TextStyle? style;
  final VoidCallback? onPressed;
  final bool isBorder;
  final double? lineWidth;

  const ButtonRow({
    super.key,
    this.margin,
    this.text,
    this.style = const TextStyle(
      // color: AppColors.ButtonTextColor,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    this.onPressed,
    this.isBorder = false,
    this.lineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        border: isBorder
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: lineWidth ?? mainLineWidth,
                ),
              )
            : null,
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          // backgroundColor: Theme.of(context).colorScheme.surface,
          //取消圆角边框
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        autofocus: true,
        onPressed: onPressed ?? () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15.0),
          alignment: Alignment.center,
          child: Text(text!, style: style),
        ),
      ),
    );
  }
}

class RoundedElevatedButton extends StatelessWidget {
  final String text;
  final bool highlighted;
  final VoidCallback? onPressed;
  final Size? size;
  final BorderRadius? borderRadius;

  const RoundedElevatedButton({
    super.key,
    required this.text,
    required this.highlighted,
    required this.onPressed,
    this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      // ignore: sort_child_properties_last
      child: n.Padding(
          left: 10,
          right: 10,
          child: Text(
            text,
            textAlign: TextAlign.center,
          )),
      style: highlighted
          ? ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(
                Colors.green,
              ),
              foregroundColor: WidgetStateProperty.all<Color>(
                Colors.white,
              ),
              minimumSize: WidgetStateProperty.all(
                size ?? const Size(88, 40),
              ),
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              shape: WidgetStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                borderRadius:
                    borderRadius ?? BorderRadius.circular(30.0), // 设置圆角大小
              )),
            )
          : ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(
                Colors.white12,
              ),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.grey),
              minimumSize: WidgetStateProperty.all(
                size ?? const Size(88, 40),
              ),
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              shape: WidgetStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                borderRadius:
                    borderRadius ?? BorderRadius.circular(30.0), // 设置圆角大小
              )),
            ),
    );
  }
}
