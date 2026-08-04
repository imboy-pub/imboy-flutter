import 'package:flutter/material.dart';

/// 头像缺省内容：有名称显示首字，无名称显示语义图标。
///
/// 问号会让头像看起来像异常状态，而不是一个可识别的对象；
/// 这里保留首字母辨识度，同时为完全没有名称的情况提供明确图标。
class AvatarFallbackContent extends StatelessWidget {
  const AvatarFallbackContent({
    super.key,
    this.name,
    required this.color,
    this.emptyIcon = Icons.person_outline_rounded,
    this.iconSize = 20,
    this.textStyle,
  });

  final String? name;
  final Color color;
  final IconData emptyIcon;
  final double iconSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final trimmedName = name?.trim() ?? '';
    if (trimmedName.isEmpty) {
      return Icon(emptyIcon, size: iconSize, color: color);
    }

    final firstRune = String.fromCharCode(
      trimmedName.runes.first,
    ).toUpperCase();
    return Text(
      firstRune,
      style: textStyle?.copyWith(color: color) ?? TextStyle(color: color),
    );
  }
}
