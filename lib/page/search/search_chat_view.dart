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

  /// 构建搜索结果项 - 使用优化后的主题样式
  Future<Widget> wordView(Message item) async {
    final msg = item;

    ContactModel? author = await ContactRepo().findByUid(msg.authorId);
    String subtitle = msg.metadata?['text'] ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(12), // 添加圆角
      child: Container(
        width: Get.width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(Get.context!).colorScheme.surface, // 使用主题表面色
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
          leading: Avatar(imgUri: author!.avatar),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  author.nickname,
                  style: Get.context!.textStyle(
                    FontSizeType.normal,
                    color: Theme.of(
                      Get.context!,
                    ).colorScheme.onSurface, // 使用主题文字色
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
                  color: AppColors.textSecondary, // 使用主题次要文字色
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          subtitle: TextHighlight(
            text: subtitle,
            // 传递需要高亮的字符串
            words: words,
            // 字典词汇
            matchCase: true, // 只高亮完全匹配的字符串
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
          // 显示定位提示
          // EasyLoading.showToast('正在定位消息...');

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
              popGesture: true, // 右滑，返回上一页
            );

            // 如果用户返回了搜索页面，可以在这里添加相应的处理逻辑
            if (result == null) {
              // 用户从聊天页面返回，可以刷新搜索结果等
              debugPrint('用户从聊天页面返回搜索页面');
            }
          } catch (e) {
            debugPrint('跳转到聊天页面失败: $e');
            // EasyLoading.showError('打开聊天失败');
          }
        }
      },
    );
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
            // 过滤器栏
            Obx(() => state.hasActiveFilters()
                ? _buildFilterBar(context)
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

  // 构建搜索栏
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
      child: Row(
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
                  hintText: 'search_messages_hint'.tr,
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
                  prefixIcon: Icon(
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
              'button_cancel'.tr,
              style: Get.context!.textStyle(
                FontSizeType.normal,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建过滤器栏
  Widget _buildFilterBar(BuildContext context) {
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              context,
              'search_filter_all'.tr,
              state.selectedMessageType.value == 'all',
              () {
                state.selectedMessageType.value = 'all';
                logic.performSearch(
                  query: state.currentQuery.value,
                  conversationUk3: widget.conversationUk3,
                  type: widget.type,
                );
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context,
              'search_filter_text'.tr,
              state.selectedMessageType.value == 'text',
              () {
                state.selectedMessageType.value = 'text';
                logic.performSearch(
                  query: state.currentQuery.value,
                  conversationUk3: widget.conversationUk3,
                  type: widget.type,
                );
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context,
              'search_filter_image'.tr,
              state.selectedMessageType.value == 'image',
              () {
                state.selectedMessageType.value = 'image';
                logic.performSearch(
                  query: state.currentQuery.value,
                  conversationUk3: widget.conversationUk3,
                  type: widget.type,
                );
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              context,
              'search_filter_today'.tr,
              state.selectedTimeRange.value == 'today',
              () {
                state.selectedTimeRange.value = 'today';
                logic.performSearch(
                  query: state.currentQuery.value,
                  conversationUk3: widget.conversationUk3,
                  type: widget.type,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 构建过滤器芯片
  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreen
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: Get.context!.textStyle(
            FontSizeType.small,
            color: isSelected
                ? AppColors.primaryGreen
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 构建搜索历史
  Widget _buildSearchHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索历史标题
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'search_history'.tr,
                style: Get.context!.textStyle(
                  FontSizeType.large,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Obx(() => state.searchHistory.isNotEmpty
                  ? TextButton(
                      onPressed: () {
                        state.clearHistory();
                      },
                      child: Text(
                        'clear_all'.tr,
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
            return Expanded(
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
                      'no_search_history'.tr,
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
            return Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      style: Get.context!.textStyle(
                        FontSizeType.normal,
                        color: Theme.of(context).colorScheme.onSurface,
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
                },
              ),
            );
          }
        }),
      ],
    );
  }

  // 构建搜索建议
  Widget _buildSearchSuggestions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'search_suggestions'.tr,
              style: Get.context!.textStyle(
                FontSizeType.small,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...state.searchSuggestions.map((suggestion) => ListTile(
            dense: true,
            leading: Icon(
              Icons.search,
              color: AppColors.textSecondary,
              size: 18,
            ),
            title: Text(
              suggestion,
              style: Get.context!.textStyle(
                FontSizeType.normal,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onTap: () {
              _searchC.text = suggestion;
              logic.performSearch(
                query: suggestion,
                conversationUk3: widget.conversationUk3,
                type: widget.type,
              );
            },
          )),
        ],
      ),
    );
  }

  // 构建加载视图
  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
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
            'search_no_results'.tr,
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

  // 构建搜索结果
  Widget _buildSearchResults(BuildContext context) {
    return Column(
      children: [
        // 搜索结果统计
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Obx(() => Text(
                '${state.totalResults.value} ${'search_results'.tr}',
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
                        'load_more'.tr,
                        style: Get.context!.textStyle(
                          FontSizeType.small,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        ),
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

  // 构建消息项
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

      return FutureBuilder<Widget>(
        future: wordView(message),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return snapshot.data!;
          } else {
            return const SizedBox.shrink();
          }
        },
      );
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
                  'search_filters'.tr,
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
                    'reset_filters'.tr,
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
                    'message_type'.tr,
                    [
                      {'value': 'all', 'label': 'all_types'.tr},
                      {'value': 'text', 'label': 'text_message'.tr},
                      {'value': 'image', 'label': 'image_message'.tr},
                      {'value': 'video', 'label': 'video_message'.tr},
                      {'value': 'file', 'label': 'file_message'.tr},
                    ],
                    state.selectedMessageType.value,
                    (value) => state.selectedMessageType.value = value,
                  ),
                  const SizedBox(height: 24),
                  // 时间范围过滤器
                  _buildFilterSection(
                    context,
                    'time_range'.tr,
                    [
                      {'value': 'all', 'label': 'all_time'.tr},
                      {'value': 'today', 'label': 'today'.tr},
                      {'value': 'week', 'label': 'this_week'.tr},
                      {'value': 'month', 'label': 'this_month'.tr},
                    ],
                    state.selectedTimeRange.value,
                    (value) => state.selectedTimeRange.value = value,
                  ),
                  const SizedBox(height: 24),
                  // 发送者过滤器
                  _buildFilterSection(
                    context,
                    'sender'.tr,
                    [
                      {'value': 'all', 'label': 'all_senders'.tr},
                      {'value': 'me', 'label': 'sent_by_me'.tr},
                      {'value': 'other', 'label': 'sent_by_others'.tr},
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
                  'apply_filters'.tr,
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