part of 'web_shell_bootstrap.dart';

extension _WebChatReadingRestore on WebChatPanelState {
  void _returnToLatest() {
    if (_savedReading != null) {
      _readingResetSaved();
    } else {
      _acceptReadingInput();
    }
    final revision = _readingRevision;
    // DEF-A11YNEW-05：prefers-reduced-motion 下回底跳转不做 animateTo
    // 滚动（引擎已把 Web 的 prefers-reduced-motion 映射进
    // MediaQuery.disableAnimations；此前此处恒走动画滚动分支）。
    final animate = !MediaQuery.disableAnimationsOf(context);
    unawaited(
      _scrollManager.scrollToBottom(
        animated: animate,
        isCurrent: () =>
            mounted && _readingOwned && revision == _readingRevision,
      ),
    );
  }

  void _acceptReadingInput() {
    _holdReadingBookmark = false;
    _savedReading = null;
  }

  Future<void> _loadSavedReading(
    ChatNotifier notifier,
    ConversationModel conversation,
    WebReadingAnchor saved,
    bool Function() current,
  ) async {
    var pages = 0;
    bool found() =>
        notifier.chatService?.messages.any((m) => m.id == saved.id) ?? false;
    while (current() && !found() && _readingHasMore && pages++ < 100) {
      final before = notifier.chatService?.messages.length ?? 0;
      await notifier.loadMoreMessages(
        conversation,
        webNewestFirst: true,
        allowPendingRetry: false,
      );
      if (!current()) return;
      notifier.syncMessagesToState();
      if ((notifier.chatService?.messages.length ?? 0) <= before) break;
    }
    if (!current()) return;
    if (!found()) {
      _savedReading = null;
      debugPrint('[web-reading] restore-incomplete');
    }
  }

  Future<void> _loadOlder() async {
    final owner = _owner;
    final selection = widget.selection;
    final request = _request;
    final resourceOwner = _resourceOwner;
    bool current() =>
        owner != null &&
        resourceOwner != null &&
        _current(request, selection, owner) &&
        AccountLocalTaskOwner.capture(uid: owner.uid) == resourceOwner;
    if (owner == null || !current() || !_historyReady) {
      return;
    }
    try {
      final conv = _conversation ?? await _findConversation(selection);
      if (!current() || conv == null || conv.uk3 != _conversationKey) return;
      await _serializeHistory(current, () async {
        await _readingNotifier.loadMoreMessages(
          conv,
          isInitial: _conversation == null,
          allowPendingRetry: false,
          webNewestFirst: true,
        );
        if (!current()) return;
        _conversation = conv;
        _readingNotifier.syncMessagesToState();
        _readingFailure(false);
      });
    } on Object {
      if (!current()) return;
      _readingFailure(true);
    }
  }
}
