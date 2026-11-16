part of 'chat_message_list.dart';

extension _SavedChatReading on _ChatMessageListState {
  bool _restoreScreenAnchor(
    _ScreenReadingAnchor anchor,
    ScrollController controller,
  ) {
    if (anchor.revision != _revision ||
        anchor.session != widget.readingSessionKey ||
        !identical(anchor.controller, controller) ||
        controller.offset != anchor.pixels ||
        _corrections >= _ChatMessageListState._maxCorrections)
      return false;
    final box = _rowBox(anchor.id);
    if (box == null) return false;
    final delta = anchor.y - box.localToGlobal(Offset.zero).dy;
    if (delta.abs() <= 0.5) {
      _corrections = 0;
      return true;
    }
    final position = controller.position;
    final target = (controller.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - controller.offset).abs() <= 0.5) return false;
    // Recheck immediately before jumpTo: an active drag/own-send must win.
    if (!identical(_idleHistory(), controller)) return false;
    _screenAnchor = (
      id: anchor.id,
      y: anchor.y,
      pixels: target,
      session: anchor.session,
      revision: anchor.revision,
      controller: controller,
    );
    _corrections++;
    _restoringAnchor = true;
    try {
      controller.jumpTo(target);
    } finally {
      _restoringAnchor = false;
    }
    _scheduleReadingLayout();
    return true;
  }

  bool _restoreSavedAnchor() {
    final saved = _savedAnchor;
    final controller = widget.scrollController;
    if (saved == null ||
        !mounted ||
        widget.isCurrent?.call() == false ||
        controller == null ||
        controller.positions.length != 1)
      return false;
    final position = controller.position;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (!position.hasContentDimensions ||
        position.isScrollingNotifier.value ||
        viewport is! RenderBox ||
        !viewport.attached ||
        !viewport.hasSize) {
      return false;
    }
    final targetIndex = widget.messages.indexWhere((m) => m.id == saved.id);
    if (targetIndex < 0 || _savedAttempts++ >= 128) {
      _savedAnchor = null;
      return false;
    }
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final target = _rowBox(saved.id);
    final delta = target == null
        ? _savedSeekDelta(targetIndex, viewportTop, viewport.size.height)
        : saved.y - (target.localToGlobal(Offset.zero).dy - viewportTop);
    if (delta == null) {
      _savedAnchor = null;
      return false;
    }
    if (target != null && delta.abs() <= 0.5) {
      _savedAnchor = null;
      widget.onReadingRestoreComplete?.call();
      return false;
    }
    return _jumpSaved(controller, delta);
  }

  double? _savedSeekDelta(int targetIndex, double viewportTop, double height) {
    int? nearestIndex;
    RenderBox? nearest;
    for (final entry in _rowKeys.entries) {
      final index = widget.messages.indexWhere((m) => m.id == entry.key);
      final box = _rowBox(entry.key);
      if (index < 0 || box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy - viewportTop;
      if (top + box.size.height <= 0 || top >= height) continue;
      if (nearestIndex == null ||
          (index - targetIndex).abs() < (nearestIndex - targetIndex).abs()) {
        nearestIndex = index;
        nearest = box;
      }
    }
    if (nearest == null || nearestIndex == null || height <= 0) return null;
    final distance = (targetIndex - nearestIndex).abs();
    final estimate = math.max(nearest.size.height, 1.0) * distance;
    return math.min(estimate, height * 0.8) *
        (targetIndex > nearestIndex ? 1 : -1);
  }

  bool _jumpSaved(ScrollController controller, double delta) {
    final position = controller.position;
    if (!_savedOffsets.add((position.pixels * 100).round())) {
      _savedAnchor = null;
      return false;
    }
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() <= 0.01) {
      _savedAnchor = null;
      return false;
    }
    _restoringAnchor = true;
    try {
      controller.jumpTo(target);
    } finally {
      _restoringAnchor = false;
    }
    _scheduleReadingLayout();
    return true;
  }
}
