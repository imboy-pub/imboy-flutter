import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_actions.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

import 'cs_message_bubble.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Bounded CS history. Anchors and read observations use laid-out boxes only.
class CsSessionTimeline extends StatefulWidget {
  const CsSessionTimeline({
    super.key,
    required this.messages,
    this.historyPartial = false,
    required this.readAllowed,
    required this.canAcknowledge,
    required this.onVisible,
    required this.hasOlder,
    required this.loadingOlder,
    required this.historyFailed,
    required this.olderFailed,
    required this.loadOlder,
    required this.retryHistory,
    required this.empty,
    required this.itemBuilder,
  });
  final List<EnterpriseMessage> messages;
  final bool historyPartial;
  final bool readAllowed, hasOlder, loadingOlder, historyFailed, olderFailed;
  final bool Function() canAcknowledge;
  final ValueChanged<List<String>> onVisible;
  final Future<void> Function() loadOlder, retryHistory;
  final Widget empty;
  final Widget Function(BuildContext, EnterpriseMessage) itemBuilder;
  @override
  State<CsSessionTimeline> createState() => _CsSessionTimelineState();
}

class _CsSessionTimelineState extends State<CsSessionTimeline> {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _center = GlobalKey();
  String? _pivot;
  final _boxes = <String, GlobalKey>{};
  bool _scheduled = false;
  bool _loading = false;
  bool _positioning = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_observeAfterLayout);
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _scheduled = false;
      _observeAfterLayout();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CsSessionTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasBottom =
        !_scroll.hasClients ||
        _scroll.position.extentAfter < AppSizes.touchTarget;
    final anchor = _visibleAnchor();
    final ids = oldWidget.messages.map((m) => m.id).toList();
    final changed = ids.join('/') != widget.messages.map((m) => m.id).join('/');
    if (!changed || _loading) return;
    _positioning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (wasBottom) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _restoreAnchor(anchor);
      }
      _positionSettled();
    });
  }

  void _positionSettled() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _positioning = false;
        _loading = false;
      });
      _observeAfterLayout();
    });
  }

  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  (String, double)? _visibleAnchor() {
    final viewport = _rect(_viewport);
    if (viewport == null) return null;
    for (final entry in _boxes.entries) {
      final rect = _rect(entry.value);
      if (rect != null && rect.overlaps(viewport)) return (entry.key, rect.top);
    }
    return null;
  }

  void _restoreAnchor((String, double)? anchor) {
    if (anchor == null || !_scroll.hasClients) return;
    final key = _boxes[anchor.$1];
    final rect = key == null ? null : _rect(key);
    if (rect == null) return;
    final target = _scroll.offset + rect.top - anchor.$2;
    _scroll.jumpTo(
      target.clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      ),
    );
  }

  void _observeAfterLayout() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          _positioning ||
          !widget.readAllowed ||
          !widget.canAcknowledge()) {
        return;
      }
      final viewport = _rect(_viewport);
      if (viewport == null || viewport.isEmpty) return;
      final visible = <String>[];
      for (final message in widget.messages) {
        final rect = _rect(_boxes[message.id]!);
        if (rect != null && !rect.isEmpty && rect.overlaps(viewport)) {
          visible.add(message.id);
        }
      }
      if (visible.isNotEmpty) widget.onVisible(visible);
    });
  }

  Future<void> _older() async {
    if (_loading || widget.loadingOlder || !widget.readAllowed) return;
    final anchor = _visibleAnchor();
    setState(() => _loading = true);
    try {
      await widget.loadOlder();
    } finally {
      _positioning = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restoreAnchor(anchor);
        _positionSettled();
      });
    }
  }

  Widget _messageSliver(List<EnterpriseMessage> messages, {Key? key}) {
    final indices = {
      for (var i = 0; i < messages.length; i++) _boxes[messages[i].id]!: i,
    };
    return SliverList(
      key: key,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final message = messages[index];
          return KeyedSubtree(
            key: _boxes[message.id],
            child: widget.itemBuilder(context, message),
          );
        },
        childCount: messages.length,
        findChildIndexCallback: (key) => indices[key],
      ),
    );
  }

  Widget _historyControls(BuildContext context) => Column(
    children: [
      if (widget.historyFailed)
        TextButton(
          onPressed: widget.retryHistory,
          child: Text(
            widget.historyPartial
                ? '${context.t.customerService.loadFailedTitle} · ${context.t.common.retry}'
                : context.t.customerService.loadFailedTitle,
          ),
        ),
      if (widget.hasOlder || widget.olderFailed)
        TextButton(
          key: const ValueKey('cs-load-older'),
          onPressed: widget.loadingOlder || _loading ? null : _older,
          child: Text(
            widget.olderFailed
                ? context.t.common.retry
                : context.t.common.loadMore,
          ),
        ),
      if (widget.loadingOlder || _loading)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.small),
          child: CircularProgressIndicator(),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.readAllowed) return const SizedBox.shrink();
    final messages = widget.messages;
    final ids = messages.map((m) => m.id).toSet();
    _boxes.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _boxes.putIfAbsent(id, GlobalKey.new);
    }
    if (_pivot == null && messages.isNotEmpty) _pivot = messages.last.id;
    final split = _pivot == null
        ? 0
        : messages.indexWhere(
            (m) => BigInt.parse(m.id) >= BigInt.parse(_pivot!),
          );
    final pivot = split < 0 ? messages.length : split;
    _observeAfterLayout();
    return SizedBox(
      key: _viewport,
      child: CustomScrollView(
        controller: _scroll,
        center: _center,
        anchor: 1.0,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _historyControls(context)),
          _messageSliver(messages.take(pivot).toList().reversed.toList()),
          _messageSliver(messages.skip(pivot).toList(), key: _center),
          if (messages.isEmpty) SliverToBoxAdapter(child: widget.empty),
        ],
      ),
    );
  }
}

/// Adapts the existing flow projection; the timeline never derives read facts.
class CsFlowTimeline extends StatelessWidget {
  const CsFlowTimeline({
    super.key,
    required this.flow,
    required this.readAllowed,
    required this.canAcknowledge,
    required this.onVisible,
    required this.loadOlder,
    required this.retryHistory,
    required this.bytesLoader,
    required this.onView,
    required this.contactName,
  });
  final CsSessionFlow flow;
  final bool readAllowed;
  final bool Function() canAcknowledge;
  final ValueChanged<List<String>> onVisible;
  final Future<void> Function() loadOlder, retryHistory;
  final Future<Uint8List?> Function(String) bytesLoader;
  final ValueChanged<CsMessageAsset> onView;
  final String contactName;

  Widget _bubble(BuildContext context, EnterpriseMessage message) {
    final actor = csSenderActorView(
      message,
      contactMaskedName: csMaskContactName(contactName),
    );
    return CsMessageBubble(
      message: message,
      isSeat: actor.isSeat,
      actorLabel: actor.label,
      assets: flow.messageAssets[message.id] ?? const <CsMessageAsset>[],
      bytesLoader: bytesLoader,
      onView: onView,
      serverReadAt: flow.messageReadAt[message.id],
    );
  }

  @override
  Widget build(BuildContext context) => CsSessionTimeline(
    key: ValueKey(
      '${flow.orgId}/${flow.workspaceId}/${flow.sessionId}/${flow.conversationId}/${flow.identityId}',
    ),
    messages: flow.messages,
    readAllowed: readAllowed && !flow.readRevoked,
    canAcknowledge: canAcknowledge,
    onVisible: onVisible,
    hasOlder: flow.hasOlder,
    loadingOlder: flow.loadingOlder,
    historyFailed: flow.historyError != null,
    olderFailed: flow.olderError != null,
    historyPartial: flow.historyError?.message == 'history-refresh-bounded',
    loadOlder: loadOlder,
    retryHistory: retryHistory,
    itemBuilder: _bubble,
    empty: Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Text(context.t.customerService.queuedEmptyTitle),
    ),
  );
}

class CsUnreadBadge extends StatelessWidget {
  const CsUnreadBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t.customerService.unreadBadgeLabel(n: count),
    child: Container(
      margin: const EdgeInsets.only(left: AppSpacing.small),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.tiny,
      ),
      decoration: BoxDecoration(
        color: AppColors.iosRed,
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: context.textStyle(
          FontSizeType.caption2,
          color: AppColors.onPrimary,
        ),
      ),
    ),
  );
}
