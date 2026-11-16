import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

import '../runtime.dart';
import '../theme.dart';
import '../types.dart';
import 'indicator.dart';
import 'progress.dart';

/// Hosts the EasyLoading presentation layer above an application widget tree.
class FlutterEasyLoading extends StatefulWidget {
  const FlutterEasyLoading({super.key, required this.child});

  /// Application content displayed below the EasyLoading presentation layer.
  final Widget? child;

  @override
  State<FlutterEasyLoading> createState() => _FlutterEasyLoadingState();
}

class _FlutterEasyLoadingState extends State<FlutterEasyLoading>
    implements EasyLoadingHost {
  int? _sessionId;
  GlobalKey<_EasyLoadingOverlayState>? _overlayKey;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    easyLoadingRuntime.attach(this);
    easyLoadingRuntime.addListener(_onRuntimeChanged);
    _syncOverlay();
  }

  @override
  void dispose() {
    easyLoadingRuntime.removeListener(_onRuntimeChanged);
    easyLoadingRuntime.detach(this);
    super.dispose();
  }

  @override
  Future<void> dismiss(int sessionId, {required bool animate}) async {
    if (!mounted || _sessionId != sessionId) {
      return;
    }

    var overlay = _overlayKey?.currentState;
    if (overlay == null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _sessionId != sessionId) {
        return;
      }
      overlay = _overlayKey?.currentState;
    }
    await overlay?.dismiss(animate);
  }

  void _onRuntimeChanged() {
    if (!mounted) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_scheduled) {
        return;
      }
      _scheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) {
          setState(_syncOverlay);
        }
      });
      return;
    }
    setState(_syncOverlay);
  }

  void _syncOverlay() {
    final nextId = easyLoadingRuntime.session?.id;
    if (_sessionId == nextId) {
      return;
    }
    _sessionId = nextId;
    _overlayKey = nextId == null
        ? null
        : GlobalKey<_EasyLoadingOverlayState>(
            debugLabel: 'EasyLoadingOverlay#$nextId',
          );
  }

  @override
  Widget build(BuildContext context) {
    _syncOverlay();
    final session = easyLoadingRuntime.session;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
          type: MaterialType.transparency,
          textStyle: DefaultTextStyle.of(context).style,
          child: widget.child ?? const SizedBox.shrink(),
        ),
        if (session != null)
          Positioned.fill(
            child: _EasyLoadingOverlay(
              key: _overlayKey,
              session: session,
              onPresented: () => easyLoadingRuntime.didPresent(session.id),
              onDismiss: () {
                unawaited(
                  easyLoadingRuntime.dismiss(
                    reason: EasyLoadingDismissReason.tap,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EasyLoadingOverlay extends StatefulWidget {
  const _EasyLoadingOverlay({
    super.key,
    required this.session,
    required this.onPresented,
    required this.onDismiss,
  });

  final EasyLoadingSession session;
  final VoidCallback onPresented;
  final VoidCallback onDismiss;

  @override
  State<_EasyLoadingOverlay> createState() => _EasyLoadingOverlayState();
}

class _EasyLoadingOverlayState extends State<_EasyLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _didNotifyPresented = false;
  double? _semanticProgress;
  String? _semanticStatus;
  Duration _lastSemanticUpdate = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.session.request.theme.animationDuration,
    );
    _syncSemanticSnapshot(force: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _present();
      }
    });
  }

  @override
  void didUpdateWidget(_EasyLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.session.request.theme.animationDuration;
    _syncSemanticSnapshot(
      force: oldWidget.session.request.status != widget.session.request.status,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismiss(bool animate) async {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!animate || disableAnimations) {
      _controller.value = 0;
      return;
    }
    try {
      await _controller.reverse(from: 1).orCancel;
    } on TickerCanceled {
      // The Host was disposed while the transition was running.
    }
  }

  Future<void> _present() async {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _controller.value = 1;
      _notifyPresented();
      return;
    }
    try {
      await _controller.forward(from: 0).orCancel;
      _notifyPresented();
    } on TickerCanceled {
      // The Host was disposed while the transition was running.
    }
  }

  void _notifyPresented() {
    if (_didNotifyPresented) {
      return;
    }
    _didNotifyPresented = true;
    widget.onPresented();
  }

  void _syncSemanticSnapshot({required bool force}) {
    final request = widget.session.request;
    final progress = request.progress;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final previous = _semanticProgress;
    final endpoint = progress == 0 || progress == 1;
    final significantChange =
        progress != null &&
        previous != null &&
        (progress - previous).abs() >= 0.1;
    final intervalElapsed =
        now - _lastSemanticUpdate >= const Duration(seconds: 1);

    if (force ||
        progress == null ||
        previous == null ||
        endpoint ||
        significantChange ||
        intervalElapsed) {
      _semanticProgress = progress;
      _semanticStatus = request.status;
      _lastSemanticUpdate = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.session.request;
    final theme = request.theme.resolve(Theme.of(context).brightness);
    final alignment = request.alignment;
    final animationAlignment = alignment.resolve(
      Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
    final localizations = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    final dismissLabel = request.dismissOnTap
        ? localizations?.modalBarrierDismissLabel
        : null;
    final insets = MediaQuery.viewInsetsOf(context);

    return Stack(
      alignment: alignment,
      children: <Widget>[
        Positioned.fill(
          child: FadeTransition(
            opacity: _controller,
            child: IgnorePointer(
              ignoring: request.ignoresPointer,
              child: Semantics(
                button: request.dismissOnTap,
                label: dismissLabel,
                onTap: request.dismissOnTap ? widget.onDismiss : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: request.dismissOnTap ? widget.onDismiss : null,
                  child: ColoredBox(color: theme.maskColor),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final horizontalInset = _adaptiveInset(constraints.maxWidth);
              final verticalInset = _adaptiveInset(constraints.maxHeight);
              return SafeArea(
                minimum: EdgeInsets.symmetric(
                  horizontal: horizontalInset,
                  vertical: verticalInset,
                ),
                child: Align(
                  alignment: alignment,
                  child: AnimatedBuilder(
                    animation: _controller,
                    child: Material(
                      type: MaterialType.transparency,
                      child: _Panel(
                        request: request,
                        theme: theme,
                        semanticStatus: _semanticStatus,
                        semanticProgress: _semanticProgress,
                      ),
                    ),
                    builder: (BuildContext context, Widget? child) {
                      return theme.animation(
                        child!,
                        _controller,
                        animationAlignment,
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

double _adaptiveInset(double extent) {
  if (!extent.isFinite) {
    return 50;
  }
  return math.min(50, math.max(0, (extent - 120) / 2));
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.request,
    required this.theme,
    required this.semanticStatus,
    required this.semanticProgress,
  });

  final EasyLoadingRequest request;
  final EasyLoadingThemeData theme;
  final String? semanticStatus;
  final double? semanticProgress;

  @override
  Widget build(BuildContext context) {
    final customContent = request.customContent;
    if (customContent != null) {
      return ConstrainedBox(
        constraints: request.constraints,
        child: customContent,
      );
    }

    final indicator = request.indicator ?? _builtInIndicator();
    final status = request.status;
    final value = semanticProgress == null
        ? null
        : '${(semanticProgress! * 100).round()}%';

    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticStatus?.isNotEmpty == true ? semanticStatus : null,
      value: value,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: request.constraints,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(theme.radius),
              boxShadow: theme.boxShadow,
            ),
            child: Padding(
              padding: theme.contentPadding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (indicator != null)
                    Padding(
                      padding: status?.isNotEmpty == true
                          ? theme.textPadding
                          : EdgeInsets.zero,
                      child: indicator,
                    ),
                  if (status != null)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          status,
                          style:
                              theme.textStyle ??
                              TextStyle(
                                color: theme.textColor,
                                fontSize: theme.fontSize,
                              ),
                          textAlign: theme.textAlign,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _builtInIndicator() {
    switch (request.type) {
      case EasyLoadingContentType.loading:
        return LoadingIndicator(
          type: theme.indicatorType,
          color: theme.indicatorColor,
          size: theme.indicatorSize,
          lineWidth: theme.lineWidth,
        );
      case EasyLoadingContentType.progress:
        return EasyLoadingProgress(
          value: request.progress!,
          color: theme.progressColor,
          size: theme.indicatorSize,
          width: theme.progressWidth,
        );
      case EasyLoadingContentType.success:
        return Icon(
          Icons.done,
          color: theme.indicatorColor,
          size: theme.indicatorSize,
        );
      case EasyLoadingContentType.error:
        return Icon(
          Icons.clear,
          color: theme.indicatorColor,
          size: theme.indicatorSize,
        );
      case EasyLoadingContentType.info:
        return Icon(
          Icons.info_outline,
          color: theme.indicatorColor,
          size: theme.indicatorSize,
        );
      case EasyLoadingContentType.toast || EasyLoadingContentType.custom:
        return null;
    }
  }
}
