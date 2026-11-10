import 'package:imboy/component/ui/bot_badge.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/conversation/message_inbox_time.dart';
import 'package:imboy/page/conversation/widget/message_inbox_tile.dart';
import 'package:imboy/page/group/group_avatar_cache.dart'
    show defaultGroupAvatarLoader;
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 会话列表项组件 - iOS 17 Premium 风格
class ConversationItem extends ConsumerStatefulWidget {
  final ConversationModel model;
  final void Function()? onTapAvatar;
  final void Function()? onTap;
  final VoidCallback? onLongPress;

  const ConversationItem({
    super.key,
    required this.model,
    required this.onTapAvatar,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends ConsumerState<ConversationItem> {
  /// 对端账号类型（0=真人 1=AI 2=官方），透明 AI 徽章数据源
  int _peerAccountType = 0;

  @override
  void initState() {
    super.initState();
    _loadPeerAccountType();
  }

  // ponytail: 每 tile 一次本地 contact 单行索引查询（autoFetch:false，不触网，
  // 服务层有查询缓存）；列表滚动性能有压力时改为 ConversationRepo JOIN contact
  // 随行返回。
  // 2026-07-30 UI/UX Sprint Task 6 复核结论：确认为已登记可接受技术债，本次延期。
  // 理由：单行索引查询有界且不触网，当前列表规模下无明显瓶颈；批量收敛需先注入
  // repository 边界（无现成 seam），超出本 Sprint 范围。升级路径见上一行。
  //
  // "不触网"这条前提有证据测试守着：
  // test/store/repository/contact_repo_no_network_test.dart
  // （A/B 已验证：去掉下面的 autoFetch: false 会真的发起 HTTP 请求）。
  // 动这里之前先看那个文件。
  Future<void> _loadPeerAccountType() async {
    if (widget.model.type != 'C2C') return;
    final ct = await ContactRepo().findByUid(
      widget.model.peerId.toString(),
      autoFetch: false,
    );
    if (mounted && ct != null && ct.accountType != _peerAccountType) {
      setState(() => _peerAccountType = ct.accountType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int remindCounter = ref.watch(
      conversationProvider.select(
        (s) => s.conversationRemind[widget.model.uk3] ?? widget.model.unreadNum,
      ),
    );
    final ConversationModel currentModel = ref.watch(
      conversationProvider.select(
        (s) => s.conversationMap[widget.model.uk3] ?? widget.model,
      ),
    );
    // W09.a（J17.c）：人工待处理可视标记（独立于 unreadNum，互不清除）。
    final bool manualPending = ref.watch(
      conversationProvider.select(
        (s) => s.manualPending[widget.model.uk3] == true,
      ),
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MessageInboxTile(
      avatar: currentModel.type == 'C2G'
          ? SmartGroupAvatar(
              avatar: currentModel.avatar,
              groupId: currentModel.peerId.toString(),
              onTap: widget.onTapAvatar,
              size: MessageInboxTile.avatarSize,
              avatarLoader: defaultGroupAvatarLoader,
              heroTag: 'avatar_${currentModel.peerId}',
            )
          : Avatar(
              imgUri: currentModel.avatar,
              onTap: widget.onTapAvatar,
              width: MessageInboxTile.avatarSize,
              height: MessageInboxTile.avatarSize,
              heroTag: 'avatar_${currentModel.peerId}',
            ),
      title: _buildTitle(currentModel, isDark),
      preview: Row(
        children: [
          // 发送中和待重试继续使用同一在制状态，不误显示成彻底失败。
          if (IMBoyMessageStatus.isInFlightStatus(currentModel.lastMsgStatus))
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.tiny),
              child: CupertinoActivityIndicator(radius: AppSpacing.medium / 2),
            ),
          Expanded(child: _buildContent(currentModel, isDark)),
        ],
      ),
      timeLabel: formatMessageInboxTime(
        currentModel.lastTime,
        yesterdayLabel: context.t.common.yesterday,
      ),
      unreadCount: remindCounter,
      isMuted: currentModel.isMuted > 0,
      isPinned: currentModel.isPinned,
      // 人工待处理保留独立标记，与未读、免打扰状态互不覆盖。
      trailingStatus: manualPending
          ? Icon(
              CupertinoIcons.flag_fill,
              size: AppSpacing.medium,
              color: AppColors.getIosOrange(theme.brightness),
              semanticLabel: context.t.chat.manualPendingBadge,
            )
          : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
    );
  }

  Widget _buildTitle(ConversationModel currentModel, bool isDark) {
    // 末档原本是 `peerId.toString()`，把 TSID 直接渲染给用户。
    // 判据与兜底已收口到 ConversationModel.displayTitle —— 会话列表、搜索过滤、
    // 跳转参数、聊天页原本各写一遍，写歪一处就漏一条路径。
    String displayTitle = currentModel.displayTitle;

    return LayoutBuilder(
      builder: (context, constraints) {
        var compactBadge = false;
        if (_peerAccountType > 0) {
          final scaler = MediaQuery.textScalerOf(context);
          final measurement = TextPainter(
            text: TextSpan(
              text: _peerAccountType == 1
                  ? context.t.agent.badgeAi
                  : context.t.agent.badgeOfficial,
              style: context.textStyle(
                FontSizeType.caption2,
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          final badgeWidth =
              measurement.width +
              AppSpacing.tiny * 2 +
              AppSpacing.medium +
              AppSpacing.tiny;
          final titleSize = context.textStyle(FontSizeType.body).fontSize!;
          compactBadge =
              constraints.maxWidth <
              badgeWidth + AppSpacing.tiny + scaler.scale(titleSize) * 2;
          measurement.dispose();
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                displayTitle,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 窄屏和大字体使用现有紧凑徽章，身份读屏标签仍完整保留。
            if (_peerAccountType > 0) ...[
              AppSpacing.horizontalTiny,
              BotBadge(
                accountType: _peerAccountType,
                compact: compactBadge,
                dense: true,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildContent(ConversationModel currentModel, bool isDark) {
    String content = currentModel.content;
    TextStyle contentStyle = context
        .textStyle(
          FontSizeType.normal,
          fontWeight: FontWeight.w400,
          color:
              (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary)
                  .withValues(alpha: 0.75),
        )
        .copyWith(height: 1.4);

    if (content.contains('_color_red_')) {
      List<String> parts = content.split('_color_red_');
      return RichText(
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: "${parts[0]} ",
              style: contentStyle.copyWith(
                color: AppColors.iosRed,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: parts.length > 1 ? parts[1] : '',
              style: contentStyle,
            ),
          ],
        ),
      );
    }

    if (currentModel.mentionUnread > 0) {
      return RichText(
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: t.common.atMentionYouTag,
              style: contentStyle.copyWith(
                color: AppColors.iosRed,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: content, style: contentStyle),
          ],
        ),
      );
    }

    return Text(
      content,
      style: contentStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
