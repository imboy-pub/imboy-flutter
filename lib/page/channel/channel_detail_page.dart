import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:intl/intl.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'channel_provider.dart';

/// 频道详情页面
///
/// 显示频道消息列表，根据用户角色显示不同的 UI：
/// - 订阅者：查看消息、点赞/反应、取消订阅
/// - 管理员/创建者：发布消息、管理频道、置顶/删除消息
class ChannelDetailPage extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelDetailPage({super.key, required this.channelId});

  @override
  ConsumerState<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends ConsumerState<ChannelDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  ChannelStatsModel? _stats;
  final ChannelApi _api = ChannelApi();

  @override
  void initState() {
    super.initState();

    // 加载频道详情
    Future.microtask(() {
      ref
          .read(channelDetailNotifierProvider.notifier)
          .loadChannel(widget.channelId);
      _loadStats();
    });

    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadStats() async {
    final stats = await _api.getChannelStats(widget.channelId);
    if (mounted && stats != null) {
      setState(() {
        _stats = stats;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(channelDetailNotifierProvider.notifier).loadMoreMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(channelDetailNotifierProvider);
    final channel = state.channel;

    return Scaffold(
      appBar: GlassAppBar(
        title: channel?.name ?? t.channel.loading,
        automaticallyImplyLeading: true,
        rightDMActions: _buildAppBarActions(channel),
      ),
      body: _buildBody(state),
      // 管理员/创建者显示消息输入框
      bottomNavigationBar: channel?.canPublish == true
          ? _buildMessageInput(channel!)
          : null,
    );
  }

  /// 构建AppBar操作按钮
  List<Widget> _buildAppBarActions(ChannelModel? channel) {
    if (channel == null) return [];

    final isManaged = channel.isManaged;
    final isSubscribed = channel.isSubscribed;

    return [
      // 管理员显示设置按钮
      if (isManaged)
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            _showChannelSettings(channel);
          },
          tooltip: context.t.channel.settings,
        ),
      // 更多菜单
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) => _handleMenuAction(value, channel),
        itemBuilder: (context) => _buildMenuItems(isManaged, isSubscribed),
      ),
    ];
  }

  /// 构建菜单项
  List<PopupMenuEntry<String>> _buildMenuItems(
    bool isManaged,
    bool isSubscribed,
  ) {
    final t = context.t;
    final items = <PopupMenuEntry<String>>[];

    if (isManaged) {
      // 管理员菜单
      items.addAll([
        PopupMenuItem(
          value: 'edit_channel',
          child: ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(t.channel.editChannel),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'manage_admins',
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(t.channel.manageAdmins),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'manage_subscribers',
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(t.channel.manageSubscribers),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ]);
    } else if (isSubscribed) {
      // 订阅者菜单
      items.add(
        PopupMenuItem(
          value: 'unsubscribe',
          child: ListTile(
            leading: const Icon(Icons.unsubscribe_outlined),
            title: Text(t.channel.unsubscribe),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    // 通用菜单
    items.add(
      PopupMenuItem(
        value: 'share',
        child: ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(t.channel.share),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );

    return items;
  }

  /// 构建消息输入框
  Widget _buildMessageInput(ChannelModel channel) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // 附件按钮
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.grey[600]),
            onPressed: () => _pickAndSendMedia(channel),
          ),
          // 输入框
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              decoration: InputDecoration(
                hintText: context.t.channel.writeMessage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.1),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(channel),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮
          FloatingActionButton.small(
            onPressed: () => _sendMessage(channel),
            child: const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }

  /// 发送消息
  Future<void> _sendMessage(ChannelModel channel) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    final success = await ref
        .read(channelDetailNotifierProvider.notifier)
        .publishMessage(content: content, msgType: 'text');

    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.channel.publishFailed)));
    }
  }

  /// 选择并发送媒体文件
  Future<void> _pickAndSendMedia(ChannelModel channel) async {
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 9,
        requestType: RequestType.common,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );

    if (assets == null || assets.isEmpty) return;

    for (final asset in assets) {
      final file = await asset.file;
      if (file == null) continue;

      // 根据类型发送不同消息
      String msgType = 'file';
      Map<String, dynamic> payload = {
        'uri': file.path,
        'name': asset.title ?? file.path.split('/').last,
        'size': await file.length(),
      };

      if (asset.type == AssetType.image) {
        msgType = 'image';
      } else if (asset.type == AssetType.video) {
        msgType = 'video';
        // 获取视频缩略图
        payload['thumb'] = {'uri': file.path};
        payload['duration'] = asset.duration;
      }

      final success = await ref
          .read(channelDetailNotifierProvider.notifier)
          .publishMessage(
            content: asset.title ?? '',
            msgType: msgType,
            payload: payload,
          );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t.channel.publishFailed)),
        );
      }
    }
  }

  /// 显示频道设置
  void _showChannelSettings(ChannelModel channel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t.channel.settings,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.t.channel.editChannel),
                subtitle: Text(context.t.channel.editChannelDesc),
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/channel/${widget.channelId}/edit',
                    extra: channel,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(context.t.channel.manageAdmins),
                subtitle: Text(context.t.channel.manageAdminsDesc),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/channel/${widget.channelId}/admins');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(context.t.channel.manageSubscribers),
                subtitle: Text(context.t.channel.manageSubscribersDesc),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/channel/${widget.channelId}/subscribers');
                },
              ),
              if (channel.userRole.isCreator)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red[400]),
                  title: Text(
                    context.t.channel.deleteChannel,
                    style: TextStyle(color: Colors.red[400]),
                  ),
                  subtitle: Text(context.t.channel.deleteChannelDesc),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteChannelDialog(channel);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示删除频道确认对话框
  void _showDeleteChannelDialog(ChannelModel channel) {
    final t = context.t;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.channel.deleteChannel),
        content: Text(t.channel.deleteChannelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _api.deleteChannel(channel.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.channelDeleted)),
                );
                // 返回上一页
                context.pop();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.deleteChannelFailed)),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ChannelDetailState state) {
    if (state.isLoading && state.channel == null) {
      return const ShimmerList(itemCount: 6);
    }

    if (state.error != null && state.channel == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(channelDetailNotifierProvider.notifier)
                    .loadChannel(widget.channelId);
              },
              child: Text(context.t.buttonRetry),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(channelDetailNotifierProvider.notifier)
            .loadChannel(widget.channelId);
        await _loadStats();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 统计信息头部
          SliverToBoxAdapter(child: _buildStatsHeader()),
          // 消息列表
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (state.messages.isEmpty && !state.isLoading) {
                  return NoDataView(
                    icon: Icons.article_outlined,
                    text: context.t.channel.noMessages,
                  );
                }

                final message = state.messages[index];
                final showDate = _shouldShowDate(state.messages, index);

                return Column(
                  children: [
                    if (showDate) _buildDateDivider(message),
                    _ChannelMessageItem(
                      message: message,
                      channelId: widget.channelId,
                      isManaged: state.channel?.isManaged ?? false,
                      onReactionChanged: () {
                        // 刷新统计
                        _loadStats();
                      },
                    ),
                  ],
                );
              },
              childCount: state.messages.isEmpty
                  ? 1
                  : state.messages.length + (state.hasMore ? 1 : 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    if (_stats == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.people_outline,
            label: context.t.channel.subscribers,
            value: _formatNumber(_stats!.subscriberCount),
          ),
          _buildStatItem(
            icon: Icons.article_outlined,
            label: context.t.channel.messages,
            value: _formatNumber(_stats!.totalMessages),
          ),
          _buildStatItem(
            icon: Icons.remove_red_eye_outlined,
            label: context.t.channel.views,
            value: _formatNumber(_stats!.totalViews),
          ),
          _buildStatItem(
            icon: Icons.thumb_up_outlined,
            label: context.t.channel.reactions,
            value: _formatNumber(_stats!.totalReactions),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    return '${(number / 1000000).toStringAsFixed(1)}M';
  }

  bool _shouldShowDate(List<ChannelMessageModel> messages, int index) {
    if (index == 0) return true;

    final current = messages[index];
    final previous = messages[index - 1];

    final currentDate = DateTime(
      current.createdAt.year,
      current.createdAt.month,
      current.createdAt.day,
    );
    final previousDate = DateTime(
      previous.createdAt.year,
      previous.createdAt.month,
      previous.createdAt.day,
    );

    return currentDate != previousDate;
  }

  Widget _buildDateDivider(ChannelMessageModel message) {
    final now = DateTime.now();
    final messageDate = message.createdAt;
    final diff = now.difference(messageDate);

    String dateText;
    if (diff.inDays == 0) {
      dateText = context.t.channel.today;
    } else if (diff.inDays == 1) {
      dateText = context.t.channel.yesterday;
    } else if (diff.inDays < 7) {
      dateText = '${diff.inDays} ${context.t.channel.daysAgo}';
    } else {
      dateText = DateFormat('yyyy-MM-dd').format(messageDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, ChannelModel? channel) {
    final t = context.t;

    switch (action) {
      case 'unsubscribe':
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.channel.unsubscribeConfirm),
            content: Text(t.channel.unsubscribeConfirmDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.cancel),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await ref
                      .read(channelListNotifierProvider.notifier)
                      .unsubscribeChannel(widget.channelId);
                  if (success && mounted) {
                    context.pop();
                  }
                },
                child: Text(t.confirm),
              ),
            ],
          ),
        );
        break;
      case 'share':
        _shareChannel(channel);
        break;
      case 'edit_channel':
        context.push('/channel/${widget.channelId}/edit', extra: channel);
        break;
      case 'manage_admins':
        context.push('/channel/${widget.channelId}/admins');
        break;
      case 'manage_subscribers':
        context.push('/channel/${widget.channelId}/subscribers');
        break;
    }
  }

  /// 分享频道
  void _shareChannel(ChannelModel? channel) {
    if (channel == null) return;

    final t = context.t;
    final shareLink = 'https://imboy.pub/channel/${channel.id}';

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                channel.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(t.channel.share),
              subtitle: Text(shareLink),
              onTap: () {
                Clipboard.setData(ClipboardData(text: shareLink));
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(t.copiedToClipboard)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: Text(t.myQrcode),
              onTap: () {
                Navigator.pop(context);
                context.push(
                  '/qrcode/channel',
                  extra: {
                    'id': channel.id,
                    'name': channel.name,
                    'avatar': channel.avatar,
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: Text(t.channel.shareToChat),
              onTap: () {
                Navigator.pop(context);
                // 跳转到选择好友页面转发频道链接
                context.push(
                  '/chat/send_to',
                  extra: {
                    'msg': {
                      'msg_type': 'channel_card',
                      'content': channel.name,
                      'payload': {
                        'channel_id': channel.id,
                        'channel_name': channel.name,
                        'channel_avatar': channel.avatar,
                        'subscriber_count': channel.subscriberCount,
                      },
                    },
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 频道消息项
class _ChannelMessageItem extends StatelessWidget {
  final ChannelMessageModel message;
  final String channelId;
  final bool isManaged;
  final VoidCallback? onReactionChanged;

  const _ChannelMessageItem({
    required this.message,
    required this.channelId,
    this.isManaged = false,
    this.onReactionChanged,
  });

  Future<void> _addReaction(BuildContext context, String reactionType) async {
    final api = ChannelApi();
    final success = await api.addReaction(
      channelId: channelId,
      messageId: message.id,
      reactionType: reactionType,
    );
    if (success && context.mounted) {
      onReactionChanged?.call();
    }
  }

  /// 移除消息反应
  /// TODO: 实现长按已添加的表情来移除功能
  // ignore: unused_element
  Future<void> _removeReaction(
    BuildContext context,
    String reactionType,
  ) async {
    final api = ChannelApi();
    final success = await api.removeReaction(
      channelId: channelId,
      messageId: message.id,
      reactionType: reactionType,
    );
    if (success && context.mounted) {
      onReactionChanged?.call();
    }
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t.channel.selectReaction,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(context, ChannelReactionType.like, '👍'),
                _buildReactionButton(context, ChannelReactionType.heart, '❤️'),
                _buildReactionButton(context, ChannelReactionType.fire, '🔥'),
                _buildReactionButton(
                  context,
                  ChannelReactionType.thumbsUp,
                  '👏',
                ),
                _buildReactionButton(
                  context,
                  ChannelReactionType.bookmark,
                  '📌',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(BuildContext context, String type, String emoji) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _addReaction(context, type);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者信息
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage:
                    message.authorAvatar != null &&
                        message.authorAvatar!.isNotEmpty
                    ? cachedImageProvider(message.authorAvatar!, w: 64)
                    : null,
                child:
                    message.authorAvatar == null ||
                        message.authorAvatar!.isEmpty
                    ? Text(
                        message.authorName != null &&
                                message.authorName!.isNotEmpty
                            ? message.authorName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          message.authorName ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        // 管理员标签
                        if (isManaged) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              context.t.channel.admin,
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (message.isPinned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, size: 12, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        context.t.channel.pinned,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              // 管理员操作菜单
              if (isManaged)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onSelected: (value) => _handleMessageAction(value, context),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: message.isPinned ? 'unpin' : 'pin',
                      child: ListTile(
                        leading: Icon(
                          message.isPinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin,
                          size: 20,
                        ),
                        title: Text(
                          message.isPinned
                              ? context.t.channel.unpinMessage
                              : context.t.channel.pinMessage,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red[400],
                        ),
                        title: Text(
                          context.t.channel.deleteMessage,
                          style: TextStyle(color: Colors.red[400]),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 消息内容
          _buildMessageContent(context),
          const SizedBox(height: 8),
          // 统计和反应
          Row(
            children: [
              // 阅读量
              Icon(
                Icons.remove_red_eye_outlined,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                '${message.viewCount}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(width: 16),
              // 反应按钮
              GestureDetector(
                onTap: () => _showReactionPicker(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.thumb_up_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.t.channel.react,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // 显示反应统计
              if (message.reactionSummary != null &&
                  message.reactionSummary!.isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildReactionSummary(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 处理消息操作
  Future<void> _handleMessageAction(String action, BuildContext context) async {
    switch (action) {
      case 'pin':
        await _setPinned(context, true);
        break;
      case 'unpin':
        await _setPinned(context, false);
        break;
      case 'delete':
        _showDeleteMessageDialog(context);
        break;
    }
  }

  /// 设置消息置顶状态
  Future<void> _setPinned(BuildContext context, bool pinned) async {
    final api = ChannelApi();
    final success = await api.setMessagePinned(channelId, message.id, pinned);
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pinned
                ? context.t.channel.messagePinned
                : context.t.channel.messageUnpinned,
          ),
        ),
      );
      onReactionChanged?.call();
    }
  }

  /// 显示删除消息确认对话框
  void _showDeleteMessageDialog(BuildContext context) {
    final t = context.t;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.channel.deleteMessage),
        content: Text(t.channel.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // TODO: 实现删除消息
              final api = ChannelApi();
              final success = await api.deleteMessage(channelId, message.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.messageDeleted)),
                );
                onReactionChanged?.call();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionSummary() {
    final summary = message.reactionSummary!;
    final List<Widget> reactionWidgets = [];

    summary.forEach((type, count) {
      final emoji = ChannelReactionType.getIcon(type);
      reactionWidgets.add(
        Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$emoji $count', style: const TextStyle(fontSize: 11)),
        ),
      );
    });

    return Row(children: reactionWidgets);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MM-dd HH:mm').format(time);
    }
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.msgType) {
      case 'image':
        return _buildImageContent(context);
      case 'video':
        return _buildVideoContent(context);
      case 'file':
        return _buildFileContent();
      default:
        return _buildTextContent();
    }
  }

  Widget _buildTextContent() {
    return SelectableText(
      message.content,
      style: const TextStyle(fontSize: 15, height: 1.5),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final payload = message.payload;
    final uri = payload?['uri'] as String?;

    if (uri == null) return _buildTextContent();

    return GestureDetector(
      onTap: () {
        // 打开图片查看器
        zoomInPhotoView(context, uri);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image(
          image: cachedImageProvider(uri, w: 400),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    final payload = message.payload;
    final thumb = payload?['thumb']?['uri'] as String?;
    final videoUri = payload?['uri'] as String?;

    return GestureDetector(
      onTap: () {
        // 打开视频播放器
        if (videoUri != null) {
          context.push(
            '/video_viewer?url=${Uri.encodeComponent(videoUri)}&thumb=${Uri.encodeComponent(thumb ?? '')}',
          );
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (thumb != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(
                image: cachedImageProvider(thumb, w: 400),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent() {
    final payload = message.payload;
    final name = payload?['name'] as String? ?? '文件';
    final size = payload?['size'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: Colors.grey[600], size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatFileSize(size),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Icon(Icons.download, color: Colors.grey[600]),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
