import 'package:flutter/material.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/theme.dart';

class LabelRow extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final VoidCallback? onPressed;
  final double? titleWidth;
  final bool? isRight;
  final bool? isLine;
  final bool? isSpacer;
  final String? value;
  final String? rValue;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double? lineWidth;

  const LabelRow({
    super.key,
    this.title,
    this.onPressed,
    this.value,
    this.titleWidth,
    this.isRight = true,
    this.isLine = false,
    this.isSpacer = true,
    this.trailing,
    this.rValue,
    this.margin,
    this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
    this.leading,
    this.lineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // ignore: sort_child_properties_last
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          // foregroundColor: AppColors.ItemOnColor,
          // backgroundColor: Theme.of(context).colorScheme.surface,
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
                      width: lineWidth ?? mainLineWidth,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
          ),
          child: n.Row([
            if (leading != null) leading!,
            SizedBox(
              width: titleWidth,
              child: Text(
                title ?? '',
                style: TextStyle(
                  fontSize: 17.0,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            value != null
                ? Text(
                    value!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withOpacity(0.7),
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
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ))
                : const SizedBox.shrink(),
            trailing != null ? Center(child: trailing!) : Container(),
            isRight!
                ? Icon(
                    Icons.navigate_next,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                : Container(width: 10.0)
          ]),
        ),
      ),
      margin: margin,
    );
  }
}
