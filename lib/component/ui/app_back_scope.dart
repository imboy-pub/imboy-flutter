import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:imboy/theme/default/app_sizes.dart';

/// 为受保护页面提供边缘返回尝试；正常返回继续由路由自身处理。
/// Edge attempts share the page's asynchronous back handler, never force a pop.
class AppBackScope<T> extends StatefulWidget {
  const AppBackScope({
    super.key,
    required this.canPop,
    required this.onPopInvokedWithResult,
    required this.child,
    this.edgeGestureEnabled = true,
    this.allowAtRoot = false,
  });

  final bool canPop;
  final FutureOr<void> Function(bool didPop, T? result) onPopInvokedWithResult;
  final Widget child;
  final bool edgeGestureEnabled;

  /// Only internal navigation, such as a department hierarchy, opts in at root.
  final bool allowAtRoot;

  @override
  State<AppBackScope<T>> createState() => _AppBackScopeState<T>();
}

class _AppBackScopeState<T> extends State<AppBackScope<T>> {
  static const _nativeEdgeWidth = 20.0;
  final Set<int> _pointers = {};
  ModalRoute<dynamic>? _dragRoute;
  Offset? _dragOrigin;
  Offset _dragOffset = Offset.zero;
  bool _handlingPop = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resetGesture();
  }

  @override
  void didUpdateWidget(covariant AppBackScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canPop || !widget.edgeGestureEnabled) _resetGesture();
  }

  @override
  Widget build(BuildContext context) {
    final active = TickerMode.valuesOf(context).enabled;
    final enabled = !widget.canPop && widget.edgeGestureEnabled;
    return PopScope<T>(
      canPop: widget.canPop || !active,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || active) unawaited(_invoke(didPop, result));
      },
      child: _guardedChild(context, enabled && active),
    );
  }

  Widget _guardedChild(BuildContext context, bool enabled) {
    final padding = MediaQuery.paddingOf(context);
    final leadingInset = Directionality.of(context) == TextDirection.ltr
        ? padding.left
        : padding.right;
    return Listener(
      onPointerDown: _pointerDown,
      onPointerUp: (event) => _pointers.remove(event.pointer),
      onPointerCancel: _pointerCancel,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (enabled)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: math.max(_nativeEdgeWidth, leadingInset),
              child: _edgeDetector(),
            ),
        ],
      ),
    );
  }

  Widget _edgeDetector() => GestureDetector(
    behavior: HitTestBehavior.translucent,
    excludeFromSemantics: true,
    dragStartBehavior: DragStartBehavior.down,
    supportedDevices: const {PointerDeviceKind.touch},
    onHorizontalDragDown: _dragDown,
    onHorizontalDragUpdate: (details) {
      final origin = _dragOrigin;
      if (origin != null) _dragOffset = details.globalPosition - origin;
    },
    onHorizontalDragEnd: (_) => _dragEnd(),
    onHorizontalDragCancel: _resetGesture,
  );

  bool _canAttempt(ModalRoute<dynamic>? route) =>
      mounted &&
      !widget.canPop &&
      widget.edgeGestureEnabled &&
      !_handlingPop &&
      TickerMode.valuesOf(context).enabled &&
      route is PageRoute<dynamic> &&
      route.isCurrent &&
      route.isActive &&
      (!route.isFirst || widget.allowAtRoot) &&
      !route.fullscreenDialog &&
      route.animation?.status == AnimationStatus.completed &&
      route.secondaryAnimation?.status == AnimationStatus.dismissed &&
      route.navigator?.userGestureInProgress == false;

  void _dragDown(DragDownDetails details) {
    _resetGesture();
    final route = ModalRoute.of(context);
    if (!_canAttempt(route) || _pointers.length > 1) return;
    _dragRoute = route;
    _dragOrigin = details.globalPosition;
  }

  void _dragEnd() {
    final route = _dragRoute;
    final offset = _dragOffset;
    _resetGesture();
    if (route == null || !_canAttempt(route)) return;
    final direction = Directionality.of(context) == TextDirection.ltr ? 1 : -1;
    final horizontal = offset.dx * direction;
    final threshold = math.max(
      AppSizes.touchTarget,
      MediaQuery.sizeOf(context).width * 0.25,
    );
    if (horizontal < threshold || horizontal <= offset.dy.abs() * 1.5) return;
    unawaited(_invoke(false, null));
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length > 1) _resetGesture();
  }

  void _pointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    _resetGesture();
  }

  void _resetGesture() {
    _dragRoute = null;
    _dragOrigin = null;
    _dragOffset = Offset.zero;
  }

  Future<void> _invoke(bool didPop, T? result) async {
    if (didPop) {
      await widget.onPopInvokedWithResult(true, result);
      return;
    }
    if (_handlingPop) return;
    _handlingPop = true;
    try {
      await widget.onPopInvokedWithResult(false, result);
    } finally {
      _handlingPop = false;
    }
  }
}
