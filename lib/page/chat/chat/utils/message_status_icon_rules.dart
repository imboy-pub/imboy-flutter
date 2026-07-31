/// 消息状态图标决策 —— 纯函数（仅依赖 flutter/material + flutter_chat_core + i18n）
///
/// slice-C-11: `chat_page.dart` L1966-1998 内联的 MessageStatus switch
/// 依赖 MessageStatus 枚举返回 iconData + colorKey（字符串键），
/// 颜色解析留给调用方的 themeNotifier，保持纯函数无 Widget 依赖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 消息状态图标描述符。
///
/// - [iconData]  null 表示不显示图标（状态不明 / 未发送）
/// - [colorKey]  null 表示不显示图标；否则为 themeNotifier 颜色键
///   （'textSecondary' / 'primary' / 'sendMessageBg' / 'error'）
/// - [semanticLabel] 读屏标签；纯图标无文字，缺它则 sending/sent/seen/error
///   四态对读屏用户完全不可感知
class MessageStatusIconSpec {
  const MessageStatusIconSpec({
    required this.iconData,
    required this.colorKey,
    this.semanticLabel,
  });

  final IconData? iconData;
  final String? colorKey;
  final String? semanticLabel;

  /// 是否应显示图标。
  bool get hasIcon => iconData != null;
}

/// 根据 [MessageStatus] 解析对应的图标规格。
///
/// 返回值的 [MessageStatusIconSpec.colorKey] 对应
/// `themeNotifier.getThemeColor` / `getChatColor` 的颜色键：
/// - 'textSecondary' → `getThemeColor`
/// - 'primary'       → `getThemeColor`
/// - 'sendMessageBg' → `getChatColor`（聊天专用颜色）
/// - 'error'         → `getThemeColor`
MessageStatusIconSpec resolveMessageStatusIcon(MessageStatus? status) {
  return switch (status) {
    MessageStatus.sending => MessageStatusIconSpec(
      iconData: Icons.access_time,
      colorKey: 'textSecondary',
      semanticLabel: t.chat.chatStatusSending,
    ),
    MessageStatus.sent => MessageStatusIconSpec(
      iconData: Icons.done_all,
      colorKey: 'primary',
      semanticLabel: t.chat.chatStatusSent,
    ),
    MessageStatus.delivered => MessageStatusIconSpec(
      iconData: Icons.done_all,
      colorKey: 'primary',
      semanticLabel: t.chat.chatStatusDelivered,
    ),
    MessageStatus.seen => MessageStatusIconSpec(
      iconData: Icons.done_all,
      colorKey: 'sendMessageBg',
      semanticLabel: t.chat.chatStatusSeen,
    ),
    MessageStatus.error => MessageStatusIconSpec(
      iconData: Icons.error_outline,
      colorKey: 'error',
      semanticLabel: t.common.chatStatusFailed,
    ),
    _ => const MessageStatusIconSpec(iconData: null, colorKey: null),
  };
}
