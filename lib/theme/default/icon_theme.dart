// 自定义图标主题
import 'package:flutter/material.dart';

class IMBoyIconTheme extends ThemeExtension<IMBoyIconTheme> {
  final IconThemeData primaryIcon;
  final IconThemeData surfaceIcon;
  final IconThemeData secondaryIcon;
  final IconThemeData errorIcon;

  const IMBoyIconTheme({
    required this.primaryIcon,
    required this.surfaceIcon,
    required this.secondaryIcon,
    required this.errorIcon,
  });

  @override
  ThemeExtension<IMBoyIconTheme> copyWith({
    IconThemeData? primaryIcon,
    IconThemeData? surfaceIcon,
    IconThemeData? secondaryIcon,
    IconThemeData? errorIcon,
  }) {
    return IMBoyIconTheme(
      primaryIcon: primaryIcon ?? this.primaryIcon,
      surfaceIcon: surfaceIcon ?? this.surfaceIcon,
      secondaryIcon: secondaryIcon ?? this.secondaryIcon,
      errorIcon: errorIcon ?? this.errorIcon,
    );
  }

  @override
  ThemeExtension<IMBoyIconTheme> lerp(
    ThemeExtension<IMBoyIconTheme>? other,
    double t,
  ) {
    if (other is! IMBoyIconTheme) return this;
    return IMBoyIconTheme(
      primaryIcon: IconThemeData.lerp(primaryIcon, other.primaryIcon, t),
      surfaceIcon: IconThemeData.lerp(surfaceIcon, other.surfaceIcon, t),
      secondaryIcon: IconThemeData.lerp(secondaryIcon, other.secondaryIcon, t),
      errorIcon: IconThemeData.lerp(errorIcon, other.errorIcon, t),
    );
  }
}
