import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide VideoMessageBuilder, AudioMessageBuilder;
import 'package:octo_image/octo_image.dart';
import 'package:open_file/open_file.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/store/repository/user_repo_local.dart';

import 'message_spacing.dart';
import 'message_audio_builder.dart';
import 'message_location_builder.dart';
import 'message_quote_builder.dart';
import 'message_revoked_builder.dart';
import 'message_video_builder.dart';
import 'message_visit_card_builder.dart';
import 'message_webrtc_builder.dart';
import 'package:imboy/i18n/strings.g.dart';

/// Material 3消息圆角半径 - Medium圆角 (16dp)
/// @deprecated 请使用 MessageSpacing.bubbleBorderRadius
const BorderRadius kMsgBorderRadius = BorderRadius.all(Radius.circular(16));

/// Material 3发送消息圆角 - 右下角小圆角
/// @deprecated 请使用 MessageSpacing.getBubbleBorderRadius(true)
const BorderRadius kSentMsgBorderRadius = BorderRadius.only(
  topLeft: Radius.circular(16),
  topRight: Radius.circular(4), // 小圆角表示消息方向
  bottomLeft: Radius.circular(16),
  bottomRight: Radius.circular(16),
);

/// Material 3接收消息圆角 - 左下角小圆角
/// @deprecated 请使用 MessageSpacing.getBubbleBorderRadius(false)
const BorderRadius kReceivedMsgBorderRadius = BorderRadius.only(
  topLeft: Radius.circular(4), // 小圆角表示消息方向
  topRight: Radius.circular(16),
  bottomLeft: Radius.circular(16),
  bottomRight: Radius.circular(16),
);

/// 构建自定义消息主入口
class CustomMessageBuilder extends StatelessWidget {
  const CustomMessageBuilder({
    super.key,
    required this.type, // C2C C2G
    required this.message,
  });

  final String type; // C2C C2G
  final CustomMessage message;

  @override
  Widget build(BuildContext context) {
    debugPrint(
      "> on CustomMessageBuilder msg: $type ${message.toJson().toString()}",
    );
    final user = User(
      id: UserRepoLocal.to.currentUid,
      name: UserRepoLocal.to.current.nickname,
      imageSource: UserRepoLocal.to.current.avatar,
    );
    bool isSentByMe = message.authorId == user.id;
    final theme = Theme.of(context);
    // 使用统一间距 12dp（之前是 horizontal: 10, vertical: 8）
    const padding = MessageSpacing.bubblePaddingSymmetric;
    Widget content = const SizedBox.shrink();
    try {
      // WebSocket API v2.0: 优先使用 msg_type，回退到 custom_type（兼容旧数据）
      final msgType = message.metadata?['msg_type'] ?? '';
      final customType = message.metadata?['custom_type'] ?? '';

      // 使用 msg_type 或 custom_type 来决定渲染逻辑
      final messageType = msgType.isNotEmpty ? msgType : customType;

      switch (messageType) {
        case 'revoked':
        case 'peer_revoked':
        case 'my_revoked':
          content = RevokedMessageBuilder(message: message, user: user);
          break;
        case 'webrtc_audio':
        case 'webrtc_video':
          content = WebRTCMessageBuilder(message: message, user: user);
          break;
        case 'quote':
          content = QuoteMessageBuilder(
            type: type,
            message: message,
            user: user,
          );
          break;
        case 'video':
          content = VideoMessageBuilder(message: message, user: user);
          break;
        case 'audio':
        case 'voice': // WebSocket API v2.0 使用 'voice'
          return Padding(
            padding: padding,
            child: AudioMessageBuilder(
              type: type,
              message: message,
              user: user,
            ),
          );
        case 'visit_card':
          content = VisitCardMessageBuilder(message: message, user: user);
          break;
        case 'location':
          content = LocationMessageBuilder(message: message, user: user);
          break;
        default:
          // 可以考虑一个默认的文本消息展示
          debugPrint("> on CustomMessageBuilder: 未知的消息类型: $messageType (msg_type=$msgType, custom_type=$customType)");
          break;
      }
    } catch (e, s) {
      debugPrint("> on CustomMessageBuilder e ${e.toString()}; $s");
    }

    // Material 3消息气泡样式
    final borderRadius = isSentByMe
        ? kSentMsgBorderRadius
        : kReceivedMsgBorderRadius;
    final colorScheme = theme.colorScheme;
    final backgroundColor = isSentByMe
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerLow;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        // Material 3阴影效果
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSentByMe ? 0.1 : 0.05),
            blurRadius: isSentByMe ? 4 : 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      // Material 3间距系统
      padding: padding,
      child: content,
    );
  }
}

/// 构建被引用消息Widget
Widget messageMsgWidget(BuildContext context, Message msg, {Color? txtColor}) {
  final user = User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );

  final textStyle = TextStyle(fontSize: 14.0, color: txtColor); // 使用固定字体大小

  // WebSocket API v2.0: 优先使用 msg_type，回退到 custom_type（兼容旧数据）
  final msgType = msg.metadata?['msg_type'] ?? '';
  final customType = msg.metadata?['custom_type'] ?? '';
  final messageType = msgType.isNotEmpty ? msgType : customType;

  Widget content;
  switch (messageType) {
    case 'video':
      content = VideoMessageBuilder(user: user, message: msg as CustomMessage);
      break;
    case 'audio':
    case 'voice': // WebSocket API v2.0 使用 'voice'
      return AudioMessageBuilder(
        type: msg.metadata?['type'] ?? 'C2C', // 提供默认值
        user: user,
        message: msg as CustomMessage,
        // onPlay: ,
      );
    // content = AudioMessageBuilder(
    //   type: msg.metadata?['type'] ?? 'C2C', // 提供默认值
    //   user: user,
    //   message: msg as CustomMessage,
    // );
    // break;
    case 'location':
      content = LocationMessageBuilder(
        user: user,
        message: msg as CustomMessage,
      );
      break;
    case 'quote':
      final txt = msg.metadata?['quote_text'] ?? '';
      content = Text(
        "[${t.quote}] $txt",
        style: textStyle,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      );
      break;
    default:
      // 普通消息类型
      if (msg is TextMessage) {
        content = Text(
          msg.text,
          style: textStyle,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        );
      } else if (msg is FileMessage) {
        // 防止 size 为空
        final sizeStr = msg.size == null
            ? ''
            : '(${formatBytes(msg.size!.truncate())})';
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insert_drive_file, size: 16, color: txtColor),
                const SizedBox(width: 8),
                Text(
                  "[${t.file}] $sizeStr",
                  style: TextStyle(color: txtColor, fontSize: 12.0),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              msg.name,
              style: TextStyle(
                color: txtColor,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      } else if (msg is ImageMessage) {
        final thumb = msg.thumbhash ?? msg.source;
        content = OctoImage(
          width: MediaQuery.of(context).size.width * 0.618,
          fit: BoxFit.cover,
          image: cachedImageProvider(
            thumb,
            w: MediaQuery.of(context).size.width,
          ),
          errorBuilder: (context, error, stacktrace) => const Icon(Icons.error),
        );
      } else {
        content = const SizedBox.shrink();
      }
      break;
  }
  // 新增：所有引用消息都包裹圆角
  return ClipRRect(borderRadius: kMsgBorderRadius, child: content);
}

/// 双击文本消息的时候全屏显示文本消息
void showTextMessage(String text) {
  // 注意：此函数需要传入 BuildContext，这里暂时保留原有签名
  // 使用时需要从调用方传入 context
  // 建议改用带 context 参数的版本
}

/// 确认是否打开文件
void confirmOpenFile(BuildContext context, String uri) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: SizedBox(
        height: 40,
        child: Center(child: Text(t.sureOpenTheFile)),
      ),
      actions: [
        TextButton(
          child: Text(t.buttonCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(t.buttonConfirm),
          onPressed: () async {
            Navigator.of(context).pop();
            final tmpF = await IMBoyCacheManager().getSingleFile(uri);
            await OpenFile.open(tmpF.path);
          },
        ),
      ],
    ),
    barrierDismissible: true,
  );
}
