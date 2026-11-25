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
  // FL-06：编辑/引用意图（接既有 send_mode_rules/编辑权威模型）与
  // 撤回后「重新编辑」事件订阅（共享 manager 的 setText 对 web 无作用）。
  StreamSubscription<dynamic>? _reEdit;
  WebComposerIntentController? _composerIntents;
  String? _claimedConversation;
  var _request = 0;
  var _loading = true;
  var _failed = false;
  var _historyReady = false;
  Future<void> _historyTail = Future<void>.value();
  bool _personalHistoryBusy = false;

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
    final reEdit = _reEdit;
    _reEdit = null;
    if (reEdit != null) unawaited(reEdit.cancel());
    final composerIntents = _composerIntents;
    _composerIntents = null;
    if (composerIntents != null) {
      composerIntents.removeListener(_onComposerIntentsChanged);
      composerIntents.dispose();
    }
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

  /// FL-06：意图跃迁 → 面板刷新（意图条/菜单可达性随状态收敛）。
  void _onComposerIntentsChanged() {
    if (!mounted) return;
    setState(() {});
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
    // FL-06：真实编辑/引用意图控制器（替代此前 no-op 编辑 setter 的占位）。
    final composerIntents = WebComposerIntentController();
    composerIntents.addListener(_onComposerIntentsChanged);
    _composerIntents = composerIntents;
    _reEdit = webBindReEditEvents(controller: composerIntents);
    _events = ChatEventSubscriptionManager(
      widgetRef: ref,
      peerId: selection.peerId,
      peerTitle: selection.peerId,
      chatType: selection.chatType,
      conversationUk3: key,
      msgIds: <String>{},
      editingMessageIdSetter: _handleEditingMessageIdEvent,
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

  /// FL-06：共享订阅管理器的真实编辑 setter（UX 合同：Web 不以 no-op
  /// 编辑 setter 冒充能力）。id 非空 → 设置编辑目标；null/空 → 取消编辑。
  /// 快照文本由 [webBindReEditEvents] 的事件订阅补充。
  void _handleEditingMessageIdEvent(String? messageId) {
    final controller = _composerIntents;
    if (controller == null || !mounted) return;
    if (messageId == null || messageId.isEmpty) {
      controller.cancelIntent();
      return;
    }
    controller.beginReEdit(messageId);
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

  Future<void> _restorePersonalHistory() async {
    final session = _owner;
    final resource = _resourceOwner;
    final notifier = _notifier;
    if (_personalHistoryBusy ||
        session == null ||
        resource == null ||
        notifier == null ||
        !_readingOwned ||
        widget.selection.chatType != 'C2C') {
      return;
    }
    final request = _request;
    final selection = widget.selection;
    bool current() => _readingOwned && _current(request, selection, session);
    setState(() => _personalHistoryBusy = true);
    var continueRequested = false;
    try {
      final outcome = await syncWebPersonalHistory(
        session: session,
        owner: resource,
        viewIsCurrent: current,
        peerId: selection.peerId,
      );
      if (!current()) return;
      notifier.updatePersonalHistoryState(outcome);
      if (outcome.recoveredText.isNotEmpty || outcome.canContinueSnapshot) {
        continueRequested = await _showRestoredHistory(outcome, current);
        return;
      }
      final enable =
          outcome.kind == PersonalHistorySyncOutcomeKind.cloudOff ||
          outcome.kind == PersonalHistorySyncOutcomeKind.setupRequired;
      if (!enable &&
          outcome.kind != PersonalHistorySyncOutcomeKind.waitingKey) {
        return;
      }
      final passphrase = await _requestHistoryPassphrase(enable: enable);
      if (passphrase == null || passphrase.isEmpty || !current()) return;
      final restored = await syncWebPersonalHistory(
        session: session,
        owner: resource,
        viewIsCurrent: current,
        peerId: selection.peerId,
        passphrase: passphrase,
        enable: enable,
      );
      if (!current()) return;
      notifier.updatePersonalHistoryState(restored);
      if (restored.recoveredText.isNotEmpty || restored.canContinueSnapshot) {
        continueRequested = await _showRestoredHistory(restored, current);
      }
    } finally {
      if (mounted) setState(() => _personalHistoryBusy = false);
      if (continueRequested && current()) unawaited(_restorePersonalHistory());
    }
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
    // FL-06：多选激活态（flag 关闭时恒 false，零 UI 变化）+ 编辑失权守卫。
    final multiSelectActive =
        webMultiSelectEnabled() && webMultiSelectActiveOf(ref, conversationKey);
    _guardEditingIntent();
    bool readingCurrent() =>
        mounted &&
        _readingOwned &&
        _historyReady &&
        readingRevision == _readingRevision &&
        conversationKey == _conversationKey &&
        ref.read(chatProvider).currentConversationId == conversationKey;
    final panel = ChatPanel(
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
          : _personalHistoryBanner(state),
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
      messageItemWrapper: (context, message, child) {
        final wrapped = _wrapWebMessage(context, message, child, readPolicy);
        // FL-06：多选激活 → 勾选框行包装（mobile chat_message_item 同语义）。
        if (!multiSelectActive) return wrapped;
        return webMultiSelectRowWrapper(
          context,
          ref: ref,
          conversationUk3: conversationKey,
          message: message,
          child: wrapped,
        );
      },
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
        // FL-06：多选模式点消息 = 切换勾选（mobile onMessageTap 同语义）。
        if (multiSelectActive) {
          webToggleMessageSelection(ref, conversationKey, message);
          return;
        }
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
          : multiSelectActive
          // FL-06：多选模式底部动作栏替换 composer（mobile 同语义）；
          // 进入前草稿已 await 落盘，退出后 composer 从草稿恢复。
          ? WebMultiSelectActionBar(
              conversationUk3: conversationKey,
              sourceChatType: widget.selection.chatType,
              conversationTitle: title,
              peerId: widget.selection.peerId,
            )
          : (widget.selection.chatType == 'C2G'
                ? WebGroupComposerGate(
                    groupId: widget.selection.peerId,
                    currentUserId: widget.currentUserId,
                    sessionReader: _sessions,
                    child: widget.inputArea,
                  )
                : widget.inputArea),
    );
    // FL-06：编辑/引用意图注入面（inputArea 在 ChatPanel 子树内，
    // WebChatInput 经 scope 读取意图并注册草稿落盘钩子）。
    final intents = _composerIntents;
    if (intents == null) return panel;
    return WebComposerIntentScope(controller: intents, child: panel);
  }
}
