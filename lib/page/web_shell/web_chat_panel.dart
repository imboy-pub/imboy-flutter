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

  /// FL-04 阶段一：个人云端历史四维状态可见性（MH-01 §10.9 优先级矩阵）。
  ///
  /// 个人历史域限 C2C（合同 §0），故仅在非 C2G 会话展示；当前只做
  /// 状态投影（删除进度 > 等待密钥 > 同步失败 > 云端关闭 > 本地空态），
  /// 重试/恢复密钥/删除进度动作由 FL-06 二阶段接线（共享文件交接点）。
  /// 文案暂为字面量，i18n 键随二阶段补齐。
  Widget? _personalHistoryBanner(ChatState state) {
    final text = switch (state.personalHistoryVisibility) {
      PersonalHistoryVisibility.deletionProgress => '云端历史清理中，暂不可读',
      PersonalHistoryVisibility.waitingKey => '云端历史需要恢复密钥',
      PersonalHistoryVisibility.syncFailed => '云端历史同步失败，展示本地记录',
      PersonalHistoryVisibility.cloudOff => '云端历史未开启（仅本设备）',
      PersonalHistoryVisibility.localEmpty => '云端历史已开启，本设备暂无投影',
      PersonalHistoryVisibility.none => null,
    };
    if (text == null) return null;
    return Tooltip(
      message: 'personal-history-status',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          key: const ValueKey('web-personal-history-banner'),
          style: ref
              .read(themeProvider.notifier)
              .getTextStyle(
                FontSizeType.small,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
        ),
      ),
    );
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

  /// Phase 2.1.b-5a/c + FL-06 — 长按消息：弹底部菜单
  ///
  /// 菜单项可见性统一由 [resolveWebLongPressMenuPlan] 决策（最低 UX 合同
  /// 决策点，chrome 测试钉矩阵）：复制 / 引用 / 编辑 / 撤回 / 删除 / 多选。
  /// 动作全部接既有模型：
  /// - 引用 → WebComposerIntentController.beginQuote（发送走 mobile
  ///   `_sendQuoteMessage` 同 metadata 合同，快照/撤回隐藏由共享模型管）；
  /// - 编辑 → beginEdit（ChatPageUtils.canEditMessage 过滤，发送走
  ///   MessagingFacade.sendEditMessage 权威模型）；
  /// - 撤回 → _revokeMessage（既有）；
  /// - 删除 → _deleteMessageForMe（mobile deleteMessageForMe 同合同）；
  /// - 多选 → _enterMultiSelect（messageSelectionProvider 既有模型）。
  void _handleLongPress(Message message) {
    final request = _request;
    final selection = widget.selection;
    final owner = _owner;
    if (owner == null || !_current(request, selection, owner)) return;
    final copyable = resolveCopyableText(message);
    final plan = resolveWebLongPressMenuPlan(
      message: message,
      currentUserId: widget.currentUserId,
      nowMs: DateTime.now().millisecondsSinceEpoch,
      multiSelectFlagEnabled: webMultiSelectEnabled(),
      conversationAvailable: _conversationKey.isNotEmpty,
    );

    // 没有任何可操作项时不弹菜单（避免空白菜单困惑用户）
    if (plan.isEmpty) return;

    final ctx = context;
    final t = Translations.of(ctx);
    showCupertinoModalPopup<void>(
      context: ctx,
      builder: (sheetCtx) {
        return CupertinoModalSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (plan.canCopy && copyable != null)
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
              if (plan.canQuote)
                ListTile(
                  key: const ValueKey('web-msg-action-quote'),
                  leading: const Icon(CupertinoIcons.reply),
                  title: Text(t.chat.reply),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    _composerIntents?.beginQuote(message);
                  },
                ),
              if (plan.canEdit)
                ListTile(
                  key: const ValueKey('web-msg-action-edit'),
                  leading: const Icon(CupertinoIcons.pencil),
                  title: Text(t.common.edit),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    _composerIntents?.beginEdit(message, widget.currentUserId);
                  },
                ),
              if (plan.canRecall)
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
              if (plan.canDelete)
                ListTile(
                  key: const ValueKey('web-msg-action-delete'),
                  leading: const Icon(CupertinoIcons.delete),
                  title: Text(t.common.buttonDelete),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    unawaited(_deleteMessageForMe(message));
                  },
                ),
              if (plan.canMultiSelect)
                ListTile(
                  key: const ValueKey('web-msg-action-multiselect'),
                  leading: const Icon(CupertinoIcons.checkmark_circle),
                  title: Text(t.chat.multiSelect),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!_current(request, selection, owner)) return;
                    unawaited(_enterMultiSelect(message));
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

  /// FL-06：多选进入 —— 先 await 草稿落盘（mobile flushDraft 契约；落盘
  /// 失败不卸载输入框避免丢草稿），再走既有 messageSelectionProvider.enter。
  Future<void> _enterMultiSelect(Message message) async {
    final controller = _composerIntents;
    if (controller == null || !mounted) return;
    final flusher = controller.draftFlusher;
    if (flusher != null) {
      final flushed = await flusher();
      if (!flushed || !mounted) return;
    }
    webEnterMultiSelect(ref, _conversationKey, message);
  }

  /// FL-06：删除（仅自己）—— 接 mobile MessageActionHandler.deleteMessageForMe
  /// 同合同：C2G 先发 S2C DEL_FOR_ME，随后 removeMessage（DB/会话联动）+
  /// chatService.removeMessageById（UI 移除）。会话行缺失时失败提示，
  /// 不做静默成功（刷新后结果一致）。
  Future<void> _deleteMessageForMe(Message message) async {
    final request = _request;
    final selection = widget.selection;
    final owner = _owner;
    if (owner == null || !_current(request, selection, owner)) return;
    final notifier = ref.read(chatProvider.notifier);
    if (widget.selection.chatType == 'C2G') {
      await notifier.sendMessage(
        webDeleteForMePayload(
          message: message,
          chatType: widget.selection.chatType,
          currentUserId: widget.currentUserId,
        ),
      );
    }
    final conversation = _conversation;
    if (conversation == null) {
      AppLoading.showToast(t.common.operationFailedAgainLater);
      return;
    }
    final removed = await notifier.removeMessage(conversation, message);
    if (!_current(request, selection, owner)) return;
    if (!removed) {
      AppLoading.showToast(t.common.operationFailedAgainLater);
      return;
    }
    await notifier.chatService?.removeMessageById(message.id);
  }

  /// FL-06：编辑意图失权守卫（撤回先到/消息离列表 → 隐藏摘要，无权限旁路）。
  /// 无法判定（服务消息列表为空）时不猜，避免瞬态镜像误伤编辑态。
  void _guardEditingIntent() {
    final controller = _composerIntents;
    if (controller == null || !controller.intent.isEditing) return;
    final live = ref.read(chatProvider.notifier).chatService?.messages;
    if (live == null || live.isEmpty) return;
    if (webEditIntentInvalidated(controller.intent, live)) {
      controller.invalidateEditing();
    }
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
