import 'dart:async';
import 'dart:io';
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
import 'package:imboy/store/model/channel_order_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'channel_detail_rules.dart';
import 'channel_provider.dart';

/// 频道详情页面
///
/// 显示频道消息列表，根据用户角色显示不同的 UI：
/// - 订阅者：查看消息、点赞/反应、取消订阅
/// - 管理员/创建者：发布消息、管理频道、置顶/删除消息
class ChannelDetailPage extends ConsumerStatefulWidget {
  final String channelId;
  final bool autoLoadStats;

  const ChannelDetailPage({
    super.key,
    required this.channelId,
    this.autoLoadStats = true,
  });

  @override
  ConsumerState<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends ConsumerState<ChannelDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  ChannelStatsModel? _stats;
  final ChannelService _channelService = ChannelService.to;
  bool _isUploadingMedia = false;
  bool _isPaying = false;
  bool _isLoadingStats = false;
  String? _statsRequestedChannelId;

  @override
  void initState() {
    super.initState();

    // 加载频道详情
    Future.microtask(() {
      ref.read(channelDetailProvider.notifier).loadChannel(widget.channelId);
    });

    _scrollController.addListener(_onScroll);
  }

  String _resolveChannelId([ChannelModel? channel]) {
    final id = channel?.id;
    if (id != null && id != 0) return id.toString();
    return widget.channelId;
  }

  Future<void> _loadStats([String? channelId]) async {
    if (_isLoadingStats) return;
    final id = (channelId != null && channelId.isNotEmpty)
        ? channelId
        : widget.channelId;
    _isLoadingStats = true;
    try {
      final stats = await _channelService.getChannelStats(id);
      if (mounted && stats != null) {
        setState(() {
          _stats = stats;
        });
      }
    } finally {
      _isLoadingStats = false;
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
      ref.read(channelDetailProvider.notifier).loadMoreMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(channelDetailProvider);
    final channel = state.channel;
    if (widget.autoLoadStats &&
        channel != null &&
        (_stats == null || _stats!.channelId != channel.id) &&
        _statsRequestedChannelId != channel.id.toString()) {
      _statsRequestedChannelId = channel.id.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadStats(channel.id.toString());
      });
    }

    return Scaffold(
      appBar: GlassAppBar(
        title: channel?.name ?? t.channel.loading,
        automaticallyImplyLeading: true,
        rightDMActions: _buildAppBarActions(channel),
      ),
      body: _buildBody(state),
      // 管理员/创建者显示消息输入框
      bottomNavigationBar: channel?.canPublish == true
          ? _buildMessageInput(
              channel!,
              state.isPublishing || _isUploadingMedia,
            )
          : null,
    );
  }

  /// 构建AppBar操作按钮
  List<Widget> _buildAppBarActions(ChannelModel? channel) {
    if (channel == null) return [];

    final isManaged = channel.isManaged;

    return [
      if (channel.canPublish)
        IconButton(
          icon: const Icon(Icons.campaign_outlined),
          onPressed: _focusPublishInput,
          tooltip: context.t.publish,
        ),
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
        itemBuilder: (context) => _buildMenuItems(channel),
      ),
    ];
  }

  /// 构建菜单项

  List<PopupMenuEntry<String>> _buildMenuItems(ChannelModel channel) {
    final t = context.t;
    final isManaged = channel.isManaged;
    final isSubscribed = channel.isSubscribed;
    final canPublish = channel.canPublish;
    final invitationEnabled = AppFeatureRegistry.isEnabled(
      'channel_invitation',
    );
    final orderEnabled = AppFeatureRegistry.isEnabled('channel_order');
    final items = <PopupMenuEntry<String>>[];

    if (canPublish) {
      items.add(
        PopupMenuItem(
          value: 'publish',
          child: ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(t.publish),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    if (isManaged) {
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

    if (invitationEnabled) {
      items.add(
        PopupMenuItem(
          value: 'invitation_center',
          child: ListTile(
            leading: const Icon(Icons.mark_email_unread_outlined),
            title: Text(t.channelInvitations),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }
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
    if (channel.type == ChannelType.paid && orderEnabled) {
      items.add(
        PopupMenuItem(
          value: 'my_orders',
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(t.myOrders),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
    }

    return items;
  }

  void _focusPublishInput() {
    if (!_messageFocusNode.canRequestFocus) return;
    _messageFocusNode.requestFocus();
  }

  /// 构建消息输入框
  Widget _buildMessageInput(ChannelModel channel, bool isBusy) {
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
            onPressed: isBusy ? null : () => _pickAndSendMedia(channel),
          ),
          // 输入框
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              enabled: !isBusy,
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
              onSubmitted: (_) {
                if (!isBusy) {
                  _sendMessage(channel);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮
          FloatingActionButton.small(
            onPressed: isBusy ? null : () => _sendMessage(channel),
            child: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }

  /// 发送消息
  Future<void> _sendMessage(ChannelModel channel) async {
    if (ref.read(channelDetailProvider).isPublishing || _isUploadingMedia) {
      return;
    }
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final success = await ref
        .read(channelDetailProvider.notifier)
        .publishMessage(content: content, msgType: ChannelMessageType.text);

    if (success) {
      if (mounted) {
        _messageController.clear();
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t.channel.publishFailed)),
      );
    }
  }

  /// 选择并发送媒体文件
  Future<void> _pickAndSendMedia(ChannelModel channel) async {
    if (ref.read(channelDetailProvider).isPublishing || _isUploadingMedia) {
      return;
    }
    if (mounted) {
      setState(() => _isUploadingMedia = true);
    }

    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 9,
        requestType: RequestType.common,
        textDelegate: const EnglishAssetPickerTextDelegate(),
      ),
    );

    if (assets == null || assets.isEmpty) {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
      return;
    }

    try {
      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        // 根据类型发送不同消息
        String msgType = ChannelMessageType.file;
        String uploadPrefix = 'files';
        Map<String, dynamic> payload = {
          'name': asset.title ?? file.path.split('/').last,
          'size': await file.length(),
        };

        if (asset.type == AssetType.image) {
          msgType = ChannelMessageType.image;
          uploadPrefix = 'img';
        } else if (asset.type == AssetType.video) {
          msgType = ChannelMessageType.video;
          uploadPrefix = 'camera';
          payload['duration'] = asset.duration;
        }

        final uploadedUri = await _uploadChannelFile(
          file,
          prefix: uploadPrefix,
        );
        if (!mounted) return;
        if (uploadedUri == null || uploadedUri.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.t.uploadFailed)));
          continue;
        }

        payload['uri'] = uploadedUri;
        if (msgType == ChannelMessageType.video) {
          final thumbData = await asset.thumbnailDataWithSize(
            const ThumbnailSize(480, 480),
            quality: 75,
          );
          final thumbUri = thumbData == null
              ? null
              : await _uploadChannelBytes(
                  thumbData,
                  prefix: uploadPrefix,
                  path: 'thumb.jpg',
                );
          if (thumbUri != null && thumbUri.isNotEmpty) {
            payload['thumb'] = {'uri': thumbUri};
          } else {
            payload['thumb'] = {'uri': ''};
          }
        }

        final fileName = asset.title ?? file.path.split('/').last;
        final content = (fileName).trim().isEmpty ? '[media]' : fileName;

        final success = await ref
            .read(channelDetailProvider.notifier)
            .publishMessage(
              content: content,
              msgType: msgType,
              payload: payload,
            );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t.channel.publishFailed)),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingMedia = false);
      }
    }
  }

  Future<String?> _uploadChannelBytes(
    Uint8List file, {
    required String prefix,
    String path = 'file.jpg',
  }) async {
    String? uploadedUrl;
    final completer = Completer<bool>();

    await AttachmentApi.uploadBytes(
      prefix,
      file,
      (Map<String, dynamic> resp, String url) {
        if (completer.isCompleted) return;
        final status = resp['status']?.toString() ?? '';
        if (status == 'ok') {
          uploadedUrl = url;
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      },
      (_) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      path: path,
      process: false,
    );

    final success = await completer.future;
    if (!success) return null;
    return uploadedUrl;
  }

  Future<String?> _uploadChannelFile(
    File file, {
    required String prefix,
  }) async {
    String? uploadedUrl;
    final completer = Completer<bool>();

    await AttachmentApi.uploadFile(
      prefix,
      file,
      (Map<String, dynamic> resp, String url) {
        if (completer.isCompleted) return;
        final status = resp['status']?.toString() ?? '';
        if (status == 'ok') {
          uploadedUrl = url;
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      },
      (_) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      process: true,
    );

    final success = await completer.future;
    if (!success) return null;
    return uploadedUrl;
  }

  /// 显示频道设置
  void _showChannelSettings(ChannelModel channel) {
    final channelId = _resolveChannelId(channel);
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
                onTap: () async {
                  Navigator.pop(context);
                  await _openChannelEdit(channel);
                },
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(context.t.channel.manageAdmins),
                subtitle: Text(context.t.channel.manageAdminsDesc),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/channel/$channelId/admins');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(context.t.channel.manageSubscribers),
                subtitle: Text(context.t.channel.manageSubscribersDesc),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/channel/$channelId/subscribers');
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
              final success = await _channelService.deleteChannel(channel.id.toString());
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
                final channel = ref.read(channelDetailProvider).channel;
                final reloadId = _resolveChannelId(channel);
                ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
              },
              child: Text(context.t.buttonRetry),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final reloadId = _resolveChannelId(state.channel);
        await ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
        _statsRequestedChannelId = null;
        await _loadStats(reloadId);
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 统计信息头部
          SliverToBoxAdapter(child: _buildStatsHeader()),
          if (_isPaidChannelLocked(state.channel))
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildPaidLockedView(state.channel!),
            )
          else
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
                        channelId: _resolveChannelId(state.channel),
                        isManaged: state.channel?.isManaged ?? false,
                        onReactionChanged: () {
                          // 刷新统计
                          _loadStats(_resolveChannelId(state.channel));
                        },
                        onPinned: (pinned) {
                          ref
                              .read(channelDetailProvider.notifier)
                              .updateMessagePinned(message.id.toString(), pinned);
                        },
                        onDeleted: () {
                          ref
                              .read(channelDetailProvider.notifier)
                              .removeMessageLocally(message.id.toString());
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

  bool _isPaidChannelLocked(ChannelModel? channel) =>
      isPaidChannelLocked(channel);

  Widget _buildPaidLockedView(ChannelModel channel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.paidChannelLocked,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                t.purchaseUnlockHint,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isPaying
                          ? null
                          : () => _buyAndUnlock(channel),
                      icon: _isPaying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.shopping_cart_checkout_outlined),
                      label: Text(_isPaying ? t.payingDots : t.purchaseAndUnlock),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _showMyOrdersSheet(channel.id.toString()),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(t.myOrders),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyAndUnlock(ChannelModel channel) async {
    if (_isPaying) return;
    final channelId = _resolveChannelId(channel);

    setState(() {
      _isPaying = true;
    });

    try {
      final order = await ChannelService.to.createAndPayOrder(channelId);
      if (!mounted) return;

      if (order == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.purchaseFailed)));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.purchaseSuccess)));

      await ref.read(channelListProvider.notifier).loadSubscribedChannels();
      await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
      _statsRequestedChannelId = null;
      await _loadStats(channelId);
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  Future<void> _showMyOrdersSheet(String channelId) async {
    final allOrders = await ChannelService.to.getMyOrders();
    if (!mounted) return;

    final orders = allOrders.where((o) => o.channelId.toString() == channelId).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.62,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                t.myOrders,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: orders.isEmpty
                    ? Center(child: Text(t.noOrders))
                    : ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return ListTile(
                            title: Text(order.orderNo),
                            subtitle: Text(
                              '${order.currency} ${order.amount.toStringAsFixed(2)} · '
                              '${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)}',
                            ),
                            trailing: Text(
                              _orderStatusLabel(order.status),
                              style: TextStyle(
                                color: _orderStatusColor(order.status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _showOrderDetail(order.orderNo),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOrderDetail(String orderNo) async {
    final order = await ChannelService.to.getOrder(orderNo);
    if (!mounted) return;

    if (order == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.orderDetailLoadFailed)));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.orderDetail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.orderNoLabel(no: order.orderNo)),
            const SizedBox(height: 6),
            Text(t.orderStatusLabel(status: _orderStatusLabel(order.status))),
            const SizedBox(height: 6),
            Text(t.orderAmountLabel(currency: order.currency, amount: order.amount.toStringAsFixed(2))),
            const SizedBox(height: 6),
            Text(
              t.orderCreatedAtLabel(time: DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt)),
            ),
            if (order.paymentAt != null) ...[
              const SizedBox(height: 6),
              Text(
                t.orderPaymentAtLabel(time: DateFormat('yyyy-MM-dd HH:mm:ss').format(order.paymentAt!)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t.confirm),
          ),
        ],
      ),
    );
  }

  String _orderStatusLabel(int status) {
    switch (status) {
      case ChannelOrderStatus.pending:
        return t.orderStatusPending;
      case ChannelOrderStatus.paid:
        return t.orderStatusPaid;
      case ChannelOrderStatus.refunded:
        return t.orderStatusRefunded;
      case ChannelOrderStatus.cancelled:
        return t.orderStatusCancelled;
      case ChannelOrderStatus.expired:
        return t.orderStatusExpired;
      default:
        return t.orderStatusUnknown;
    }
  }

  Color _orderStatusColor(int status) {
    switch (status) {
      case ChannelOrderStatus.paid:
        return Colors.green;
      case ChannelOrderStatus.pending:
        return Colors.orange;
      case ChannelOrderStatus.refunded:
      case ChannelOrderStatus.cancelled:
      case ChannelOrderStatus.expired:
        return Colors.grey;
      default:
        return Colors.grey;
    }
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

  String _formatNumber(int number) => formatChannelNumber(number);

  bool _shouldShowDate(List<ChannelMessageModel> messages, int index) =>
      shouldShowDateDivider(messages, index);

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
            borderRadius: AppRadius.borderRadiusMedium,
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
    final channelId = _resolveChannelId(channel);

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
                      .read(channelListProvider.notifier)
                      .unsubscribeChannel(channelId);
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
      case 'publish':
        _focusPublishInput();
        break;
      case 'share':
        _shareChannel(channel);
        break;
      case 'invitation_center':
        if (!AppFeatureRegistry.isEnabled('channel_invitation')) {
          break;
        }
        context.push('/channel/invitations');
        break;
      case 'my_orders':
        if (!AppFeatureRegistry.isEnabled('channel_order')) {
          break;
        }
        _showMyOrdersSheet(channelId);
        break;
      case 'edit_channel':
        if (channel != null) {
          _openChannelEdit(channel);
        }
        break;
      case 'manage_admins':
        context.push('/channel/$channelId/admins');
        break;
      case 'manage_subscribers':
        final invitationEnabled = AppFeatureRegistry.isEnabled(
          'channel_invitation',
        );
        final isPrivate = channel?.type == ChannelType.private;
        context.push(
          '/channel/$channelId/subscribers',
          extra: {
            'canInvite': invitationEnabled && isPrivate,
          },
        );
        break;
    }
  }

  Future<void> _openChannelEdit(ChannelModel channel) async {
    final channelId = _resolveChannelId(channel);
    final result = await context.push(
      '/channel/$channelId/edit',
      extra: channel,
    );
    if (!mounted) return;
    if (result == null || result == false) return;

    final reloadId = result is ChannelModel && result.id != 0
        ? result.id.toString()
        : _resolveChannelId(result is ChannelModel ? result : channel);

    await ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
    _statsRequestedChannelId = null;
    await _loadStats(reloadId);
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
  final ValueChanged<bool>? onPinned;
  final VoidCallback? onDeleted;

  const _ChannelMessageItem({
    required this.message,
    required this.channelId,
    this.isManaged = false,
    this.onReactionChanged,
    this.onPinned,
    this.onDeleted,
  });

  Future<void> _addReaction(BuildContext context, String reactionType) async {
    final success = await ChannelService.to.addReaction(
      channelId: channelId,
      messageId: message.id.toString(),
      reactionType: reactionType,
    );
    if (success && context.mounted) {
      onReactionChanged?.call();
    }
  }

  /// 移除消息反应（通过长按反应标签触发）
  Future<void> _removeReaction(
    BuildContext context,
    String reactionType,
  ) async {
    final success = await ChannelService.to.removeReaction(
      channelId: channelId,
      messageId: message.id.toString(),
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
                    borderRadius: AppRadius.borderRadiusTiny,
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
                _buildReactionSummary(context),
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
    final success = await ChannelService.to.setMessagePinned(
      channelId,
      message.id.toString(),
      pinned,
    );
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
      onPinned?.call(pinned);
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
              final success = await ChannelService.to.deleteMessage(
                channelId,
                message.id.toString(),
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.messageDeleted)),
                );
                onReactionChanged?.call();
                onDeleted?.call();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
  }

  /// 构建反应摘要（支持长按移除自己的反应）
  Widget _buildReactionSummary(BuildContext context) {
    final summary = message.reactionSummary!;
    final List<Widget> reactionWidgets = [];

    summary.forEach((type, count) {
      final emoji = ChannelReactionType.getIcon(type);
      reactionWidgets.add(
        GestureDetector(
          onLongPress: () => _showRemoveReactionDialog(context, type),
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderRadiusCell,
            ),
            child: Text('$emoji $count', style: const TextStyle(fontSize: 11)),
          ),
        ),
      );
    });

    return Row(children: reactionWidgets);
  }

  /// 显示移除反应确认对话框
  void _showRemoveReactionDialog(BuildContext context, String reactionType) {
    final emoji = ChannelReactionType.getIcon(reactionType);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.removeReaction),
        content: Text(t.removeReactionConfirm(emoji: emoji)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeReaction(context, reactionType);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.t.confirm),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return formatMessageTime(time);
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.msgType) {
      case ChannelMessageType.image:
      case 'image':
        return _buildImageContent(context);
      case ChannelMessageType.video:
      case 'video':
        return _buildVideoContent(context);
      case ChannelMessageType.file:
      case 'file':
        return _buildFileContent(context);
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
        borderRadius: AppRadius.borderRadiusSmall,
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
    String? thumb;
    final dynamic thumbRaw = payload?['thumb'];
    if (thumbRaw is String) {
      thumb = thumbRaw;
    } else if (thumbRaw is Map) {
      thumb = thumbRaw['uri']?.toString();
    }
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
          if (thumb != null && thumb.isNotEmpty)
            ClipRRect(
              borderRadius: AppRadius.borderRadiusSmall,
              child: Image(
                image: cachedImageProvider(thumb, w: 400),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: AppRadius.borderRadiusSmall,
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

  Widget _buildFileContent(BuildContext context) {
    final payload = message.payload;
    final name = payload?['name'] as String? ?? t.defaultFileName;
    final size = payload?['size'] as int? ?? 0;
    final uri = payload?['uri']?.toString();

    return InkWell(
      onTap: (uri == null || uri.isEmpty)
          ? null
          : () async {
              await _openFile(context, uri);
            },
      borderRadius: AppRadius.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderRadiusSmall,
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
      ),
    );
  }

  Future<void> _openFile(BuildContext context, String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.fileUrlInvalid)));
      return;
    }
    if (!await canLaunchUrl(parsed)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.fileOpenFailed)));
      return;
    }
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  String _formatFileSize(int bytes) => formatFileSize(bytes);
}
