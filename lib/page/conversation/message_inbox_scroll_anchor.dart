import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A bounded restore transaction for the Web inbox's existing lazy sliver.
class MessageInboxScrollAnchor {
  final controller = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  List<String> _order = const [];
  Object? _scope;
  _Transaction? _transaction;
  bool _jumping = false;
  bool _scheduled = false;
  bool _disposed = false;

  /// Exposed for focused tests; a failed search is never recorded as restored.
  @visibleForTesting
  String? lastOutcome;

  Widget row(String id, Widget child) =>
      KeyedSubtree(key: _keys.putIfAbsent(id, GlobalKey.new), child: child);

  void userInput() {
    if (!_jumping) _finish('user-scroll');
  }

  bool onScroll(ScrollNotification notification) {
    if (!_jumping &&
        notification.depth == 0 &&
        (notification is UserScrollNotification &&
                notification.direction != ScrollDirection.idle ||
            notification is ScrollStartNotification &&
                notification.dragDetails != null ||
            notification is ScrollUpdateNotification &&
                notification.dragDetails != null)) {
      _finish('user-scroll');
    }
    return false;
  }

  void update(
    List<String> ids,
    Object scope, {
    required bool enabled,
    required bool Function() isCurrent,
  }) {
    final sameScope = enabled && _scope == scope;
    final changed = sameScope && !_sameOrder(_order, ids);
    if (!sameScope) {
      _finish('scope-changed');
    } else if (changed && _transaction == null) {
      final snapshots = _capture();
      if (snapshots.isNotEmpty) {
        _transaction = _Transaction(snapshots, controller.position, isCurrent);
        lastOutcome = 'pending';
      }
    }
    if (changed) _transaction?.offsets.clear();
    _order = enabled ? List.of(ids) : const [];
    _scope = enabled ? scope : null;
    final current = _order.toSet();
    _keys.removeWhere((id, _) => !current.contains(id));
    final transaction = _transaction;
    if (transaction != null) {
      while (transaction.index < transaction.snapshots.length &&
          !current.contains(transaction.snapshots[transaction.index].id)) {
        transaction.index++;
      }
      if (transaction.index == transaction.snapshots.length) {
        _finish('anchor-deleted');
      } else {
        _schedule();
      }
    }
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  ({double top, double bottom, double viewport})? _rect(String id) {
    final object = _keys[id]?.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize)
      return null;
    final viewport = RenderAbstractViewport.maybeOf(object);
    if (viewport == null || !viewport.attached || viewport.paintBounds.isEmpty)
      return null;
    final top = object.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return (
      top: top,
      bottom: top + object.size.height,
      viewport: viewport.paintBounds.height,
    );
  }

  List<_Snapshot> _capture() {
    if (!controller.hasClients || controller.positions.length != 1) return [];
    final position = controller.position;
    if (!position.hasContentDimensions ||
        position.isScrollingNotifier.value ||
        position.pixels <= position.minScrollExtent)
      return [];
    final snapshots = <_Snapshot>[];
    for (final id in _order) {
      final rect = _rect(id);
      if (rect != null && rect.bottom > 0 && rect.top < rect.viewport) {
        snapshots.add(_Snapshot(id, rect.top));
      }
    }
    snapshots.sort((a, b) => a.top.compareTo(b.top));
    return snapshots;
  }

  void _schedule() {
    if (_scheduled || _transaction == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _step();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _step() {
    final transaction = _transaction;
    if (_disposed || transaction == null) return;
    if (!transaction.isCurrent()) {
      _finish('scope-changed');
      return;
    }
    if (!controller.hasClients ||
        controller.positions.length != 1 ||
        !identical(controller.position, transaction.position) ||
        transaction.position.isScrollingNotifier.value) {
      _finish('position-changed');
      return;
    }
    final anchor = transaction.snapshots[transaction.index];
    final targetIndex = _order.indexOf(anchor.id);
    if (targetIndex < 0) {
      _finish('anchor-deleted');
      return;
    }
    if (transaction.attempts++ >= 128) {
      _finish('seek-exhausted');
      return;
    }
    final targetRect = _rect(anchor.id);
    double delta;
    if (targetRect != null) {
      delta = targetRect.top - anchor.top;
      if (delta.abs() <= 0.5) {
        _finish('restored');
        return;
      }
    } else {
      final seekDelta = _seekDelta(targetIndex);
      if (seekDelta == null) {
        _finish('seek-no-visible-row');
        return;
      }
      delta = seekDelta;
    }
    _applyDelta(transaction, delta);
  }

  double? _seekDelta(int targetIndex) {
    int? nearestIndex;
    ({double top, double bottom, double viewport})? nearest;
    for (var index = 0; index < _order.length; index++) {
      final rect = _rect(_order[index]);
      if (rect == null || rect.bottom <= 0 || rect.top >= rect.viewport)
        continue;
      if (nearestIndex == null ||
          (index - targetIndex).abs() < (nearestIndex - targetIndex).abs()) {
        nearestIndex = index;
        nearest = rect;
      }
    }
    if (nearest == null || nearestIndex == null || nearest.viewport <= 0) {
      return null;
    }
    final distance = (targetIndex - nearestIndex).abs();
    final estimate = math.max(nearest.bottom - nearest.top, 1.0) * distance;
    return math.min(estimate, nearest.viewport * 0.8) *
        (targetIndex > nearestIndex ? 1 : -1);
  }

  void _applyDelta(_Transaction transaction, double delta) {
    final position = transaction.position;
    final marker = (position.pixels * 100).round();
    if (!transaction.offsets.add(marker)) {
      _finish('seek-oscillation');
      return;
    }
    final next = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((next - position.pixels).abs() <= 0.01) {
      _finish('seek-at-boundary');
      return;
    }
    _jumping = true;
    try {
      controller.jumpTo(next);
    } finally {
      _jumping = false;
    }
    _schedule();
  }

  void _finish(String outcome) {
    if (_transaction != null) {
      lastOutcome = outcome;
      if (outcome.startsWith('seek-')) {
        debugPrint('[inbox-anchor] $outcome');
      }
    }
    _transaction = null;
  }

  void dispose() {
    _disposed = true;
    _finish('disposed');
    controller.dispose();
    _keys.clear();
  }
}

class _Snapshot {
  const _Snapshot(this.id, this.top);
  final String id;
  final double top;
}

class _Transaction {
  _Transaction(this.snapshots, this.position, this.isCurrent);
  final List<_Snapshot> snapshots;
  final ScrollPosition position;
  final bool Function() isCurrent;
  final Set<int> offsets = {};
  int index = 0;
  int attempts = 0;
}
