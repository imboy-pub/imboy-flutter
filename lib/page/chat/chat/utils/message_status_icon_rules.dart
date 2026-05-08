/// 消息状态图标决策 —— 纯函数（仅依赖 flutter/material + flutter_chat_core）
///
/// slice-C-11: `chat_page.dart` L1966-1998 内联的 MessageStatus switch
/// 依赖 MessageStatus 枚举返回 iconData + colorKey（字符串键），
/// 颜色解析留给调用方的 themeNotifier，保持纯函数无 Widget 依赖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

/// 消息状态图标描述符。
///
/// - [iconData]  null 表示不显示图标（状态不明 / 未发送）
/// - [colorKey]  null 表示不显示图标；否则为 themeNotifier 颜色键
///   （'textSecondary' / 'primary' / 'sendMessageBg' / 'error'）
class MessageStatusIconSpec {
  const MessageStatusIconSpec({required this.iconData, required this.colorKey});

  final IconData? iconData;
  final String? colorKey;

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
    MessageStatus.sending => const MessageStatusIconSpec(
      iconData: Icons.access_time,
      colorKey: 'textSecondary',
    ),
    MessageStatus.sent ||
    MessageStatus.delivered => const MessageStatusIconSpec(
      iconData: Icons.done_all,
      colorKey: 'primary',
    ),
    MessageStatus.seen => const MessageStatusIconSpec(
      iconData: Icons.done_all,
      colorKey: 'sendMessageBg',
    ),
    MessageStatus.error => const MessageStatusIconSpec(
      iconData: Icons.error_outline,
      colorKey: 'error',
    ),
    _ => const MessageStatusIconSpec(iconData: null, colorKey: null),
  };
}
