part of 'web_shell_bootstrap.dart';

/// 以会话与本地资源属主约束历史、消息和已读回调。
class WebChatPanel extends ConsumerStatefulWidget {
  final ChatSelection selection;
  final String currentUserId;
  final String closeTooltip;
  final VoidCallback onClose;
  final Widget inputArea;
  final AuthSessionReader? sessionReader;
  final Future<ConversationModel?> Function(String, String)? conversationLoader;
  final Future<ContactModel?> Function(String)? contactLoader;
  final Future<GroupModel?> Function(String)? groupLoader;
  final Future<void> Function(BuildContext, String)? imagePreview;
  final Future<Map<String, dynamic>?> Function(String, int, int)?
  groupMemberPageLoader;

  const WebChatPanel({
    super.key,
    required this.selection,
    required this.currentUserId,
    required this.closeTooltip,
    required this.onClose,
    required this.inputArea,
    this.sessionReader,
    this.conversationLoader,
    this.contactLoader,
    this.groupLoader,
    this.imagePreview,
    this.groupMemberPageLoader,
  });

  @override
  ConsumerState<WebChatPanel> createState() => WebChatPanelState();
}

class WebChatPanelState extends ConsumerState<WebChatPanel> {
  final _messageScrollController = ScrollController();
  late final ProviderContainer _scrollScope;
  late final MessageScrollManager _scrollManager;
  late final ProviderSubscription<MessageScrollState> _scrollChanges;
  final _newMessageIds = <String>{};
  int _readingRevision = 0;
  ContactModel? _resolvedContact;
  GroupModel? _resolvedGroup;
  String _resolvedGroupTitle = '';
  WebGroupMetadataReader? _groupMetadata;
  late final Future<String> Function(String, String) _groupAuthorLoader =
      _groupAuthorName;
  ConversationModel? _conversation;
  ChatNotifier? _notifier;
  late final AuthSessionReader _sessions;
  late final WebReadingAnchorStore _readingStore;
  WebReadingAnchor? _savedReading;
  bool _holdReadingBookmark = false;
  AuthSessionScope? _owner;
  AccountLocalTaskOwner? _resourceOwner;
  ChatEventSubscriptionManager? _events;
  StreamSubscription<ChatOperation>? _operations;
  StreamSubscription<ConversationAuthoritySyncEvent>? _authority;
  String? _claimedConversation;
  var _request = 0;
  var _loading = true;
  var _failed = false;
  var _historyReady = false;
  Future<void> _historyTail = Future<void>.value();

  String get _conversationKey => ConversationUk3Generator.generateSmart(
    type: widget.selection.chatType,
    currentUserId: widget.currentUserId,
    peerId: widget.selection.peerId,
  );

  bool get _active =>
      _notifier?.isDisposed != true &&
      _owner != null &&
      _sessions.isCurrent(_owner!) &&
      _owner!.uid == widget.currentUserId;

  bool _current(int request, ChatSelection selection, AuthSessionScope owner) =>
      mounted &&
      _notifier?.isDisposed != true &&
      request == _request &&
      selection == widget.selection &&
      owner.uid == widget.currentUserId &&
      _sessions.isCurrent(owner);

  @override
  void initState() {
    super.initState();
    _scrollScope = ProviderContainer();
    _scrollChanges = _scrollScope.listen(messageScrollManagerProvider, (
      _,
      next,
    ) {
      if (next.isAtBottom && _newMessageIds.isNotEmpty && mounted) {
        setState(_newMessageIds.clear);
      }
    });
    _scrollManager = _scrollScope.read(messageScrollManagerProvider.notifier);
    _scrollManager.attachScrollController(
      _messageScrollController,
      reversed: true,
    );
    _sessions = widget.sessionReader ?? authSessionReader;
    _readingStore = ref.read(webReadingAnchorStoreProvider);
    _sessions.addListener(_onAuthChanged);
    unawaited(_activate());
  }

  void _resetView() {
    _readingRevision++;
    _savedReading = null;
    _holdReadingBookmark = false;
    _newMessageIds.clear();
    final revision = _readingRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _readingRevision) return;
      _scrollManager.resetReadingState();
      if (_messageScrollController.hasClients) {
        _messageScrollController.jumpTo(
          _messageScrollController.position.minScrollExtent,
        );
      }
    });
    _resolvedContact = null;
    _resolvedGroup = null;
    _resolvedGroupTitle = '';
    _groupMetadata = null;
    _conversation = null;
    _loading = true;
    _failed = false;
    _historyReady = false;
  }

  @override
  void didUpdateWidget(covariant WebChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection ||
        oldWidget.currentUserId != widget.currentUserId) {
      _resetView();
      unawaited(_activate());
    }
  }

  void _stopListening() {
    final authority = _authority;
    _authority = null;
    if (authority != null) unawaited(authority.cancel());
    _events?.dispose();
    _events = null;
    final operations = _operations;
    _operations = null;
    if (operations != null) unawaited(operations.cancel());
    if (_claimedConversation != null &&
        MessageRepo.currentActiveConversationUk3 == _claimedConversation) {
      MessageRepo.setCurrentActiveConversationUk3(null);
    }
    _claimedConversation = null;
  }

  void _onAuthChanged() {
    if (!mounted || _owner == _sessions.current) return;
    _readingStore.clear();
    _request++;
    _stopListening();
    setState(_resetView);
    if (_sessions.current.uid == widget.currentUserId &&
        !_sessions.current.transitioning) {
      unawaited(_activate());
    }
  }

  @override
  void dispose() {
    _request++;
    _sessions.removeListener(_onAuthChanged);
    _stopListening();
    _scrollManager.detachScrollController(_messageScrollController);
    _scrollChanges.close();
    _scrollScope.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  bool get _readingOwned =>
      _active &&
      _resourceOwner != null &&
      AccountLocalTaskOwner.capture(uid: widget.currentUserId) ==
          _resourceOwner;

  void _newMessages(List<Message> added, bool nearBottom) {
    if (!_readingOwned || !_historyReady) return;
    final ownMessage = added.any((m) => m.authorId == widget.currentUserId);
    if (ownMessage || (nearBottom && !_holdReadingBookmark)) {
      _returnToLatest();
    } else {
      final liveIds =
          _notifier?.chatService?.messages.map((m) => m.id).toSet() ??
          <String>{};
      setState(
        () => _newMessageIds.addAll(
          added.where((m) => liveIds.contains(m.id)).map((m) => m.id),
        ),
      );
    }
  }

  ChatNotifier get _readingNotifier => ref.read(chatProvider.notifier);
  bool get _readingHasMore => ref.read(chatProvider).hasMoreMessage;
  void _readingFailure(bool value) => setState(() => _failed = value);

  void _readingResetSaved() => setState(_acceptReadingInput);

  Future<ConversationModel?> _findConversation(ChatSelection selection) =>
      widget.conversationLoader?.call(selection.chatType, selection.peerId) ??
      ConversationRepo().findByPeerId(selection.chatType, selection.peerId);

  Future<void> _prepareConversation(
    ChatNotifier notifier,
    String key,
    bool Function() current,
  ) async {
    if (ref.read(chatProvider).currentConversationId == key) return;
    notifier.setCurrentConversationId(key);
    notifier.updateNextAutoId(0);
    await notifier.chatService?.setMessages([], animated: false);
    if (current()) notifier.syncMessagesToState();
  }

  void _listenToConversation(
    ChatNotifier notifier,
    ChatSelection selection,
    String key,
    bool Function() current,
  ) {
    final service = notifier.chatService;
    _operations = service?.operationsStream.listen((_) {
      if (current() && identical(service, notifier.chatService)) {
        final liveIds = service.messages.map((m) => m.id).toSet();
        _newMessageIds.removeWhere((id) => !liveIds.contains(id));
        notifier.syncMessagesToState();
      }
    });
    _events = ChatEventSubscriptionManager(
      widgetRef: ref,
      peerId: selection.peerId,
      peerTitle: selection.peerId,
      chatType: selection.chatType,
      conversationUk3: key,
      msgIds: <String>{},
      editingMessageIdSetter: (_) {},
      chatInputKey: GlobalKey<ChatInputState>(),
      isBurnMessageChecker: (message) =>
          _conversation != null && ChatPageUtils.isBurnMessage(message),
      conversationGetter: () => _conversation!,
      newGroupNameSetter: (_) {},
      isCurrent: current,
      newestFirst: true,
    )..setupCoreMessageListeners();
    _claimedConversation = key;
    MessageRepo.setCurrentActiveConversationUk3(key);
  }

  Future<void> _resolvePeerTitle(
    ChatSelection selection,
    bool Function() current,
  ) async {
    switch (selection.chatType) {
      case 'C2C':
        final value =
            await (widget.contactLoader?.call(selection.peerId) ??
                ContactRepo().findByUid(selection.peerId));
        if (current()) _resolvedContact = value;
      case 'C2G':
        final value =
            await (widget.groupLoader?.call(selection.peerId) ??
                GroupRepo().findById(selection.peerId));
        if (!current()) return;
        final title = await _ownedGroupTitle(value, selection.peerId, current);
        if (current()) {
          _resolvedGroup = value;
          _resolvedGroupTitle = title;
        }
    }
  }

  Future<void> _serializeHistory(
    bool Function() current,
    Future<void> Function() action,
  ) async {
    final previous = _historyTail;
    final completed = Completer<void>();
    _historyTail = completed.future;
    try {
      await previous;
      if (!current()) return;
      await action();
    } finally {
      completed.complete();
    }
  }

  Future<void> _activate() async {
    final request = ++_request;
    _historyTail = Future<void>.value();
    final selection = widget.selection;
    _stopListening();
    if (!isValidWebChatSelection(selection)) return;
    final owner = _sessions.current;
    final key = _conversationKey;
    final resourceOwner = AccountLocalTaskOwner.capture(uid: owner.uid);
    _owner = owner;
    _resourceOwner = resourceOwner;
    _savedReading = _sessions.isCurrent(owner)
        ? _readingStore.read(owner, resourceOwner, key)
        : null;
    _holdReadingBookmark = _savedReading != null;
    bool valid() =>
        _current(request, selection, owner) &&
        AccountLocalTaskOwner.capture(uid: owner.uid) == resourceOwner;
    await WidgetsBinding.instance.endOfFrame;
    if (!valid()) return;
    final notifier = ref.read(chatProvider.notifier);
    _notifier = notifier;
    try {
      if (!notifier.ownsCurrentSession) throw StateError('chat owner expired');
      notifier.initChatService(selection.chatType);
      await _prepareConversation(notifier, key, valid);
      bool current() =>
          valid() && ref.read(chatProvider).currentConversationId == key;
      if (!current()) return;
      _listenToConversation(notifier, selection, key, current);
      var lookupDone = false;
      var pendingSync = false;
      var refreshing = false;
      var refreshFailed = false;
      Future<void> refreshMissing() async {
        if (refreshing || !lookupDone || !current()) return;
        refreshing = true;
        try {
          while (pendingSync && _conversation == null && current()) {
            pendingSync = false;
            final next = await _findConversation(selection);
            if (!current()) return;
            if (next == null || next.uk3 != key) continue;
            await _serializeHistory(current, () async {
              if (_conversation != null) return;
              await notifier.loadMoreMessages(
                next,
                isInitial: true,
                webNewestFirst: true,
                allowPendingRetry: false,
              );
              if (!current()) return;
              _conversation = next;
              refreshFailed = false;
              notifier.syncMessagesToState();
              setState(() => _failed = false);
            });
          }
        } on Object {
          refreshFailed = true;
          if (current()) setState(() => _failed = true);
        } finally {
          refreshing = false;
          if (pendingSync && _conversation == null && current()) {
            unawaited(refreshMissing());
          }
        }
      }

      _authority = AppEventBus.on<ConversationAuthoritySyncEvent>().listen((
        event,
      ) {
        if (!event.success || !current() || _conversation != null) return;
        pendingSync = true;
        unawaited(refreshMissing());
      });
      ConversationModel? conv;
      try {
        conv = await _findConversation(selection);
      } on Object {
        refreshFailed = true;
      }
      if (!current()) return;
      if (conv != null && conv.uk3 == key) {
        try {
          await notifier.loadMoreMessages(
            conv,
            isInitial: true,
            webNewestFirst: true,
            allowPendingRetry: false,
          );
          if (!current()) return;
          _conversation = conv;
          notifier.syncMessagesToState();
        } on Object {
          refreshFailed = true;
        }
      }
      lookupDone = true;
      await refreshMissing();
      if (!current()) return;
      final saved = _savedReading;
      if (saved != null && _conversation != null) {
        await _serializeHistory(
          current,
          () => _loadSavedReading(notifier, _conversation!, saved, current),
        );
      }
      if (!current()) return;
      setState(() {
        _loading = false;
        _failed = refreshFailed;
        _historyReady = true;
      });
      try {
        await _resolvePeerTitle(selection, current);
        if (current()) setState(() {});
      } on Object {
        // A failed optional title lookup must not hide loaded messages.
      }
    } on Object {
      if (!valid()) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _retry() {
    if (!_active) return;
    setState(_resetView);
    unawaited(_activate());
  }

  @override
  Widget build(BuildContext context) {
    if (!isValidWebChatSelection(widget.selection)) {
      return WebWelcomePanel(
        key: const ValueKey('web-chat-invalid-selection'),
        title: Translations.of(context).chat.titleMessage,
      );
    }
    final state = ref.watch(chatProvider);
    final readPolicy = _webReadPolicy(
      widget.currentUserId,
      ref.watch(currentUserProvider),
    );
    if (!_active) return const SizedBox.shrink();
    final messages =
        _historyReady && state.currentConversationId == _conversationKey
        ? state.messages
        : const <Message>[];
    final t = Translations.of(context);
    // DEF-LAY02-A（P3）：数字型不存在的 peer 深链（如 123 / 999999999999999999）
    // 此前照常渲染 composer 可见面板且 header=裸 id。本地既无会话又无
    // 联系人/群档案时视为「对端未解析」：收起 composer（不给发送面）、
    // header 用中性占位而非裸 id。后续权威同步若发现真实会话/档案，
    // 本派生值随状态翻回，正常 peer 不受影响。
    final peerMissing =
        _resolvedContact == null &&
        _resolvedGroup == null &&
        _conversation == null;
    final title = peerMissing
        ? t.main.unnamed
        : pickChatTitle(
            chatType: widget.selection.chatType,
            peerId: widget.selection.peerId,
            contactTitle: _resolvedContact?.title,
            groupTitle: _resolvedGroupTitle.isEmpty
                ? t.main.unnamed
                : _resolvedGroupTitle,
          );

    final fontSizeOption = ref.watch(themeProvider).fontSizeOption;
    final pendingCount = messages
        .where((m) => _newMessageIds.contains(m.id))
        .length;
    final readingRevision = _readingRevision;
    final conversationKey = _conversationKey;
    bool readingCurrent() =>
        mounted &&
        _readingOwned &&
        _historyReady &&
        readingRevision == _readingRevision &&
        conversationKey == _conversationKey &&
        ref.read(chatProvider).currentConversationId == conversationKey;
    return ChatPanel(
      scrollController: _messageScrollController,
      preserveReadingPosition: true,
      initialReadingAnchor: _savedReading,
      onReadingAnchor: (anchor) {
        if (readingCurrent() && !_holdReadingBookmark) {
          _readingStore.write(
            _owner!,
            _resourceOwner!,
            conversationKey,
            anchor,
          );
        }
      },
      onReadingUserInput: _acceptReadingInput,
      onReadingRestoreComplete: () {
        if (readingCurrent()) _holdReadingBookmark = false;
      },
      readingSessionKey: (
        widget.currentUserId,
        widget.selection,
        _owner,
        readingRevision,
      ),
      isCurrent: readingCurrent,
      onNewMessages: (added, nearBottom) {
        if (readingCurrent()) _newMessages(added, nearBottom);
      },
      messageOverlay: pendingCount == 0
          ? null
          : Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.regular),
                child: TextButton.icon(
                  key: const ValueKey('web-chat-new-messages'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    minimumSize: const Size(
                      AppSizes.touchTarget,
                      AppSizes.touchTarget,
                    ),
                  ),
                  onPressed: readingCurrent() ? _returnToLatest : null,
                  icon: const Icon(CupertinoIcons.chevron_down),
                  label: Text(
                    '${t.customerService.newMessagesJump} ($pendingCount)',
                  ),
                ),
              ),
            ),
      peerId: widget.selection.peerId,
      chatType: widget.selection.chatType,
      title: title,
      headerLeading: widget.selection.chatType == 'C2G'
          ? SmartGroupAvatar(
              groupId: widget.selection.peerId,
              avatar: _resolvedGroup?.avatar,
              size: AppSizes.avatarSizeSmall,
            )
          : null,
      headerAccessory: widget.selection.chatType == 'C2G'
          ? WebGroupInfoButton(
              groupId: widget.selection.peerId,
              sessionReader: _sessions,
            )
          : null,
      closeTooltip: widget.closeTooltip,
      onClose: widget.onClose,
      messages: messages,
      historyPlaceholder: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.common.operationFailedAgainLater),
                  CupertinoButton(
                    onPressed: _retry,
                    child: Text(t.common.buttonRetry),
                  ),
                ],
              ),
            )
          : messages.isEmpty && state.historySyncFailed
          ? ChatHistorySyncFailedView(onRetry: _retry)
          : messages.isEmpty &&
                !state.hasMoreMessage &&
                state.historyUnavailable
          ? ChatHistoryUnavailableView(onRetry: _retry)
          : null,
      currentUserId: widget.currentUserId,
      onEndReached: _loadOlder,
      messageContentBuilder: (context, message, index) => webMessageContent(
        context: context,
        message: message,
        index: index,
        currentUserId: widget.currentUserId,
        theme: ChatThemeConfig.getChatThemeFromOption(
          fontSizeOption,
          isDark: Theme.of(context).brightness == Brightness.dark,
          context: context,
        ),
      ),
      messageItemWrapper: (context, message, child) =>
          _wrapWebMessage(context, message, child, readPolicy),
      messageStatusBuilder: (context, message) {
        final theme = ref.read(themeProvider.notifier);
        return webMessageStatus(
          message,
          themeColor: theme.getThemeColor,
          chatColor: theme.getChatColor,
        );
      },
      onMessageTap: (message) {
        if (!mounted || !_active) return;
        if (message is ImageMessage) {
          _previewImage(message);
          return;
        }
        if (message is! FileMessage) return;
        if (message.metadata?['_e2ee_failed'] == true ||
            message.source.isEmpty) {
          AppLoading.showError(t.common.operationFailedAgainLater);
          return;
        }
        confirmOpenFile(context, message.source, fileName: message.name);
      },
      onMessageLongPress: _handleLongPress,
      onMessageDoubleTap: (message) {
        if (message is ImageMessage) _previewImage(message);
      },
      inputArea: peerMissing
          ? const SizedBox.shrink()
          : (widget.selection.chatType == 'C2G'
                ? WebGroupComposerGate(
                    groupId: widget.selection.peerId,
                    currentUserId: widget.currentUserId,
                    sessionReader: _sessions,
                    child: widget.inputArea,
                  )
                : widget.inputArea),
    );
  }

  void _previewImage(ImageMessage message) {
    if (!mounted ||
        !_active ||
        message.metadata?['_e2ee_failed'] == true ||
        message.source.trim().isEmpty) {
      return;
    }
    final owner = _owner;
    final resourceOwner = _resourceOwner;
    final selection = widget.selection;
    bool current() =>
        mounted &&
        _active &&
        owner == _owner &&
        selection == widget.selection &&
        resourceOwner != null &&
        AccountLocalTaskOwner.capture(uid: widget.currentUserId) ==
            resourceOwner;
    if (!current()) return;
    final preview = widget.imagePreview;
    if (preview != null) {
      unawaited(preview(context, message.source));
    } else {
      unawaited(zoomInPhotoView(context, message.source, isCurrent: current));
    }
  }

  /// Phase 2.1.b-5a/c — 长按消息：弹底部菜单
  ///
  /// 当前菜单项（按可见性条件）：
  /// - 复制（resolveCopyableText 非 null 时）— 真实写入 Clipboard
  /// - 撤回（canShowRecallAction true 时，即自己发的 + 时间窗内）— 已接 _revokeMessage
  /// - 取消
  ///
  /// 后续切片可扩展：转发 / 收藏 / 删除 / 引用回复。
  void _handleLongPress(Message message) {
    final request = _request;
    final selection = widget.selection;
    final owner = _owner;
    if (owner == null || !_current(request, selection, owner)) return;
    final copyable = resolveCopyableText(message);
    final canRecall = canShowRecallAction(
      message: message,
      currentUserId: widget.currentUserId,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );

    // 没有任何可操作项时不弹菜单（避免空白菜单困惑用户）
    if (copyable == null && !canRecall) return;

    final ctx = context;
    final t = Translations.of(ctx);
    showCupertinoModalPopup<void>(
      context: ctx,
      builder: (sheetCtx) {
        return CupertinoModalSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (copyable != null)
                ListTile(
                  key: const ValueKey('web-msg-action-copy'),
                  leading: const Icon(CupertinoIcons.doc_on_doc),
                  title: Text(t.common.buttonCopy),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    await Clipboard.setData(ClipboardData(text: copyable));
                    if (!_current(request, selection, owner)) return;
                    AppLoading.showToast(
                      t.main.copied,
                      duration: const Duration(seconds: 1),
                    );
                  },
                ),
              if (canRecall)
                ListTile(
                  key: const ValueKey('web-msg-action-recall'),
                  leading: const Icon(CupertinoIcons.arrow_counterclockwise),
                  title: Text(t.chat.revoke),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    unawaited(_revokeMessage(message));
                  },
                ),
              ListTile(
                key: const ValueKey('web-msg-action-cancel'),
                leading: const Icon(CupertinoIcons.xmark),
                title: Text(t.common.cancel),
                onTap: () => Navigator.of(sheetCtx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Phase 2.1.b-5d — 撤回消息（接 MessagingFacade.sendRevokeMessage）
  ///
  /// 决策已由 [canShowRecallAction] 在菜单显示前过滤；本方法假设入参可撤回。
  /// 失败时仅 SnackBar 提示，不抛异常给上层（避免 widget tree unhandled future）。
  Future<void> _revokeMessage(Message message) async {
    final request = _request;
    final selection = widget.selection;
    final owner = _owner;
    if (owner == null || !_current(request, selection, owner)) return;
    final ctx = context;
    final t = Translations.of(ctx);
    try {
      final ok = await MessagingFacade.instance.sendRevokeMessage(
        message.id,
        selection.chatType,
      );
      if (!_current(request, selection, owner)) return;
      AppLoading.showToast(
        ok ? t.common.revokeSuccess : t.common.revokeFailed,
        duration: const Duration(seconds: 2),
      );
    } on Object {
      if (!_current(request, selection, owner)) return;
      AppLoading.showToast(
        t.common.revokeFailed,
        duration: const Duration(seconds: 2),
      );
    }
  }
}
