import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

bool isLocationTargetVisible(GlobalKey key) {
  final target = key.currentContext?.findRenderObject();
  final viewport = target == null
      ? null
      : RenderAbstractViewport.maybeOf(target);
  if (target == null ||
      viewport == null ||
      !target.attached ||
      !viewport.attached) {
    return false;
  }
  return MatrixUtils.transformRect(
    target.getTransformTo(viewport),
    target.paintBounds,
  ).overlaps(viewport.paintBounds);
}
