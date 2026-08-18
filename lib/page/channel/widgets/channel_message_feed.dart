import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/page/channel/channel_detail_rules.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/channel_model.dart';

import '../channel_message_item.dart';
import '../channel_provider.dart';

/// 频道消息流
///
/// 从详情页 [_buildBody] 的消息列表部分抽出。
/// 职责单一：分页加载、日期分割、空态/加载态/错误态、滚动监听。
class ChannelMessageFeed extends ConsumerStatefulWidget {
  final String channelId;
  final bool isManaged;
  final ScrollController? scrollController;

  /// 消息反应变化回调（用于刷新上层统计）
  final VoidCallback? onReactionChanged;

  /// 下拉刷新回调
  final Future<void> Function()? onRefresh;

  const ChannelMessageFeed({
    super.key,
    required this.channelId,
    this.isManaged = false,
    this.scrollController,
    this.onReactionChanged,
    this.onRefresh,
  });

  @override
  ConsumerState<ChannelMessageFeed> createState() => _ChannelMessageFeedState();
}

class _ChannelMessageFeedState extends ConsumerState<ChannelMessageFeed> {
  late ScrollController _scrollController;
  bool _showScrollTop = false;
  bool _isSubscribingFromEmpty = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
    setState(() => _isSubscribingFromEmpty = true);
    try {
      final success = await ref
          .read(channelListProvider.notifier)
          .subscribeChannel(channelId);
      if (!mounted) return;
      if (success) {
        await ref.read(channelDetailProvider.notifier).loadChannel(channelId);
        widget.onReactionChanged?.call();
      } else {
        AppLoading.showError(context.t.channel.subscribeFailed);
      }
    } catch (_) {
      if (mounted) {
        AppLoading.showError(context.t.channel.subscribeFailed);
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
          return _buildStartGrowingCard(context, channel, t);
        }
        return NoDataView(
          icon: Icons.edit_note_outlined,
          text: t.channel.noMessagesManaged,
          description: t.channel.noMessagesManagedDesc,
          onTop: () => context.push('/channel/${widget.channelId}/compose'),
          retryLabel: t.channel.publishFirstContent,
        );
      } else if (!hasContentAccess) {
        return NoDataView(
          icon: Icons.notifications_active_outlined,
          text: _isSubscribingFromEmpty
              ? t.common.loading
              : t.channel.noMessagesVisitor,
          description: _isSubscribingFromEmpty
              ? null
              : t.channel.noMessagesVisitorDesc,
          onTop: _isSubscribingFromEmpty
              ? null
              : () => _subscribeFromEmpty(widget.channelId),
          retryLabel: _isSubscribingFromEmpty ? null : t.channel.subscribe,
        );
      } else {
        return NoDataView(
          icon: Icons.article_outlined,
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final message = state.messages[index];
              final showDate = _shouldShowDate(state.messages, index);

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
                    onReactionChanged: widget.onReactionChanged,
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
              child: const Icon(Icons.arrow_upward, size: 20),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, String error, Translations t) {
    // 与同 build 里的 NoDataView 空态统一，避免失败态自成一套视觉。
    return NoDataView(
      icon: Icons.error_outline,
      text: error,
      onTop: () => ref
          .read(channelDetailProvider.notifier)
          .loadChannel(widget.channelId),
    );
  }

  /// 日期分割判断：首条或与前一条不在同一天
  bool _shouldShowDate(List<ChannelMessageModel> messages, int index) {
    if (index == 0) return true;
    final current = messages[index].createdAt;
    final previous = messages[index - 1].createdAt;
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  Widget _buildDateDivider(ChannelMessageModel message, Translations t) {
    final now = DateTime.now();
    final diff = now.difference(message.createdAt);

    String dateText;
    if (diff.inDays == 0) {
      dateText = t.channel.today;
    } else if (diff.inDays == 1) {
      dateText = t.channel.yesterday;
    } else if (diff.inDays < 7) {
      dateText = '${diff.inDays} ${t.channel.daysAgo}';
    } else {
      dateText = DateTimeHelper.dateTimeFmt(
        message.createdAt,
        pattern: 'yyyy-MM-dd',
        relative: false,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.getIosSeparator(Theme.of(context).brightness),
            borderRadius: AppRadius.borderRadiusMedium,
          ),
          child: Text(
            dateText,
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.getTextColor(
                Theme.of(context).brightness,
                isSecondary: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartGrowingCard(
    BuildContext context,
    ChannelModel channel,
    dynamic t,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final textPrimary = AppColors.getTextColor(Theme.of(context).brightness);
    final channelName = channel.name;

    final hasAvatar = channel.avatar != null && channel.avatar!.isNotEmpty;
    final isChinese = Localizations.localeOf(context).languageCode == 'zh';

    final createdPillText = isChinese
        ? '频道 “$channelName” 已创建'
        : 'Channel "$channelName" created';
    final cardTitle = isChinese
        ? '开始发展壮大 “$channelName”'
        : 'Start growing "$channelName"';
    final addPhotoText = hasAvatar
        ? (isChinese ? '修改照片' : 'Change photo')
        : (isChinese ? '添加照片' : 'Add photo');
    final addDescText =
        (channel.description != null && channel.description!.isNotEmpty)
        ? channel.description!
        : (isChinese ? '添加描述' : 'Add description');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // 1. 系统消息 pill: 频道 "xxx" 已创建
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.chatWebBackgroundDark
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                createdPillText,
                style: context.textStyle(
                  FontSizeType.small,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.chatWebBrand,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // 2. 发展壮大 Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lightTextPrimary.withValues(
                      alpha: isDark ? 0.2 : 0.05,
                    ),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 大圆形占位头像 / 频道头像
                  GestureDetector(
                    onTap: () => context.push(
                      '/channel/${channel.id}/edit',
                      extra: channel,
                    ),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.chatWebSecondaryDark.withValues(
                          alpha: 0.15,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasAvatar
                          ? Image(
                              image: cachedImageProvider(
                                channel.avatar!,
                                w: 256,
                              ),
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            )
                          : const Center(
                              child: Icon(
                                Icons.campaign_outlined,
                                size: 48,
                                color: AppColors.chatWebSecondaryDark,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // "添加照片" 绿色文本按钮
                  TextButton(
                    onPressed: () => context.push(
                      '/channel/${channel.id}/edit',
                      extra: channel,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.chatWebBrand,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    ),
                    child: Text(
                      addPhotoText,
                      style: TextStyle(
                        fontSize: FontSizeType.medium.size,
                        fontWeight: FontWeight.bold,
                        color: AppColors.chatWebBrand,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title: 开始发展壮大 "xxx"
                  Text(
                    cardTitle,
                    style: context
                        .textStyle(
                          FontSizeType.large,
                          fontWeight: FontWeight.w800,
                        )
                        .copyWith(color: textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // "添加描述" / "已有描述" 绿色文本按钮
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/channel/${channel.id}/edit',
                      extra: channel,
                    ),
                    icon: const Icon(
                      CupertinoIcons.pencil,
                      size: 16,
                      color: AppColors.chatWebBrand,
                    ),
                    label: Text(
                      addDescText,
                      style: TextStyle(
                        fontSize: FontSizeType.normal.size,
                        fontWeight: FontWeight.w600,
                        color: AppColors.chatWebBrand,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pill Button 1: 分享至我的动态
                  _buildPillButton(
                    context: context,
                    icon: CupertinoIcons.arrow_2_circlepath,
                    label: isChinese ? "分享至我的动态" : "Share to My Status",
                    onTap: () {
                      context.push(
                        AppRoutes.momentCreate,
                        extra: {
                          'content': isChinese
                              ? '大家快来关注我的频道【$channelName】吧！$webBaseUrl/channel/${channel.id}'
                              : 'Come and follow my channel "$channelName" at $webBaseUrl/channel/${channel.id}',
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Pill Button 2: 邀请管理员
                  _buildPillButton(
                    context: context,
                    icon: CupertinoIcons.plus,
                    label: isChinese ? "邀请管理员" : "Invite Admins",
                    onTap: () {
                      context.push('/channel/${channel.id}/admins');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark
        ? AppColors.lightSurface.withValues(alpha: 0.08)
        : AppColors.chatWebBackgroundLight;
    final textPrimary = AppColors.getTextColor(Theme.of(context).brightness);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: context
                  .textStyle(FontSizeType.normal, fontWeight: FontWeight.bold)
                  .copyWith(color: textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
