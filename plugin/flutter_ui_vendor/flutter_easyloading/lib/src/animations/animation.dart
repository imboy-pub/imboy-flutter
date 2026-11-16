import 'package:flutter/widgets.dart';

/// Defines how an EasyLoading panel responds to its animation controller.
abstract class EasyLoadingAnimation {
  const EasyLoadingAnimation();

  /// Builds the animated representation of [child].
  Widget call(
    Widget child,
    AnimationController controller,
    AlignmentGeometry alignment,
  ) {
    return buildWidget(child, controller, alignment);
  }

  /// Creates the transition for [child] at the controller's current value.
  Widget buildWidget(
    Widget child,
    AnimationController controller,
    AlignmentGeometry alignment,
  );
}

/// Fades the loading panel in and out.
class OpacityAnimation extends EasyLoadingAnimation {
  const OpacityAnimation();

  @override
  Widget buildWidget(
    Widget child,
    AnimationController controller,
    AlignmentGeometry alignment,
  ) {
    return Opacity(opacity: controller.value, child: child);
  }
}

/// Slides the loading panel from its resolved alignment while fading it.
class OffsetAnimation extends EasyLoadingAnimation {
  const OffsetAnimation();

  @override
  Widget buildWidget(
    Widget child,
    AnimationController controller,
    AlignmentGeometry alignment,
  ) {
    final resolved = alignment is Alignment
        ? alignment
        : alignment.resolve(TextDirection.ltr);
    final begin = Offset(
      resolved.x.clamp(-1.0, 1.0).toDouble(),
      resolved.y.clamp(-1.0, 1.0).toDouble(),
    );
    final animation = Tween<Offset>(
      begin: begin,
      end: Offset.zero,
    ).animate(controller);
    return Opacity(
      opacity: controller.value,
      child: SlideTransition(position: animation, child: child),
    );
  }
}

/// Scales the loading panel while fading it.
class ScaleAnimation extends EasyLoadingAnimation {
  const ScaleAnimation();

  @override
  Widget buildWidget(
    Widget child,
    AnimationController controller,
    AlignmentGeometry alignment,
  ) {
    return Opacity(
      opacity: controller.value,
      child: ScaleTransition(scale: controller, child: child),
    );
  }
}
