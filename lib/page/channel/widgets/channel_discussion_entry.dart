import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// A fresh binding read never joins the group. Membership requires a user tap.
class ChannelDiscussionEntry extends ConsumerStatefulWidget {
  const ChannelDiscussionEntry({super.key, required this.channel});
  final ChannelModel channel;

  @override
  ConsumerState<ChannelDiscussionEntry> createState() =>
      _ChannelDiscussionEntryState();
}

class _ChannelDiscussionEntryState
    extends ConsumerState<ChannelDiscussionEntry> {
  bool _busy = false;
  int? _groupId;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadBinding);
  }

  @override
  void didUpdateWidget(covariant ChannelDiscussionEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.id != widget.channel.id ||
        oldWidget.channel.isSubscribed != widget.channel.isSubscribed ||
        oldWidget.channel.hasPurchased != widget.channel.hasPurchased ||
        oldWidget.channel.discussionGroupId !=
            widget.channel.discussionGroupId) {
      Future.microtask(_loadBinding);
    }
  }

  Future<void> _loadBinding() async {
    final generation = ++_generation;
    if (!mounted || !ChannelApi.microCommunityEnabled) return;
    setState(() {
      _groupId = null;
      _error = null;
    });
    try {
      final id = await ref
          .read(channelApiProvider)
          .getDiscussion(widget.channel.id.toString());
      if (!mounted || generation != _generation) return;
      setState(() => _groupId = id);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = context.t.common.loadError);
      }
    }
  }

  bool get _eligible =>
      widget.channel.isManaged ||
      (widget.channel.isSubscribed &&
          (!widget.channel.isPaid || widget.channel.hasPurchased));

  Future<bool?> _confirmJoin() => showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(context.t.channel.joinDiscussion),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.t.common.buttonCancel),
        ),
        CupertinoDialogAction(
          key: const Key('mc_join_confirm'),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.t.common.buttonConfirm),
        ),
      ],
    ),
  );

  Future<void> _join() async {
    if (_busy ||
        !_eligible ||
        _groupId == null ||
        !ChannelApi.microCommunityEnabled) {
      return;
    }
    final approved = await _confirmJoin();
    if (approved != true || !mounted || !ChannelApi.microCommunityEnabled) {
      return;
    }
    setState(() => _busy = true);
    try {
      final binding = await ref
          .read(channelApiProvider)
          .getDiscussion(widget.channel.id.toString());
      if (binding == null || binding != _groupId) {
        throw const FormatException('binding changed');
      }
      final result = await ref
          .read(channelApiProvider)
          .joinDiscussion(widget.channel.id.toString());
      final joined = int.tryParse('${result['discussion_group_id']}');
      if (joined != binding) {
        throw const FormatException('discussion identity changed');
      }
      if (!mounted || !ChannelApi.microCommunityEnabled) return;
      context.push(
        '/chat/$joined',
        extra: {
          'type': 'C2G',
          'title': result['title']?.toString() ?? context.t.chat.groupChat,
          'avatar': result['avatar']?.toString() ?? '',
          'options': {'memberCount': result['member_count'] ?? 0},
        },
      );
    } catch (_) {
      if (mounted) AppLoading.showError(context.t.common.loadError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ChannelApi.microCommunityEnabled) return const SizedBox.shrink();
    if (_error != null) {
      return CupertinoButton(
        key: const Key('mc_discussion_retry'),
        onPressed: _loadBinding,
        child: Text(context.t.common.retry),
      );
    }
    if (_groupId == null || !_eligible) return const SizedBox.shrink();
    return Padding(
      padding: AppSpacing.allRegular,
      child: CupertinoButton(
        key: const Key('mc_discussion_join'),
        minimumSize: const Size(double.infinity, 44),
        onPressed: _busy ? null : _join,
        child: _busy
            ? const CupertinoActivityIndicator()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.chat_bubble_2,
                    color: AppColors.iosBlue,
                  ),
                  AppSpacing.horizontalSmall,
                  Text(context.t.channel.joinDiscussion),
                ],
              ),
      ),
    );
  }
}
