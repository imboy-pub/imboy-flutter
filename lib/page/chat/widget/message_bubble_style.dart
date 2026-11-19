import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

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

    // 高亮/选中态：实色主题气泡 token（DSN-05 S1：原 primary@0.2 半透明
    // 叠底复合 #C9D9F3 与正文白字仅 1.333:1；实色 token 与白字 ≥5.35:1）。
    if (isHighlighted) {
      bubbleColor = isDark
          ? AppColors.darkSentMessageBackground
          : AppColors.lightSentMessageBackground;
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
    const baseRadius = Radius.circular(AppRadius.xLarge);
    const smallRadius = Radius.circular(AppRadius.tiny);

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

    return context
        .textStyle(
          // DSN-04 O1：聊天正文 17pt 合同（DESIGN.md §chat），与
          // ChatTypography.bodyLarge(17,w400) 对齐；原 medium(16) 偏离合同。
          FontSizeType.body,
          fontWeight: FontWeight.w400,
          color: isSentByMe
              ? (theme.brightness == Brightness.dark
                    ? AppColors.sentMessageText
                    : AppColors.onPrimary)
              : AppColors.getTextColor(theme.brightness),
        )
        .copyWith(height: 1.4);
  }

  /// 获取时间戳样式
  ///
  /// 必须按收发分色（2026-11-19 属主反馈"看不清"）：发送气泡底色是
  /// primaryDark(#1565C0)/darkSent(#1D5EC2)，原先统一用深色次级文字
  /// @54% → 深灰叠深蓝，对比度远低于 WCAG AA。发送侧改走 onPrimary
  /// 白 @90%（亮 5.75:1 / 暗 ≈4.8:1 过 AA）。
  /// 接收侧原 54% 同样不达标（亮 2.9:1 / 暗 2.55:1，存量问题），提到
  /// 亮 @75%（≈5.2:1）/ 暗 @95%（≈4.9:1）——仍低于正文层级，保持"次级"观感。
  static TextStyle getTimestampStyle({
    required BuildContext context,
    required bool isSentByMe,
  }) {
    final brightness = Theme.of(context).brightness;
    final Color color;
    if (isSentByMe) {
      color = AppColors.onPrimary.withValues(alpha: 0.9);
    } else {
      color = AppColors.getTextColor(
        brightness,
        isSecondary: true,
      ).withValues(alpha: brightness == Brightness.dark ? 0.95 : 0.75);
    }
    return context.textStyle(
      FontSizeType.small,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  /// 获取消息状态图标颜色
  static Color getStatusIconColor({
    required bool isSentByMe,
    required BuildContext context,
    MessageStatus status = MessageStatus.delivered,
  }) {
    if (!isSentByMe) return AppColors.transparent;

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final secondary = AppColors.getTextColor(brightness, isSecondary: true);

    switch (status) {
      case MessageStatus.sending:
        return secondary.withValues(alpha: 0.54);
      case MessageStatus.delivered:
        return secondary.withValues(alpha: isDark ? 0.70 : 0.87);
      case MessageStatus.read:
        // 已读指示走 iOS 系统绿（与品牌蓝区分），DESIGN.md 语义色
        return isDark ? AppColors.iosGreenDark : AppColors.iosGreen;
      default:
        return secondary.withValues(alpha: 0.54);
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
