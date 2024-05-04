import 'package:flutter/material.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';

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
          foregroundColor: Theme.of(context).colorScheme.onBackground,
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          // backgroundColor: Theme.of(context).colorScheme.background,
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
  final VoidCallback? onPressed;
  final bool highlighted;
  final Size? size;
  final BorderRadius? borderRadius;

  const RoundedElevatedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.highlighted = false,
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
              backgroundColor: MaterialStateProperty.all<Color>(
                Colors.green,
              ),
              foregroundColor: MaterialStateProperty.all<Color>(
                Colors.white,
              ),
              minimumSize: MaterialStateProperty.all(
                size ?? const Size(88, 40),
              ),
              visualDensity: VisualDensity.compact,
              padding: MaterialStateProperty.all(EdgeInsets.zero),
              shape: MaterialStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                borderRadius:
                    borderRadius ?? BorderRadius.circular(30.0), // 设置圆角大小
              )),
            )
          : ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(
                Colors.white12,
              ),
              foregroundColor: MaterialStateProperty.all<Color>(Colors.grey),
              minimumSize: MaterialStateProperty.all(
                size ?? const Size(88, 40),
              ),
              visualDensity: VisualDensity.compact,
              padding: MaterialStateProperty.all(EdgeInsets.zero),
              shape: MaterialStateProperty.all<OutlinedBorder>(
                  RoundedRectangleBorder(
                borderRadius:
                    borderRadius ?? BorderRadius.circular(30.0), // 设置圆角大小
              )),
            ),
    );
  }
}
