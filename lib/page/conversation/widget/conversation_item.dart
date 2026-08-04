import 'package:imboy/component/ui/badge_widget.dart';
import 'package:imboy/component/ui/bot_badge.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 会话列表项组件 - iOS 17 Premium 风格
class ConversationItem extends ConsumerStatefulWidget {
  final ConversationModel model;
  final void Function()? onTapAvatar;
  final void Function()? onTap;

  const ConversationItem({
    super.key,
    required this.model,
    required this.onTapAvatar,
    this.onTap,
  });

  @override
  ConsumerState<ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends ConsumerState<ConversationItem> {
  bool _isPressed = false;

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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 背景色处理：置顶会话使用淡灰背景
    final Color bgColor = currentModel.isPinned
        ? (isDark
              ? AppColors.darkSurfaceGrouped
              : AppColors.lightSurfaceGrouped.withValues(alpha: 0.5))
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);

    return GestureDetector(
      onTap: widget.onTap,
      // 不触发 HapticFeedback：iOS 系统列表按下不给触感，只有切换/选择类
      // 操作才给。每点一个会话都震一下是噪音，高频列表尤其明显。
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        // DESIGN.md 6.4：Cell 按压反馈 100ms
        duration: AppDuration.buttonPress,
        color: _isPressed
            // 按压态半透明高光叠加：暗色用白、亮色用黑，属固定交互反馈
            ? (isDark ? AppColors.overlayWhite10 : AppColors.overlayBlack5)
            : bgColor,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 头像区域 + 未读角标
            BadgeWidget(
              showBadge: (remindCounter > 0),
              semanticLabel: context.t.common.unreadCount(
                count: '$remindCounter',
              ),
              content: Text(
                remindCounter > 99 ? '99+' : "$remindCounter",
                style: context
                    .textStyle(
                      FontSizeType.caption2,
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    )
                    .copyWith(fontFeatures: [FontFeature.tabularFigures()]),
              ),
              color: AppColors.iosRed,
              padding: const EdgeInsets.all(5),
              top: -4,
              left: -4,
              right: null,
              child: GestureDetector(
                onTap: widget.onTapAvatar,
                child: currentModel.type == 'C2G'
                    ? SmartGroupAvatar(
                        avatar: currentModel.avatar,
                        groupId: currentModel.peerId.toString(),
                        onTap: widget.onTapAvatar,
                        size: 56,
                        avatarLoader: GroupListService().computeAvatar,
                        heroTag: 'avatar_${currentModel.peerId}',
                      )
                    : Avatar(
                        imgUri: currentModel.avatar,
                        width: 56,
                        height: 56,
                        heroTag: 'avatar_${currentModel.peerId}',
                      ),
              ),
            ),

            // 12pt 不是随手取的：分隔线按 16(左padding)+56(头像)+12 = 84 起画
            // （conversation_page)。这里给 14 的话文字左缘和分隔线差 2pt。
            AppSpacing.horizontalMedium,

            // 内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题与时间
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildTitle(currentModel, theme, isDark)),
                      _buildTime(currentModel, theme, isDark),
                    ],
                  ),
                  AppSpacing.verticalTiny,
                  // 消息预览
                  Row(
                    children: [
                      // 在制中（发送中 / 待重试）均显示进度指示，
                      // 待重试不再误显示为彻底失败。
                      if (IMBoyMessageStatus.isInFlightStatus(
                        currentModel.lastMsgStatus,
                      ))
                        const Padding(
                          padding: EdgeInsets.only(right: AppSpacing.tiny),
                          child: CupertinoActivityIndicator(radius: 6),
                        ),
                      Expanded(
                        child: _buildContent(currentModel, theme, isDark),
                      ),
                      if (currentModel.isMuted > 0)
                        // 纯图标：不补 semanticLabel 的话读屏用户完全不知道
                        // 这个会话已设免打扰。
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.small,
                          ),
                          child: Icon(
                            CupertinoIcons.bell_slash_fill,
                            size: 12,
                            color: AppColors.iosGray3,
                            semanticLabel: context.t.common.muteNotifications,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(
    ConversationModel currentModel,
    ThemeData theme,
    bool isDark,
  ) {
    // 末档原本是 `peerId.toString()`，把 TSID 直接渲染给用户。
    // 判据与兜底已收口到 ConversationModel.displayTitle —— 会话列表、搜索过滤、
    // 跳转参数、聊天页原本各写一遍，写歪一处就漏一条路径。
    String displayTitle = currentModel.displayTitle;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            displayTitle,
            style: context
                .textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                )
                .copyWith(letterSpacing: -0.4),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // 昵称先 ellipsis，徽章不压缩（透明 AI 披露）
        if (_peerAccountType > 0) ...[
          AppSpacing.horizontalTiny,
          BotBadge(accountType: _peerAccountType),
        ],
      ],
    );
  }

  Widget _buildTime(
    ConversationModel currentModel,
    ThemeData theme,
    bool isDark,
  ) {
    if (currentModel.lastTime <= 0) return const SizedBox.shrink();

    // 不画 disclosure chevron：整行都可点，箭头传达不了额外信息，
    // 只是占宽度、和时间挤在一起。微信 / Telegram / iMessage 的会话列表
    // 都没有这个箭头。
    return Text(
      DateTimeHelper.lastTimeFmt(currentModel.lastTime),
      style: context
          .textStyle(
            FontSizeType.footnote,
            color: AppColors.iosGray,
            fontWeight: FontWeight.w400,
          )
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }

  Widget _buildContent(
    ConversationModel currentModel,
    ThemeData theme,
    bool isDark,
  ) {
    String content = currentModel.content;
    TextStyle contentStyle = context
        .textStyle(FontSizeType.subheadline, color: AppColors.iosGray)
        .copyWith(height: 1.3, letterSpacing: -0.2);

    if (content.contains('_color_red_')) {
      List<String> parts = content.split('_color_red_');
      return RichText(
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
