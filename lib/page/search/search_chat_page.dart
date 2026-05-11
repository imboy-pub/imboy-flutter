import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'search_provider.dart';

class SearchChatPage extends ConsumerStatefulWidget {
  final String conversationUk3;
  final String type; // [C2C | C2G | C2S]
  final String peerId; // 用户ID | GroupId | SID
  final String peerAvatar;
  final String peerTitle;
  final String peerSign;

  const SearchChatPage({
    super.key,
    required this.conversationUk3,
    required this.type,
    required this.peerId,
    required this.peerTitle,
    required this.peerAvatar,
    required this.peerSign,
  });

  @override
  ConsumerState<SearchChatPage> createState() => _SearchChatPageState();
}

class _SearchChatPageState extends ConsumerState<SearchChatPage> {
  final TextEditingController _searchC = TextEditingController();
  Timer? _debounceTimer;
  List<Message> items = [];
  Map<String, HighlightedWord> words = {};

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 防抖搜索
  void debouncedSearch(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      ref.read(searchProvider.notifier).resetSearch();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      performSearch(query: query);
    });
  }

  /// 执行搜索
  Future<void> performSearch({required String query}) async {
    if (query.trim().isEmpty) return;

    final notifier = ref.read(searchProvider.notifier);
    final effectiveQuery = query.trim();

    notifier.setCurrentQuery(effectiveQuery);
    notifier.setLoading(true);
    notifier.startSearching();
    notifier.setError('');

    try {
      final response = await FtsApi.to.searchConversationMessages(
        keyword: effectiveQuery,
        conversationUk3: widget.conversationUk3,
        page: 1,
        size: 50,
      );

      if (response == null) {
        notifier.setError(t.searchError);
        return;
      }

      // 将 MessageSearchResult 转换为 flutter_chat_core Message
      final messages = response.items.map((item) {
        final text = item.payload?['text'] as String? ?? item.content;
        return CustomMessage(
          authorId: item.fromId,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            item.createdAt,
            isUtc: true,
          ),
          id: item.id,
          metadata: {
            'text': text,
            'msg_type': item.msgType ?? MessageType.text,
            ...?item.payload,
          },
        );
      }).toList();

      notifier.updateSearchResults(messages);
      notifier.addToHistory(effectiveQuery);

      // 高亮关键词
      if (!mounted) return;
      setState(() {
        words = {
          effectiveQuery: HighlightedWord(
            textStyle: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        };
      });
    } on Exception catch (e) {
      notifier.setError(t.searchError);
      if (kDebugMode) debugPrint('Search error: ${e.runtimeType}');
    } finally {
      notifier.setLoading(false);
      notifier.stopSearching();
    }
  }

  /// 构建搜索结果项 - 优化版本，使用缓存
  Widget wordView(Message item, ContactModel? author) {
    final msg = item;
    String subtitle = msg.metadata?['text'] ?? '';

    return InkWell(
      borderRadius: AppRadius.borderRadiusMedium,
      child: Container(
        width: MediaQuery.of(context).size.width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.borderRadiusMedium,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: Avatar(imgUri: author?.avatar ?? ''),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  author?.nickname ?? 'Loading...',
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                DateTimeHelper.lastTimeFmt(
                  msg.createdAt!.millisecondsSinceEpoch +
                      DateTime.now().timeZoneOffset.inMilliseconds,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: FontSizeType.small.size,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          subtitle: TextHighlight(
            text: subtitle,
            words: words,
            matchCase: false,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),
      onTap: () async {
        if (widget.type == 'C2C' ||
            widget.type == 'C2G' ||
            widget.type == 'S2C') {
          try {
            await Navigator.push(
              context,
              CupertinoPageRoute<dynamic>(
                builder: (context) => ChatPage(
                  peerId: widget.peerId,
                  peerTitle: widget.peerTitle,
                  peerAvatar: widget.peerAvatar,
                  peerSign: widget.peerSign,
                  type: widget.type,
                  msgId: msg.id,
                ),
              ),
            );
          } on Exception catch (e) {
            if (kDebugMode) debugPrint('跳转到聊天页面失败: ${e.runtimeType}');
          }
        }
      },
    );
  }

  // 异步加载并缓存联系人信息 - 优化版本
  Future<void> _loadAndCacheContact(String uid) async {
    try {
      final contact = await ContactRepo().findByUid(uid);
      if (contact != null && mounted) {
        ref.read(searchProvider.notifier).cacheContact(uid, contact);
        setState(() {});
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('加载联系人信息失败: ${e.runtimeType}');

      // 如果是加密相关错误，创建基础联系人对象
      if (e.toString().contains('Invalid padding') ||
          e.toString().contains('decrypt')) {
        final fallbackContact = ContactModel(
          peerId: parseModelInt(uid),
          nickname: 'User_${uid.substring(0, 8)}',
          avatar: '',
        );
        ref.read(searchProvider.notifier).cacheContact(uid, fallbackContact);

        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            _buildSearchBar(context),
            // 快速过滤器栏
            if (state.currentQuery.isNotEmpty || state.hasActiveFilters())
              _buildQuickFilterBar(context),
            // 搜索内容
            Expanded(child: _buildSearchContent(state)),
          ],
        ),
      ),
    );
  }

  // 搜索栏
  Widget _buildSearchBar(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.borderRadiusMedium,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchC,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: t.searchMessagesHint,
                      hintStyle: TextStyle(
                        fontSize: FontSizeType.normal.size,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.borderRadiusMedium,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.borderRadiusMedium,
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: state.isSearching
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
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
                      suffixIcon: Wrap(
                        spacing: 4,
                        children: [
                          // 过滤器按钮
                          IconButton(
                            icon: Icon(
                              Icons.tune,
                              color: state.hasActiveFilters()
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            onPressed: () => _showFilterDialog(context),
                          ),
                          // 清除按钮
                          if (state.currentQuery.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () {
                                _searchC.clear();
                                ref
                                    .read(searchProvider.notifier)
                                    .cancelSearch();
                                ref.read(searchProvider.notifier).resetSearch();
                              },
                            ),
                        ],
                      ),
                    ),
                    onChanged: (value) {
                      debouncedSearch(value);
                      // 更新搜索建议
                      if (value.length >= 2) {
                        ref
                            .read(searchProvider.notifier)
                            .updateSearchSuggestions(value);
                      }
                    },
                    onSubmitted: (value) {
                      performSearch(query: value);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 取消按钮
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  t.buttonCancel,
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // 搜索进度条
          if (state.isSearching)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                value: state.searchProgress / 100,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  // 快速过滤器栏
  Widget _buildQuickFilterBar(BuildContext context) {
    final state = ref.watch(searchProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.quickFilters,
                style: TextStyle(
                  fontSize: FontSizeType.small.size,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (state.hasActiveFilters())
                TextButton(
                  onPressed: () {
                    ref.read(searchProvider.notifier).resetFilters();
                    performSearch(query: state.currentQuery);
                  },
                  child: Text(
                    t.resetFilters,
                    style: TextStyle(
                      fontSize: FontSizeType.small.size,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickFilterChip(
                  context,
                  t.allTypes,
                  state.selectedMessageType == 'all',
                  () {
                    ref.read(searchProvider.notifier).resetFilters();
                    performSearch(query: state.currentQuery);
                  },
                  Icons.apps,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.textMessage,
                  state.selectedMessageType == MessageType.text,
                  () {
                    ref.read(searchProvider.notifier).resetFilters();
                    performSearch(query: state.currentQuery);
                  },
                  Icons.text_fields,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.imageMessage,
                  state.selectedMessageType == MessageType.image,
                  () {
                    ref.read(searchProvider.notifier).resetFilters();
                    performSearch(query: state.currentQuery);
                  },
                  Icons.image,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.today,
                  state.selectedTimeRange == 'today',
                  () {
                    ref.read(searchProvider.notifier).resetFilters();
                    performSearch(query: state.currentQuery);
                  },
                  Icons.today,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.thisWeek,
                  state.selectedTimeRange == 'week',
                  () {
                    ref.read(searchProvider.notifier).resetFilters();
                    performSearch(query: state.currentQuery);
                  },
                  Icons.date_range,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建快速过滤器芯片
  Widget _buildQuickFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: FontSizeType.small.size,
                color: isSelected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建搜索内容
  Widget _buildSearchContent(SearchDataState state) {
    if (state.isLoading && state.searchResults.isEmpty) {
      return _buildLoadingView();
    } else if (state.currentQuery.isEmpty) {
      return _buildSearchHistory();
    } else if (state.searchResults.isEmpty && !state.isLoading) {
      return _buildEmptyResults();
    } else {
      return _buildSearchResults();
    }
  }

  // 构建搜索历史
  Widget _buildSearchHistory() {
    final state = ref.watch(searchProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 搜索历史标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.searchHistory,
                  style: TextStyle(
                    fontSize: FontSizeType.large.size,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.searchHistory.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(searchProvider.notifier).clearHistory();
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
          // 搜索建议
          if (state.searchSuggestions.isNotEmpty) _buildSearchSuggestions(),
          // 搜索历史列表
          if (state.searchHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
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
              ),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: state.searchHistory.map((query) {
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
                        color: colorScheme.onSurface,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                      onPressed: () {
                        _searchC.text = query;
                        performSearch(query: query);
                      },
                    ),
                    onTap: () {
                      _searchC.text = query;
                      performSearch(query: query);
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // 构建搜索建议
  Widget _buildSearchSuggestions() {
    final state = ref.watch(searchProvider);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  t.searchSuggestions,
                  style: TextStyle(
                    fontSize: FontSizeType.small.size,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...state.searchSuggestions.map((suggestion) {
            return ListTile(
              dense: true,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusRegular,
                ),
                child: Icon(
                  Icons.trending_up,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
              title: Text(
                suggestion,
                style: TextStyle(
                  fontSize: FontSizeType.normal.size,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 14,
              ),
              onTap: () {
                _searchC.text = suggestion;
                performSearch(query: suggestion);
              },
            );
          }),
        ],
      ),
    );
  }

  // 构建加载视图
  Widget _buildLoadingView() {
    final state = ref.watch(searchProvider);
    return state.showSkeleton
        ? _buildSkeletonView()
        : const Center(child: CircularProgressIndicator());
  }

  // 构建骨架屏
  Widget _buildSkeletonView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppRadius.borderRadiusMedium,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.borderRadiusLarge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.borderRadiusTiny,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.borderRadiusTiny,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 构建空结果视图
  Widget _buildEmptyResults() {
    final state = ref.watch(searchProvider);

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

  // 构建搜索结果
  Widget _buildSearchResults() {
    final state = ref.watch(searchProvider);

    return Column(
      children: [
        // 搜索结果统计
        _buildSearchResultsHeader(),
        // 搜索结果列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.searchResults.length,
            itemBuilder: (context, index) {
              final message = state.searchResults[index];
              return _buildMessageItem(message);
            },
          ),
        ),
      ],
    );
  }

  // 构建搜索结果统计
  Widget _buildSearchResultsHeader() {
    final state = ref.watch(searchProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : AppColors.lightPageBackground,
      ),
      child: Row(
        children: [
          Text(
            '${state.totalResults} ${t.searchResults}',
            style: TextStyle(
              fontSize: FontSizeType.small.size,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // 构建消息项
  Widget _buildMessageItem(Message message) {
    final state = ref.watch(searchProvider);

    // 设置高亮词
    if (state.currentQuery.isNotEmpty) {
      words = {
        state.currentQuery: HighlightedWord(
          textStyle: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            backgroundColor: AppColors.primaryAlpha10,
          ),
        ),
      };
    }

    // 获取联系人信息
    ContactModel? author = state.getCachedContact(message.authorId);
    if (author == null) {
      _loadAndCacheContact(message.authorId);
      author = ContactModel(
        peerId: parseModelInt(message.authorId),
        nickname: 'Loading...',
        avatar: '',
      );
    }

    return wordView(message, author);
  }

  // 显示过滤器对话框
  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(),
    );
  }

  // 构建过滤器底部表单
  Widget _buildFilterSheet() {
    final state = ref.watch(searchProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部拖拽指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: AppRadius.borderRadiusTiny,
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.searchFilters,
                  style: TextStyle(
                    fontSize: FontSizeType.large.size,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(searchProvider.notifier).resetFilters();
                    performSearch(query: state.currentQuery);
                    Navigator.pop(context);
                  },
                  child: Text(
                    t.resetFilters,
                    style: TextStyle(
                      fontSize: FontSizeType.normal.size,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 应用按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  performSearch(query: state.currentQuery);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                ),
                child: Text(
                  t.applyFilters,
                  style: TextStyle(
                    fontSize: FontSizeType.normal.size,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
