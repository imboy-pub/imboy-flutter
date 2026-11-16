import 'package:material_ui/material_ui.dart';

class HighlightedWord {
  final TextStyle? textStyle;
  final VoidCallback? onTap;
  final BoxDecoration? decoration;
  final EdgeInsetsGeometry? padding;

  HighlightedWord({
    this.textStyle,
    this.onTap,
    this.decoration,
    this.padding,
  });
}
