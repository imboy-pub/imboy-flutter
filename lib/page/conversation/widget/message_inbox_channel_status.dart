import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 消息滚动列表中的频道状态：有会话时使用局部提示，否则使用完整状态。
/// 页面保留加载状态与重试控制，组件只负责布局、操作入口与读屏反馈。
class MessageInboxChannelStatusSliver extends StatelessWidget {
  const MessageInboxChannelStatusSliver({
    super.key,
    required this.isLoading,
    this.error,
    this.onRetry,
    this.compact = false,
  });

  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => compact
      ? SliverToBoxAdapter(child: _compact(context))
      : SliverFillRemaining(hasScrollBody: false, child: _full(context));

  Widget _full(BuildContext context) {
    final t = context.t;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ResourcePageLayout.maxWidth,
        ),
        child: Semantics(
          liveRegion: isLoading,
          label: isLoading ? t.common.loading : null,
          child: AsyncStateView(
            key: const ValueKey('message-inbox-channel-state'),
            isLoading: isLoading,
            isEmpty: false,
            error: error,
            errorText: t.chat.inbox.channelLoadFailed,
            onRetry: onRetry,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResourcePageLayout.maxWidth,
          ),
          child: Wrap(
            key: const ValueKey('message-inbox-channel-notice'),
            spacing: AppSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  t.chat.inbox.channelLoadFailed,
                  style: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w400,
                    color: AppColors.getTextColor(
                      Theme.of(context).brightness,
                      isSecondary: true,
                    ),
                  ),
                ),
              ),
              if (onRetry != null || isLoading)
                CupertinoButton(
                  key: const ValueKey('message-inbox-channel-retry'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                  ),
                  minimumSize: const Size.square(AppSizes.touchTarget),
                  onPressed: isLoading ? null : onRetry,
                  child: isLoading
                      ? Semantics(
                          liveRegion: true,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CupertinoActivityIndicator(),
                              AppSpacing.horizontalSmall,
                              Flexible(child: Text(t.common.loading)),
                            ],
                          ),
                        )
                      : Text(t.common.buttonRetry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
