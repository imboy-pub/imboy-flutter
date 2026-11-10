import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/conversation/channel_inbox_preferences.dart';
import 'package:imboy/page/conversation/message_inbox_channel_host.dart';
import 'package:imboy/page/conversation/message_inbox_entry.dart';
import 'package:imboy/page/conversation/message_inbox_time.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart';
import 'package:imboy/service/channel_inbox_actions.dart';
import 'package:imboy/store/repository/channel_inbox_preference_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'message_inbox_actions.dart';
import 'message_inbox_tile.dart';

/// Adapter kept behind compiledSubscribedChannelStrip(). The generated feature
/// seam and its signature stay stable while the host owns one unified list.
class SubscribedChannelStrip extends ConsumerWidget {
  const SubscribedChannelStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(subscribedChannelStripProvider);
    final hidden = ref.watch(channelInboxHiddenIdsProvider);
    final owner = ref.read(channelInboxPreferenceRepoProvider).captureScope();
    final entries = <MessageInboxEntry>[];
    final names = <String, int>{};
    for (final summary
        in summaries.value ?? const <SubscribedChannelSummary>[]) {
      if (canShowPersonalInboxChannel(summary.channel)) {
        names.update(summary.name, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    // Never momentarily reveal hidden channels before preferences have loaded.
    if (hidden.value != null) {
      for (final summary
          in summaries.value ?? const <SubscribedChannelSummary>[]) {
        if (!canShowPersonalInboxChannel(summary.channel) ||
            hidden.value!.contains(summary.channelId)) {
          continue;
        }
        if (summary.lastMessageTime == null &&
            summary.unreadCount == 0 &&
            !summary.isPinned) {
          continue;
        }
        final customId = summary.channel.customId?.trim() ?? '';
        final source = names[summary.name]! > 1
            ? (customId.isNotEmpty ? '@$customId' : '#${summary.channelId}')
            : '';
        final preview = [
          if (source.isNotEmpty) source,
          if (summary.lastMessagePreview?.isNotEmpty ?? false)
            summary.lastMessagePreview!,
        ].join(' · ');
        entries.add(
          MessageInboxEntry(
            key: 'channel:${summary.channelId}',
            kind: MessageInboxKind.channel,
            title: summary.name,
            preview: preview,
            lastTime: summary.lastMessageTime ?? 0,
            unreadCount: summary.unreadCount,
            isPinned: summary.isPinned,
            builder: (_) => _ChannelInboxTile(
              summary: summary,
              preview: preview,
              owner: owner,
            ),
          ),
        );
      }
    }
    final data = MessageInboxChannelData(
      entries: entries,
      isLoading: summaries.isLoading || hidden.isLoading,
      error:
          summaries.error ??
          hidden.error ??
          ((summaries.value?.any((item) => item.previewLoadFailed) ?? false)
              ? StateError('channel preview unavailable')
              : null),
      refresh: () async {
        final summaryLoad = ref.refresh(subscribedChannelStripProvider.future);
        final preferenceLoad = ref.refresh(
          channelInboxHiddenIdsProvider.future,
        );
        try {
          await Future.wait([summaryLoad, preferenceLoad]);
        } catch (_) {
          // The providers retain AsyncError; the host exposes its retry state.
        }
      },
    );
    final host = MessageInboxChannelHost.maybeOf(context);
    if (host != null) return host.builder(context, data);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in selectMessageInboxEntries(entries))
          entry.builder(context),
      ],
    );
  }
}

class _ChannelInboxTile extends ConsumerWidget {
  const _ChannelInboxTile({
    required this.summary,
    required this.preview,
    required this.owner,
  });
  final SubscribedChannelSummary summary;
  final String preview;
  final ChannelInboxPreferenceScope owner;

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(channelInboxPreferenceRepoProvider);
    final scope = owner;
    if (!repo.isCurrent(scope)) return;
    final preferences = ref.read(channelInboxHiddenIdsProvider.notifier);
    final service = ref.read(channelServiceProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final t = context.t;
    await showMessageInboxActions(
      context,
      title: summary.name,
      message: t.chat.inbox.channelOnlyDescription,
      actions: [
        MessageInboxAction(
          summary.isPinned ? t.chat.unpin : t.chat.pin,
          () async {
            if (!repo.isCurrent(scope)) return;
            final success = await setPersonalInboxChannelPinned(
              service: service,
              channelId: summary.channelId,
              pinned: !summary.isPinned,
              isCurrent: () => repo.isCurrent(scope),
            );
            if (repo.isCurrent(scope) && !success) {
              AppLoading.showError(t.chat.inbox.actionFailed);
            }
          },
        ),
        MessageInboxAction(t.chat.inbox.channelOnly, () async {
          if (!repo.isCurrent(scope)) return;
          final success = await preferences.setHidden(
            scope,
            summary.channelId,
            true,
          );
          if (!repo.isCurrent(scope)) return;
          if (!success) {
            AppLoading.showError(t.chat.inbox.actionFailed);
            return;
          }
          if (messenger == null || !messenger.mounted) return;
          // The hidden row is disposed now; the scaffold owns feedback/undo.
          // A stale snackbar cannot write into another account.
          messenger.showSnackBar(
            SnackBar(
              content: Text(t.chat.inbox.channelOnly),
              action: SnackBarAction(
                label: t.chat.inbox.undo,
                onPressed: () async {
                  if (!repo.isCurrent(scope)) return;
                  final restored = await preferences.setHidden(
                    scope,
                    summary.channelId,
                    false,
                  );
                  if (repo.isCurrent(scope) && !restored) {
                    AppLoading.showError(t.chat.inbox.actionFailed);
                  }
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.getTextSecondary(brightness);
    return MessageInboxTile(
      key: ValueKey('channel-inbox-row-${summary.channelId}'),
      avatar: _ChannelAvatar(avatar: summary.avatar, name: summary.name),
      title: Row(
        children: [
          Icon(
            CupertinoIcons.speaker_2,
            size: AppSpacing.regular,
            color: secondary,
            semanticLabel: context.t.channel.title,
          ),
          AppSpacing.horizontalTiny,
          Expanded(
            child: Text(
              summary.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.body,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextColor(brightness),
              ),
            ),
          ),
        ],
      ),
      preview: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(FontSizeType.subheadline, color: secondary),
      ),
      timeLabel: formatMessageInboxTime(summary.lastMessageTime ?? 0),
      unreadCount: summary.unreadCount,
      isMuted: summary.isMuted,
      isPinned: summary.isPinned,
      onTap: () {
        if (ref.read(channelInboxPreferenceRepoProvider).isCurrent(owner)) {
          context.push('/channel/${summary.channelId}');
        }
      },
      onLongPress: () => _showActions(context, ref),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.avatar, required this.name});
  final String? avatar;
  final String name;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadius.borderRadiusMedium,
    child: avatar != null && avatar!.isNotEmpty
        ? Image(
            image: cachedImageProvider(avatar!, w: 96),
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => _placeholder(context),
          )
        : _placeholder(context),
  );

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: AppColors.primaryAlpha10,
    child: Center(
      child: AvatarFallbackContent(
        name: name,
        color: AppColors.primary,
        emptyIcon: CupertinoIcons.speaker_2,
        iconSize: AppSpacing.large,
        textStyle: context.textStyle(
          FontSizeType.large,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
