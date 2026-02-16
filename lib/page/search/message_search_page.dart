import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'message_search_provider.dart';

/// 消息搜索页面
class MessageSearchPage extends ConsumerStatefulWidget {
  /// 搜索范围：当前会话的唯一标识（可选）
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
  Map<String, HighlightedWord> _highlightWords = {};

  @override
  void initState() {
    super.initState();
    // 设置搜索范围
    if (widget.conversationUk3 != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(messageSearchProvider.notifier).setSearchScope(
              widget.conversationUk3,
              widget.conversationTitle,
            );
      });
    }

    // 滚动监听，实现加载更多
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(messageSearchProvider.notifier).loadMore();
    }
  }

  /// 防抖搜索
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      ref.read(messageSearchProvider.notifier).resetSearch();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(messageSearchProvider.notifier).performSearch(query: query);
    });
  }

  /// 更新高亮词
  void _updateHighlightWords(String query) {
    if (query.trim().isEmpty) {
      _highlightWords = {};
    } else {
      _highlightWords = {
        query.trim(): HighlightedWord(
          onTap: () {},
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _updateHighlightWords(state.currentQuery);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            _buildSearchBar(context, state, t),
            // 过滤器栏
            if (state.currentQuery.isNotEmpty)
              _buildFilterBar(context, state, t),
            // 搜索范围提示
            if (widget.conversationTitle != null)
              _buildScopeHint(context, state, t),
            // 内容区域
            Expanded(child: _buildContent(context, state, t, isDark)),
          ],
        ),
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          // 返回按钮
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // 搜索输入框
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.borderRadiusMedium,
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: t.searchHint,
                  hintStyle: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  prefixIcon: state.isSearching
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(messageSearchProvider.notifier)
                                .resetSearch();
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (value) {
                  ref
                      .read(messageSearchProvider.notifier)
                      .performSearch(query: value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 取消按钮
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              t.buttonCancel,
              style: TextStyle(
                fontSize: FontSizeType.normal.size,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建过滤器栏
  Widget _buildFilterBar(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            // 消息类型过滤
            _buildFilterChip(
              context: context,
              label: t.all,
              isSelected: state.selectedType == 'all',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTypeFilter('all'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context: context,
              label: t.privateChat,
              isSelected: state.selectedType == 'C2C',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTypeFilter('C2C'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context: context,
              label: t.groupChat,
              isSelected: state.selectedType == 'C2G',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTypeFilter('C2G'),
            ),
            const SizedBox(width: 16),
            // 时间范围过滤
            _buildFilterChip(
              context: context,
              label: t.allTime,
              isSelected: state.selectedTimeRange == 'all',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTimeRangeFilter('all'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context: context,
              label: t.today,
              isSelected: state.selectedTimeRange == 'today',
              onTap: () => ref
                  .read(messageSearchProvider.notifier)
                  .setTimeRangeFilter('today'),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context: context,
              label: t.thisWeek,
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
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          style: TextStyle(
            fontSize: FontSizeType.small.size,
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 构建搜索范围提示
  Widget _buildScopeHint(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${t.searchScope}: ${widget.conversationTitle}',
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(messageSearchProvider.notifier).clearSearchScope();
              if (_searchController.text.isNotEmpty) {
                ref
                    .read(messageSearchProvider.notifier)
                    .performSearch(query: _searchController.text);
              }
            },
            child: Text(
              t.searchAll,
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建内容区域
  Widget _buildContent(
    BuildContext context,
    MessageSearchState state,
    Translations t,
    bool isDark,
  ) {
    if (state.isLoading && state.searchResults.isEmpty) {
      return _buildLoadingView();
    }

    if (state.currentQuery.isEmpty) {
      return _buildSearchHistory(context, state, t);
    }

    if (state.searchResults.isEmpty && !state.isLoading) {
      return _buildEmptyView(context, state, t);
    }

    return _buildSearchResults(context, state, t, isDark);
  }

  /// 构建加载视图
  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  /// 构建搜索历史
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
              Icons.history,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              t.noSearchHistory,
              style: TextStyle(
                fontSize: FontSizeType.normal.size,
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
        // 标题栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.searchHistory,
                style: TextStyle(
                  fontSize: FontSizeType.large.size,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(messageSearchProvider.notifier).clearHistory();
                },
                child: Text(
                  t.clearAll,
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 历史列表
        Expanded(
          child: ListView.builder(
            itemCount: state.searchHistory.length,
            itemBuilder: (context, index) {
              final query = state.searchHistory[index];
              return ListTile(
                leading: Icon(
                  Icons.history,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                title: Text(
                  query,
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  onPressed: () {
                    ref
                        .read(messageSearchProvider.notifier)
                        .removeFromHistory(query);
                  },
                ),
                onTap: () {
                  _searchController.text = query;
                  ref
                      .read(messageSearchProvider.notifier)
                      .performSearch(query: query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建空结果视图
  Widget _buildEmptyView(
    BuildContext context,
    MessageSearchState state,
    Translations t,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            t.searchNoResults,
            style: TextStyle(
              fontSize: FontSizeType.large.size,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${state.currentQuery}"',
            style: TextStyle(
              fontSize: FontSizeType.normal.size,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索结果列表
  Widget _buildSearchResults(
    BuildContext context,
    MessageSearchState state,
    Translations t,
    bool isDark,
  ) {
    return Column(
      children: [
        // 结果统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text(
                '${state.totalResults} ${t.searchResults}',
                style: TextStyle(
                  fontSize: FontSizeType.small.size,
                  color: AppColors.textSecondary,
                ),
              ),
              if (state.hasActiveFilters()) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ref.read(messageSearchProvider.notifier).resetFilters();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    t.resetFilters,
                    style: TextStyle(
                      fontSize: FontSizeType.small.size,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // 结果列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.searchResults.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == state.searchResults.length) {
                // 加载更多指示器
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: state.isLoading
                        ? const CircularProgressIndicator()
                        : TextButton(
                            onPressed: () {
                              ref
                                  .read(messageSearchProvider.notifier)
                                  .loadMore();
                            },
                            child: Text(t.loadMore),
                          ),
                  ),
                );
              }

              final result = state.searchResults[index];
              return _buildResultItem(context, result, state, isDark);
            },
          ),
        ),
      ],
    );
  }

  /// 构建单个搜索结果项
  Widget _buildResultItem(
    BuildContext context,
    MessageSearchResult result,
    MessageSearchState state,
    bool isDark,
  ) {
    // 获取发送者信息
    ContactModel? sender = state.getCachedContact(result.fromId);
    if (sender == null) {
      // 异步加载联系人
      _loadContact(result.fromId);
      sender = ContactModel(
        peerId: result.fromId,
        nickname: 'Loading...',
        avatar: '',
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppRadius.borderRadiusMedium,
        onTap: () => _onResultTap(result),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：会话信息和时间
              Row(
                children: [
                  // 会话图标
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: result.type == 'C2G'
                          ? AppColors.secondary.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusTiny,
                    ),
                    child: Text(
                      result.type == 'C2G' ? t.groupChat : t.privateChat,
                      style: TextStyle(
                        fontSize: FontSizeType.tiny.size,
                        color: result.type == 'C2G'
                            ? AppColors.secondary
                            : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 发送者名称
                  Expanded(
                    child: Text(
                      sender.nickname,
                      style: TextStyle(
                        fontSize: FontSizeType.small.size,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 时间
                  Text(
                    DateTimeHelper.lastTimeFmt(result.createdAt),
                    style: TextStyle(
                      fontSize: FontSizeType.tiny.size,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 消息内容（高亮显示）
              TextHighlight(
                text: _getMessageContent(result),
                words: _highlightWords,
                textStyle: TextStyle(
                  fontSize: FontSizeType.normal.size,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取消息内容
  String _getMessageContent(MessageSearchResult result) {
    if (result.payload != null && result.payload!['text'] != null) {
      return result.payload!['text'].toString();
    }
    return result.content;
  }

  /// 异步加载联系人
  Future<void> _loadContact(String uid) async {
    try {
      final contact = await ContactRepo().findByUid(uid);
      if (contact != null && mounted) {
        // 使用 notifier 的方法来更新状态
        ref.read(messageSearchProvider.notifier).cacheContact(uid, contact);
        setState(() {});
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 点击搜索结果
  void _onResultTap(MessageSearchResult result) {
    // 跳转到聊天页面，定位到该消息
    final peerId = result.type == 'C2C' ? result.toId : result.fromId;

    Navigator.of(context).push(
      CupertinoPageRoute(
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
  }
}
