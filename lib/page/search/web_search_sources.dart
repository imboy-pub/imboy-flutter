part of 'web_search_page.dart';

mixin _WebSearchSources on ConsumerState<WebSearchPage> {
  WebSearchState get _state;
  set _state(WebSearchState value);
  int get _searchGeneration;
  bool get _isAuthTransitioning;
  Future<void> _performSearch(String query);
  Future<void> _onItemTap(SearchItem item);
  void _removeExpiredResults();

  final _sourceFailures = <SearchItemType, WebMessageSearchFailure>{};
  final _retryingSources = <SearchItemType>{};
  bool _authSearchBlocked = false;

  Map<SearchItemType, Future<List<SearchItem>> Function()> _searchesFor(
    String query,
  ) => {
    SearchItemType.message: () =>
        widget.messageSearchForTest?.call(query) ?? _searchMessages(query),
    SearchItemType.contact: () =>
        widget.otherSearchForTest?.call(query) ?? _searchContacts(query),
    SearchItemType.group: () => widget.otherSearchForTest == null
        ? _searchGroups(query)
        : Future.value(<SearchItem>[]),
    SearchItemType.conversation: () => widget.otherSearchForTest == null
        ? _searchConversations(query)
        : Future.value(<SearchItem>[]),
  };

  Future<void> _retrySearchSource(SearchItemType source) async {
    if (_isAuthTransitioning || _retryingSources.contains(source)) return;
    if (_authSearchBlocked) return _performSearch(_state.query);
    final query = _state.query;
    final generation = _searchGeneration;
    final user = UserRepoLocal.to;
    final session = user.sessionGeneration;
    final uid = user.currentUid;
    final endpoint = Env().apiBaseUrl;
    setState(() => _retryingSources.add(source));
    final (items, failure) = await runWebMessageSearch(
      _searchesFor(query)[source]!,
    );
    if (!mounted ||
        _isAuthTransitioning ||
        generation != _searchGeneration ||
        !user.isCurrentSession(session) ||
        user.currentUid != uid ||
        Env().apiBaseUrl != endpoint ||
        _state.query != query) {
      return;
    }
    setState(() {
      _retryingSources.remove(source);
      if (failure == null) {
        _sourceFailures.remove(source);
        _state = _state.copyWith(
          results: [
            ..._state.results.where((item) => item.type != source),
            ...items,
          ],
        );
      } else {
        _sourceFailures[source] = failure;
      }
    });
    _removeExpiredResults();
  }

  /// 搜索消息
  Future<List<SearchItem>> _searchMessages(String query) async {
    final results = <SearchItem>[];
    final response = await ref
        .read(ftsApiProvider)
        .searchMessages(keyword: query, page: 1, size: 10, type: 'all');

    if (response == null) {
      throw const FormatException('Invalid message search response');
    }

    if (response.items.isNotEmpty) {
      for (final item in response.items) {
        final uid = UserRepoLocal.to.currentUid;
        if (!item.isVisibleAt(DateTimeHelper.millisecond(), uid)) continue;
        // 判断消息的发送者/接收者
        final isAuthor = item.fromId == UserRepoLocal.to.currentUid;
        final peerId = isAuthor ? item.toId : item.fromId;

        results.add(
          SearchItem(
            type: SearchItemType.message,
            id: item.id,
            title: peerId, // 后续需要获取联系人名称
            subtitle: item.content,
            avatar: '',
            highlightText: query,
            message: item,
            metadata: {
              'timestamp': item.createdAt * 1000,
              'conversationId': item.type == 'C2G' ? item.toId : peerId,
              'type': item.type,
              'fromId': item.fromId,
              'toId': item.toId,
            },
          ),
        );
      }
    }
    return results;
  }

  /// 搜索联系人
  Future<List<SearchItem>> _searchContacts(String query) async {
    final results = <SearchItem>[];
    final contactRepo = ContactRepo();
    final contacts = await contactRepo.search(kwd: query, limit: 20);

    for (final contact in contacts) {
      results.add(
        SearchItem(
          type: SearchItemType.contact,
          id: contact.peerId.toString(),
          title: (contact.remark.isNotEmpty)
              ? contact.remark
              : contact.nickname,
          subtitle: contact.sign,
          avatar: contact.avatar,
          highlightText: query,
        ),
      );
    }
    return results;
  }

  /// 搜索群组
  Future<List<SearchItem>> _searchGroups(String query) async {
    final results = <SearchItem>[];
    final groupRepo = GroupRepo();
    final groups = await groupRepo.search(kwd: query, limit: 20);

    for (final group in groups) {
      results.add(
        SearchItem(
          type: SearchItemType.group,
          id: group.groupId.toString(),
          title: group.title,
          subtitle: group.introduction.isNotEmpty
              ? group.introduction
              : '${group.memberCount} ${t.group.groupMembers}',
          avatar: group.avatar,
          highlightText: query,
        ),
      );
    }
    return results;
  }

  /// 搜索会话
  Future<List<SearchItem>> _searchConversations(String query) async {
    final results = <SearchItem>[];
    final convRepo = ConversationRepo();
    final conversations = await convRepo.search(
      "${ConversationRepo.title} LIKE ?",
      ['%$query%'],
    );

    for (final conv in conversations) {
      results.add(
        SearchItem(
          type: SearchItemType.conversation,
          id: conv.peerId.toString(),
          title: conv.title,
          subtitle: conv.subtitle,
          avatar: conv.avatar,
          highlightText: query,
          metadata: {'type': conv.type, 'lastTime': conv.lastTime},
        ),
      );
    }
    return results;
  }

  Widget _buildSearchResults(bool isDark) {
    if (_state.error != null) {
      return NoDataView(
        text: _state.error!,
        icon: CupertinoIcons.exclamationmark_circle,
        iconSize: 64,
        iconColor: isDark ? AppColors.iosRedDark : AppColors.iosRed,
        onTop: () => _performSearch(_state.query),
      );
    }
    if (_state.results.isEmpty &&
        _state.query.isNotEmpty &&
        _sourceFailures.isEmpty) {
      return NoDataView(
        text: '${t.common.search}: "${_state.query}"',
        icon: CupertinoIcons.slash_circle,
        iconSize: 64,
        iconColor: isDark
            ? AppColors.chatWebDividerDark
            : AppColors.chatWebDividerLight,
      );
    }
    return ListView(
      controller: _searchScrollController,
      children: [
        for (final source in SearchItemType.values)
          ..._buildSourceGroup(source, isDark),
      ],
    );
  }

  ScrollController get _searchScrollController;

  String _sourceTitle(SearchItemType source) => switch (source) {
    SearchItemType.conversation => t.common.searchConversations,
    SearchItemType.message => t.channel.messages,
    SearchItemType.contact => t.common.titleContact,
    SearchItemType.group => t.chat.groupChat,
  };

  List<Widget> _buildSourceGroup(SearchItemType source, bool isDark) {
    final items = _state.results.where((item) => item.type == source);
    final failure = _sourceFailures[source];
    if (items.isEmpty && failure == null) return [];
    return [
      WebSearchSectionHeader(title: _sourceTitle(source), isDark: isDark),
      if (failure != null) ...[
        Padding(
          padding: AppSpacing.allMedium,
          child: Text(
            failure == WebMessageSearchFailure.disabled
                ? t.common.searchDisabledByEncryption
                : source == SearchItemType.message
                ? t.common.searchFailedRetry
                : t.common.searchError,
            key: ValueKey('web_${source.name}_search_failure'),
          ),
        ),
        if (failure == WebMessageSearchFailure.unavailable)
          _buildSourceRetry(source),
      ],
      ...items.map(
        (item) => WebSearchResultTile(
          item: item,
          isDark: isDark,
          onTap: () => _onItemTap(item),
        ),
      ),
    ];
  }

  Widget _buildSourceRetry(SearchItemType source) => CupertinoButton(
    key: ValueKey('web_${source.name}_search_retry'),
    minimumSize: const Size.square(AppSizes.touchTarget),
    onPressed: _retryingSources.contains(source)
        ? null
        : () => _retrySearchSource(source),
    child: _retryingSources.contains(source)
        ? Semantics(
            liveRegion: true,
            label: '${_sourceTitle(source)}，${t.common.retrying}',
            child: const CupertinoActivityIndicator(),
          )
        : Text(
            t.common.retry,
            semanticsLabel: '${_sourceTitle(source)}，${t.common.retry}',
          ),
  );
}
