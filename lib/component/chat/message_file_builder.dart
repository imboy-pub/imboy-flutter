import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/message.dart' show confirmOpenFile;
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/message_model.dart';

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
    final String filename = metadata['name'] ?? metadata['filename'] ?? '未知文件';
    final int size = metadata['size'] ?? 0;
    final String uri = metadata['uri'] ?? '';
    final bool isSentByMe = message.authorId == user.id;

    return GestureDetector(
      onTap: () {
        if (uri.isNotEmpty) {
          confirmOpenFile(context, uri);
        }
      },
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSentByMe ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatBytes(size),
                    style: TextStyle(
                      fontSize: 12,
                      color: (isSentByMe ? Colors.white : Colors.black54)
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isSentByMe ? Colors.white : Colors.blue)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insert_drive_file,
                color: isSentByMe ? Colors.white : Colors.blue,
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
