part of 'channel_message_item.dart';

/// Per-item metadata state and the corresponding manager/author menus.
mixin _ChannelMessageMetadataActions on ConsumerState<ChannelMessageItem> {
  bool _metadataBusy = false;

  Future<void> _setPinned(bool pinned);
  void _showDeleteMessageDialog();
  void _shareMessage();

  Widget _buildPostMetadata(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
    child: Wrap(
      spacing: AppSpacing.small,
      children: [
        if (widget.message.isEssence)
          Padding(
            padding: AppSpacing.allTiny,
            child: Text(
              context.t.channel.essence,
              style: context.textStyle(
                FontSizeType.caption2,
                color: AppColors.iosOrange,
              ),
            ),
          ),
        for (final tag in widget.message.tags)
          CupertinoButton(
            key: ValueKey('mc_tag_${widget.message.id}_$tag'),
            padding: AppSpacing.allTiny,
            minimumSize: const Size(44, 44),
            onPressed: widget.onTagSelected == null
                ? null
                : () => widget.onTagSelected!(tag),
            child: Text(
              '#$tag',
              style: context.textStyle(
                FontSizeType.caption2,
                color: AppColors.iosBlue,
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _setEssence() async {
    if (_metadataBusy ||
        !widget.isManaged ||
        !ChannelApi.microCommunityEnabled) {
      return;
    }
    _metadataBusy = true;
    try {
      await ref
          .read(channelApiProvider)
          .setPostEssence(
            widget.channelId,
            widget.message.id.toString(),
            !widget.message.isEssence,
          );
      await ref
          .read(channelDetailProvider.notifier)
          .loadMessages(widget.channelId);
      widget.onMetadataChanged?.call();
    } catch (_) {
      if (mounted) AppLoading.showError(context.t.common.loadError);
    } finally {
      _metadataBusy = false;
    }
  }

  Future<void> _editTags() async {
    if (_metadataBusy || !ChannelApi.microCommunityEnabled) return;
    final value = await showCupertinoDialog<List<String>>(
      context: context,
      builder: (_) => PostTagsDialog(initialTags: widget.message.tags),
    );
    if (value == null || !mounted) return;
    final tags = value;
    _metadataBusy = true;
    try {
      await ref
          .read(channelApiProvider)
          .setPostTags(widget.channelId, widget.message.id.toString(), tags);
      await ref
          .read(channelDetailProvider.notifier)
          .loadMessages(widget.channelId);
      widget.onMetadataChanged?.call();
    } catch (_) {
      if (mounted) AppLoading.showError(context.t.common.loadError);
    } finally {
      _metadataBusy = false;
    }
  }

  // ---- 管理菜单 ----

  void _showManageMenu(BuildContext context) {
    final t = context.t;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + renderBox.size.width - 120,
        position.dy,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height,
      ),
      items: _manageMenuItems(t),
    ).then((value) {
      if (value != null && context.mounted) _handleMessageAction(value);
    });
  }

  List<PopupMenuEntry<String>> _manageMenuItems(Translations t) {
    return [
      if (ChannelApi.microCommunityEnabled)
        CheckedPopupMenuItem(
          value: 'essence',
          checked: widget.message.isEssence,
          child: Text(t.channel.essence),
        ),
      if (ChannelApi.microCommunityEnabled)
        PopupMenuItem(value: 'tags', child: Text(t.channel.editPostTags)),
      _pinMenuItem(t),
      _deleteMenuItem(t),
    ];
  }

  PopupMenuEntry<String> _pinMenuItem(Translations t) {
    return PopupMenuItem(
      value: widget.message.isPinned ? 'unpin' : 'pin',
      child: ListTile(
        leading: Icon(
          widget.message.isPinned
              ? CupertinoIcons.pin
              : CupertinoIcons.pin_fill,
          size: 20,
        ),
        title: Text(
          widget.message.isPinned
              ? t.channel.unpinMessage
              : t.channel.pinMessage,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  PopupMenuEntry<String> _deleteMenuItem(Translations t) {
    return PopupMenuItem(
      value: 'delete',
      child: ListTile(
        leading: const Icon(
          CupertinoIcons.delete,
          size: 20,
          color: AppColors.iosRed,
        ),
        title: Text(
          t.channel.deleteMessage,
          style: const TextStyle(color: AppColors.iosRed),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final t = context.t;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoModalSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ChannelApi.microCommunityEnabled &&
                widget.message.authorId?.toString() ==
                    UserRepoLocal.to.currentUid)
              CupertinoButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _editTags();
                },
                child: Text(t.channel.editPostTags),
              ),
            ListTile(
              leading: const Icon(CupertinoIcons.doc_on_doc),
              title: Text(t.common.copy),
              onTap: () {
                Navigator.pop(ctx);
                if (widget.message.msgType == ChannelMessageType.text) {
                  Clipboard.setData(
                    ClipboardData(text: widget.message.content),
                  );
                  AppLoading.showToast(t.main.copiedToClipboard);
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.share),
              title: Text(t.channel.share),
              onTap: () {
                Navigator.pop(ctx);
                _shareMessage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMessageAction(String action) async {
    switch (action) {
      case 'essence':
        await _setEssence();
        break;
      case 'tags':
        await _editTags();
        break;
      case 'pin':
        await _setPinned(true);
        break;
      case 'unpin':
        await _setPinned(false);
        break;
      case 'delete':
        _showDeleteMessageDialog();
        break;
    }
  }
}
