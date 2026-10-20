import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/channel_events.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'channel_detail_rules.dart';
import 'channel_di_provider.dart';
import 'channel_provider.dart';

/// Account-bound local cache only. Access-locked channels never reveal previews.
final channelListPreviewsProvider =
    FutureProvider.autoDispose<Map<int, ChannelMessageModel>>((ref) {
      ref.watch(currentUserProvider.select((user) => user?.uid));
      final channels = ref.watch(
        channelListProvider.select((state) => state.channels),
      );
      final updates = AppEventBus.on<ChannelNewMessageEvent>().listen(
        (_) => ref.invalidateSelf(),
      );
      final states = AppEventBus.on<ChannelStateChangedEvent>().listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(() {
        updates.cancel();
        states.cancel();
      });
      final ids = channels
          .where(
            (channel) => channel.isManaged || hasChannelContentAccess(channel),
          )
          .map((channel) => channel.id.toString())
          .toList(growable: false);
      if (ids.isEmpty) return const {};
      return ref.watch(channelServiceProvider).getCachedPreviews(ids);
    }, retry: (_, _) => null);
