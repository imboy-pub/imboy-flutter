/// Web 端会话列表页面 - WhatsApp Web 风格
///
/// 功能：
/// - 左侧会话列表（可搜索）
/// - 与右侧聊天内容联动
/// - 响应式布局支持
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/conversation_model.dart';

import 'conversation_provider.dart';

/// Web 会话列表页面
class WebConversationPage extends ConsumerStatefulWidget {
  /// 选中的会话 ID（用于响应式布局）
  final String? selectedConversationId;

  const WebConversationPage({
    super.key,
    this.selectedConversationId,
  });

  @override
  ConsumerState<WebConversationPage> createState() =>
      _WebConversationPageState();
}

class _WebConversationPageState extends ConsumerState<WebConversationPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 防抖搜索
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query.toLowerCase();
      });
    });
  }

  /// 过滤会话列表
  List<ConversationModel> _filterConversations(
    List<ConversationModel> conversations,
  ) {
    if (_searchQuery.isEmpty) {
      return conversations;
    }
    return conversations.where((conv) {
      final title = conv.title.toLowerCase();
      final subtitle = conv.subtitle.toLowerCase();
      return title.contains(_searchQuery) || subtitle.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversationState = ref.watch(conversationProvider);
    final conversations = _filterConversations(conversationState.conversations);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF111B21) : const Color(0xFFFFFFFF),
      child: Column(
        children: [
          // 顶部搜索栏
          _buildSearchBar(isDark),

          // 网络状态提示
          if (conversationState.connectDesc.isNotEmpty)
            _buildNetworkTip(conversationState.connectDesc, isDark),

          // 会话列表
          Expanded(
            child: conversations.isEmpty
                ? _buildEmptyState(isDark)
                : _buildConversationList(conversations, isDark),
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: t.search,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
            size: 20,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF2A3942) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark
                        ? const Color(0xFF8696A0)
                        : const Color(0xFF667781),
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  /// 构建网络状态提示
  Widget _buildNetworkTip(String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF00A884).withAlpha(30) : const Color(0xFF00A884).withAlpha(20),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off,
            size: 16,
            color: Color(0xFF00A884),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF00A884),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(bool isDark) {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: isDark ? const Color(0xFF3B4A54) : const Color(0xFFE9EDEF),
            ),
            const SizedBox(height: 16),
            Text(
              t.searchChatRecord,
              style: TextStyle(
                color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return NoDataView(text: t.searchChatRecord);
  }

  /// 构建会话列表
  Widget _buildConversationList(
    List<ConversationModel> conversations,
    bool isDark,
  ) {
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final isSelected = widget.selectedConversationId == conversation.uk3;

        return _WebConversationItem(
          conversation: conversation,
          isSelected: isSelected,
          isDark: isDark,
          onTap: () => _onConversationTap(conversation),
        );
      },
    );
  }

  /// 处理会话点击
  void _onConversationTap(ConversationModel conversation) {
    // 根据会话类型跳转
    if (conversation.type == 'C2C') {
      context.push('/chat/${conversation.peerId}');
    } else if (conversation.type == 'C2G') {
      context.push('/group/chat/${conversation.peerId}');
    }
  }
}

/// Web 会话列表项组件
class _WebConversationItem extends StatelessWidget {
  final ConversationModel conversation;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _WebConversationItem({
    required this.conversation,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // 头像
            _buildAvatar(),
            const SizedBox(width: 12),

            // 内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行
                  _buildTitleRow(),
                  const SizedBox(height: 4),

                  // 副标题行
                  _buildSubtitleRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Avatar(imgUri: conversation.avatar);
  }

  Widget _buildTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 标题
        Expanded(
          child: Text(
            conversation.title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),

        // 时间
        const SizedBox(width: 8),
        Text(
          DateTimeHelper.lastTimeFmt(conversation.lastTime * 1000),
          style: TextStyle(
            color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitleRow() {
    return Row(
      children: [
        // 消息状态图标
        if (conversation.lastMsgStatus != null) ...[
          _buildStatusIcon(),
          const SizedBox(width: 4),
        ],

        // 副标题
        Expanded(
          child: Text(
            conversation.subtitle,
            style: TextStyle(
              color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),

        // 未读消息数
        if (conversation.unreadNum > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00A884),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 20),
            child: Text(
              conversation.unreadNum > 99
                  ? '99+'
                  : conversation.unreadNum.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon() {
    // lastMsgStatus: 10 发送中 sending; 11 已发送 send
    if (conversation.lastMsgStatus == null) return const SizedBox.shrink();

    final status = conversation.lastMsgStatus!;
    if (status == 10) {
      // 发送中
      return Icon(
        Icons.access_time,
        size: 14,
        color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
      );
    } else if (status == 11) {
      // 已发送
      return Icon(
        Icons.done,
        size: 14,
        color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
      );
    }
    return const SizedBox.shrink();
  }
}
