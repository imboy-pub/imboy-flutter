import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart'
    show ChannelMessageRepo;
import 'package:imboy/store/repository/channel_repo_sqlite.dart'
    show ChannelRepo;

/// 会话列表顶部频道置顶区 — 单条摘要数据结构
final class SubscribedChannelSummary {
  const SubscribedChannelSummary({
    required this.channel,
    required this.subscription,
    this.lastMessagePreview,
    this.lastMessageTime,
  });

  final ChannelModel channel;
  final ChannelSubscriptionModel subscription;

  /// 最新一条消息的文本预览（null 表示尚无消息）
  final String? lastMessagePreview;

  /// 最新一条消息时间（毫秒 epoch），用于排序
  final int? lastMessageTime;

  int get channelId => channel.id;
  String get name => channel.name;
  String? get avatar => channel.avatar;
  int get unreadCount => subscription.unreadCount;
  bool get isPinned => subscription.isPinned;
}

/// 会话列表顶部订阅频道摘要列表
///
/// - 排序规则：置顶优先 → 有未读优先 → 最新消息时间倒序
/// - 自动响应 [ChannelStateChangedEvent] / [ChannelUnreadCountUpdatedEvent] /
///   [ChannelNewMessageEvent] 刷新
/// - 受 channelEnabled feature flag 保护（调用方判断，本 provider 不感知）
final subscribedChannelStripProvider = AsyncNotifierProvider<
  SubscribedChannelStripNotifier,
  List<SubscribedChannelSummary>
>(SubscribedChannelStripNotifier.new);

class SubscribedChannelStripNotifier
    extends AsyncNotifier<List<SubscribedChannelSummary>> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  Future<List<SubscribedChannelSummary>> build() async {
    _subscriptions
      ..add(
        AppEventBus.on<ChannelStateChangedEvent>().listen((_) => _reload()),
      )
      ..add(
        AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen(
          (e) => _applyUnreadUpdate(e),
        ),
      )
      ..add(
        AppEventBus.on<ChannelNewMessageEvent>().listen((_) => _reload()),
      );

    // Riverpod 在 provider dispose 时调用 onDispose
    ref.onDispose(() {
      for (final s in _subscriptions) {
        s.cancel();
      }
      _subscriptions.clear();
    });

    return _fetch();
  }

  Future<List<SubscribedChannelSummary>> _fetch() async {
    final repo = ChannelRepo();
    final rawRows = await repo.getSubscribedChannelsWithSubscription();

    final summaries = <SubscribedChannelSummary>[];
    final msgRepo = ChannelMessageRepo();

    for (final row in rawRows) {
      final channel = ChannelModel.fromMap(row);
      final sub = ChannelSubscriptionModel.fromMap(row);
      if (channel.id == 0) continue; // 防卫：id=0 哨兵跳过

      String? preview;
      int? msgTime;
      try {
        final latest = await msgRepo.getLatestMessages(
          channelId: channel.id.toString(),
          limit: 1,
        );
        if (latest.isNotEmpty) {
          preview = latest.first.contentPreview;
          msgTime = latest.first.createdAt.millisecondsSinceEpoch;
        }
      } catch (_) {
        // 查询失败不阻塞整体加载
      }

      summaries.add(
        SubscribedChannelSummary(
          channel: channel,
          subscription: sub,
          lastMessagePreview: preview,
          lastMessageTime: msgTime,
        ),
      );
    }

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
      return bTime.compareTo(aTime);
    });
  }

  /// 完整重载（订阅状态变化、新消息到达）
  void _reload() {
    state = const AsyncLoading();
    Future(() async {
      state = await AsyncValue.guard(_fetch);
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
      );
    }).toList();

    _sort(updated);
    state = AsyncData(updated);
  }
}
