import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ChatMessage, Username;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:imboy/component/chat/performance_monitor.dart';
import 'package:imboy/component/ui/avatar.dart' as imboy_ui;
import 'package:imboy/page/chat/widget/burn_badge.dart';
import 'package:imboy/modules/messaging/domain/policy/message_bubble_rules.dart';
import 'package:imboy/modules/messaging/domain/policy/burn_read_at_rules.dart';
import 'package:imboy/modules/messaging/domain/policy/visibility_read_rules.dart';
import 'package:imboy/page/chat/chat/utils/message_status_icon_rules.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

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
      statusIcon = Icon(statusSpec.iconData, size: 16, color: color);
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

    final burnBadge = _isBurnMessage(message)
        ? BurnBadge(
            isSentByMe: isCurrentUser,
            burnAfterMs: _burnAfterMsFromMessage(message),
            burnReadAtMs: parseBurnReadAtMs(message.metadata),
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

    final chatMsg = ChatMessage(
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
      leadingWidget: !isCurrentUser
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

    final s = UserRepoLocal.to.setting;
    if (!s.enableVisibilityRead) {
      return chatMsg;
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
      child: chatMsg,
    );
  }
}
