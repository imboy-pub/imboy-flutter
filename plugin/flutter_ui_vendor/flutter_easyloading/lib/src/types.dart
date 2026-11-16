import 'package:material_ui/material_ui.dart';

import 'animations/animation.dart';

/// Visual style used by the loading panel.
enum EasyLoadingStyle {
  light,
  dark,
  custom,

  /// Follows the brightness of the application theme while visible.
  auto,
}

/// Screen position used by text-only toast messages.
enum EasyLoadingToastPosition { top, center, bottom }

/// Transition used when the loading panel appears and disappears.
enum EasyLoadingAnimationStyle { opacity, offset, scale, custom }

/// Interaction barrier displayed behind the loading panel.
enum EasyLoadingMaskType {
  /// Allows interactions with the application below the overlay.
  none,

  /// Blocks interactions without drawing a visible mask.
  clear,

  /// Blocks interactions and draws a translucent black mask.
  black,

  /// Blocks interactions and uses [EasyLoadingOptions.maskColor] or the
  /// globally configured mask color.
  custom,
}

/// Built-in loading indicator variants.
enum EasyLoadingIndicatorType {
  fadingCircle,
  circle,
  threeBounce,
  chasingDots,
  wave,
  wanderingCubes,
  rotatingPlain,
  doubleBounce,
  fadingFour,
  fadingCube,
  pulse,
  cubeGrid,
  rotatingCircle,
  foldingCube,
  pumpingHeart,
  dualRing,
  hourGlass,
  pouringHourGlass,
  fadingGrid,
  ring,
  ripple,
  spinningCircle,
  squareCircle,

  // New values remain appended so existing enum indices stay stable.
  dancingSquare,
  pianoWave,
  pouringHourGlassRefined,
  pulsingGrid,
  spinningLines,
  threeInOut,
  waveSpinner,
}

/// Visibility event emitted by [EasyLoading].
enum EasyLoadingStatus { show, dismiss }

/// Receives visibility changes from [EasyLoading].
typedef EasyLoadingStatusCallback = void Function(EasyLoadingStatus status);

/// Cause of a completed EasyLoading dismissal.
enum EasyLoadingDismissReason {
  /// [EasyLoading.dismiss] was called directly.
  programmatic,

  /// The user tapped a dismissible barrier.
  tap,

  /// The current display duration elapsed.
  timeout,

  /// The active [FlutterEasyLoading] Host left the widget tree.
  hostDetached,
}

/// Receives the reason after a visible overlay has been dismissed.
typedef EasyLoadingDismissCallback =
    void Function(EasyLoadingDismissReason reason);

/// Immutable visual and layout overrides for one display call.
///
/// Null values inherit the corresponding global [EasyLoading.instance]
/// configuration. Interaction parameters declared directly by a display
/// method take precedence over global configuration and are intentionally not
/// duplicated here.
@immutable
class EasyLoadingOptions {
  const EasyLoadingOptions({
    this.loadingStyle,
    this.indicatorType,
    this.alignment,
    this.constraints,
    this.animationStyle,
    this.textAlign,
    this.contentPadding,
    this.textPadding,
    this.indicatorSize,
    this.radius,
    this.fontSize,
    this.progressWidth,
    this.lineWidth,
    this.animationDuration,
    this.customAnimation,
    this.textStyle,
    this.textColor,
    this.indicatorColor,
    this.progressColor,
    this.backgroundColor,
    this.boxShadow,
    this.maskColor,
    this.userInteractions,
  });

  final EasyLoadingStyle? loadingStyle;
  final EasyLoadingIndicatorType? indicatorType;
  final AlignmentGeometry? alignment;
  final BoxConstraints? constraints;
  final EasyLoadingAnimationStyle? animationStyle;
  final TextAlign? textAlign;
  final EdgeInsets? contentPadding;
  final EdgeInsets? textPadding;
  final double? indicatorSize;
  final double? radius;
  final double? fontSize;
  final double? progressWidth;
  final double? lineWidth;
  final Duration? animationDuration;
  final EasyLoadingAnimation? customAnimation;
  final TextStyle? textStyle;
  final Color? textColor;
  final Color? indicatorColor;
  final Color? progressColor;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final Color? maskColor;
  final bool? userInteractions;
}
