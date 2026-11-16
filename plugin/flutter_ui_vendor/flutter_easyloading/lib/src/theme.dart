import 'package:material_ui/material_ui.dart';

import 'animations/animation.dart';
import 'types.dart';

@immutable
class EasyLoadingConfigurationSnapshot {
  const EasyLoadingConfigurationSnapshot({
    required this.loadingStyle,
    required this.indicatorType,
    required this.animationStyle,
    required this.textAlign,
    required this.contentPadding,
    required this.textPadding,
    required this.indicatorSize,
    required this.radius,
    required this.fontSize,
    required this.progressWidth,
    required this.lineWidth,
    required this.animationDuration,
    required this.customAnimation,
    required this.textStyle,
    required this.textColor,
    required this.indicatorColor,
    required this.progressColor,
    required this.backgroundColor,
    required this.boxShadow,
    required this.maskColor,
  });

  final EasyLoadingStyle loadingStyle;
  final EasyLoadingIndicatorType indicatorType;
  final EasyLoadingAnimationStyle animationStyle;
  final TextAlign textAlign;
  final EdgeInsets contentPadding;
  final EdgeInsets textPadding;
  final double indicatorSize;
  final double radius;
  final double fontSize;
  final double progressWidth;
  final double lineWidth;
  final Duration animationDuration;
  final EasyLoadingAnimation? customAnimation;
  final TextStyle? textStyle;
  final Color? textColor;
  final Color? indicatorColor;
  final Color? progressColor;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final Color? maskColor;
}

/// Immutable visual snapshot captured when a display call is accepted.
@immutable
class EasyLoadingThemeSnapshot {
  const EasyLoadingThemeSnapshot._({
    required this.loadingStyle,
    required this.customIndicatorColor,
    required this.customProgressColor,
    required this.customBackgroundColor,
    required this.customTextColor,
    required this.maskColor,
    required this.animation,
    required this.animationDuration,
    required this.contentPadding,
    required this.textPadding,
    required this.textAlign,
    required this.textStyle,
    required this.boxShadow,
    required this.indicatorSize,
    required this.progressWidth,
    required this.lineWidth,
    required this.radius,
    required this.fontSize,
    required this.indicatorType,
  });

  final EasyLoadingStyle loadingStyle;
  final Color? customIndicatorColor;
  final Color? customProgressColor;
  final Color? customBackgroundColor;
  final Color? customTextColor;
  final Color maskColor;
  final EasyLoadingAnimation animation;
  final Duration animationDuration;
  final EdgeInsets contentPadding;
  final EdgeInsets textPadding;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final List<BoxShadow>? boxShadow;
  final double indicatorSize;
  final double progressWidth;
  final double lineWidth;
  final double radius;
  final double fontSize;
  final EasyLoadingIndicatorType indicatorType;

  static EasyLoadingThemeSnapshot capture(
    EasyLoadingConfigurationSnapshot config, {
    required EasyLoadingMaskType maskType,
    EasyLoadingOptions? options,
    bool progress = false,
    bool panel = true,
  }) {
    final loadingStyle = options?.loadingStyle ?? config.loadingStyle;
    final indicatorColor = options?.indicatorColor ?? config.indicatorColor;
    final progressColor = options?.progressColor ?? config.progressColor;
    final backgroundColor = options?.backgroundColor ?? config.backgroundColor;
    final textColor = options?.textColor ?? config.textColor;

    if (loadingStyle == EasyLoadingStyle.custom && panel) {
      _require(indicatorColor, 'indicatorColor');
      _require(backgroundColor, 'backgroundColor');
      _require(textColor, 'textColor');
      if (progress) {
        _require(progressColor, 'progressColor');
      }
    }

    final Color maskColor = switch (maskType) {
      EasyLoadingMaskType.custom => _require(
        options?.maskColor ?? config.maskColor,
        'maskColor',
      ),
      EasyLoadingMaskType.black => Colors.black.withValues(alpha: 0.5),
      EasyLoadingMaskType.none ||
      EasyLoadingMaskType.clear => Colors.transparent,
    };

    final animationStyle = options?.animationStyle ?? config.animationStyle;
    final EasyLoadingAnimation animation = switch (animationStyle) {
      EasyLoadingAnimationStyle.custom => _require(
        options?.customAnimation ?? config.customAnimation,
        'customAnimation',
      ),
      EasyLoadingAnimationStyle.offset => const OffsetAnimation(),
      EasyLoadingAnimationStyle.scale => const ScaleAnimation(),
      EasyLoadingAnimationStyle.opacity => const OpacityAnimation(),
    };

    final shadows = options?.boxShadow ?? config.boxShadow;
    return EasyLoadingThemeSnapshot._(
      loadingStyle: loadingStyle,
      customIndicatorColor: indicatorColor,
      customProgressColor: progressColor ?? indicatorColor,
      customBackgroundColor: backgroundColor,
      customTextColor: textColor,
      maskColor: maskColor,
      animation: animation,
      animationDuration: validateDuration(
        options?.animationDuration ?? config.animationDuration,
        'animationDuration',
      ),
      contentPadding: validateEdgeInsets(
        options?.contentPadding ?? config.contentPadding,
        'contentPadding',
      ),
      textPadding: validateEdgeInsets(
        options?.textPadding ?? config.textPadding,
        'textPadding',
      ),
      textAlign: options?.textAlign ?? config.textAlign,
      textStyle: options?.textStyle ?? config.textStyle,
      boxShadow: loadingStyle == EasyLoadingStyle.custom && shadows != null
          ? List<BoxShadow>.unmodifiable(shadows)
          : null,
      indicatorSize: validatePositiveDouble(
        options?.indicatorSize ?? config.indicatorSize,
        'indicatorSize',
      ),
      progressWidth: validatePositiveDouble(
        options?.progressWidth ?? config.progressWidth,
        'progressWidth',
      ),
      lineWidth: validatePositiveDouble(
        options?.lineWidth ?? config.lineWidth,
        'lineWidth',
      ),
      radius: validateNonNegativeDouble(
        options?.radius ?? config.radius,
        'radius',
      ),
      fontSize: validatePositiveDouble(
        options?.fontSize ?? config.fontSize,
        'fontSize',
      ),
      indicatorType: options?.indicatorType ?? config.indicatorType,
    );
  }

  EasyLoadingThemeData resolve(Brightness brightness) {
    final effectiveStyle = loadingStyle == EasyLoadingStyle.auto
        ? switch (brightness) {
            Brightness.dark => EasyLoadingStyle.dark,
            Brightness.light => EasyLoadingStyle.light,
          }
        : loadingStyle;

    return switch (effectiveStyle) {
      EasyLoadingStyle.custom => EasyLoadingThemeData(
        indicatorColor: customIndicatorColor ?? Colors.white,
        progressColor:
            customProgressColor ?? customIndicatorColor ?? Colors.white,
        backgroundColor: customBackgroundColor ?? Colors.transparent,
        textColor: customTextColor ?? Colors.white,
        maskColor: maskColor,
        animation: animation,
        animationDuration: animationDuration,
        contentPadding: contentPadding,
        textPadding: textPadding,
        textAlign: textAlign,
        textStyle: textStyle,
        boxShadow: boxShadow,
        indicatorSize: indicatorSize,
        progressWidth: progressWidth,
        lineWidth: lineWidth,
        radius: radius,
        fontSize: fontSize,
        indicatorType: indicatorType,
      ),
      EasyLoadingStyle.dark => _resolved(
        foreground: Colors.white,
        background: Colors.black.withValues(alpha: 0.9),
      ),
      EasyLoadingStyle.light => _resolved(
        foreground: Colors.black,
        background: Colors.white,
      ),
      EasyLoadingStyle.auto => throw StateError(
        'EasyLoadingStyle.auto must resolve to a brightness.',
      ),
    };
  }

  EasyLoadingThemeData _resolved({
    required Color foreground,
    required Color background,
  }) {
    return EasyLoadingThemeData(
      indicatorColor: foreground,
      progressColor: foreground,
      backgroundColor: background,
      textColor: foreground,
      maskColor: maskColor,
      animation: animation,
      animationDuration: animationDuration,
      contentPadding: contentPadding,
      textPadding: textPadding,
      textAlign: textAlign,
      textStyle: textStyle,
      boxShadow: null,
      indicatorSize: indicatorSize,
      progressWidth: progressWidth,
      lineWidth: lineWidth,
      radius: radius,
      fontSize: fontSize,
      indicatorType: indicatorType,
    );
  }
}

@immutable
class EasyLoadingThemeData {
  const EasyLoadingThemeData({
    required this.indicatorColor,
    required this.progressColor,
    required this.backgroundColor,
    required this.textColor,
    required this.maskColor,
    required this.animation,
    required this.animationDuration,
    required this.contentPadding,
    required this.textPadding,
    required this.textAlign,
    required this.textStyle,
    required this.boxShadow,
    required this.indicatorSize,
    required this.progressWidth,
    required this.lineWidth,
    required this.radius,
    required this.fontSize,
    required this.indicatorType,
  });

  final Color indicatorColor;
  final Color progressColor;
  final Color backgroundColor;
  final Color textColor;
  final Color maskColor;
  final EasyLoadingAnimation animation;
  final Duration animationDuration;
  final EdgeInsets contentPadding;
  final EdgeInsets textPadding;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final List<BoxShadow>? boxShadow;
  final double indicatorSize;
  final double progressWidth;
  final double lineWidth;
  final double radius;
  final double fontSize;
  final EasyLoadingIndicatorType indicatorType;
}

AlignmentGeometry easyLoadingAlignment(EasyLoadingToastPosition position) {
  return switch (position) {
    EasyLoadingToastPosition.top => AlignmentDirectional.topCenter,
    EasyLoadingToastPosition.center => AlignmentDirectional.center,
    EasyLoadingToastPosition.bottom => AlignmentDirectional.bottomCenter,
  };
}

double validatePositiveDouble(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'must be finite and greater than 0');
  }
  return value;
}

double validateNonNegativeDouble(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'must be finite and non-negative');
  }
  return value;
}

Duration validateDuration(Duration value, String name) {
  if (value.isNegative) {
    throw ArgumentError.value(value, name, 'must be non-negative');
  }
  return value;
}

EdgeInsets validateEdgeInsets(EdgeInsets value, String name) {
  for (final side in <double>[
    value.left,
    value.top,
    value.right,
    value.bottom,
  ]) {
    if (!side.isFinite || side < 0) {
      throw ArgumentError.value(
        value,
        name,
        'must contain finite, non-negative values',
      );
    }
  }
  return value;
}

BoxConstraints validateConstraints(BoxConstraints value, String name) {
  final values = <double>[
    value.minWidth,
    value.maxWidth,
    value.minHeight,
    value.maxHeight,
  ];
  if (values.any((item) => item.isNaN || item < 0) ||
      value.minWidth > value.maxWidth ||
      value.minHeight > value.maxHeight) {
    throw ArgumentError.value(value, name, 'contains invalid bounds');
  }
  return value;
}

T _require<T>(T? value, String name) {
  if (value == null) {
    throw StateError(
      '$name must be set when using the selected custom EasyLoading mode.',
    );
  }
  return value;
}
