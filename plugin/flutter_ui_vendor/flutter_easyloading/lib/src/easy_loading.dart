import 'package:material_ui/material_ui.dart';

import 'animations/animation.dart';
import 'runtime.dart';
import 'theme.dart';
import 'types.dart';
import 'widgets/loading.dart';

/// Global facade for displaying loading, progress, result, and toast overlays.
class EasyLoading {
  EasyLoading._internal();

  /// Returns the shared configuration instance.
  factory EasyLoading() => _instance;

  static final EasyLoading _instance = EasyLoading._internal();

  /// Shared mutable configuration used by subsequent display calls.
  static EasyLoading get instance => _instance;

  /// Whether an EasyLoading overlay is currently active.
  static bool get isShow => easyLoadingRuntime.isShow;

  /// Color scheme used by the panel.
  EasyLoadingStyle loadingStyle = EasyLoadingStyle.dark;

  /// Built-in indicator used by loading calls.
  EasyLoadingIndicatorType indicatorType =
      EasyLoadingIndicatorType.fadingCircle;

  /// Default interaction barrier used by display calls.
  EasyLoadingMaskType maskType = EasyLoadingMaskType.none;

  /// Default vertical placement of text-only toast messages.
  EasyLoadingToastPosition toastPosition = EasyLoadingToastPosition.center;

  /// Transition used to present and dismiss the panel.
  EasyLoadingAnimationStyle animationStyle = EasyLoadingAnimationStyle.opacity;

  /// Alignment of status text inside the panel.
  TextAlign textAlign = TextAlign.center;

  /// Padding between the panel boundary and its content.
  EdgeInsets contentPadding = const EdgeInsets.symmetric(
    vertical: 15,
    horizontal: 20,
  );

  /// Padding inserted between an indicator and status text.
  EdgeInsets textPadding = const EdgeInsets.only(bottom: 10);

  /// Width and height of the built-in indicator.
  double indicatorSize = 40;

  /// Corner radius of the panel.
  double radius = 5;

  /// Font size used when [textStyle] is not supplied.
  double fontSize = 15;

  /// Stroke width of the determinate progress ring.
  double progressWidth = 2;

  /// Stroke width used by supported built-in indicators.
  double lineWidth = 4;

  /// Default lifetime of result and toast messages.
  Duration displayDuration = const Duration(milliseconds: 2000);

  /// Duration of panel presentation and dismissal transitions.
  Duration animationDuration = const Duration(milliseconds: 200);

  /// Transition implementation required by the custom animation style.
  EasyLoadingAnimation? customAnimation;

  /// Complete status text style, merged with the surrounding Material style.
  TextStyle? textStyle;

  /// Status text color required by the custom loading style.
  Color? textColor;

  /// Indicator color required by the custom loading style.
  Color? indicatorColor;

  /// Progress ring color required by custom determinate progress.
  Color? progressColor;

  /// Panel background color required by the custom loading style.
  Color? backgroundColor;

  /// Shadows drawn behind a custom panel.
  List<BoxShadow>? boxShadow;

  /// Barrier color required by the custom mask type.
  Color? maskColor;

  /// Whether pointer input can reach the application below the overlay.
  bool? userInteractions;

  /// Whether tapping the barrier dismisses the current overlay.
  bool? dismissOnTap;

  /// Optional replacement for the built-in loading indicator.
  Widget? indicatorWidget;

  /// Optional replacement for the built-in success icon.
  Widget? successWidget;

  /// Optional replacement for the built-in error icon.
  Widget? errorWidget;

  /// Optional replacement for the built-in information icon.
  Widget? infoWidget;

  /// Creates the application-level EasyLoading Host builder.
  static TransitionBuilder init({TransitionBuilder? builder}) {
    return (BuildContext context, Widget? child) {
      final host = FlutterEasyLoading(child: child);
      return builder?.call(context, host) ?? host;
    };
  }

  /// Shows or updates an indeterminate loading indicator.
  static Future<void> show({
    String? status,
    Widget? indicator,
    EasyLoadingMaskType? maskType,
    bool? dismissOnTap,
    Duration? duration,
    EasyLoadingOptions? options,
  }) {
    return _instance._display(
      _instance._request(
        type: EasyLoadingContentType.loading,
        status: status,
        indicator: indicator ?? _instance.indicatorWidget,
        maskType: maskType,
        dismissOnTap: dismissOnTap,
        duration: duration,
        options: options,
      ),
    );
  }

  /// Shows or updates determinate progress in the inclusive range 0 to 1.
  static Future<void> showProgress(
    double value, {
    String? status,
    EasyLoadingMaskType? maskType,
    Widget? indicator,
    Duration? duration,
    bool? dismissOnTap,
    EasyLoadingOptions? options,
  }) {
    _validateProgress(value);
    return _instance._display(
      _instance._request(
        type: EasyLoadingContentType.progress,
        status: status,
        indicator: indicator,
        progress: value,
        maskType: maskType,
        dismissOnTap: dismissOnTap,
        duration: duration,
        options: options,
        progressTheme: true,
      ),
      progress: true,
    );
  }

  /// Shows a success result using [displayDuration] by default.
  static Future<void> showSuccess(
    String status, {
    Duration? duration,
    EasyLoadingMaskType? maskType,
    bool? dismissOnTap,
    EasyLoadingOptions? options,
  }) {
    return _instance._showResult(
      type: EasyLoadingContentType.success,
      status: status,
      indicator: _instance.successWidget,
      duration: duration,
      maskType: maskType,
      dismissOnTap: dismissOnTap,
      options: options,
    );
  }

  /// Shows an error result using [displayDuration] by default.
  static Future<void> showError(
    String status, {
    Duration? duration,
    EasyLoadingMaskType? maskType,
    bool? dismissOnTap,
    EasyLoadingOptions? options,
  }) {
    return _instance._showResult(
      type: EasyLoadingContentType.error,
      status: status,
      indicator: _instance.errorWidget,
      duration: duration,
      maskType: maskType,
      dismissOnTap: dismissOnTap,
      options: options,
    );
  }

  /// Shows an information result using [displayDuration] by default.
  static Future<void> showInfo(
    String status, {
    Duration? duration,
    EasyLoadingMaskType? maskType,
    bool? dismissOnTap,
    EasyLoadingOptions? options,
  }) {
    return _instance._showResult(
      type: EasyLoadingContentType.info,
      status: status,
      indicator: _instance.infoWidget,
      duration: duration,
      maskType: maskType,
      dismissOnTap: dismissOnTap,
      options: options,
    );
  }

  /// Shows a text-only toast using [displayDuration] by default.
  static Future<void> showToast(
    String status, {
    Duration? duration,
    EasyLoadingToastPosition? toastPosition,
    EasyLoadingMaskType? maskType,
    bool? dismissOnTap,
    EasyLoadingOptions? options,
  }) {
    final alignment =
        options?.alignment ??
        easyLoadingAlignment(toastPosition ?? _instance.toastPosition);
    return _instance._display(
      _instance._request(
        type: EasyLoadingContentType.toast,
        status: status,
        duration: duration ?? _instance.displayDuration,
        maskType: maskType,
        dismissOnTap: dismissOnTap,
        alignment: alignment,
        options: options,
      ),
    );
  }

  /// Shows arbitrary content inside the EasyLoading presentation layer.
  static Future<void> showCustom(
    Widget content, {
    Duration? duration,
    EasyLoadingMaskType? maskType,
    bool? dismissOnTap,
    EasyLoadingOptions? options,
  }) {
    return _instance._display(
      _instance._request(
        type: EasyLoadingContentType.custom,
        customContent: content,
        duration: duration,
        maskType: maskType,
        dismissOnTap: dismissOnTap,
        options: options,
        panel: false,
      ),
    );
  }

  /// Dismisses the active overlay.
  static Future<void> dismiss({bool animation = true}) {
    return easyLoadingRuntime.dismiss(animation: animation);
  }

  /// Adds a visibility callback if it has not already been registered.
  static void addStatusCallback(EasyLoadingStatusCallback callback) {
    easyLoadingRuntime.addStatusCallback(callback);
  }

  /// Removes one visibility callback.
  static void removeCallback(EasyLoadingStatusCallback callback) {
    easyLoadingRuntime.removeStatusCallback(callback);
  }

  /// Removes every visibility callback.
  static void removeAllCallbacks() {
    easyLoadingRuntime.clearStatusCallbacks();
  }

  /// Adds a final dismissal-reason callback.
  static void addDismissCallback(EasyLoadingDismissCallback callback) {
    easyLoadingRuntime.addDismissCallback(callback);
  }

  /// Removes one dismissal-reason callback.
  static void removeDismissCallback(EasyLoadingDismissCallback callback) {
    easyLoadingRuntime.removeDismissCallback(callback);
  }

  /// Removes every dismissal-reason callback.
  static void removeAllDismissCallbacks() {
    easyLoadingRuntime.clearDismissCallbacks();
  }

  Future<void> _showResult({
    required EasyLoadingContentType type,
    required String status,
    required Widget? indicator,
    required Duration? duration,
    required EasyLoadingMaskType? maskType,
    required bool? dismissOnTap,
    required EasyLoadingOptions? options,
  }) {
    return _display(
      _request(
        type: type,
        status: status,
        indicator: indicator,
        duration: duration ?? displayDuration,
        maskType: maskType,
        dismissOnTap: dismissOnTap,
        options: options,
      ),
    );
  }

  Future<void> _display(EasyLoadingRequest request, {bool progress = false}) {
    try {
      return progress
          ? easyLoadingRuntime.showProgress(request)
          : easyLoadingRuntime.show(request);
    } catch (error, stackTrace) {
      return Future<void>.error(error, stackTrace);
    }
  }

  EasyLoadingRequest _request({
    required EasyLoadingContentType type,
    String? status,
    Widget? indicator,
    double? progress,
    Duration? duration,
    EasyLoadingMaskType? maskType,
    bool? dismissOnTap,
    AlignmentGeometry? alignment,
    Widget? customContent,
    EasyLoadingOptions? options,
    bool progressTheme = false,
    bool panel = true,
  }) {
    final mask = maskType ?? this.maskType;
    final dismiss = dismissOnTap ?? this.dismissOnTap ?? false;
    final interactions = options?.userInteractions ?? userInteractions;
    final effectiveDuration = duration == null
        ? null
        : validateDuration(duration, 'duration');
    final effectiveConstraints = validateConstraints(
      options?.constraints ?? const BoxConstraints(maxWidth: 360),
      'constraints',
    );
    final theme = EasyLoadingThemeSnapshot.capture(
      _configurationSnapshot(),
      maskType: mask,
      options: options,
      progress: progressTheme,
      panel: panel,
    );

    return EasyLoadingRequest(
      type: type,
      theme: theme,
      status: status,
      indicator: indicator,
      progress: progress,
      duration: effectiveDuration,
      alignment: alignment ?? options?.alignment ?? AlignmentDirectional.center,
      constraints: effectiveConstraints,
      dismissOnTap: dismiss,
      ignoresPointer: dismiss
          ? false
          : interactions ?? mask == EasyLoadingMaskType.none,
      customContent: customContent,
    );
  }

  EasyLoadingConfigurationSnapshot _configurationSnapshot() {
    return EasyLoadingConfigurationSnapshot(
      loadingStyle: loadingStyle,
      indicatorType: indicatorType,
      animationStyle: animationStyle,
      textAlign: textAlign,
      contentPadding: contentPadding,
      textPadding: textPadding,
      indicatorSize: indicatorSize,
      radius: radius,
      fontSize: fontSize,
      progressWidth: progressWidth,
      lineWidth: lineWidth,
      animationDuration: animationDuration,
      customAnimation: customAnimation,
      textStyle: textStyle,
      textColor: textColor,
      indicatorColor: indicatorColor,
      progressColor: progressColor,
      backgroundColor: backgroundColor,
      boxShadow: boxShadow,
      maskColor: maskColor,
    );
  }

  static void _validateProgress(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw RangeError.range(value, 0, 1, 'value');
    }
  }
}
