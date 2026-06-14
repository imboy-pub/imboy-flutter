/// ImBoy 消息组件统一间距常量
///
/// 基于 Material Design 3 设计规范
/// 使用 4dp 作为基础单位，确保视觉一致性
///
/// @author ImBoy UI/UX Team
/// @since 2026-01-09
library;

import 'package:flutter/material.dart';

/// 消息组件统一间距系统
///
/// 设计原则：
/// - 使用 4dp 作为基础单位（Material 3 标准）
/// - 统一所有消息类型的间距值
/// - 确保视觉一致性和可维护性
class MessageSpacing {
  // ========================================
  // 基础单位
  // ========================================

  /// 基础间距单位（Material 3 标准）
  static const double unit = 4.0;

  // ========================================
  // 消息气泡外边距
  // ========================================

  /// 消息水平外边距（2 units）
  static const double messageHorizontalMargin = 8.0;

  /// 消息垂直外边距（1 unit）
  static const double messageVerticalMargin = 4.0;

  /// 消息外边距统一 EdgeInsets
  static const EdgeInsets messageMargin = EdgeInsets.symmetric(
    horizontal: messageHorizontalMargin,
    vertical: messageVerticalMargin,
  );

  // ========================================
  // 消息气泡内边距（统一为 12dp）
  // ========================================

  /// 消息气泡内边距（3 units）- 统一标准
  static const double bubblePadding = 12.0;

  /// 消息气泡水平内边距（3 units）
  static const double bubblePaddingHorizontal = 12.0;

  /// 消息气泡垂直内边距（2 units）
  /// 收紧为 8pt，对齐 iMessage 紧凑视觉密度
  static const double bubblePaddingVertical = 8.0;

  /// 消息气泡内边距统一 EdgeInsets
  static const EdgeInsets bubblePaddingAll = EdgeInsets.all(bubblePadding);

  /// 消息气泡内边距（对称）EdgeInsets
  static const EdgeInsets bubblePaddingSymmetric = EdgeInsets.symmetric(
    horizontal: bubblePaddingHorizontal,
    vertical: bubblePaddingVertical,
  );

  // ========================================
  // 引用消息间距
  // ========================================

  /// 引用容器外边距（3 units）
  static const double quoteContainerMargin = 12.0;

  /// 引用容器内边距（3 units）
  static const double quoteContainerPadding = 12.0;

  /// 引用内容内边距（3 units）
  static const double quoteContentPadding = 12.0;

  /// 引用竖条与内容间距（3 units）
  static const double quoteBarSpacing = 12.0;

  /// 引用容器外边距 EdgeInsets
  static const EdgeInsets quoteContainerMarginAll = EdgeInsets.only(
    left: quoteContainerMargin,
    right: quoteContainerMargin,
    bottom: quoteContainerMargin,
  );

  /// 引用内容内边距 EdgeInsets
  static const EdgeInsets quoteContentPaddingAll = EdgeInsets.all(
    quoteContentPadding,
  );

  // ========================================
  // 组件间距
  // ========================================

  /// 图标与文本间距（3 units）
  static const double iconSpacing = 12.0;

  /// 状态图标与消息间距（1 unit）
  static const double statusIconSpacing = 4.0;

  /// 头像与消息间距（2 units）
  static const double avatarSpacing = 8.0;

  /// 音频波形与时长标签间距（3 units）
  static const double waveformSpacing = 12.0;

  /// 音频播放按钮与波形间距（3 units）
  static const double playButtonSpacing = 12.0;

  // ========================================
  // 特殊组件间距
  // ========================================

  /// 播放按钮内边距（2 units）
  static const double playButtonPadding = 8.0;

  /// 时长标签内边距
  static const EdgeInsets durationLabelPadding = EdgeInsets.symmetric(
    horizontal: 6.0,
    vertical: 2.0,
  );

  /// 位置消息内边距（2 units）
  static const double locationPadding = 8.0;

  /// 位置消息标题内边距（2 units）
  static const EdgeInsets locationTitlePadding = EdgeInsets.only(
    left: locationPadding,
    right: locationPadding,
    top: locationPadding,
  );

  /// 位置消息地址内边距（2 units）
  static const EdgeInsets locationAddressPadding = EdgeInsets.only(
    left: locationPadding,
    bottom: locationPadding,
  );

  /// 未读提示外边距（2 units）
  static const double unreadIndicatorMargin = 8.0;

  // ========================================
  // 圆角系统
  // ========================================

  /// 主气泡圆角（5 units）- iOS 17+ iMessage 标准
  /// 对齐 DESIGN.md 第 9.1 章：气泡主圆角 20pt
  static const double bubbleBorderRadius = 20.0;

  /// 方向指示圆角（1 unit）- 右下角/左下角小圆角
  static const double bubbleDirectionRadius = 4.0;

  /// 引用容器圆角（2 units）
  static const double quoteBorderRadius = 8.0;

  /// 视频缩略图圆角（3 units）
  static const double thumbnailBorderRadius = 12.0;

  /// 图片消息圆角（3.5 units）
  /// 统一单图 / 九宫格多图，对齐 iMessage 风格
  static const double imageBorderRadius = 14.0;

  /// 音频播放按钮圆角（完全圆形）
  static const double playButtonBorderRadius = 20.0; // 40dp 直径的一半

  /// 播放按钮边框宽度
  static const double playButtonBorderWidth = 1.5;

  /// 时长标签圆角（1 unit）
  static const double durationLabelBorderRadius = 4.0;

  // ========================================
  // 尺寸系统
  // ========================================

  /// 播放按钮尺寸（10 units）
  static const double playButtonSize = 40.0;

  /// 播放按钮图标尺寸（5 units）
  static const double playButtonIconSize = 20.0;

  /// 波形高度（8 units）
  static const double waveformHeight = 32.0;

  /// 波形间距（0.5 unit）
  static const double waveformSpacingValue = 2.0;

  /// 波形粗细（约 0.375 unit）
  static const double waveformThickness = 1.5;

  /// 视频缩略图高度（50 units）
  static const double thumbnailHeight = 200.0;

  /// 视频播放按钮尺寸（14 units）
  static const double videoPlayButtonSize = 56.0;

  /// 视频播放按钮图标尺寸（8 units）
  static const double videoPlayButtonIconSize = 32.0;

  /// 状态图标尺寸（4 units）
  static const double statusIconSize = 16.0;

  /// 未读红点尺寸（2 units）
  static const double unreadIndicatorSize = 8.0;

  // ========================================
  // 阴影层级（Material 3 Elevation）
  // ========================================

  /// 发送消息阴影（elevation 2）
  static const double sentMessageElevation = 2.0;

  /// 接收消息阴影（elevation 1）
  static const double receivedMessageElevation = 1.0;

  /// 播放按钮阴影（elevation 1）
  static const double playButtonElevation = 1.0;

  // ========================================
  // 辅助方法
  // ========================================

  /// 根据是否为发送者返回对应的气泡圆角。
  ///
  /// 方向圆角：发送方 topRight 小角（尾巴指向自己），接收方 topLeft 小角（指向对方），
  /// 其余三角为大圆角。与 message_bubble_style._getBubbleBorderRadius 设计一致。
  static BorderRadius getBubbleBorderRadius(bool isSentByMe) {
    const big = Radius.circular(bubbleBorderRadius);
    const small = Radius.circular(bubbleDirectionRadius);
    return isSentByMe
        ? const BorderRadius.only(
            topLeft: big,
            topRight: small,
            bottomLeft: big,
            bottomRight: big,
          )
        : const BorderRadius.only(
            topLeft: small,
            topRight: big,
            bottomLeft: big,
            bottomRight: big,
          );
  }

  /// 根据是否为发送者返回对应的阴影效果
  static List<BoxShadow> getBubbleBoxShadows(bool isSentByMe, Color bgColor) {
    return [
      BoxShadow(
        color: bgColor.withValues(alpha: isSentByMe ? 0.1 : 0.05),
        blurRadius: isSentByMe ? 4.0 : 2.0,
        offset: const Offset(0, 1),
      ),
    ];
  }
}
