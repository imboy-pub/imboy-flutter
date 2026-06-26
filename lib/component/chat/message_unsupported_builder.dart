import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 不支持的消息类型构建器
///
/// 用于展示客户端无法识别或处理的消息类型
/// 显示友好的错误提示，避免显示空白或崩溃
class ImUnsupportedMessageBuilder extends StatelessWidget {
  const ImUnsupportedMessageBuilder({
    super.key,
    required this.type,
    required this.message,
    required this.user,
  });

  final String type; // C2C C2G
  final CustomMessage message;
  final User user;

  @override
  Widget build(BuildContext context) {
    // 从 metadata 获取消息类型信息
    final msgType = (message.metadata?['msg_type'] ?? 'unknown') as String;
    final originalType = (message.metadata?['original_type'] ?? '') as String;

    final displayType = msgType.isNotEmpty ? msgType : originalType;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.iosOrange,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.chat.unsupportedMessageType,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (displayType.isNotEmpty && displayType != 'unknown')
                  Text(
                    '($displayType)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UnsupportedMessageTypePlugin implements MessageTypePlugin {
  const UnsupportedMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.unsupported}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  String get type => MessageType.unsupported;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return ImUnsupportedMessageBuilder(
      type: context.type,
      message: message,
      user: context.user,
    );
  }
}
