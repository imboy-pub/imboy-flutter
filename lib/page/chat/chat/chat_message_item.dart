import 'dart:async';

import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ChatMessage, Username;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:imboy/component/chat/performance_monitor.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/avatar.dart' as imboy_ui;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selection.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/page/chat/widget/burn_badge.dart';
import 'package:imboy/modules/messaging/domain/policy/message_bubble_rules.dart';
import 'package:imboy/modules/messaging/domain/policy/burn_read_at_rules.dart';
import 'package:imboy/modules/messaging/domain/policy/visibility_read_rules.dart';
// 多选可选性 traits 提取（W5-G1 G1-7 抽离至 services，本文件仍消费）。
import 'package:imboy/page/chat/chat/services/message_selection_traits.dart';
import 'package:imboy/page/chat/chat/utils/message_status_icon_rules.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

// W5-G1 G1-7 兼容出口：messageSelectionTraitsOf 已移至 services/
// message_selection_traits.dart；此 re-export 让既有 import 本文件的调用方
//（chat_page、integration_test helpers 等）零改动继续解析。
export 'package:imboy/page/chat/chat/services/message_selection_traits.dart';

/// 切换一条消息的多选选中态，并按 W1-A 契约给出用户反馈。
///
/// - 取消已选：始终成功（即使消息已变为不可选）；
/// - 不可选消息：返回 reason，静默（勾选框已置灰表达状态）；
/// - 第 101 条：返回 [MessageSelectionReason.limitExceeded] 并 toast 上限。
///
/// 返回 null=成功，非 null=被拒 reason code。
String? toggleMessageSelectionWithFeedback(
  WidgetRef ref,
  String conversationUk3,
  Message message,
) {
  if (conversationUk3.isEmpty) {
    return MessageSelectionReason.inactive;
  }
  final reason = ref
      .read(messageSelectionProvider(conversationUk3).notifier)
      .toggle(message.id, messageSelectionTraitsOf(message));
  if (reason == MessageSelectionReason.limitExceeded) {
    AppLoading.showToast(
      t.chat.multiSelectLimit(
        count: MessageSelectionNotifier.maxSelectionCount,
      ),
    );
  }
  return reason;
}

/// 单条聊天消息容器 Widget。
///
/// 负责渲染消息布局（头像、状态图标、阅后即焚徽章）以及
/// 可视阈值已读推进逻辑，从 ChatPageState.chatMessageBuilder 闭包提取。
class ChatMessageItem extends ConsumerWidget {
  const ChatMessageItem({
    super.key,
    required this.message,
    required this.index,
    required this.animation,
    required this.child,
    required this.currentUser,
    required this.targetMsgId,
    required this.targetMessageKey,
    required this.burnTicker,
    required this.performanceMonitor,
    required this.readDelayTimers,
    required this.readCommitted,
    required this.onMessageStatusTap,
    required this.onVisibleRead,
    this.isRemoved,
    this.groupStatus,
    this.peerId = '',
    this.peerAvatar = '',
    this.conversationUk3 = '',
  });

  final Message message;
  final int index;
  final Animation<double> animation;
  final Widget child;
  final User currentUser;
  final String targetMsgId;
  final GlobalKey targetMessageKey;
  final Stream<int> burnTicker;
  final ChatPerformanceMonitor performanceMonitor;
  final Map<String, Timer> readDelayTimers;
  final Set<String> readCommitted;
  final void Function(BuildContext ctx, Message msg) onMessageStatusTap;

  /// Called when the message becomes sufficiently visible; parent handles
  /// the actual markAsRead + burnReadAt side-effects.
  final Future<void> Function(Message message) onVisibleRead;
  final bool? isRemoved;
  final MessageGroupStatus? groupStatus;

  /// c2c 对方 uid/头像（object_key）。群消息 authorId ≠ peerId 时回退占位。
  final String peerId;
  final String peerAvatar;

  /// 多选状态归属会话（messageSelectionProvider family key）。
  ///
  /// 空串（默认/旧调用方）= 多选 UI 完全不渲染（零 UI 变化）；非空时
  /// 本条消息行在多选激活后自绘 44×44pt 勾选框并按 provider 状态着色 ——
  /// 状态按 message.id 从 provider 读取，滚动复用/重建不会串选。
  final String conversationUk3;

  bool _isBurnMessage(Message msg) {
    final meta = msg.metadata;
    if (meta == null) return false;
    return meta['burn_enabled'] == true || meta['burn_after_ms'] != null;
  }

  int _burnAfterMsFromMessage(Message msg) {
    final ms = msg.metadata?['burn_after_ms'];
    if (ms is int) return ms;
    if (ms is String) return int.tryParse(ms) ?? 30000;
    return 30000;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeProvider.notifier);

    // 多选状态（chat_multi_select_v1）：conversationUk3 为空（旧调用方 /
    // flag 未开启的布局路径）时完全不引入多选 UI。状态按 message.id 从
    // provider 读取 —— 滚动复用换 message 重建时自然取到新 id 的选中态，
    // 不会串选。
    final MessageSelectionState? selectionState = conversationUk3.isEmpty
        ? null
        : ref.watch(messageSelectionProvider(conversationUk3));
    final bool selectionActive = selectionState?.active ?? false;
    final bool selectionChecked = selectionState?.contains(message.id) ?? false;
    // 置灰判定：不可选（系统行/发送中/E2EE 失败占位等）灰显且不可点；
    // 已选消息保持可用 —— 取消勾选不受可选性限制（W1-A toggle 契约）。
    final bool selectionSelectable =
        selectionActive &&
        (selectionChecked ||
            evaluateMessageSelectability(messageSelectionTraitsOf(message))
                .selectable);

    // 目标消息绑定 GlobalKey 以便定位
    Key? itemKey;
    if (targetMsgId.isNotEmpty && message.id == targetMsgId) {
      itemKey = targetMessageKey;
    }

    final isSystemMessage = message.authorId == 'system';
    final isFirstInGroup = groupStatus?.isFirst ?? true;
    final isLastInGroup = groupStatus?.isLast ?? true;
    final shouldShowAvatar = shouldShowMessageAvatar(
      isSystemMessage: isSystemMessage,
      isLastInGroup: isLastInGroup,
      isRemoved: isRemoved,
    );
    final isCurrentUser = message.authorId == currentUser.id;
    final shouldShowUsername = shouldShowMessageUsername(
      isSystemMessage: isSystemMessage,
      isFirstInGroup: isFirstInGroup,
      isRemoved: isRemoved,
    );

    final statusSpec = resolveMessageStatusIcon(message.status);
    Widget? statusIcon;
    if (statusSpec.hasIcon) {
      final color = statusSpec.colorKey == 'sendMessageBg'
          ? themeNotifier.getChatColor(statusSpec.colorKey!)
          : themeNotifier.getThemeColor(statusSpec.colorKey!);
      statusIcon = Icon(
        statusSpec.iconData,
        size: 16,
        color: color,
        semanticLabel: statusSpec.semanticLabel,
      );
    }

    Widget? avatar;
    if (shouldShowAvatar) {
      // flutter_chat_ui.Avatar 直接裸加载 imageSource，无法处理项目的
      // avatar object_key（需 presign 授权）；改用项目 Avatar（内置授权链）。
      final avatarUri = isCurrentUser
          ? UserRepoLocal.to.current.avatar
          : (message.authorId == peerId ? peerAvatar : '');
      avatar = Padding(
        padding: EdgeInsets.only(
          left: isCurrentUser ? 8 : 0,
          right: isCurrentUser ? 0 : 8,
        ),
        child: imboy_ui.Avatar(imgUri: avatarUri, width: 40, height: 40),
      );
    } else if (!isSystemMessage) {
      avatar = const SizedBox(width: 40);
    }

    // BUG#139：发送方自己的阅后即焚消息倒计时从发送时间起算
    // （销毁逻辑同语义，见 ChatBurnService.ensureBurnTimerForItem）
    final int metaReadAt = parseBurnReadAtMs(message.metadata);
    final int badgeReadAtMs = metaReadAt > 0
        ? metaReadAt
        : (isCurrentUser && message.createdAt != null
              ? message.createdAt!.millisecondsSinceEpoch
              : 0);

    final burnBadge = _isBurnMessage(message)
        ? BurnBadge(
            isSentByMe: isCurrentUser,
            burnAfterMs: _burnAfterMsFromMessage(message),
            burnReadAtMs: badgeReadAtMs,
            burnTicker: burnTicker,
          )
        : null;

    Widget messageBody = burnBadge == null
        ? child
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              child,
              const SizedBox(height: 2),
              Padding(
                padding: EdgeInsets.only(
                  right: isCurrentUser ? 2 : 0,
                  left: isCurrentUser ? 0 : 2,
                ),
                child: burnBadge,
              ),
            ],
          );

    Widget composedChild;
    if (isCurrentUser && statusIcon != null) {
      final tappableStatus = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onMessageStatusTap(context, message),
        child: statusIcon,
      );
      composedChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: messageBody),
          AppSpacing.horizontalTiny,
          tappableStatus,
        ],
      );
    } else {
      composedChild = messageBody;
    }

    final Widget chatMsg = ChatMessage(
      key: itemKey,
      message: message,
      index: index,
      animation: animation,
      isRemoved: isRemoved,
      groupStatus: groupStatus,
      topWidget: shouldShowUsername
          ? Padding(
              padding: EdgeInsets.only(
                bottom: 4,
                left: isCurrentUser ? 0 : 48,
                right: isCurrentUser ? 48 : 0,
              ),
              child: Username(userId: message.authorId),
            )
          : null,
      // 多选模式：所有消息行的 leading 统一替换为勾选框（头像从 trailing
      // 保留）；非多选路径保持原布局 —— flag 关闭/未激活时零 UI 变化。
      leadingWidget: selectionActive
          ? _MessageSelectCheckbox(
              messageId: message.id,
              checked: selectionChecked,
              enabled: selectionSelectable,
              onTap: () => toggleMessageSelectionWithFeedback(
                ref,
                conversationUk3,
                message,
              ),
            )
          : !isCurrentUser
          ? avatar
          : isSystemMessage
          ? null
          : const SizedBox(width: 40),
      trailingWidget: isCurrentUser
          ? avatar
          : isSystemMessage
          ? null
          : const SizedBox(width: 40),
      receivedMessageScaleAnimationAlignment: isSystemMessage
          ? Alignment.center
          : Alignment.centerLeft,
      receivedMessageAlignment: isSystemMessage
          ? AlignmentDirectional.center
          : AlignmentDirectional.centerStart,
      horizontalPadding: isSystemMessage ? 0 : 8,
      child: composedChild,
    );

    // 多选模式下的不可选消息：整行置灰（含勾选框），不可点。
    final Widget effectiveMsg = selectionActive && !selectionSelectable
        ? Opacity(opacity: 0.45, child: chatMsg)
        : chatMsg;

    final s = UserRepoLocal.to.setting;
    if (!s.enableVisibilityRead) {
      return effectiveMsg;
    }

    final double fractionThreshold = normalizeVisibilityFraction(
      s.visibilityReadFraction,
    );
    final int delayMs = normalizeVisibilityDelayMs(s.visibilityReadDelayMs);

    return VisibilityDetector(
      key: Key('msg_vis_${message.id}'),
      onVisibilityChanged: (info) {
        final fraction = info.visibleFraction;
        if (fraction > 0.1) {
          performanceMonitor.markMessageVisible(message.id);
        } else {
          performanceMonitor.markMessageInvisible(message.id);
        }

        final isIncoming = message.authorId != currentUser.id;
        if (!isIncoming) return;
        if (readCommitted.contains(message.id)) return;

        if (fraction >= fractionThreshold) {
          readDelayTimers[message.id]?.cancel();
          readDelayTimers[message.id] = Timer(
            Duration(milliseconds: delayMs),
            () async {
              if (performanceMonitor.isMessageVisible(message.id)) {
                await onVisibleRead(message);
              }
            },
          );
        } else {
          readDelayTimers[message.id]?.cancel();
          readDelayTimers.remove(message.id);
        }
      },
      child: effectiveMsg,
    );
  }
}

/// 多选勾选框（chat_multi_select_v1 / W2-E）。
///
/// - 视觉 22pt 图标 + **44×44pt 触达区**（DESIGN.md §13.2 Hard Rule 1）；
/// - [enabled]=false（不可选消息）：置灰且不响应点击；
/// - [checked]=true 时恒可用（取消已选不受可选性限制）。
class _MessageSelectCheckbox extends StatelessWidget {
  const _MessageSelectCheckbox({
    required this.messageId,
    required this.checked,
    required this.enabled,
    required this.onTap,
  });

  /// 所属消息 ID：构成稳定 Key（测试/W3-K 集成测试定位用）。
  final String messageId;
  final bool checked;
  final bool enabled;
  final VoidCallback onTap;

  /// 触达区尺寸（≥44×44pt）。
  static const double kTouchTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color color = checked
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: enabled ? 0.35 : 0.2);
    return Semantics(
      button: true,
      enabled: enabled,
      checked: checked,
      // W5-G1 G1-3：无障碍标签（读屏播报「多选」而非无声按钮）。
      label: t.chat.multiSelect,
      child: GestureDetector(
        key: ValueKey('multi_select_check_$messageId'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: kTouchTarget,
          height: kTouchTarget,
          child: Center(
            child: Icon(
              checked
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              // DESIGN.md §13.2 的 22pt 视觉图标：AppSizes 无 22 档 token
              // （iconSizeSmall=20 / iconSizeMedium=24），此处保留字面量。
              size: 22,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
