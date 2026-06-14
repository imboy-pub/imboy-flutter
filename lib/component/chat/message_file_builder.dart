import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/message.dart' show confirmOpenFile;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 文件消息构建器
class MessageFileBuilder extends StatelessWidget {
  const MessageFileBuilder({
    super.key,
    required this.type,
    required this.message,
    required this.user,
  });

  final String type;
  final CustomMessage message;
  final User user;

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final String filename =
        metadata['name'] as String? ??
        metadata['filename'] as String? ??
        '未知文件';
    final int size = metadata['size'] as int? ?? 0;
    final String uri = metadata['uri'] as String? ?? '';
    final bool isSentByMe = message.authorId == user.id;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isSentByMe
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final subTextColor = isSentByMe
        ? Colors.white.withValues(alpha: 0.7)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return GestureDetector(
      onTap: () {
        if (uri.isNotEmpty) {
          confirmOpenFile(context, uri);
        }
      },
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.tiny,
          vertical: AppSpacing.tiny,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatBytes(size),
                    style: TextStyle(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSentByMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.getIosBlue(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.doc_fill,
                color: isSentByMe
                    ? Colors.white
                    : AppColors.getIosBlue(Theme.of(context).brightness),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 文件消息插件注册
class FileMessageTypePlugin implements MessageTypePlugin {
  const FileMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.file}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  String get type => MessageType.file;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return MessageFileBuilder(
      type: context.type,
      message: message,
      user: context.user,
    );
  }
}
