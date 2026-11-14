import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'message_search_provider.dart';
import 'message_search_result_card.dart';

class MessageSearchPage extends ConsumerStatefulWidget {
  final String? conversationUk3;
  final String? conversationTitle;
  final String? conversationType;
  final String? peerId;
  final String? peerAvatar;

  const MessageSearchPage({
    super.key,
    this.conversationUk3,
    this.conversationTitle,
    this.conversationType,
    this.peerId,
    this.peerAvatar,
  });

  @override
  ConsumerState<MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends ConsumerState<MessageSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  late final String _ownerUid;
  late final int _ownerSession;
  Map<String, HighlightedWord> _highlightWords = {};

  @override
  void initState() {
    super.initState();
    final user = UserRepoLocal.to;
    _ownerUid = user.currentUid;
    _ownerSession = user.sessionGeneration;
    user.addAuthListener(_onAuthChanged);
    if (widget.conversationUk3 != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ownerActive) return;
        ref
            .read(messageSearchProvider.notifier)
            .setSearchScope(widget.conversationUk3, widget.conversationTitle);
      });
    }
    _scrollController.addListener(_onScroll);
  }

  bool get _ownerActive {
    final user = UserRepoLocal.to;
    return mounted &&
        _ownerUid.isNotEmpty &&
        user.currentUid == _ownerUid &&
        user.isCurrentSession(_ownerSession) &&
        !user.isAuthTransitioning;
  }

  void _onAuthChanged() {
    if (!mounted || _ownerActive) return;
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() => _highlightWords = {});
  }

  @override
  void dispose() {
    UserRepoLocal.to.removeAuthListener(_onAuthChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_ownerActive ||
        ref.read(messageSearchProvider).errorMessage.isNotEmpty) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(messageSearchProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    if (!_ownerActive) return;
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      ref.read(messageSearchProvider.notifier).resetSearch();
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => _submitSearch(query),
    );
  }

  void _submitSearch(String query) {
    if (!mounted || !_ownerActive) return;
    _debounceTimer?.cancel();
    unawaited(
      ref.read(messageSearchProvider.notifier).performSearch(query: query),
    );
  }

  void _updateHighlightWords(String query) {
    if (query.trim().isEmpty) {
      _highlightWords = {};
    } else {
      _highlightWords = {
        query.trim(): HighlightedWord(
          textStyle: TextStyle(
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageSearchProvider);
    final t = context.t;
    _updateHighlightWords(state.currentQuery);
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(context, state, t),
            if (_ownerActive && state.currentQuery.isNotEmpty)
              _buildFilterBar(context, state, t),
            if (_ownerActive && widget.conversationTitle != null)
              _buildScopeHint(context, state, t),
            Expanded(
              child: _ownerActive
                  ? _buildContent(context, state, t)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              CupertinoIcons.chevron_left,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSizes.touchTarget,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.borderRadiusMedium,
              ),
              child: TextField(
                enabled: _ownerActive,
                enableSuggestions: false,
                autocorrect: false,
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: t.common.searchHint,
                  hintStyle: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.regular,
                    vertical: 10,
                  ),
                  prefixIcon: state.isSearching
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: CupertinoActivityIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Icon(
                          CupertinoIcons.search,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            CupertinoIcons.clear,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          tooltip: t.common.clear,
                          onPressed: () {
                            if (!_ownerActive) return;
                            _searchController.clear();
                            // 清除时一并取消防抖，避免旧查询再次触发。
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: _submitSearch,
              ),
            ),
          ),
          AppSpacing.horizontalSmall,
          CupertinoButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              t.common.buttonCancel,
              style: context.textStyle(
                FontSizeType.normal,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              context: context,
              label: t.common.all,
              isSelected: state.selectedType == 'all',
              onTap: () =>
                  ref.read(messageSearchProvider.notifier).setTypeFilter('all'),
            ),
            AppSpacing.horizontalSmall,
            _buildFilterChip(
              context: context,
              label: t.chat.privateChat,
              isSelected: state.selectedType == 'C2C',
              onTap: () =>
                  ref.read(messageSearchProvider.notifier).setTypeFilter('C2C'),
            ),
            AppSpacing.horizontalSmall,
            _buildFilterChip(
              context: context,
              label: t.chat.groupChat,
              isSelected: state.selectedType == 'C2G',
              onTap: () =>
                  ref.read(messageSearchProvider.notifier).setTypeFilter('C2G'),
            ),
            AppSpacing.horizontalRegular,
            _buildFilterChip(
              context: context,
              label: t.common.allTime,
              isSelected: state.selectedTimeRange == 'all',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTimeRangeFilter('all'),
            ),
            AppSpacing.horizontalSmall,
            _buildFilterChip(
              context: context,
              label: t.common.today,
              isSelected: state.selectedTimeRange == 'today',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTimeRangeFilter('today'),
            ),
            AppSpacing.horizontalSmall,
            _buildFilterChip(
              context: context,
              label: t.main.thisWeek,
              isSelected: state.selectedTimeRange == 'week',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTimeRangeFilter('week'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (!_ownerActive) return;
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.borderRadiusLarge,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: context.textStyle(
            FontSizeType.small,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildScopeHint(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            CupertinoIcons.chat_bubble,
            size: 16,
            color: AppColors.textSecondary,
          ),
          AppSpacing.horizontalSmall,
          Expanded(
            child: Text(
              '${t.common.searchScope}: ${widget.conversationTitle}',
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          CupertinoButton(
            onPressed: () {
              if (!_ownerActive) return;
              ref.read(messageSearchProvider.notifier).clearSearchScope();
              if (_searchController.text.isNotEmpty) {
                _submitSearch(_searchController.text);
              }
            },
            child: Text(
              t.common.searchAll,
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    if (state.isLoading && state.searchResults.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (state.currentQuery.isEmpty) {
      return _buildSearchHistory(context, state, t);
    }
    if (state.errorMessage.isNotEmpty &&
        !state.isLoading &&
        (state.searchResults.isEmpty || state.searchDisabled)) {
      return _buildErrorView(context, state, t);
    }
    if (state.searchResults.isEmpty && !state.isLoading) {
      return _buildEmptyView(state, t);
    }
    return _buildSearchResults(context, state, t);
  }

  Widget _buildSearchHistory(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    if (state.searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.clock,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            AppSpacing.verticalRegular,
            Text(
              t.common.noSearchHistory,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.regular,
            AppSpacing.regular,
            AppSpacing.regular,
            AppSpacing.small,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.common.searchHistory,
                style: context.textStyle(
                  FontSizeType.large,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              CupertinoButton(
                onPressed: () {
                  if (!_ownerActive) return;
                  ref.read(messageSearchProvider.notifier).clearHistory();
                },
                child: Text(
                  t.common.clearAll,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.searchHistory.length,
            itemBuilder: (context, index) {
              final query = state.searchHistory[index];
              return ImBoyListTile(
                leading: Icon(
                  CupertinoIcons.clock,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                title: Text(
                  query,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  tooltip: t.common.buttonDelete,
                  onPressed: () {
                    if (!_ownerActive) return;
                    ref
                        .read(messageSearchProvider.notifier)
                        .removeFromHistory(query);
                  },
                ),
                onTap: () {
                  if (!_ownerActive) return;
                  _searchController.text = query;
                  _submitSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView(MessageSearchState state, Translations t) {
    return NoDataView(
      text: t.common.searchNoResults,
      description: '"${state.currentQuery}"',
      icon: CupertinoIcons.slash_circle,
      iconSize: 64,
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    // E2EE 策略禁用属于预期状态，不能提供永远无法成功的重试。
    if (state.searchDisabled) {
      return NoDataView(
        text: t.common.searchDisabledTitle,
        description: state.errorMessage,
        icon: CupertinoIcons.lock,
        iconSize: 64,
      );
    }
    return NoDataView(
      text: t.common.searchError,
      description: state.errorMessage,
      icon: CupertinoIcons.exclamationmark_circle,
      iconSize: 64,
      onTop: () => _submitSearch(state.currentQuery),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.small,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text(
                '${state.totalResults} ${t.common.searchResults}',
                style: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.textSecondary,
                ),
              ),
              if (state.hasActiveFilters()) ...[
                AppSpacing.horizontalSmall,
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.small,
                  ),
                  onPressed: () {
                    if (!_ownerActive) return;
                    ref.read(messageSearchProvider.notifier).resetFilters();
                  },
                  child: Text(
                    t.common.resetFilters,
                    style: context.textStyle(
                      FontSizeType.small,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            itemCount:
                state.searchResults.length +
                (state.hasMore || state.errorMessage.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.searchResults.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.regular),
                    child: state.isLoading
                        ? const CupertinoActivityIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (state.errorMessage.isNotEmpty)
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    state.errorMessage,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              CupertinoButton(
                                onPressed: () {
                                  if (!_ownerActive) return;
                                  ref
                                      .read(messageSearchProvider.notifier)
                                      .loadMore();
                                },
                                child: Text(
                                  state.errorMessage.isNotEmpty
                                      ? t.common.buttonRetry
                                      : t.common.loadMore,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }
              final result = state.searchResults[index];
              return _buildResultItem(context, result, state);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(
    BuildContext context,
    MessageSearchResult result,
    MessageSearchState state,
  ) {
    ContactModel? sender = state.getCachedContact(result.fromId);
    if (sender == null) {
      _loadContact(result.fromId);
      sender = ContactModel(
        peerId: result.fromId,
        nickname: 'Loading...',
        avatar: '',
      );
    }
    return MessageSearchResultCard(
      result: result,
      sender: sender,
      highlightWords: _highlightWords,
      onTap: () => _onResultTap(result),
    );
  }

  Future<void> _loadContact(String uid) async {
    if (!_ownerActive) return;
    final generation = ref
        .read(messageSearchProvider.notifier)
        .searchGeneration;
    try {
      final contact = await ContactRepo().findByUid(uid);
      if (contact != null &&
          mounted &&
          _ownerActive &&
          generation ==
              ref.read(messageSearchProvider.notifier).searchGeneration) {
        ref.read(messageSearchProvider.notifier).cacheContact(uid, contact);
        setState(() {});
      }
    } catch (_) {
      // 联系人加载失败时保留占位，不阻断搜索结果。
    }
  }

  Future<void> _onResultTap(MessageSearchResult result) async {
    if (!_ownerActive) return;
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final generation = session.sessionGeneration;
    final notifier = ref.read(messageSearchProvider.notifier);
    final searchGeneration = notifier.searchGeneration;
    if (!result.isVisibleAt(
      DateTimeHelper.millisecond(),
      UserRepoLocal.to.currentUid,
    )) {
      ref.read(messageSearchProvider.notifier).removeExpiredResults();
      return;
    }
    final current = await ref
        .read(ftsApiProvider)
        .refreshResultVisibility(result);
    if (!mounted ||
        session.currentUid != uid ||
        !session.isCurrentSession(generation) ||
        notifier.searchGeneration != searchGeneration ||
        session.isAuthTransitioning) {
      return;
    }
    if (!notifier.applyVisibilityResult(result, current)) return;
    // C2G 指向群；C2C 指向另一端，避免收到的消息打开与自己的聊天。
    final String peerId;
    if (result.type == 'C2G') {
      peerId = result.toId;
    } else {
      final isAuthor = result.fromId == UserRepoLocal.to.currentUid;
      peerId = isAuthor ? result.toId : result.fromId;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute<dynamic>(
        builder: (context) => ChatPage(
          peerId: peerId,
          type: result.type,
          peerTitle: '',
          peerAvatar: '',
          peerSign: '',
          msgId: result.id,
        ),
      ),
    );
    if (mounted && _ownerActive) {
      await ref.read(messageSearchProvider.notifier).refreshVisibleResults();
    }
  }
}
