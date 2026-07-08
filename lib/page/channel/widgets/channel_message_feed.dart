import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_message_model.dart';

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
      return NoDataView(
        icon: Icons.article_outlined,
        text: t.channel.noMessages,
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.onRefresh ?? _handleRefresh,
          child: ListView.builder(
            controller: _scrollController,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(error),
          AppSpacing.verticalRegular,
          ElevatedButton(
            onPressed: () => ref
                .read(channelDetailProvider.notifier)
                .loadChannel(widget.channelId),
            child: Text(t.common.buttonRetry),
          ),
        ],
      ),
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
}
