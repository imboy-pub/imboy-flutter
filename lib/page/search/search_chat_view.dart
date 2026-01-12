import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'package:imboy/component/ui/avatar.dart';

import 'search_logic.dart';
import 'search_state.dart';
import 'package:imboy/i18n/strings.g.dart';

class SearchChatPage extends StatefulWidget {
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
  // ignore: library_private_types_in_public_api
  _SearchChatPageState createState() => _SearchChatPageState();
}

class _SearchChatPageState extends State<SearchChatPage> {
  final logic = Get.put(SearchLogic());
  final SearchState state = Get.find<SearchLogic>().state;

  final TextEditingController _searchC = TextEditingController();

  List<Message> items = [];
  Map<String, HighlightedWord> words = {};

  /// 构建搜索结果项 - 优化版本，使用缓存
  Widget wordView(Message item) {
    final msg = item;
    String subtitle = msg.metadata?['text'] ?? '';

    // 使用缓存的联系人信息
    ContactModel? author = state.getCachedContact(msg.authorId);
    if (author == null) {
      // 如果缓存中没有，异步加载并缓存
      _loadAndCacheContact(msg.authorId);
      // 显示占位符
      author = ContactModel(
        peerId: msg.authorId,
        nickname: 'Loading...',
        avatar: '',
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: Get.width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(Get.context!).shadowColor.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: Avatar(imgUri: author.avatar),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  author.nickname,
                  style: Get.context!.textStyle(
                    FontSizeType.normal,
                    color: Theme.of(Get.context!).colorScheme.onSurface,
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
                style: Get.context!.textStyle(
                  FontSizeType.small,
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
            final result = await Get.to(
              () => ChatPage(
                peerId: widget.peerId,
                peerTitle: widget.peerTitle,
                peerAvatar: widget.peerAvatar,
                peerSign: widget.peerSign,
                type: widget.type,
                msgId: msg.id,
              ),
              transition: Transition.rightToLeft,
              popGesture: true,
            );

            if (result == null) {
              debugPrint('用户从聊天页面返回搜索页面');
            }
          } catch (e) {
            debugPrint('跳转到聊天页面失败: $e');
          }
        }
      },
    );
  }

  // 异步加载并缓存联系人信息 - 优化版本
  Future<void> _loadAndCacheContact(String uid) async {
    try {
      final contact = await ContactRepo().findByUid(uid);
      if (contact != null) {
        state.cacheContact(uid, contact);
        // 触发UI更新
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('加载联系人信息失败: $uid, $e');
      
      // 如果是加密相关错误，创建基础联系人对象
      if (e.toString().contains('Invalid padding') || 
          e.toString().contains('decrypt')) {
        final fallbackContact = ContactModel(
          peerId: uid,
          nickname: 'User_${uid.substring(0, 8)}',
          avatar: '',
        );
        state.cacheContact(uid, fallbackContact);
        
        // 触发UI更新
        if (mounted) {
          setState(() {});
        }
        debugPrint('使用降级联系人信息: $uid');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 搜索栏
            _buildSearchBar(context),
            // 快速过滤器栏
            Obx(() => (state.currentQuery.value.isNotEmpty || state.hasActiveFilters())
                ? _buildQuickFilterBar(context)
                : const SizedBox.shrink()),
            // 搜索内容
            Expanded(
              child: Obx(() {
                if (state.isLoading.value && state.searchResults.isEmpty) {
                  return _buildLoadingView();
                } else if (state.currentQuery.value.isEmpty) {
                  return _buildSearchHistory(context);
                } else if (state.searchResults.isEmpty && !state.isLoading.value) {
                  return _buildEmptyResults(context);
                } else {
                  return _buildSearchResults(context);
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  // 搜索栏
  Widget _buildSearchBar(BuildContext context) {
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchC,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: t.searchMessagesHint,
                      hintStyle: Get.context!.textStyle(
                        FontSizeType.normal,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: state.isSearching.value
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryGreen,
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
                                  ? AppColors.primaryGreen
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
                          Obx(() => state.currentQuery.value.isNotEmpty
                              ? IconButton(
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
                                    logic.cancelSearch();
                                    state.resetSearch();
                                  },
                                )
                              : const SizedBox.shrink()),
                        ],
                      ),
                    ),
                    onChanged: (value) {
                      logic.debouncedSearch(
                        value,
                        conversationUk3: widget.conversationUk3,
                        type: widget.type,
                      );
                      // 更新搜索建议
                      if (value.length >= 2) {
                        logic.getSearchSuggestions(value);
                      }
                    },
                    onSubmitted: (value) {
                      logic.performSearch(
                        query: value,
                        conversationUk3: widget.conversationUk3,
                        type: widget.type,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 取消按钮
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  t.buttonCancel,
                  style: Get.context!.textStyle(
                    FontSizeType.normal,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // 搜索进度条
          Obx(() => state.isSearching.value
              ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    value: state.searchProgress.value / 100,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

// 快速过滤器栏
  Widget _buildQuickFilterBar(BuildContext context) {
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
                style: Get.context!.textStyle(
                  FontSizeType.small,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Obx(() => state.hasActiveFilters()
                  ? TextButton(
                      onPressed: () {
                        state.resetFilters();
                        logic.performSearch(
                          query: state.currentQuery.value,
                          conversationUk3: widget.conversationUk3,
                          type: widget.type,
                        );
                      },
                      child: Text(
                        t.resetFilters,
                        style: Get.context!.textStyle(
                          FontSizeType.small,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
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
                  state.selectedMessageType.value == 'all',
                  () {
                    state.selectedMessageType.value = 'all';
                    _triggerSearch();
                  },
                  Icons.apps,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.textMessage,
                  state.selectedMessageType.value == 'text',
                  () {
                    state.selectedMessageType.value = 'text';
                    _triggerSearch();
                  },
                  Icons.text_fields,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.imageMessage,
                  state.selectedMessageType.value == 'image',
                  () {
                    state.selectedMessageType.value = 'image';
                    _triggerSearch();
                  },
                  Icons.image,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.today,
                  state.selectedTimeRange.value == 'today',
                  () {
                    state.selectedTimeRange.value = 'today';
                    _triggerSearch();
                  },
                  Icons.today,
                ),
                const SizedBox(width: 8),
                _buildQuickFilterChip(
                  context,
                  t.thisWeek,
                  state.selectedTimeRange.value == 'week',
                  () {
                    state.selectedTimeRange.value = 'week';
                    _triggerSearch();
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

  // 触发搜索
  void _triggerSearch() {
    if (state.currentQuery.value.isNotEmpty) {
      logic.performSearch(
        query: state.currentQuery.value,
        conversationUk3: widget.conversationUk3,
        type: widget.type,
      );
    }
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
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
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
                  ? AppColors.primaryGreen
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Get.context!.textStyle(
                FontSizeType.small,
                color: isSelected
                    ? AppColors.primaryGreen
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  // 构建搜索历史
  Widget _buildSearchHistory(BuildContext context) {
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
                  style: Get.context!.textStyle(
                    FontSizeType.large,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Obx(() => state.searchHistory.isNotEmpty
                    ? TextButton(
                        onPressed: () {
                          state.clearHistory();
                        },
                        child: Text(
                          t.clearAll,
                          style: Get.context!.textStyle(
                            FontSizeType.normal,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
          // 搜索建议
          Obx(() => state.searchSuggestions.isNotEmpty
              ? _buildSearchSuggestions(context)
              : const SizedBox.shrink()),
          // 搜索历史列表
          Obx(() {
            if (state.searchHistory.isEmpty) {
              return Padding(
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
                        style: Get.context!.textStyle(
                          FontSizeType.normal,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                        style: Get.context!.textStyle(
                          FontSizeType.normal,
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
                          logic.performSearch(
                            query: query,
                            conversationUk3: widget.conversationUk3,
                            type: widget.type,
                          );
                        },
                      ),
                      onTap: () {
                        _searchC.text = query;
                        logic.performSearch(
                          query: query,
                          conversationUk3: widget.conversationUk3,
                          type: widget.type,
                        );
                      },
                    );
                  }).toList(),
                ),
              );
            }
          }),
        ],
      ),
    );
  }

  // 构建搜索建议 - 优化版本
  Widget _buildSearchSuggestions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.05),
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
              color: AppColors.primaryGreen.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  t.searchSuggestions,
                  style: Get.context!.textStyle(
                    FontSizeType.small,
                    color: AppColors.primaryGreen,
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
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: AppColors.primaryGreen,
                  size: 16,
                ),
              ),
              title: Text(
                suggestion,
                style: Get.context!.textStyle(
                  FontSizeType.normal,
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
                logic.performSearch(
                  query: suggestion,
                  conversationUk3: widget.conversationUk3,
                  type: widget.type,
                );
              },
            );
          }),
        ],
      ),
    );
  }

  // 构建加载视图 - 骨架屏
  Widget _buildLoadingView() {
    return Obx(() => state.showSkeleton.value
        ? _buildSkeletonView()
        : const Center(
            child: CircularProgressIndicator(),
          ));
  }

  // 构建骨架屏
  Widget _buildSkeletonView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 5, // 显示5个骨架项
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              // 头像骨架
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题骨架
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 内容骨架
                    Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
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
  Widget _buildEmptyResults(BuildContext context) {
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
            style: Get.context!.textStyle(
              FontSizeType.large,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() => Text(
            '"${state.currentQuery.value}"',
            style: Get.context!.textStyle(
              FontSizeType.normal,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          )),
        ],
      ),
    );
  }

  // 构建搜索结果统计
  Widget _buildSearchResultsHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      ),
      child: Row(
        children: [
          Obx(() => Text(
                '${state.totalResults.value} ${t.searchResults}',
                style: Get.context!.textStyle(
                  FontSizeType.small,
                  color: AppColors.textSecondary,
                ),
              )),
          const Spacer(),
          Obx(() => state.hasMore.value
              ? TextButton(
                  onPressed: () {
                    logic.loadMoreResults(
                      conversationUk3: widget.conversationUk3,
                      type: widget.type,
                    );
                  },
                  child: Text(
                    t.loadMore,
                    style: Get.context!.textStyle(
                      FontSizeType.small,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  // 构建搜索结果
  Widget _buildSearchResults(BuildContext context) {
    return Column(
      children: [
        // 搜索结果统计
        _buildSearchResultsHeader(context),
        // 搜索结果列表
        Expanded(
          child: Obx(() => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.searchResults.length,
                itemBuilder: (context, index) {
                  final message = state.searchResults[index];
                  return _buildMessageItem(context, message);
                },
              )),
        ),
      ],
    );
  }

  // 构建消息项 - 优化版本，直接构建无需Future
  Widget _buildMessageItem(BuildContext context, dynamic message) {
    return Obx(() {
      // 设置高亮词
      if (state.currentQuery.value.isNotEmpty) {
        words = {
          state.currentQuery.value: HighlightedWord(
            onTap: () {},
            textStyle: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              backgroundColor: AppColors.primaryGreenAlpha10,
            ),
          ),
        };
      }

      return wordView(message);
    });
  }

  // 显示过滤器对话框
  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterSheet(context),
    );
  }

  // 构建过滤器底部表单
  Widget _buildFilterSheet(BuildContext context) {
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
              borderRadius: BorderRadius.circular(2),
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
                  style: Get.context!.textStyle(
                    FontSizeType.large,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    state.resetFilters();
                    logic.performSearch(
                      query: state.currentQuery.value,
                      conversationUk3: widget.conversationUk3,
                      type: widget.type,
                    );
                    Get.back();
                  },
                  child: Text(
                    t.resetFilters,
                    style: Get.context!.textStyle(
                      FontSizeType.normal,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 过滤器选项
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 消息类型过滤器
                  _buildFilterSection(
                    context,
                    t.messageType,
                    [
                      {'value': 'all', 'label': t.allTypes},
                      {'value': 'text', 'label': t.textMessage},
                      {'value': 'image', 'label': t.imageMessage},
                      {'value': 'video', 'label': t.videoMessage},
                      {'value': 'file', 'label': t.fileMessage},
                    ],
                    state.selectedMessageType.value,
                    (value) => state.selectedMessageType.value = value,
                  ),
                  const SizedBox(height: 24),
                  // 时间范围过滤器
                  _buildFilterSection(
                    context,
                    t.timeRange,
                    [
                      {'value': 'all', 'label': t.allTime},
                      {'value': 'today', 'label': t.today},
                      {'value': 'week', 'label': t.thisWeek},
                      {'value': 'month', 'label': t.thisMonth},
                    ],
                    state.selectedTimeRange.value,
                    (value) => state.selectedTimeRange.value = value,
                  ),
                  const SizedBox(height: 24),
                  // 发送者过滤器
                  _buildFilterSection(
                    context,
                    t.sender,
                    [
                      {'value': 'all', 'label': t.allSenders},
                      {'value': 'me', 'label': t.sentByMe},
                      {'value': 'other', 'label': t.sentByOthers},
                    ],
                    state.selectedSender.value,
                    (value) => state.selectedSender.value = value,
                  ),
                ],
              ),
            ),
          ),
          // 应用按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  logic.performSearch(
                    query: state.currentQuery.value,
                    conversationUk3: widget.conversationUk3,
                    type: widget.type,
                  );
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  t.applyFilters,
                  style: Get.context!.textStyle(
                    FontSizeType.normal,
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

  // 构建过滤器部分
  Widget _buildFilterSection(
    BuildContext context,
    String title,
    List<Map<String, String>> options,
    String selectedValue,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Get.context!.textStyle(
            FontSizeType.normal,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option['value'];
            return GestureDetector(
              onTap: () => onChanged(option['value']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGreen.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  option['label']!,
                  style: Get.context!.textStyle(
                    FontSizeType.normal,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    Get.delete<SearchLogic>();
    super.dispose();
  }
}