import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

class ButtonRow extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final String? text;
  final TextStyle style;
  final VoidCallback? onPressed;
  final bool isBorder;
  final double lineWidth;

  const ButtonRow({
    Key? key,
    this.margin,
    this.text,
    this.style = const TextStyle(
        color: AppColors.ButtonTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 16),
    this.onPressed,
    this.isBorder = false,
    this.lineWidth = mainLineWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        border: isBorder
            ? Border(
                bottom:
                    BorderSide(color: AppColors.LineColor, width: lineWidth),
              )
            : null,
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
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
