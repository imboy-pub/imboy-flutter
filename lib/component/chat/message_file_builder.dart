import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/component/chat/message.dart' show confirmOpenFile;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 按扩展名给文件挑图标。
///
/// 原来所有文件都是同一个 `doc_fill`——一屏里 PDF、压缩包、表格长得一模一样，
/// 用户只能靠读文件名区分。这里只做粗分类，不追求覆盖所有扩展名。
IconData _iconForFile(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return CupertinoIcons.doc_fill;
  final ext = filename.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'pdf' => CupertinoIcons.doc_richtext,
    'doc' || 'docx' || 'rtf' || 'odt' => CupertinoIcons.doc_text_fill,
    'xls' || 'xlsx' || 'csv' || 'numbers' => CupertinoIcons.table_fill,
    'ppt' || 'pptx' || 'key' => CupertinoIcons.rectangle_on_rectangle,
    'zip' || 'rar' || '7z' || 'tar' || 'gz' => CupertinoIcons.archivebox_fill,
    'png' ||
    'jpg' ||
    'jpeg' ||
    'gif' ||
    'webp' ||
    'heic' ||
    'bmp' => CupertinoIcons.photo_fill,
    'mp4' || 'mov' || 'avi' || 'mkv' || 'webm' => CupertinoIcons.videocam_fill,
    'mp3' || 'wav' || 'aac' || 'flac' || 'm4a' => CupertinoIcons.music_note,
    'apk' || 'ipa' || 'dmg' || 'exe' => CupertinoIcons.cube_box_fill,
    _ => CupertinoIcons.doc_fill,
  };
}

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
    final String filename = parseModelString(
      metadata['name'] ?? metadata['filename'],
      defaultValue: t.chat.unknownFile,
    );
    final int size = parseModelInt(metadata['size']);
    final String uri = parseModelString(metadata['uri']);
    final bool isSentByMe = message.authorId == user.id;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isSentByMe
        ? AppColors.onPrimary
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final subTextColor = isSentByMe
        ? AppColors.overlayWhite70
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
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatBytes(size),
                    style: context.textStyle(
                      FontSizeType.small,
                      color: subTextColor,
                    ),
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
                    ? AppColors.mediaScrimWhite.withValues(alpha: 0.2)
                    : AppColors.getIosBlue(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForFile(filename),
                color: isSentByMe
                    ? AppColors.onPrimary
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
