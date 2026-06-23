import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
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
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'search_provider.dart';

/// 聊天记录搜索页面 - 极致 iOS 17 Premium 风格
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
  Map<String, HighlightedWord> words = {};

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void debouncedSearch(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      ref.read(searchProvider.notifier).resetSearch();
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => performSearch(query: query),
    );
  }

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
        notifier.setError(t.common.searchError);
        return;
      }
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
      if (mounted) {
        setState(() {
          words = {
            effectiveQuery: HighlightedWord(
              textStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          };
        });
      }
    } catch (_) {
      notifier.setError(t.common.searchError);
    } finally {
      notifier.setLoading(false);
      notifier.stopSearching();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.searchChatContent,
      useLargeTitle: false,
      child: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchC,
              placeholder: t.common.searchMessagesHint,
              onChanged: debouncedSearch,
              onSubmitted: (v) => performSearch(query: v),
            ),
          ),

          // 快速过滤器
          if (state.currentQuery.isNotEmpty || state.hasActiveFilters())
            _buildQuickFilterBar(context, state, brightness),

          // 结果列表
          Expanded(child: _buildSearchContent(state, brightness)),
        ],
      ),
    );
  }

  Widget _buildQuickFilterBar(
    BuildContext context,
    SearchDataState state,
    Brightness b,
  ) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            t.common.allTypes,
            state.selectedMessageType == 'all',
            () => _applyFilter('all'),
            b,
          ),
          AppSpacing.horizontalSmall,
          _buildFilterChip(
            t.chat.textMessage,
            state.selectedMessageType == MessageType.text,
            () => _applyFilter(MessageType.text),
            b,
          ),
          AppSpacing.horizontalSmall,
          _buildFilterChip(
            t.chat.imageMessage,
            state.selectedMessageType == MessageType.image,
            () => _applyFilter(MessageType.image),
            b,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Brightness b,
  ) {
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: context.textStyle(
          FontSizeType.footnote,
          color: isSelected ? AppColors.onPrimary : null,
        ),
      ),
      selectedColor: AppColors.getIosBlue(b),
      showCheckmark: false,
      onSelected: (_) => onTap(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  void _applyFilter(String type) {
    ref.read(searchProvider.notifier).resetFilters(); // 简单示例
    performSearch(query: _searchC.text);
  }

  Widget _buildSearchContent(SearchDataState state, Brightness b) {
    if (state.isLoading && state.searchResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 100),
        child: CupertinoActivityIndicator(),
      );
    }
    if (state.currentQuery.isEmpty) return _buildHistoryList(state, b);
    if (state.searchResults.isEmpty) {
      return _buildEmptyResults(state.currentQuery);
    }

    return ListView.builder(
      itemCount: state.searchResults.length,
      itemBuilder: (context, index) =>
          _buildResultItem(state.searchResults[index], state, b),
    );
  }

  Widget _buildHistoryList(SearchDataState state, Brightness b) {
    if (state.searchHistory.isEmpty) return const SizedBox.shrink();
    return ImBoySettingsSection(
      header: Text(t.common.searchHistory.toUpperCase()),
      children: state.searchHistory
          .map(
            (query) => ImBoySettingsTile(
              title: Text(query),
              leading: const Icon(
                CupertinoIcons.clock,
                color: AppColors.iosGray,
                size: 18,
              ),
              onTap: () {
                _searchC.text = query;
                performSearch(query: query);
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyResults(String q) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.search,
              size: 60,
              color: AppColors.iosGray3,
            ),
            AppSpacing.verticalRegular,
            Text(
              t.common.searchNoResults,
              style: const TextStyle(color: AppColors.iosGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(
    Message message,
    SearchDataState state,
    Brightness b,
  ) {
    ContactModel? author = state.getCachedContact(message.authorId);
    if (author == null) {
      _loadAndCacheContact(message.authorId);
      author = ContactModel(
        peerId: parseModelInt(message.authorId),
        nickname: '...',
        avatar: '',
      );
    }

    return ImBoyListTile(
      onTap: () => _goToChat(message.id),
      leading: Avatar(imgUri: author.avatar, width: 44, height: 44),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              author.nickname,
              style: context.textStyle(
                FontSizeType.medium,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            DateTimeHelper.lastTimeFmt(
              message.createdAt!.millisecondsSinceEpoch,
            ),
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.iosGray,
            ),
          ),
        ],
      ),
      subtitle: TextHighlight(
        text: message.metadata?['text'] as String? ?? '',
        words: words,
        textStyle: TextStyle(
          fontSize: FontSizeType.normal.size,
          color: AppColors.iosGray,
        ),
      ),
    );
  }

  void _goToChat(String msgId) {
    Navigator.push(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (context) => ChatPage(
          peerId: widget.peerId,
          peerTitle: widget.peerTitle,
          peerAvatar: widget.peerAvatar,
          peerSign: widget.peerSign,
          type: widget.type,
          msgId: msgId,
        ),
      ),
    );
  }

  Future<void> _loadAndCacheContact(String uid) async {
    final contact = await ContactRepo().findByUid(uid);
    if (contact != null && mounted) {
      ref.read(searchProvider.notifier).cacheContact(uid, contact);
      setState(() {});
    }
  }
}
