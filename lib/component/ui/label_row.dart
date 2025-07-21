import 'package:flutter/material.dart';

import '../../config/theme.dart' show mainLineWidth;

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
    this.leading,
    this.onPressed,
    this.titleWidth,
    this.isRight = true,
    this.isLine = false,
    this.isSpacer = true,
    this.value,
    this.rValue,
    this.trailing,
    this.margin,
    this.padding = const EdgeInsets.only(top: 15.0, bottom: 15.0, right: 5.0),
    this.lineWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        onPressed: onPressed ?? () {},
        child: Container(
          margin: const EdgeInsets.only(left: 15.0, top: 10),
          padding: padding,
          decoration: BoxDecoration(
            border: isLine == true
                ? Border(
              bottom: BorderSide(
                width: lineWidth ?? mainLineWidth,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
                : null,
          ),
          child: Row(
            children: [
              if (leading != null) leading!,
              _buildTitle(context),
              if (value != null) _buildValue(context),
              if (isSpacer == true) const Spacer(),
              if (rValue != null) _buildRValue(context),
              if (trailing != null) Center(child: trailing),
              isRight == true
                  ? Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.navigate_next,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
                  : const SizedBox(width: 10.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return SizedBox(
      width: titleWidth,
      child: Text(
        title ?? '',
        style: TextStyle(
          fontSize: 16.0,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildValue(BuildContext context) {
    final fadedColor = Theme.of(context)
        .colorScheme
        .onPrimary
        .withValues(alpha: 0.7);

    return Expanded(
      child: Text(
        value!,
        style: TextStyle(
          color: fadedColor,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
      ),
    );
  }

  Widget _buildRValue(BuildContext context) {
    final fadedColor = Theme.of(context)
        .colorScheme
        .onPrimary
        .withValues(alpha: 0.7);

    return Expanded(
      child: Text(
        rValue!,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: fadedColor,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}