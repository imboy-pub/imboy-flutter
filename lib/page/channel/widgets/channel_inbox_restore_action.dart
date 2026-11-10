import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/channel_inbox_preferences.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/repository/channel_inbox_preference_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Visible recovery path in the subscription directory. Restoring visibility
/// never alters subscription, notification, pinning or read-watermark facts.
class ChannelInboxRestoreAction extends ConsumerStatefulWidget {
  const ChannelInboxRestoreAction({super.key, required this.channel});
  final ChannelModel channel;

  @override
  ConsumerState<ChannelInboxRestoreAction> createState() =>
      _ChannelInboxRestoreActionState();
}

class _ChannelInboxRestoreActionState
    extends ConsumerState<ChannelInboxRestoreAction> {
  bool _restoring = false;

  Future<void> _restore(ChannelInboxPreferenceScope scope) async {
    final repo = ref.read(channelInboxPreferenceRepoProvider);
    if (!repo.isCurrent(scope) || _restoring) return;
    final preferences = ref.read(channelInboxHiddenIdsProvider.notifier);
    final failure = context.t.chat.inbox.actionFailed;
    setState(() => _restoring = true);
    final success = await preferences.setHidden(
      scope,
      widget.channel.id,
      false,
    );
    if (!mounted) return;
    setState(() => _restoring = false);
    if (repo.isCurrent(scope) && !success) {
      AppLoading.showError(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    if (channel.scope != 'personal' ||
        (channel.workspaceId?.isNotEmpty ?? false)) {
      return const SizedBox.shrink();
    }
    final hidden = ref.watch(channelInboxHiddenIdsProvider).value;
    if (!(hidden?.contains(channel.id) ?? false)) {
      return const SizedBox.shrink();
    }
    final summaries =
        ref.watch(subscribedChannelStripProvider).value ??
        const <SubscribedChannelSummary>[];
    final unread = summaries
        .where((item) => item.channelId == channel.id)
        .fold<int>(0, (total, item) => total + item.unreadCount);
    final brightness = Theme.of(context).brightness;
    final t = context.t;
    final owner = ref.read(channelInboxPreferenceRepoProvider).captureScope();
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.regular + AppSpacing.xxxLarge,
        end: AppSpacing.regular,
        bottom: AppSpacing.small,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.small,
        children: [
          Text(
            unread > 0
                ? '${t.chat.inbox.channelOnly} · ${t.common.unreadCount(count: '$unread')}'
                : t.chat.inbox.channelOnly,
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.getTextSecondary(brightness),
            ),
          ),
          CupertinoButton(
            key: ValueKey('restore-channel-inbox-${channel.id}'),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny),
            onPressed: _restoring ? null : () => _restore(owner),
            child: _restoring
                ? const CupertinoActivityIndicator()
                : Text(t.chat.inbox.restoreToInbox),
          ),
        ],
      ),
    );
  }
}
