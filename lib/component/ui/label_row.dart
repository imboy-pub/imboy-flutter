import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

class LabelRow extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final double? labelWidth;
  final bool? isRight;
  final bool? isLine;
  final bool? isSpacer;
  final String? value;
  final String? rValue;
  final Widget? rightW;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Widget? headW;
  final double? lineWidth;

  const LabelRow({
    super.key,
    this.label,
    this.onPressed,
    this.value,
    this.labelWidth,
    this.isRight = true,
    this.isLine = false,
    this.isSpacer = true,
    this.rightW,
    this.rValue,
    this.margin,
    this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
    this.headW,
    this.lineWidth = mainLineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // ignore: sort_child_properties_last
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          foregroundColor: AppColors.ItemOnColor,
          backgroundColor: Colors.white,
          //取消圆角边框
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        onPressed: onPressed ?? () {},
        child: Container(
          padding: padding,
          margin: const EdgeInsets.only(left: 15.0, top: 10),
          decoration: BoxDecoration(
            border: isLine!
                ? Border(
                    bottom: BorderSide(
                        color: AppColors.LineColor, width: lineWidth!))
                : null,
          ),
          child: n.Row([
            if (headW != null) headW!,
            SizedBox(
              width: labelWidth,
              child: Text(
                label ?? '',
                style: const TextStyle(fontSize: 17.0),
              ),
            ),
            value != null
                ? Text(
                    value!,
                    style: TextStyle(
                      color: AppColors.MainTextColor.withOpacity(0.7),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                  )
                : Container(),
            isSpacer == true ? const Spacer() : const SizedBox.shrink(),
            rValue != null
                ? Text(rValue!,
                    style: TextStyle(
                        color: AppColors.MainTextColor.withOpacity(0.7),
                        fontWeight: FontWeight.w400))
                : const SizedBox.shrink(),
            rightW != null ? Center(child: rightW!) : Container(),
            isRight!
                ? Icon(CupertinoIcons.right_chevron,
                    color: AppColors.MainTextColor.withOpacity(0.5))
                : Container(width: 10.0)
          ]),
        ),
      ),
      margin: margin,
    );
  }
}
