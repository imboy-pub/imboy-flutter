import 'package:imboy/store/repository/user_repo_local.dart';

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/page/channel/channel_detail_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/api/report_api.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';

import '../channel_di_provider.dart';
import '../channel_message_item.dart';
import '../channel_provider.dart';

/// 频道消息流
///
/// 从详情页 [_buildBody] 的消息列表部分抽出。
/// 职责单一：分页加载、日期分割、空态/加载态/错误态、滚动监听。
class ChannelMessageFeed extends ConsumerStatefulWidget {
  final String channelId;
  final bool isManaged;

  /// Null keeps the standalone toolbar; a host app bar may own the toggle.
  final bool? searchOpen;
  final ScrollController? scrollController;

  /// 消息反应变化回调（用于刷新上层统计）
  final VoidCallback? onReactionChanged;

  /// 下拉刷新回调
  final Future<void> Function()? onRefresh;

  const ChannelMessageFeed({
    super.key,
    required this.channelId,
    this.isManaged = false,
    this.searchOpen,
    this.scrollController,
    this.onReactionChanged,
    this.onRefresh,
  });

  static bool contentToolsAvailable(ChannelModel? channel) =>
      ChannelApi.microCommunityEnabled &&
      channel != null &&
      (channel.isManaged || hasChannelContentAccess(channel));

  @override
  ConsumerState<ChannelMessageFeed> createState() => _ChannelMessageFeedState();
}

class _ChannelMessageFeedState extends ConsumerState<ChannelMessageFeed> {
  /// 收缩态下仍给消息列表保留的最小高度（约一条列表项）。
  static const double _minListHeight = 48;

  late ScrollController _scrollController;
  bool _showScrollTop = false;
  bool _isSubscribingFromEmpty = false;
  String _query = '';
  String? _tag;
  final _tagInput = TextEditingController();
  bool _essenceOnly = false;
  int _page = 1;

  /// 高级筛选（标签/全部·精华）展开态（P1-06/D09）：默认折叠，仅展示
  /// 搜索与筛选入口；展开/收起是纯本地展示状态，不改查询语义（
  /// _query/_tag/_essenceOnly/_page 与 provider 参数原样保留），也不
  /// 触发额外业务查询。controller 常驻 State，收起仅移除输入框渲染，
  /// 已输入条件与文本不丢失。
  bool _advancedOpen = false;
  bool _searchOpen = false;
  bool get _searchActive => _query.isNotEmpty || _tag != null || _essenceOnly;

  ChannelPostSearch get _filter => (
    channelId: widget.channelId,
    q: _query,
    tag: _tag,
    essence: _essenceOnly ? true : null,
    page: _page,
  );

  void _selectTag(String tag) => setState(() {
    _tag = tag;
    _tagInput.text = tag;
    _page = 1;
  });

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tagInput.dispose();
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    // 距底部 200px 时触发分页
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll - pixels <= 200) {
      ref.read(channelDetailProvider.notifier).loadMoreMessages();
    }
    // 向下滚动超过 400px 时显示「回到顶部」按钮
    final shouldShow = pixels > 400;
    if (shouldShow != _showScrollTop) {
      setState(() => _showScrollTop = shouldShow);
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleRefresh() async {
    await ref
        .read(channelDetailProvider.notifier)
        .loadChannel(widget.channelId);
    widget.onReactionChanged?.call();
  }

  Future<void> _subscribeFromEmpty(String channelId) async {
    if (_isSubscribingFromEmpty) return;
    final t = context.t;
    final user = UserRepoLocal.to;
    final uid = user.currentUid;
    final generation = user.sessionGeneration;
    bool isCurrent() =>
        mounted &&
        widget.channelId == channelId &&
        user.currentUid == uid &&
        user.isCurrentSession(generation) &&
        !user.isAuthTransitioning;
    setState(() => _isSubscribingFromEmpty = true);
    try {
      final success = await ref
          .read(channelListProvider.notifier)
          .subscribeChannel(channelId);
      if (!isCurrent()) return;
      if (success == ChannelSubscribeOutcome.completed) {
        await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
        if (isCurrent()) widget.onReactionChanged?.call();
      } else if (success == ChannelSubscribeOutcome.pending) {
        AppLoading.showToast(t.channel.subscribePending);
      }
      // 失败分支不再叠兜底文案：后端中文原因已由 ChannelApi.subscribe 透出
    } catch (e) {
      iPrint('[ChannelMessageFeed] 订阅失败: $e');
      if (isCurrent()) {
        AppLoading.showError(t.channel.subscribeFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubscribingFromEmpty = false);
      } else {
        _isSubscribingFromEmpty = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(channelDetailProvider.select((s) => s.channel));
    final enabled = ChannelMessageFeed.contentToolsAvailable(channel);
    final searchOpen = widget.searchOpen ?? _searchOpen;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          // 外层 SliverFillRemaining 按「视口 − 头部条/讨论区」的剩余空间下发
          // 紧约束：页首未收起头部或键盘压缩视口时，剩余高度可能小于筛选区
          // 自然高度（约 114px），固定高度筛选区 + Expanded 列表会底部溢出
          // （实测 360×99.7 溢出 14px）。这里把筛选区压到剩余高度内并允许
          // 内部滚动；空间充足时仍取自然高度，布局不变。筛选区必须始终留在
          // 树里——集成测试靠 ensureVisible 滚出它后再操作。
          if (enabled &&
              (widget.searchOpen == null || searchOpen || _searchActive))
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(0, constraints.maxHeight - _minListHeight),
              ),
              child: SingleChildScrollView(
                primary: false,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.searchOpen == null)
                      CupertinoButton(
                        key: const Key('channel-content-search-toggle'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.regular,
                        ),
                        onPressed: () => setState(() {
                          _searchOpen = !_searchOpen;
                          if (!_searchOpen) FocusScope.of(context).unfocus();
                        }),
                        child: Icon(
                          _searchOpen
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.search,
                          semanticLabel: context.t.common.search,
                        ),
                      ),
                    if (searchOpen || _searchActive) _buildPostFilters(context),
                  ],
                ),
              ),
            ),
          Expanded(
            child: enabled && _searchActive
                ? _buildSearchResults(context)
                : _buildRegularFeed(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPostFilters(BuildContext context) {
    final theme = Theme.of(context);
    final defaultIconColor = AppColors.getTextColor(
      theme.brightness,
      isSecondary: true,
    );
    return Padding(
      padding: AppSpacing.allRegular,
      child: Column(
        children: [
          // 常驻行：搜索 + 筛选入口（P1-06/D09）。高级筛选默认折叠；
          // 有已生效筛选（_searchActive）时入口用主色作可见指示。
          Row(
            children: [
              Expanded(
                child: CupertinoSearchTextField(
                  key: const Key('mc_post_search'),
                  placeholder: context.t.common.search,
                  onChanged: (q) {
                    if (q.trim().isEmpty && _query.isNotEmpty) {
                      setState(() {
                        _query = '';
                        _page = 1;
                      });
                    }
                  },
                  onSubmitted: (q) => setState(() {
                    _query = q.trim();
                    _page = 1;
                  }),
                ),
              ),
              AppSpacing.horizontalSmall,
              // 语义标签用现有键组合（P1-06 范围内不新增 i18n 键）：
              // 按钮控制「标签 / 全部·精华」两组高级筛选的展开与收起。
              Semantics(
                label: '${context.t.contact.tags}/${context.t.channel.essence}',
                button: true,
                child: CupertinoButton(
                  key: const Key('mc_filter_toggle'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => setState(() {
                    _advancedOpen = !_advancedOpen;
                    // 收起时焦点安全转移：输入框离开树前先收键盘，
                    // 避免焦点悬挂在已移除节点上。
                    if (!_advancedOpen) {
                      FocusScope.of(context).unfocus();
                    }
                  }),
                  child: Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 20,
                    color: _searchActive
                        ? theme.colorScheme.primary
                        : defaultIconColor,
                  ),
                ),
              ),
            ],
          ),
          if (_advancedOpen) ...[
            AppSpacing.verticalSmall,
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    key: const Key('mc_tag_filter'),
                    controller: _tagInput,
                    onChanged: (value) {
                      if (value.trim().isEmpty && _tag != null) {
                        setState(() {
                          _tag = null;
                          _page = 1;
                        });
                      }
                    },
                    placeholder: context.t.contact.tags,
                    onSubmitted: (value) => setState(() {
                      _tag = value.trim().isEmpty ? null : value.trim();
                      _page = 1;
                    }),
                  ),
                ),
                AppSpacing.horizontalSmall,
                CupertinoSlidingSegmentedControl<bool>(
                  key: const Key('mc_essence_filter'),
                  groupValue: _essenceOnly,
                  children: {
                    false: Text(context.t.channel.allPosts),
                    true: Text(context.t.channel.essence),
                  },
                  onValueChanged: (value) => setState(() {
                    _essenceOnly = value ?? false;
                    _page = 1;
                  }),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final result = ref.watch(channelPostSearchProvider(_filter));
    return result.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (_, _) => NoDataView(
        icon: CupertinoIcons.exclamationmark_circle,
        text: context.t.common.loadError,
        onTop: () => ref.invalidate(channelPostSearchProvider(_filter)),
        retryLabel: context.t.common.retry,
      ),
      data: (page) => LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: page.list.isEmpty
                  ? NoDataView(
                      icon: CupertinoIcons.search,
                      text: context.t.channel.noResults,
                    )
                  : ListView.builder(
                      itemCount: page.list.length,
                      itemBuilder: (context, index) => ChannelMessageItem(
                        key: ValueKey(page.list[index].id),
                        message: page.list[index],
                        channelId: widget.channelId,
                        isManaged: widget.isManaged,
                        onTagSelected: _selectTag,
                        onPinned: (_) =>
                            ref.invalidate(channelPostSearchProvider(_filter)),
                        onMetadataChanged: () =>
                            ref.invalidate(channelPostSearchProvider(_filter)),
                        onDeleted: () =>
                            ref.invalidate(channelPostSearchProvider(_filter)),
                      ),
                    ),
            ),
            // 结果区高度不足以同时容纳列表与分页条（小屏细条预览、键盘
            // 压缩视口）时隐藏分页条避免溢出，展开后自动恢复。
            if (constraints.maxHeight >= 96)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoButton(
                    key: const Key('mc_posts_previous'),
                    onPressed: _page > 1 ? () => setState(() => _page--) : null,
                    child: Icon(
                      CupertinoIcons.chevron_left,
                      semanticLabel: MaterialLocalizations.of(context)
                          .previousPageTooltip,
                    ),
                  ),
                  Text('${page.page}'),
                  CupertinoButton(
                    key: const Key('mc_posts_next'),
                    onPressed: page.hasMore
                        ? () => setState(() => _page++)
                        : null,
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      semanticLabel: MaterialLocalizations.of(context)
                          .nextPageTooltip,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegularFeed(BuildContext context) {
    final state = ref.watch(channelDetailProvider);
    final t = context.t;

    if (state.isLoading && state.messages.isEmpty) {
      return const ShimmerList(itemCount: 6);
    }

    if (state.error != null && state.messages.isEmpty) {
      return _buildErrorView(context, state.error!, t);
    }

    if (state.messages.isEmpty && !state.isLoading) {
      final channel = state.channel;
      final isManaged = channel?.isManaged ?? widget.isManaged;
      // 付费频道的内容权限由购买订单授予；历史订单恢复或订阅状态
      // 短暂不同步时，已购买用户仍不应看到访客订阅 CTA。
      final hasContentAccess = hasChannelContentAccess(channel);

      if (isManaged) {
        if (channel != null) {
          return _buildStartGrowingCard(context, channel);
        }
        return NoDataView(
          icon: CupertinoIcons.pencil,
          text: t.channel.noMessagesManaged,
          description: t.channel.noMessagesManagedDesc,
          onTop: () => context.push('/channel/${widget.channelId}/compose'),
          retryLabel: t.channel.publishFirstContent,
        );
      } else if (!hasContentAccess) {
        return NoDataView(
          icon: CupertinoIcons.bell_fill,
          text: _isSubscribingFromEmpty
              ? t.common.loading
              : t.channel.noMessagesVisitor,
          description: _isSubscribingFromEmpty
              ? null
              : t.channel.noMessagesVisitorDesc,
          onTop: _isSubscribingFromEmpty
              ? null
              : () => _subscribeFromEmpty(widget.channelId),
          retryLabel: _isSubscribingFromEmpty
              ? null
              : (ref
                        .read(channelServiceProvider)
                        .hasPendingSubscription(widget.channelId)
                    ? t.channel.subscribeRefresh
                    : t.channel.subscribe),
        );
      } else {
        return NoDataView(
          icon: CupertinoIcons.doc_text,
          text: t.channel.noMessagesSubscribed,
          description: t.channel.noMessagesSubscribedDesc,
        );
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.onRefresh ?? _handleRefresh,
          child: ListView.builder(
            controller: _scrollController,
            // 下滑即收键盘：消息流是实际吃掉手势的那一层，不加这里外层白搭。
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: AppSpacing.regular),
            itemCount: state.messages.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // 加载更多指示器
              if (index == state.messages.length) {
                return Padding(
                  padding: AppSpacing.allRegular,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CupertinoActivityIndicator(),
                    ),
                  ),
                );
              }

              final message = state.messages[index];
              final showDate = shouldShowDateDivider(state.messages, index);

              return Column(
                // 稳定 Key：发消息头插、置顶/删除会重排列表，缺 Key 时 Flutter
                // 按位置复用 State，会把 ChannelMessageItem 的 _liked/_expanded
                // 错配到滑入该位置的另一条消息（状态张冠李戴 + 误发反应 API）。
                key: ValueKey(message.id),
                children: [
                  if (showDate) _buildDateDivider(message, t),
                  ChannelMessageItem(
                    message: message,
                    channelId: widget.channelId,
                    isManaged: widget.isManaged,
                    onTagSelected: ChannelApi.microCommunityEnabled
                        ? _selectTag
                        : null,
                    onReactionChanged: widget.onReactionChanged,
                    // R-01 频道消息举报入口：长按弹原因选择，走 message 一等举报
                    onLongPress: () => _showChannelMessageReport(message, t),
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
          ),
        ),
        // 回到顶部按钮（向下滚动超过 400px 时浮现）
        if (_showScrollTop)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'channel_scroll_top_${widget.channelId}',
              onPressed: _scrollToTop,
              elevation: 2,
              child: const Icon(CupertinoIcons.chevron_up, size: 20),
            ),
          ),
      ],
    );
  }

  /// R-01 频道消息举报：target_type='message'（chat_type=channel），
  /// scope=频道 ID，服务端核验订阅/公开可见性；频道消息非 E2EE，
  /// 文本摘录直接随工单提交。
  void _showChannelMessageReport(ChannelMessageModel message, Translations t) {
    GroupDialogs.actionSheet(
      context,
      title: t.complaint.complaint,
      actions: [
        (
          label: t.complaintReason.spam,
          destructive: false,
          onPressed: () => _submitChannelMessageReport(message, 'spam'),
        ),
        (
          label: t.complaintReason.harassment,
          destructive: false,
          onPressed: () => _submitChannelMessageReport(message, 'harassment'),
        ),
        (
          label: t.complaintReason.inappropriate,
          destructive: false,
          onPressed: () =>
              _submitChannelMessageReport(message, 'inappropriate'),
        ),
        (
          label: t.complaintReason.other,
          destructive: false,
          onPressed: () => _submitChannelMessageReport(message, 'other'),
        ),
      ],
    );
  }

  Future<void> _submitChannelMessageReport(
    ChannelMessageModel message,
    String reason,
  ) async {
    final t = context.t;
    final (ok, serverMsg) = await ReportApi().createMessage(
      chatType: 'channel',
      targetId: message.id.toString(),
      scopeId: widget.channelId,
      reason: reason,
      excerpt: message.content.trim(),
      clientMsgId: message.id.toString(),
      msgType: message.msgType,
      sentAt: message.createdAt.millisecondsSinceEpoch,
    );
    if (ok) {
      AppLoading.showSuccess(t.common.complaintSuccess);
    } else {
      AppLoading.showError(
        ReportApi.friendlyError(serverMsg, t.common.complaintFailed),
      );
    }
  }

  Widget _buildErrorView(BuildContext context, String error, Translations t) {
    // 与同 build 里的 NoDataView 空态统一，避免失败态自成一套视觉。
    // 错误正文为空（服务端无 message）时用通用失败文案兜底，杜绝只显示
    // 一个孤立「重试」按钮（2026-10-17 截图问题）。
    final detail = error.trim();
    return NoDataView(
      icon: CupertinoIcons.exclamationmark_circle,
      // P1-03/D10 两段结构：标题（服务端安全 message，空则通用兜底）
      // + 固定安全说明（不透出 raw exception/URL/Token）。说明复用
      // enterpriseOa 的通用网络错误提示键（现有键，语义一致）。
      text: detail.isEmpty ? t.common.loadError : detail,
      description: t.enterpriseOa.statusErrorHint,
      retryLabel: t.common.retry,
      onTop: () => ref
          .read(channelDetailProvider.notifier)
          .loadChannel(widget.channelId),
    );
  }

  Widget _buildDateDivider(ChannelMessageModel message, Translations t) {
    final dateText = formatChannelDateDivider(message.createdAt, t);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Center(
        child: Text(
          dateText,
          style: context.textStyle(
            FontSizeType.caption2,
            color: AppColors.getTextColor(
              Theme.of(context).brightness,
              isSecondary: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartGrowingCard(BuildContext context, ChannelModel channel) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Column(
          children: [
            Text(
              t.channel.startGrowing(name: channel.name),
              style: context.textStyle(
                FontSizeType.large,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalSmall,
            Text(
              t.channel.channelCreated(name: channel.name),
              style: context.textStyle(FontSizeType.small),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalRegular,
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed: () =>
                  context.push('/channel/${channel.id}/edit', extra: channel),
              child: Text(t.channel.settings),
            ),
            AppSpacing.verticalSmall,
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.iosBlue,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath),
                  label: Text(t.channel.shareToMyStatus),
                  onPressed: () => context.push(
                    AppRoutes.momentCreate,
                    extra: {
                      'content': t.channel.shareInviteText(
                        name: channel.name,
                        url: '$webBaseUrl/channel/${channel.id}',
                      ),
                    },
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.iosBlue,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(CupertinoIcons.plus),
                  label: Text(t.channel.inviteAdmins),
                  onPressed: () =>
                      context.push('/channel/${channel.id}/admins'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
