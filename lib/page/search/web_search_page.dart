/// Web 端全局搜索页面 - WhatsApp Web 风格
///
/// 功能：
/// - 全局消息搜索
/// - 联系人搜索
/// - 群组搜索
/// - 搜索历史记录
library;

import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'web_search_state.dart';

/// Web 全局搜索页面
class WebSearchPage extends ConsumerStatefulWidget {
  /// 初始搜索关键词
  final String? initialQuery;

  /// 搜索范围（可选）
  final String? scope; // 'all', 'messages', 'contacts', 'groups'

  const WebSearchPage({super.key, this.initialQuery, this.scope});

  @override
  ConsumerState<WebSearchPage> createState() => _WebSearchPageState();
}

class _WebSearchPageState extends ConsumerState<WebSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounceTimer;
  WebSearchState _state = const WebSearchState();

  @override
  void initState() {
    super.initState();

    // 设置初始搜索词
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }

    // 加载最近搜索记录
    _loadRecentSearches();

    // 自动聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 加载最近搜索记录
  Future<void> _loadRecentSearches() async {
    try {
      final jsonStr = StorageService.to.getString('web_search_history');
      if (jsonStr.isNotEmpty) {
        final List<dynamic> history = jsonDecode(jsonStr) as List<dynamic>;
        setState(() {
          _state = _state.copyWith(recentSearches: history.cast<String>());
        });
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('加载搜索历史失败: ${e.runtimeType}');
    }
  }

  /// 防抖搜索
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _state = _state.copyWith(
          query: '',
          results: [],
          showRecent: true,
          isLoading: false,
        );
      });
      return;
    }

    setState(() {
      _state = _state.copyWith(
        query: query,
        showRecent: false,
        isLoading: true,
      );
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  /// 执行搜索
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final results = <SearchItem>[];

      // 并行执行所有搜索
      final futures = await Future.wait([
        // 1. 搜索消息（使用 FTS API）
        _searchMessages(query),
        // 2. 搜索联系人
        _searchContacts(query),
        // 3. 搜索群组
        _searchGroups(query),
        // 4. 搜索会话
        _searchConversations(query),
      ]);

      // 合并所有搜索结果
      for (final items in futures) {
        results.addAll(items);
      }

      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(results: results, isLoading: false);
      });

      // 保存搜索记录
      _saveSearchHistory(query);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Search error: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(isLoading: false, error: t.common.searchError);
      });
    }
  }

  /// 搜索消息
  Future<List<SearchItem>> _searchMessages(String query) async {
    final results = <SearchItem>[];
    try {
      final response = await FtsApi.to.searchMessages(
        keyword: query,
        page: 1,
        size: 10,
        type: 'all',
      );

      if (response != null && response.items.isNotEmpty) {
        for (final item in response.items) {
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
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Search messages error: ${e.runtimeType}');
    }
    return results;
  }

  /// 搜索联系人
  Future<List<SearchItem>> _searchContacts(String query) async {
    final results = <SearchItem>[];
    try {
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
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Search contacts error: ${e.runtimeType}');
    }
    return results;
  }

  /// 搜索群组
  Future<List<SearchItem>> _searchGroups(String query) async {
    final results = <SearchItem>[];
    try {
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
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Search groups error: ${e.runtimeType}');
    }
    return results;
  }

  /// 搜索会话
  Future<List<SearchItem>> _searchConversations(String query) async {
    final results = <SearchItem>[];
    try {
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
    } on Exception {
      if (kDebugMode) {}
    }
    return results;
  }

  /// 保存搜索记录
  Future<void> _saveSearchHistory(String query) async {
    try {
      final history = List<String>.from(_state.recentSearches);
      // 移除重复项
      history.remove(query);
      // 添加到开头
      history.insert(0, query);
      // 限制数量为 20
      if (history.length > 20) {
        history.removeRange(20, history.length);
      }
      // 保存到本地存储
      await StorageService.to.setString(
        'web_search_history',
        jsonEncode(history),
      );
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(recentSearches: history);
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('保存搜索历史失败: ${e.runtimeType}');
    }
  }

  /// 清除搜索记录
  Future<void> _clearSearchHistory() async {
    try {
      await StorageService.to.remove('web_search_history');
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(recentSearches: []);
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('清除搜索历史失败: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? AppColors.chatWebSurfaceDarkest : AppColors.lightSurface,
      child: Column(
        children: [
          // 搜索栏
          _buildSearchBar(isDark),

          // 搜索内容
          Expanded(
            child: _state.isLoading
                ? _buildLoadingState(isDark)
                : _state.showRecent
                ? _buildRecentSearches(isDark)
                : _buildSearchResults(isDark),
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: AppSpacing.allMedium,
      color: isDark
          ? AppColors.chatWebBackgroundDark
          : AppColors.chatWebBackgroundLight,
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: isDark
                  ? AppColors.chatWebSecondaryDark
                  : AppColors.chatWebSecondaryLight,
            ),
            onPressed: () => context.pop(),
          ),

          // 搜索输入框
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontSize: FontSizeType.subheadline.size,
              ),
              decoration: InputDecoration(
                hintText: t.common.search,
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.chatWebSecondaryDark
                      : AppColors.chatWebSecondaryLight,
                  fontSize: FontSizeType.subheadline.size,
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.chatWebSurfaceDark
                    : AppColors.lightSurface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusSmall,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: isDark
                              ? AppColors.chatWebSecondaryDark
                              : AppColors.chatWebSecondaryLight,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加载状态
  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.chatWebBrand),
          AppSpacing.verticalRegular,
          Text(
            t.common.search,
            style: TextStyle(
              color: isDark
                  ? AppColors.chatWebSecondaryDark
                  : AppColors.chatWebSecondaryLight,
              fontSize: FontSizeType.normal.size,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建最近搜索
  Widget _buildRecentSearches(bool isDark) {
    if (_state.recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: isDark
                  ? AppColors.chatWebDividerDark
                  : AppColors.chatWebDividerLight,
            ),
            AppSpacing.verticalRegular,
            Text(
              t.common.searchChatContent,
              style: TextStyle(
                color: isDark
                    ? AppColors.chatWebSecondaryDark
                    : AppColors.chatWebSecondaryLight,
                fontSize: FontSizeType.normal.size,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.common.searchHistory,
                style: TextStyle(
                  color: isDark
                      ? AppColors.chatWebSecondaryDark
                      : AppColors.chatWebSecondaryLight,
                  fontSize: FontSizeType.normal.size,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _clearSearchHistory,
                child: Text(
                  t.common.clear,
                  style: TextStyle(
                    color: AppColors.chatWebBrand,
                    fontSize: FontSizeType.normal.size,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 搜索记录列表
        Expanded(
          child: ListView.builder(
            itemCount: _state.recentSearches.length,
            itemBuilder: (context, index) {
              final search = _state.recentSearches[index];
              return ListTile(
                leading: Icon(
                  Icons.history,
                  color: isDark
                      ? AppColors.chatWebSecondaryDark
                      : AppColors.chatWebSecondaryLight,
                ),
                title: Text(
                  search,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                    fontSize: FontSizeType.subheadline.size,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.north_west,
                    color: isDark
                        ? AppColors.chatWebSecondaryDark
                        : AppColors.chatWebSecondaryLight,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.text = search;
                    _onSearchChanged(search);
                  },
                ),
                onTap: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建搜索结果
  Widget _buildSearchResults(bool isDark) {
    if (_state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? AppColors.iosRedDark : AppColors.iosRed,
            ),
            AppSpacing.verticalRegular,
            Text(
              _state.error!,
              style: TextStyle(
                color: isDark ? AppColors.iosRedDark : AppColors.iosRed,
                fontSize: FontSizeType.normal.size,
              ),
            ),
          ],
        ),
      );
    }

    if (_state.results.isEmpty && _state.query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark
                  ? AppColors.chatWebDividerDark
                  : AppColors.chatWebDividerLight,
            ),
            AppSpacing.verticalRegular,
            Text(
              '${t.common.search}: "${_state.query}"',
              style: TextStyle(
                color: isDark
                    ? AppColors.chatWebSecondaryDark
                    : AppColors.chatWebSecondaryLight,
                fontSize: FontSizeType.normal.size,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 按类型分组结果
    final conversations = _state.results
        .where((r) => r.type == SearchItemType.conversation)
        .toList();
    final messages = _state.results
        .where((r) => r.type == SearchItemType.message)
        .toList();
    final contacts = _state.results
        .where((r) => r.type == SearchItemType.contact)
        .toList();
    final groups = _state.results
        .where((r) => r.type == SearchItemType.group)
        .toList();

    return ListView(
      controller: _scrollController,
      children: [
        if (conversations.isNotEmpty) ...[
          _buildSectionHeader('conversations', isDark),
          ...conversations.map((item) => _buildSearchItem(item, isDark)),
        ],
        if (messages.isNotEmpty) ...[
          _buildSectionHeader('messages', isDark),
          ...messages.map((item) => _buildSearchItem(item, isDark)),
        ],
        if (contacts.isNotEmpty) ...[
          _buildSectionHeader('contacts', isDark),
          ...contacts.map((item) => _buildSearchItem(item, isDark)),
        ],
        if (groups.isNotEmpty) ...[
          _buildSectionHeader('groups', isDark),
          ...groups.map((item) => _buildSearchItem(item, isDark)),
        ],
      ],
    );
  }

  /// 构建分组标题
  Widget _buildSectionHeader(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark
          ? AppColors.chatWebBackgroundDark
          : AppColors.chatWebBackgroundLight,
      child: Text(
        title,
        style: TextStyle(
          color: isDark
              ? AppColors.chatWebSecondaryDark
              : AppColors.chatWebSecondaryLight,
          fontSize: FontSizeType.footnote.size,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建搜索结果项
  Widget _buildSearchItem(SearchItem item, bool isDark) {
    final words = <String, HighlightedWord>{};
    if (item.highlightText != null && item.highlightText!.isNotEmpty) {
      words[item.highlightText!.toLowerCase()] = HighlightedWord(
        textStyle: TextStyle(
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          backgroundColor: AppColors.chatWebBrand.withAlpha(50),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return InkWell(
      onTap: () => _onItemTap(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 图标或头像
            _buildItemIcon(item, isDark),
            AppSpacing.horizontalMedium,

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  TextHighlight(
                    text: item.title,
                    words: words,
                    textStyle: TextStyle(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontSize: FontSizeType.subheadline.size,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    TextHighlight(
                      text: item.subtitle!,
                      words: words,
                      textStyle: TextStyle(
                        color: isDark
                            ? AppColors.chatWebSecondaryDark
                            : AppColors.chatWebSecondaryLight,
                        fontSize: FontSizeType.footnote.size,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // 时间戳（消息类型）
            if (item.type == SearchItemType.message &&
                item.metadata?['timestamp'] != null) ...[
              AppSpacing.horizontalSmall,
              Text(
                DateTimeHelper.lastTimeFmt(item.metadata!['timestamp'] as int),
                style: TextStyle(
                  color: isDark
                      ? AppColors.chatWebSecondaryDark
                      : AppColors.chatWebSecondaryLight,
                  fontSize: FontSizeType.small.size,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建项目图标
  Widget _buildItemIcon(SearchItem item, bool isDark) {
    if (item.avatar != null && item.avatar!.isNotEmpty) {
      return Avatar(imgUri: item.avatar!);
    }

    IconData iconData;
    switch (item.type) {
      case SearchItemType.conversation:
        iconData = Icons.chat_bubble_outline;
      case SearchItemType.message:
        iconData = Icons.message_outlined;
      case SearchItemType.contact:
        iconData = Icons.person_outline;
      case SearchItemType.group:
        iconData = Icons.group_outlined;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.chatWebSurfaceDark
            : AppColors.chatWebBackgroundLight,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: isDark
            ? AppColors.chatWebSecondaryDark
            : AppColors.chatWebSecondaryLight,
        size: 24,
      ),
    );
  }

  /// 处理结果项点击
  void _onItemTap(SearchItem item) {
    switch (item.type) {
      case SearchItemType.conversation:
        context.push('/chat/${item.id}');
      case SearchItemType.message:
        // 跳转到消息详情
        if (item.metadata?['conversationId'] != null) {
          context.push('/chat/${item.metadata!['conversationId']}');
        }
      case SearchItemType.contact:
        context.push('/people_info/${item.id}');
      case SearchItemType.group:
        // 群聊点击进入会话，统一走 /chat/:peerId?type=C2G
        context.push('/chat/${item.id}?type=C2G');
    }
  }
}
