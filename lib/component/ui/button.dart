import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

class ButtonRow extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final String? text;
  final TextStyle? style;
  final VoidCallback? onPressed;
  final bool isBorder;
  final double lineWidth;

  const ButtonRow({
    super.key,
    this.margin,
    this.text,
    this.style = const TextStyle(
        color: AppColors.ButtonTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 16),
    this.onPressed,
    this.isBorder = false,
    this.lineWidth = mainLineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        border: isBorder
            ? Border(
                bottom: BorderSide(
                color: AppColors.LineColor,
                width: lineWidth,
              ))
            : null,
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryElement,
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
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
