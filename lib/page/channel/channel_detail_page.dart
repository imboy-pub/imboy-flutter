import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/generated_channel_order_widget.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'channel_detail_rules.dart';
import 'channel_provider.dart';
import 'widgets/channel_header_bar.dart';
import 'widgets/channel_overflow_menu.dart';

import 'widgets/channel_discussion_entry.dart';
import 'widgets/channel_message_feed.dart';
import 'widgets/channel_publish_bar.dart';

import 'package:imboy/component/ui/app_loading.dart';

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

  /// 嵌套模式（如工作区频道详情）：不渲染自身 GlassAppBar，标题/返回/⋮
  /// 菜单由宿主页顶栏接管（⋮ 用公共的 [ChannelOverflowMenu]），避免双层头部。
  final bool embedded;

  const ChannelDetailPage({
    super.key,
    required this.channelId,
    this.autoLoadStats = true,
    this.embedded = false,
  });

  @override
  ConsumerState<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends ConsumerState<ChannelDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _publishFocusNode = FocusNode();
  late final ChannelService _channelService = ChannelService.to;

  bool _searchOpen = false;
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
    ref.watch(featureRevisionProvider);
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
      // embedded 模式由宿主（如 WorkspaceChannelDetailPage）提供 AppBar。
      appBar: widget.embedded
          ? null
          : GlassAppBar(
              title: channel?.name ?? t.channel.loading,
              titleWidget: channel == null
                  ? null
                  : CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => showChannelInfoDialog(context, channel),
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
              automaticallyImplyLeading: true,
              rightDMActions: _buildAppBarActions(channel),
            ),
      // 发布栏必须在 body 内（而非 bottomNavigationBar）：Flutter 的
      // _ScaffoldLayout 把 bottomNavigationBar 定位在整屏底部（bottom =
      // size.height），只有 body 会按 minInsets 内缩，键盘一弹发布栏就被压在
      // 键盘下面「消失」。放进 Column 尾部后随 body 一起被顶起，粘在键盘上沿。
      body: ResourcePageLayout(
        child: Column(
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
                key: ValueKey(widget.channelId),
                channelId: widget.channelId,
                focusNode: _publishFocusNode,
                onMessageSent: () => _loadStats(channelId),
              ),
          ],
        ),
      ),
    );
  }

  // ---- AppBar ----

  List<Widget> _buildAppBarActions(ChannelModel? channel) {
    if (channel == null) return [];

    return [
      if (ChannelMessageFeed.contentToolsAvailable(channel))
        IconButton(
          key: const Key('channel-content-search-toggle'),
          tooltip: context.t.common.search,
          icon: Icon(
            _searchOpen ? CupertinoIcons.xmark : CupertinoIcons.search,
          ),
          onPressed: () => setState(() {
            _searchOpen = !_searchOpen;
            if (!_searchOpen) FocusScope.of(context).unfocus();
          }),
        ),
      ChannelOverflowMenu(
        channel: channel,
        subscriberCount: _stats?.subscriberCount,
      ),
    ];
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
              // P1-01：详情路由 AppBar（standalone GlassAppBar / embedded
              // 宿主 AppBar）承载唯一频道身份标题，元信息区进紧凑模式。
              showIdentityTitle: false,
              channel: state.channel!,
              stats: _stats,
              isActionPending: _subscribeActionBusy,
              onActionTap: () => _handleSubscribeAction(state.channel!),
              onShareTap: () => showChannelShareSheet(context, state.channel!),
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
        if (state.channel != null)
          SliverToBoxAdapter(
            child: ChannelDiscussionEntry(
              key: ValueKey('discussion_$channelId'),
              channel: state.channel!,
            ),
          ),
        if (isPaidChannelLocked(state.channel))
          SliverFillRemaining(
            hasScrollBody: false,
            child: compiledChannelPaywall(
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
              searchOpen: widget.embedded ? null : _searchOpen,
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
    // P1-03/D10：标题 + 固定安全说明两段（说明复用 enterpriseOa 的
    // 通用网络错误提示键），重试走既有 loadChannel。
    final detail = error.trim();
    return NoDataView(
      icon: CupertinoIcons.exclamationmark_circle,
      text: detail.isEmpty ? t.common.loadError : detail,
      description: t.enterpriseOa.statusErrorHint,
      retryLabel: t.common.retry,
      onTop: () => ref
          .read(channelDetailProvider.notifier)
          .loadChannel(_resolveChannelId()),
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
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(t.channel.unsubscribeConfirm),
          content: Text(t.channel.unsubscribeConfirmDesc),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.common.cancel),
            ),
            CupertinoDialogAction(
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
          AppLoading.showToast(t.common.tipSuccess);
        }
      }
      // 失败分支不再叠兜底文案：后端中文原因已由 ChannelApi.unsubscribe 透出
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
          AppLoading.showToast(t.channel.subscribeSuccess);
        }
      }
      // 失败分支不再叠兜底文案：后端中文原因已由 ChannelApi.subscribe 透出
    }
  }

  // ---- 菜单动作已抽至 widgets/channel_overflow_menu.dart（embedded 复用） ----

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
}
