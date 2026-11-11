import 'dart:async';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'search_provider.dart';
import 'search_result_expiry.dart';

/// 聊天记录搜索页面 - 极致 iOS 17 Premium 风格
class SearchChatPage extends StatelessWidget {
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
  Widget build(BuildContext context) => ProviderScope(
    overrides: [searchProvider.overrideWith(SearchNotifier.new)],
    child: _SearchChatBody(
      conversationUk3: conversationUk3,
      type: type,
      peerId: peerId,
      peerAvatar: peerAvatar,
      peerTitle: peerTitle,
      peerSign: peerSign,
    ),
  );
}

class _SearchChatBody extends ConsumerStatefulWidget {
  const _SearchChatBody({
    required this.conversationUk3,
    required this.type,
    required this.peerId,
    required this.peerAvatar,
    required this.peerTitle,
    required this.peerSign,
  });

  final String conversationUk3;
  final String type;
  final String peerId;
  final String peerAvatar;
  final String peerTitle;
  final String peerSign;

  @override
  ConsumerState<_SearchChatBody> createState() => _SearchChatPageState();
}

class _SearchChatPageState extends ConsumerState<_SearchChatBody> {
  final TextEditingController _searchC = TextEditingController();
  Timer? _debounceTimer;
  late final SearchResultExpiry _resultExpiry;
  Map<String, MessageSearchResult> _resultFacts = {};
  int _searchGeneration = 0;
  int _visibilityGeneration = 0;
  bool _scopeResetPending = false;
  int _scopeGeneration = 0;
  late final String _ownerUid;
  late final int _ownerSession;
  Map<String, HighlightedWord> words = {};

  /// 服务端按策略关闭了消息搜索（E2EE 模式下读不到明文）。
  /// 这是预期状态而非故障，错误视图要走说明性空态且不给重试入口。
  bool _searchDisabled = false;

  bool get _ownerActive {
    final user = UserRepoLocal.to;
    return _ownerUid.isNotEmpty &&
        user.currentUid == _ownerUid &&
        user.isCurrentSession(_ownerSession) &&
        !user.isAuthTransitioning;
  }

  @override
  void initState() {
    super.initState();
    _resultExpiry = SearchResultExpiry(
      _removeExpiredResults,
      onResume: () => unawaited(_refreshResultFacts()),
    );
    final user = UserRepoLocal.to;
    _ownerUid = user.currentUid;
    _ownerSession = user.sessionGeneration;
    user.addAuthListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (!mounted || _ownerActive) return;
    _searchGeneration++;
    _debounceTimer?.cancel();
    _resultExpiry.cancel();
    _resultFacts = {};
    _searchC.clear();
    words = {};
    _searchDisabled = false;
    ref.read(searchProvider.notifier).resetSearch();
    setState(() {});
  }

  @override
  void dispose() {
    _searchGeneration++;
    _debounceTimer?.cancel();
    _resultExpiry.dispose();
    UserRepoLocal.to.removeAuthListener(_onAuthChanged);
    _searchC.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SearchChatBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationUk3 != widget.conversationUk3) {
      _searchGeneration++;
      _debounceTimer?.cancel();
      _resultExpiry.cancel();
      _resultFacts = {};
      _searchC.clear();
      _searchDisabled = false;
      words = {};
      _scopeResetPending = true;
      final generation = _searchGeneration;
      final scopeGeneration = ++_scopeGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || scopeGeneration != _scopeGeneration) return;
        if (generation == _searchGeneration) {
          ref.read(searchProvider.notifier).resetSearch();
        }
        setState(() => _scopeResetPending = false);
      });
    }
  }

  void debouncedSearch(String query) {
    if (!_ownerActive) return;
    _debounceTimer?.cancel();
    _resultExpiry.cancel();
    _resultFacts = {};
    _searchGeneration++;
    ref.read(searchProvider.notifier).resetSearch();
    if (query.trim().isEmpty) {
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => performSearch(query: query),
    );
  }

  Future<void> performSearch({required String query}) async {
    if (query.trim().isEmpty || !_ownerActive) return;
    _debounceTimer?.cancel();
    final request = ++_searchGeneration;
    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final sessionGeneration = session.sessionGeneration;
    final conversation = widget.conversationUk3;
    bool isCurrent() =>
        mounted &&
        request == _searchGeneration &&
        widget.conversationUk3 == conversation &&
        session.currentUid == uid &&
        session.isCurrentSession(sessionGeneration) &&
        !session.isAuthTransitioning;
    final notifier = ref.read(searchProvider.notifier);
    final effectiveQuery = query.trim();
    notifier.setCurrentQuery(effectiveQuery);
    notifier.setLoading(true);
    notifier.startSearching();
    notifier.setError('');
    _searchDisabled = false;
    try {
      final response = await ref
          .read(ftsApiProvider)
          .searchConversationMessages(
            keyword: effectiveQuery,
            conversationUk3: conversation,
            page: 1,
            size: 50,
            msgType: ref.read(searchProvider).selectedMessageType,
          );
      if (!isCurrent()) return;
      if (response == null) {
        notifier.setError(t.common.searchError);
        return;
      }
      final nowMs = DateTimeHelper.millisecond();
      final visibleItems = response.items
          .where((item) => item.isVisibleAt(nowMs, uid))
          .toList();
      _resultFacts = {for (final item in visibleItems) item.id: item};
      final messages = visibleItems.map((item) {
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
      _removeExpiredResults();
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
    } on FtsFeatureDisabledException {
      // 与 message_search_page 同款处理：搜索被策略禁用是预期状态，不是故障。
      // 原先这里被 catch (_) 一并吞成「搜索错误 + 重试」，而重试永远不可能
      // 成功——服务端 imboy_policy:message_search_enabled() 恒为 false。
      if (!isCurrent()) return;
      setState(() => _searchDisabled = true);
      notifier.setError(t.common.searchDisabledByEncryption);
    } catch (_) {
      if (!isCurrent()) return;
      notifier.setError(t.common.searchError);
    } finally {
      if (isCurrent()) {
        notifier.setLoading(false);
        notifier.stopSearching();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final brightness = Theme.of(context).brightness;

    // 不能用 IosPageTemplate：它内部强制 SingleChildScrollView(无界高度)，
    // 而本页 Column 含 Expanded → RenderFlex unbounded height 异常导致整页
    // 白屏(无搜索框/无列表)。改用 Scaffold 给 Column 有界高度（QA#20）。
    return Scaffold(
      // 被 push 进来的子页（聊天设置 / 群详情 → 搜索聊天记录），
      // GlassAppBar 的 automaticallyImplyLeading 默认 false，必须显式打开才有返回键。
      appBar: GlassAppBar(
        title: t.common.searchChatContent,
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchC,
              enabled: _ownerActive,
              placeholder: t.common.searchMessagesHint,
              onChanged: debouncedSearch,
              onSubmitted: (v) => performSearch(query: v),
            ),
          ),

          // 快速过滤器
          if (_ownerActive &&
              !_scopeResetPending &&
              (state.currentQuery.isNotEmpty || state.hasActiveFilters()))
            _buildQuickFilterBar(context, state, brightness),

          // 结果列表
          Expanded(
            child: !_ownerActive || _scopeResetPending
                ? const SizedBox.shrink()
                : _buildSearchContent(state, brightness),
          ),
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
      constraints: const BoxConstraints(minHeight: 44),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildFilterChip(
              t.common.allTypes,
              state.selectedMessageType == 'all',
              () => _applyFilter('all'),
              b,
            ),
            AppSpacing.horizontalSmall,
            // 口径统一为「类型名」：t.chat.imageMessage 的值是消息预览标识
            // "[图片]"，带方括号的预览文案不该出现在筛选标签上。
            _buildFilterChip(
              t.main.text,
              state.selectedMessageType == MessageType.text,
              () => _applyFilter(MessageType.text),
              b,
            ),
            AppSpacing.horizontalSmall,
            _buildFilterChip(
              t.chat.image,
              state.selectedMessageType == MessageType.image,
              () => _applyFilter(MessageType.image),
              b,
            ),
          ],
        ),
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
    // 此前误调 resetFilters() 会把 selectedMessageType 重置回 'all'，
    // 导致筛选 chip 只更新 UI 选中态但从未真正按类型过滤（见 fix 记录）。
    ref.read(searchProvider.notifier).setMessageTypeFilter(type);
    performSearch(query: _searchC.text);
  }

  Widget _buildSearchContent(SearchDataState state, Brightness b) {
    if (state.isLoading && state.searchResults.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (state.currentQuery.isEmpty) return _buildHistoryList(state, b);
    if (state.errorMessage.isNotEmpty) {
      return _buildErrorResults(state.errorMessage, state.currentQuery);
    }
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
    return ListView(
      children: [
        ImBoySettingsSection(
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
        ),
      ],
    );
  }

  /// 构建搜索出错视图（区别于"无结果"，可点击重试）
  Widget _buildErrorResults(String errorMessage, String query) {
    return _searchDisabled
        ? NoDataView(
            text: t.common.searchDisabledTitle,
            description: errorMessage,
            icon: CupertinoIcons.lock,
            iconSize: 64,
          )
        : NoDataView(
            text: t.common.searchError,
            description: errorMessage,
            icon: CupertinoIcons.exclamationmark_circle,
            iconSize: 64,
            onTop: () => performSearch(query: query),
          );
  }

  Widget _buildEmptyResults(String q) {
    return NoDataView(
      text: t.common.searchNoResults,
      icon: CupertinoIcons.search,
      iconSize: 60,
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
        peerId: message.authorId,
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
        text: parseModelString(message.metadata?['text']),
        words: words,
        textStyle: context.textStyle(
          FontSizeType.normal,
          color: AppColors.iosGray,
        ),
      ),
    );
  }

  Future<void> _goToChat(String msgId) async {
    if (!_ownerActive) return;
    final generation = _searchGeneration;
    final result = _resultFacts[msgId];
    if (result == null) return;
    if (!result.isVisibleAt(DateTimeHelper.millisecond(), _ownerUid)) {
      _removeExpiredResults();
      return;
    }
    final current = await ref
        .read(ftsApiProvider)
        .refreshResultVisibility(result);
    if (!mounted || !_ownerActive || generation != _searchGeneration) return;
    if (!identical(_resultFacts[msgId], result)) return;
    if (current == null ||
        !current.isVisibleAt(DateTimeHelper.millisecond(), _ownerUid)) {
      _resultFacts.remove(msgId);
      ref.read(searchProvider.notifier).removeSearchResults({msgId});
      _removeExpiredResults();
      return;
    }
    _resultFacts[msgId] = current;
    _removeExpiredResults();
    if (!mounted) return;
    // 统一走 go_router：原生 push 的 ChatPage 内 go_router 调用会失灵
    await context.push(
      '/chat/${widget.peerId}',
      extra: {
        'type': widget.type,
        'title': widget.peerTitle,
        'avatar': widget.peerAvatar,
        'sign': widget.peerSign,
        'msg_id': msgId,
      },
    );
    if (mounted && _ownerActive && generation == _searchGeneration) {
      await _refreshResultFacts();
    }
  }

  /// 接收方可能在聊天页才开始倒计时；返回/恢复时重新读取本机事实。
  Future<void> _refreshResultFacts() async {
    if (!mounted || !_ownerActive) return;
    _removeExpiredResults();
    if (ref.read(searchProvider).isLoading) return;
    final search = _searchGeneration;
    final refresh = ++_visibilityGeneration;
    final snapshot = Map<String, MessageSearchResult>.of(_resultFacts);
    for (final item in snapshot.values) {
      final current = await ref
          .read(ftsApiProvider)
          .refreshResultVisibility(item);
      if (!mounted ||
          !_ownerActive ||
          search != _searchGeneration ||
          refresh != _visibilityGeneration) {
        return;
      }
      // 定时器可能已删除结果；晚到的回查不能将其重新放回列表。
      if (!identical(_resultFacts[item.id], item)) continue;
      if (current == null) {
        _resultFacts.remove(item.id);
        ref.read(searchProvider.notifier).removeSearchResults({item.id});
      } else {
        _resultFacts[item.id] = current;
      }
      _removeExpiredResults();
    }
  }

  void _removeExpiredResults() {
    if (!mounted || !_ownerActive) return;
    final nowMs = DateTimeHelper.millisecond();
    final expired = _resultFacts.values
        .where((item) => !item.isVisibleAt(nowMs, _ownerUid))
        .map((item) => item.id)
        .toSet();
    for (final id in expired) {
      _resultFacts.remove(id);
    }
    ref.read(searchProvider.notifier).removeSearchResults(expired);
    _resultExpiry.schedule(
      _resultFacts.values.map((item) => item.expiresAtMs(_ownerUid)),
    );
  }

  Future<void> _loadAndCacheContact(String uid) async {
    final generation = _searchGeneration;
    final contact = await ContactRepo().findByUid(uid);
    if (contact != null &&
        mounted &&
        _ownerActive &&
        generation == _searchGeneration) {
      ref.read(searchProvider.notifier).cacheContact(uid, contact);
      setState(() {});
    }
  }
}
