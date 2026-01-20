import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 消息气泡样式配置类
/// 提供现代化的消息气泡样式设计
class MessageBubbleStyle {
  MessageBubbleStyle._();

  /// 获取优化后的消息气泡装饰
  static BoxDecoration getBubbleDecoration({
    required bool isSentByMe,
    MessageGroupStatus? groupStatus,
    bool isHighlighted = false,
  }) {
    final theme = ThemeManager.instance;
    final isDark = theme.isDarkMode;

    // 根据消息位置确定圆角
    BorderRadius borderRadius = _getBubbleBorderRadius(
      isSentByMe: isSentByMe,
      groupStatus: groupStatus,
    );

    // 根据发送方确定颜色
    Color bubbleColor = isSentByMe
        ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50))
        : (isDark ? const Color(0xFF424242) : const Color(0xFFF5F5F5));

    // 高亮状态
    if (isHighlighted) {
      bubbleColor = isDark
          ? const Color(0xFF1976D2).withValues(alpha: 0.3)
          : const Color(0xFF2196F3).withValues(alpha: 0.2);
    }

    return BoxDecoration(
      color: bubbleColor,
      borderRadius: borderRadius,
      boxShadow: _getBubbleShadow(isDark),
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

  /// 获取消息气泡阴影
  static List<BoxShadow> _getBubbleShadow(bool isDark) {
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.1),
        blurRadius: 4,
        offset: const Offset(0, 2),
        spreadRadius: 0,
      ),
    ];
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
    if (!isSentByMe) return Colors.transparent;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (status) {
      case MessageStatus.sending:
        return isDark ? Colors.white54 : Colors.black54;
      case MessageStatus.delivered:
        return isDark ? Colors.white70 : Colors.black87;
      case MessageStatus.read:
        return const Color(0xFF4CAF50);
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
