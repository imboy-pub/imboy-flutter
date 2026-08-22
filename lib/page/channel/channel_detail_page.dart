import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/helper/func.dart';

import 'channel_detail_rules.dart';
import 'channel_provider.dart';
import 'widgets/channel_header_bar.dart';
import 'widgets/channel_message_feed.dart';
import 'widgets/channel_publish_bar.dart';
import 'paid/channel_paywall_view.dart';

/// 频道详情页（壳页面）
///
/// 重构后只负责：路由参数解析、Provider 编排、角色路由分发。
/// 具体渲染委托给：
/// - [ChannelHeaderBar] 头部封面+统计
/// - [ChannelMessageFeed] 消息流
/// - [ChannelPublishBar] 发布栏
/// - [ChannelPaywallView] 付费锁定视图
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
  final FocusNode _publishFocusNode = FocusNode();
  late final ChannelService _channelService = ChannelService.to;

  ChannelStatsModel? _stats;
  bool _isLoadingStats = false;
  String? _pendingStatsChannelId;
  String? _statsRequestedChannelId;
  ProviderSubscription<ChannelDetailState>? _markReadSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(channelDetailProvider.notifier).loadChannel(widget.channelId);
    });

    // 消息首次加载后自动清零未读
    _markReadSub = ref.listenManual<ChannelDetailState>(channelDetailProvider, (
      prev,
      next,
    ) {
      final wasEmpty = prev?.messages.isEmpty ?? true;
      if (wasEmpty && next.messages.isNotEmpty) {
        final latestId = next.messages.first.id.toString();
        ref.read(channelDetailProvider.notifier).markAsRead(latestId);
        _markReadSub?.close();
        _markReadSub = null;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _publishFocusNode.dispose();
    _markReadSub?.close();
    super.dispose();
  }

  String _resolveChannelId([ChannelModel? channel]) {
    final id = channel?.id;
    if (id != null && id != 0) return id.toString();
    return widget.channelId;
  }

  Future<void> _loadStats([String? channelId]) async {
    final id = (channelId != null && channelId.isNotEmpty)
        ? channelId
        : widget.channelId;
    if (_isLoadingStats) {
      // 发布、点赞和订阅可能在首轮统计请求未完成时同时触发；记住最后
      // 一个目标，首轮结束后补一次权威刷新，避免把“请求被跳过”误当成已同步。
      _pendingStatsChannelId = id;
      return;
    }
    _isLoadingStats = true;
    try {
      final stats = await _channelService.getChannelStats(id);
      if (mounted && stats != null) {
        setState(() => _stats = stats);
      }
    } catch (_) {
      // 统计是辅助信息，失败不应打断内容流；保留已有统计并等待后续刷新。
    } finally {
      _isLoadingStats = false;
      final pendingId = _pendingStatsChannelId;
      _pendingStatsChannelId = null;
      if (pendingId != null && mounted) {
        unawaited(_loadStats(pendingId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(channelDetailProvider);
    final channel = state.channel;

    // 自动加载统计
    if (widget.autoLoadStats &&
        channel != null &&
        (_stats == null || _stats!.channelId != channel.id) &&
        _statsRequestedChannelId != channel.id.toString()) {
      _statsRequestedChannelId = channel.id.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadStats(channel.id.toString());
      });
    }

    final channelId = _resolveChannelId(channel);

    // 计算感知的背景色，使内容区与底部的灰色发布栏拉开对比
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBgColor = isDark
        ? AppColors
              .darkBackground // 暗色下用纯黑背景
        : AppColors.lightSurface; // 亮色下用纯白背景

    return Scaffold(
      backgroundColor: scaffoldBgColor, // 设置背景色以拉开层次
      appBar: GlassAppBar(
        titleWidget: channel != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      channel.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: FontSizeType.large.size,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (channel.isManaged) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (channel.userRole == ChannelUserRole.creator
                                    ? AppColors.primary
                                    : channel.userRole == ChannelUserRole.admin
                                    ? AppColors.iosOrange
                                    : AppColors.iosBlue)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'zh'
                            ? (channel.userRole == ChannelUserRole.creator
                                  ? '创建者'
                                  : channel.userRole == ChannelUserRole.admin
                                  ? '管理员'
                                  : '编辑')
                            : (channel.userRole == ChannelUserRole.creator
                                  ? 'Creator'
                                  : channel.userRole == ChannelUserRole.admin
                                  ? 'Admin'
                                  : 'Editor'),
                        style: TextStyle(
                          fontSize: FontSizeType.tiny.size,
                          fontWeight: FontWeight.bold,
                          color: channel.userRole == ChannelUserRole.creator
                              ? AppColors.primary
                              : channel.userRole == ChannelUserRole.admin
                              ? AppColors.iosOrange
                              : AppColors.iosBlue,
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : null,
        title: channel?.name ?? t.channel.loading,
        automaticallyImplyLeading: true,
        rightDMActions: _buildAppBarActions(channel),
      ),
      // 发布栏必须在 body 内（而非 bottomNavigationBar）：Flutter 的
      // _ScaffoldLayout 把 bottomNavigationBar 定位在整屏底部（bottom =
      // size.height），只有 body 会按 minInsets 内缩，键盘一弹发布栏就被压在
      // 键盘下面「消失」。放进 Column 尾部后随 body 一起被顶起，粘在键盘上沿。
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: _buildBody(state),
            ),
          ),
          if (channel?.canPublish == true)
            ChannelPublishBar(
              focusNode: _publishFocusNode,
              onMessageSent: () => _loadStats(channelId),
            ),
        ],
      ),
    );
  }

  // ---- AppBar ----

  List<Widget> _buildAppBarActions(ChannelModel? channel) {
    if (channel == null) return [];

    return [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceContainerHighest
            : AppColors.lightSurface,
        elevation: 8.0,
        offset: const Offset(0, 48), // Float elegantly below the app bar
        onSelected: (value) => _handleMenuAction(value, channel),
        itemBuilder: (context) => _buildMenuItems(channel),
      ),
    ];
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String text,
    Color? iconColor,
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        iconColor ??
        (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final effectiveTextColor =
        textColor ??
        (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      height: 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: effectiveIconColor),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: FontSizeType.medium.size,
              fontWeight: FontWeight.w400,
              color: effectiveTextColor,
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(ChannelModel channel) {
    final t = context.t;
    final items = <PopupMenuEntry<String>>[];
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';

    if (channel.isManaged) {
      // 1. Channel Info / 频道信息
      items.add(
        _buildPopupMenuItem(
          value: 'show_channel_info',
          icon: Icons.info_outline,
          text: isChinese ? '频道信息' : 'Channel Info',
        ),
      );

      // 2. Share / 分享
      items.add(
        _buildPopupMenuItem(
          value: 'share',
          icon: CupertinoIcons.share,
          text: isChinese ? '分享' : t.channel.share,
        ),
      );

      // 3. Invite Admins / 邀请管理员
      items.add(
        _buildPopupMenuItem(
          value: 'manage_admins',
          icon: Icons.add,
          text: isChinese ? '邀请管理员' : 'Invite Admins',
        ),
      );

      // 4. Channel Settings / 频道设置
      items.add(
        _buildPopupMenuItem(
          value: 'edit_channel',
          icon: Icons.settings_outlined,
          text: isChinese ? '频道设置' : 'Channel Settings',
        ),
      );
    } else {
      // Normal subscriber / visitor view
      // 1. Channel Info
      items.add(
        _buildPopupMenuItem(
          value: 'show_channel_info',
          icon: Icons.info_outline,
          text: isChinese ? '频道信息' : 'Channel Info',
        ),
      );

      // 2. Share
      items.add(
        _buildPopupMenuItem(
          value: 'share',
          icon: CupertinoIcons.share,
          text: isChinese ? '分享' : t.channel.share,
        ),
      );

      // 3. Unsubscribe
      if (channel.isSubscribed) {
        items.add(
          _buildPopupMenuItem(
            value: 'unsubscribe',
            icon: CupertinoIcons.bell_slash,
            text: t.channel.unsubscribe,
          ),
        );
      }

      // 4. My Orders
      if (channel.type == ChannelType.paid &&
          AppFeatureRegistry.isEnabled(FeatureKeys.channelOrder)) {
        items.add(
          _buildPopupMenuItem(
            value: 'my_orders',
            icon: CupertinoIcons.doc_plaintext,
            text: t.main.myOrders,
          ),
        );
      }
    }

    return items;
  }

  // ---- Body（角色路由）----

  Widget _buildBody(ChannelDetailState state) {
    // 加载中
    if (state.isLoading && state.channel == null) {
      return const ShimmerList(itemCount: 6);
    }
    // 错误
    if (state.error != null && state.channel == null) {
      return _buildErrorView(state.error!);
    }

    final channelId = _resolveChannelId(state.channel);

    return CustomScrollView(
      controller: _scrollController,
      // 下滑即收键盘（微信手感）：GestureDetector 只吃 onTap，列表滑动吞掉手势后
      // 键盘赖着不走，这里交给框架内建行为处理拖拽收起。
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        // 头部信息 + 统计
        if (state.channel != null)
          SliverToBoxAdapter(
            child: ChannelHeaderBar(
              channel: state.channel!,
              stats: _stats,
              isActionPending: _subscribeActionBusy,
              onActionTap: () => _handleSubscribeAction(state.channel!),
              onShareTap: () => _shareChannel(state.channel),
              onForwardTap: () {
                if (state.channel != null) {
                  context.push(
                    '/chat/send_to',
                    extra: {
                      'msg': {
                        'msg_type': 'channel_card',
                        'content': state.channel!.name,
                        'payload': {
                          'channel_id': state.channel!.id,
                          'channel_name': state.channel!.name,
                          'channel_avatar': state.channel!.avatar,
                          'subscriber_count': state.channel!.subscriberCount,
                        },
                      },
                    },
                  );
                }
              },
              onManageTap: () => _openChannelEdit(state.channel!),
            ),
          ),
        // 付费锁定 vs 消息流
        if (isPaidChannelLocked(state.channel))
          SliverFillRemaining(
            hasScrollBody: false,
            child: ChannelPaywallView(
              channel: state.channel!,
              onPurchased: () {
                _statsRequestedChannelId = null;
                _loadStats(channelId);
              },
            ),
          )
        else
          SliverFillRemaining(
            hasScrollBody: true,
            child: ChannelMessageFeed(
              channelId: channelId,
              isManaged: state.channel?.isManaged ?? false,
              // 不共用外层 CustomScrollView 的 controller：同一 ScrollController
              // attach 两个 ScrollPosition 会让 .position getter 抛异常，_onScroll
              // 崩溃→loadMore 永不触发+只渲染1条。feed 自建独立 controller（QA#24）
              onReactionChanged: () => _loadStats(channelId),
              onRefresh: () async {
                await ref
                    .read(channelDetailProvider.notifier)
                    .loadChannel(channelId);
                _statsRequestedChannelId = null;
                await _loadStats(channelId);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(String error) {
    // 与空态统一走 NoDataView，避免同一 App 内失败态样式各写一套。
    return NoDataView(
      icon: Icons.error_outline,
      text: error,
      onTop: () => ref
          .read(channelDetailProvider.notifier)
          .loadChannel(_resolveChannelId()),
    );
  }

  // ---- 删除对话框 ----

  void _showDeleteChannelDialog(ChannelModel channel) {
    final t = context.t;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.channel.deleteChannel),
        content: Text(t.channel.deleteChannelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await _channelService.deleteChannel(
                channel.id.toString(),
              );
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.channelDeleted)),
                );
                context.pop();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.deleteChannelFailed)),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.iosRed),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  // ---- 订阅/退订（头部按钮入口）----

  /// 防重入：快速双击"已订阅"会在首个 dialog route push 完成前二次进入，
  /// 叠出两层 AlertDialog → Duplicate GlobalKey(_OverlayEntryWidgetState)
  /// → 整页红屏（QA#29）。
  bool _subscribeActionBusy = false;

  Future<void> _handleSubscribeAction(ChannelModel channel) async {
    if (_subscribeActionBusy) return;
    if (mounted) {
      setState(() => _subscribeActionBusy = true);
    } else {
      _subscribeActionBusy = true;
    }
    try {
      await _doSubscribeAction(channel);
    } finally {
      if (mounted) {
        setState(() => _subscribeActionBusy = false);
      } else {
        _subscribeActionBusy = false;
      }
    }
  }

  Future<void> _doSubscribeAction(ChannelModel channel) async {
    final t = context.t;
    final channelId = _resolveChannelId(channel);

    if (channel.isManaged) {
      await _openChannelEdit(channel);
      return;
    }

    if (channel.isSubscribed) {
      // 已订阅 → 确认退订
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.channel.unsubscribeConfirm),
          content: Text(t.channel.unsubscribeConfirmDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t.common.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final success = await ref
          .read(channelListProvider.notifier)
          .unsubscribeChannel(channelId);
      if (success && mounted) {
        await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
        _statsRequestedChannelId = null;
        await _loadStats(channelId);
        // 与订阅成功/发现页退订保持对称的成功反馈（M9）
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.common.tipSuccess)));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.common.operationFailedAgainLater)),
        );
      }
    } else {
      // 未订阅 → 订阅
      final success = await ref
          .read(channelListProvider.notifier)
          .subscribeChannel(channelId);
      if (success && mounted) {
        await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
        _statsRequestedChannelId = null;
        await _loadStats(channelId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.subscribeSuccess)));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.channel.subscribeFailed)));
      }
    }
  }

  // ---- 菜单动作 ----

  void _handleMenuAction(String action, ChannelModel? channel) {
    final channelId = _resolveChannelId(channel);

    switch (action) {
      case 'unsubscribe':
        if (channel != null) {
          _handleSubscribeAction(channel);
        }
        break;
      case 'share':
        _shareChannel(channel);
        break;
      case 'invitation_center':
        if (AppFeatureRegistry.isEnabled(FeatureKeys.channelInvitation)) {
          context.push('/channel/invitations');
        }
        break;
      case 'my_orders':
        // 委托给付费视图内的订单 sheet 不适用，这里直接跳订单页
        context.push('/channel/orders');
        break;
      case 'edit_channel':
        if (channel != null) _openChannelEdit(channel);
        break;
      case 'show_channel_info':
        if (channel != null) _showChannelInfoDialog(channel);
        break;
      case 'publish_article':
        context.push('/channel/$channelId/compose');
        break;
      case 'manage_admins':
        context.push('/channel/$channelId/admins');
        break;
      case 'delete_channel':
        if (channel != null) _showDeleteChannelDialog(channel);
        break;
      case 'manage_subscribers':
        final invitationEnabled = AppFeatureRegistry.isEnabled(
          FeatureKeys.channelInvitation,
        );
        final isPrivate = channel?.type == ChannelType.private;
        context.push(
          '/channel/$channelId/subscribers',
          extra: {'canInvite': invitationEnabled && isPrivate},
        );
        break;
    }
  }

  void _showChannelInfoDialog(ChannelModel channel) {
    final desc = channel.description;
    final descText = (desc != null && desc.isNotEmpty) ? desc : '暂无介绍';
    final hasAvatar = channel.avatar != null && channel.avatar!.isNotEmpty;
    final subscriberCount = _stats?.subscriberCount ?? channel.subscriberCount;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Row(
          children: [
            if (hasAvatar)
              CircleAvatar(
                radius: 20,
                backgroundImage: cachedImageProvider(channel.avatar!),
              )
            else
              const CircleAvatar(radius: 20, child: Icon(Icons.campaign)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                channel.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              descText,
              style: TextStyle(fontSize: FontSizeType.subheadline.size),
            ),
            const SizedBox(height: 16),
            Text(
              '${context.t.channel.subscribers}: $subscriberCount',
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
                color: AppColors.iosGray,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t.common.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _openChannelEdit(ChannelModel channel) async {
    final channelId = _resolveChannelId(channel);
    final result = await context.push(
      '/channel/$channelId/edit',
      extra: channel,
    );
    if (!mounted || result == null || result == false) return;

    final reloadId = result is ChannelModel && result.id != 0
        ? result.id.toString()
        : _resolveChannelId(result is ChannelModel ? result : channel);

    await ref.read(channelDetailProvider.notifier).loadChannel(reloadId);
    _statsRequestedChannelId = null;
    await _loadStats(reloadId);
  }

  void _shareChannel(ChannelModel? channel) {
    if (channel == null) return;
    final t = context.t;
    final shareLink = '$webBaseUrl/channel/${channel.id}';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                channel.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.link),
              title: Text(t.channel.share),
              subtitle: Text(shareLink),
              onTap: () {
                Clipboard.setData(ClipboardData(text: shareLink));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.main.copiedToClipboard)),
                );
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.qrcode),
              title: Text(t.account.myQrcode),
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
              leading: const Icon(CupertinoIcons.paperplane),
              title: Text(t.channel.shareToChat),
              onTap: () {
                Navigator.pop(context);
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
