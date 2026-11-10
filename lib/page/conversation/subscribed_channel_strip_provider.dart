import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/channel/channel_detail_rules.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';

/// Shared subscription facts. Presentation preferences never remove entries here:
/// the generated channel-tab counter also consumes this provider.
final class SubscribedChannelSummary {
  const SubscribedChannelSummary({
    required this.channel,
    required this.subscription,
    this.lastMessagePreview,
    this.lastMessageTime,
    this.previewLoadFailed = false,
  });

  final ChannelModel channel;
  final ChannelSubscriptionModel subscription;

  /// 最新一条消息的文本预览（null 表示尚无消息）
  final String? lastMessagePreview;

  /// 最新一条消息时间（毫秒 epoch），用于排序
  final int? lastMessageTime;
  final bool previewLoadFailed;

  String get channelId => channel.id;
  String get name => channel.name;
  String? get avatar => channel.avatar;
  int get unreadCount => subscription.unreadCount;
  bool get isPinned => subscription.isPinned;
  bool get isMuted => subscription.isMuted;
}

/// Only explicitly personal, subscribed and currently accessible channels may
/// contribute content to the personal inbox. Unknown provenance stays unknown.
bool canShowPersonalInboxChannel(ChannelModel channel) =>
    channel.scope == 'personal' &&
    (channel.workspaceId?.isEmpty ?? true) &&
    channel.isSubscribed &&
    (channel.isManaged || hasChannelContentAccess(channel));

/// Account-bound local subscription summaries.
///
/// - 排序规则：置顶优先 → 有未读优先 → 最新消息时间倒序
/// - 自动响应 [ChannelStateChangedEvent] / [ChannelUnreadCountUpdatedEvent] /
///   [ChannelNewMessageEvent] 刷新
/// - 受 channelEnabled feature flag 保护（调用方判断，本 provider 不感知）
final subscribedChannelStripProvider =
    AsyncNotifierProvider<
      SubscribedChannelStripNotifier,
      List<SubscribedChannelSummary>
    >(SubscribedChannelStripNotifier.new);

class SubscribedChannelStripNotifier
    extends AsyncNotifier<List<SubscribedChannelSummary>> {
  SubscribedChannelStripNotifier({AuthSessionReader? session})
    : _session = session ?? authSessionReader;

  final AuthSessionReader _session;
  int _generation = 0;

  @override
  Future<List<SubscribedChannelSummary>> build() async {
    final session = _session.current;
    final generation = ++_generation;
    final environment = currentEnv;
    final endpoint = Env().apiBaseUrl;
    final service = ref.watch(channelServiceProvider);
    final unreadUpdates = <String, int>{};
    bool isCurrent() =>
        ref.mounted &&
        generation == _generation &&
        _session.isCurrent(session) &&
        environment == currentEnv &&
        endpoint == Env().apiBaseUrl;
    void reload({bool discardPrevious = false}) {
      if (!isCurrent()) return;
      if (discardPrevious) state = const AsyncData([]);
      ref.invalidateSelf();
    }

    void authChanged() {
      if (_session.isCurrent(session)) return;
      ++_generation;
      // Invalidation normally retains previous data; never retain it across an
      // account switch or a same-account reauthentication.
      state = const AsyncData([]);
      ref.invalidateSelf();
    }

    _session.addListener(authChanged);
    final subscriptions = <StreamSubscription<dynamic>>[
      AppEventBus.on<ChannelStateChangedEvent>().listen(
        (_) => reload(discardPrevious: true),
      ),
      AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen((e) {
        if (!isCurrent()) return;
        // An event arriving while previews load must beat the older SQL
        // subscription snapshot returned by this same load.
        unreadUpdates[e.channelId] = e.unreadCount;
        _applyUnreadUpdate(e);
      }),
      AppEventBus.on<ChannelNewMessageEvent>().listen((_) => reload()),
      AppEventBus.on<ChannelMessageDeletedEvent>().listen((_) => reload()),
    ];

    // Riverpod 在 provider dispose 时调用 onDispose
    ref.onDispose(() {
      _session.removeListener(authChanged);
      for (final s in subscriptions) {
        s.cancel();
      }
    });

    if (!isCurrent()) return const [];
    return _fetch(service, isCurrent, unreadUpdates);
  }

  Future<List<SubscribedChannelSummary>> _fetch(
    ChannelService service,
    bool Function() isCurrent,
    Map<String, int> unreadUpdates,
  ) async {
    final rawRows = await service.repo.getSubscribedChannelsWithSubscription();
    if (!isCurrent()) return const [];

    final rows =
        <({ChannelModel channel, ChannelSubscriptionModel subscription})>[];
    final previewIds = <String>[];

    for (final row in rawRows) {
      final channel = ChannelModel.fromMap(row);
      final sub = ChannelSubscriptionModel.fromMap(row);
      if (channel.id == '0') continue; // 防卫：id=0 哨兵跳过
      rows.add((channel: channel, subscription: sub));
      if (canShowPersonalInboxChannel(channel)) previewIds.add(channel.id);
    }
    var previews = <String, ChannelMessageModel>{};
    var previewLoadFailed = false;
    if (previewIds.isNotEmpty) {
      try {
        previews = await service.getCachedPreviews(previewIds);
      } catch (_) {
        // Keep subscription counts, but expose the failed preview load to UI.
        previewLoadFailed = true;
      }
    }
    if (!isCurrent()) return const [];
    final summaries = [
      for (final row in rows)
        SubscribedChannelSummary(
          channel: row.channel,
          subscription: unreadUpdates.containsKey(row.channel.id)
              ? row.subscription.copyWith(
                  unreadCount: unreadUpdates[row.channel.id],
                )
              : row.subscription,
          lastMessagePreview: previews[row.channel.id]?.contentPreview,
          lastMessageTime:
              previews[row.channel.id]?.createdAt.millisecondsSinceEpoch,
          previewLoadFailed:
              previewLoadFailed && canShowPersonalInboxChannel(row.channel),
        ),
    ];

    _sort(summaries);
    return summaries;
  }

  void _sort(List<SubscribedChannelSummary> list) {
    list.sort((a, b) {
      // 1. 置顶优先
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      // 2. 有未读优先
      final aHasUnread = a.unreadCount > 0;
      final bHasUnread = b.unreadCount > 0;
      if (aHasUnread != bHasUnread) return aHasUnread ? -1 : 1;
      // 3. 最新消息时间倒序
      final aTime = a.lastMessageTime ?? 0;
      final bTime = b.lastMessageTime ?? 0;
      final byTime = bTime.compareTo(aTime);
      return byTime == 0 ? a.channelId.compareTo(b.channelId) : byTime;
    });
  }

  /// 仅更新未读数（避免全量重载闪动）
  void _applyUnreadUpdate(ChannelUnreadCountUpdatedEvent e) {
    final current = state.value;
    if (current == null) return;

    final updated = current.map((s) {
      if (s.channelId.toString() != e.channelId) return s;
      final newSub = s.subscription.copyWith(unreadCount: e.unreadCount);
      return SubscribedChannelSummary(
        channel: s.channel,
        subscription: newSub,
        lastMessagePreview: s.lastMessagePreview,
        lastMessageTime: s.lastMessageTime,
        previewLoadFailed: s.previewLoadFailed,
      );
    }).toList();

    _sort(updated);
    state = AsyncData(updated);
  }
}
