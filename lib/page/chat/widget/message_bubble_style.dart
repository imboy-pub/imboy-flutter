import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 消息气泡样式配置类
/// 提供现代化的消息气泡样式设计
class MessageBubbleStyle {
  MessageBubbleStyle._();

  /// 获取优化后的消息气泡装饰
  static BoxDecoration getBubbleDecoration({
    required BuildContext context,
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
    bool isHighlighted = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 根据消息位置确定圆角
    BorderRadius borderRadius = _getBubbleBorderRadius(
      isSentByMe: isSentByMe,
      groupStatus: groupStatus,
    );

    // DESIGN.md 双蓝策略：发送=品牌蓝 / 接收=surface token（去 Material 绿残留）
    Color bubbleColor = isSentByMe
        ? (isDark
              ? AppColors.darkSentMessageBackground
              : AppColors.lightSentMessageBackground)
        : (isDark
              ? AppColors.darkReceivedMessageBackground
              : AppColors.lightReceivedMessageBackground);

    // 高亮状态：统一走品牌蓝半透明，避免双蓝色标失控
    if (isHighlighted) {
      bubbleColor = AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2);
    }

    return BoxDecoration(
      color: bubbleColor,
      borderRadius: borderRadius,
      // DESIGN.md §9.1 聊天气泡：iOS 气泡 **不带阴影**；
      // 亮色用 0.5pt iosGray5 边框（仅接收方），暗色不加边框
    );
  }

  /// 获取消息气泡圆角设计
  static BorderRadius _getBubbleBorderRadius({
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
  }) {
    const baseRadius = Radius.circular(18.0);
    const smallRadius = Radius.circular(4.0);

    // 根据消息分组状态调整圆角
    if (groupStatus != null) {
      if (groupStatus.isFirst) {
        return isSentByMe
            ? const BorderRadius.only(
                topLeft: baseRadius,
                topRight: baseRadius,
                bottomLeft: baseRadius,
                bottomRight: smallRadius,
              )
            : const BorderRadius.only(
                topLeft: baseRadius,
                topRight: baseRadius,
                bottomLeft: smallRadius,
                bottomRight: baseRadius,
              );
      } else if (groupStatus.isMiddle) {
        return isSentByMe
            ? const BorderRadius.only(
                topLeft: baseRadius,
                topRight: smallRadius,
                bottomLeft: baseRadius,
                bottomRight: smallRadius,
              )
            : const BorderRadius.only(
                topLeft: smallRadius,
                topRight: baseRadius,
                bottomLeft: smallRadius,
                bottomRight: baseRadius,
              );
      } else if (groupStatus.isLast) {
        return isSentByMe
            ? const BorderRadius.only(
                topLeft: baseRadius,
                topRight: smallRadius,
                bottomLeft: baseRadius,
                bottomRight: baseRadius,
              )
            : const BorderRadius.only(
                topLeft: smallRadius,
                topRight: baseRadius,
                bottomLeft: baseRadius,
                bottomRight: baseRadius,
              );
      }
    }

    // 默认情况（单独消息）
    return AppRadius.borderRadiusLarge;
  }

  /// 获取消息文本样式
  static TextStyle getMessageTextStyle({
    required bool isSentByMe,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: isSentByMe
          ? Colors.white
          : (isDark ? Colors.white : Colors.black87),
      height: 1.4,
    );
  }

  /// 获取时间戳样式
  static TextStyle getTimestampStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextStyle(
      fontSize: 12,
      color: isDark ? Colors.white54 : Colors.black54,
      fontWeight: FontWeight.w400,
    );
  }

  /// 获取消息状态图标颜色
  static Color getStatusIconColor({
    required bool isSentByMe,
    required BuildContext context,
    MessageStatus status = MessageStatus.delivered,
  }) {
    if (!isSentByMe) return AppColors.transparent;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case MessageStatus.sending:
        return isDark ? Colors.white54 : Colors.black54;
      case MessageStatus.delivered:
        return isDark ? Colors.white70 : Colors.black87;
      case MessageStatus.read:
        // 已读指示走 iOS 系统绿（与品牌蓝区分），DESIGN.md 语义色
        return isDark ? AppColors.iosGreenDark : AppColors.iosGreen;
      default:
        return isDark ? Colors.white54 : Colors.black54;
    }
  }
}

/// 消息状态枚举
enum MessageStatus {
  sending, // 发送中
  delivered, // 已送达
  read, // 已读
  failed, // 发送失败
}
