import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide VideoMessageBuilder, AudioMessageBuilder;
import 'package:get/get.dart';
import 'package:octo_image/octo_image.dart';
import 'package:open_file/open_file.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:provider/provider.dart';

import 'message_audio_builder.dart';
import 'message_location_builder.dart';
import 'message_quote_builder.dart';
import 'message_revoked_builder.dart';
import 'message_video_builder.dart';
import 'message_visit_card_builder.dart';
import 'message_webrtc_builder.dart';

/// 消息圆角半径，可按需自定义
const BorderRadius kMsgBorderRadius = BorderRadius.all(Radius.circular(12));

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
    debugPrint("> on CustomMessageBuilder msg: ${message.toJson().toString()}");
    final user = User(
      id: UserRepoLocal.to.currentUid,
      name: UserRepoLocal.to.current.nickname,
      imageSource: UserRepoLocal.to.current.avatar,
    );
    bool isSentByMe = message.authorId == user.id;
    final theme = context.select(
          (ChatTheme t) => (
      bodyMedium: t.typography.bodyMedium,
      labelSmall: t.typography.labelSmall,
      onPrimary: t.colors.onPrimary,
      onSurface: t.colors.onSurface,
      primary: t.colors.primary,
      shape: t.shape,
      surfaceContainer: t.colors.surfaceContainer,
      ),
    );

    Widget content = const SizedBox.shrink();
    try {
      final customType = message.metadata?['custom_type'] ?? '';
      switch (customType) {
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
          content = QuoteMessageBuilder(type: type, message: message, user: user);
          break;
        case 'video':
          content = VideoMessageBuilder(message: message, user: user);
          break;
        case 'audio':
          content = AudioMessageBuilder(type: type, message: message, user: user);
          break;
        case 'visit_card':
          content = VisitCardMessageBuilder(message: message, user: user);
          break;
        case 'location':
          content = LocationMessageBuilder(message: message, user: user);
          break;
        default:
        // 可以考虑一个默认的文本消息展示
          break;
      }
    } catch (e, s) {
      debugPrint("> on CustomMessageBuilder e ${e.toString()}; $s");
    }

    return ClipRRect(
      borderRadius: kMsgBorderRadius,
      child: Container(
        color: isSentByMe ? theme.primary : theme.surfaceContainer,
        child: content,
      ),
    );
  }
}

/// 构建被引用消息Widget
Widget messageMsgWidget(Message msg, {Color? txtColor}) {
  final user = User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );

  final textStyle = TextStyle(fontSize: 13.0, color: txtColor);

  // 优先处理 custom_type
  final customType = msg.metadata?['custom_type'] ?? '';
  Widget content;
  switch (customType) {
    case 'video':
      content = VideoMessageBuilder(user: user, message: msg as CustomMessage);
      break;
    case 'audio':
      content = AudioMessageBuilder(
        type: msg.metadata?['type'],
        user: user,
        message: msg as CustomMessage,
      );
      break;
    case 'location':
      content = LocationMessageBuilder(user: user, message: msg as CustomMessage);
      break;
    case 'quote':
      final txt = msg.metadata?['quote_text'] ?? '';
      content = Text(
        "[${'quote'.tr}] $txt",
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
            Row(children: [
              Text("[${'file'.tr}] $sizeStr", style: TextStyle(color: txtColor)),
            ]),
            Row(children: [
              Text(msg.name, style: TextStyle(color: txtColor)),
            ]),
          ],
        );
      } else if (msg is ImageMessage) {
        final thumb = msg.thumbhash ?? msg.source;
        content = OctoImage(
          width: Get.width * 0.618,
          fit: BoxFit.cover,
          image: cachedImageProvider(thumb, w: Get.width),
          errorBuilder: (context, error, stacktrace) => const Icon(Icons.error),
        );
      } else {
        content = const SizedBox.shrink();
      }
      break;
  }
  // 新增：所有引用消息都包裹圆角
  return ClipRRect(
    borderRadius: kMsgBorderRadius,
    child: content,
  );
}

/// 双击文本消息的时候全屏显示文本消息
void showTextMessage(String text) {
  final isDark = Get.isDarkMode;
  Get.bottomSheet(
    Container(
      width: double.infinity,
      height: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
      alignment: Alignment.center,
      color: isDark
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SelectableText.rich(
            TextSpan(
              text: text,
              style: const TextStyle(fontSize: 24),
            ),
            onTap: () {
              Get.closeAllBottomSheets();
            },
            textAlign: TextAlign.left,
          ),
        ),
      ),
    ),
    isScrollControlled: true,
    enableDrag: true,
  );
}

/// 确认是否打开文件
void confirmOpenFile(String uri) {
  showDialog(
    context: Get.context!,
    builder: (context) => AlertDialog(
      content: SizedBox(
        height: 40,
        child: Center(child: Text('sure_open_the_file'.tr)),
      ),
      actions: [
        TextButton(
          child: Text('button_cancel'.tr),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text('button_confirm'.tr),
          onPressed: () async {
            Navigator.of(context).pop();
            final tmpF = await IMBoyCacheManager().getSingleFile(
              uri,
              key: EncrypterService.md5(uri),
            );
            await OpenFile.open(tmpF.path);
          },
        ),
      ],
    ),
    barrierDismissible: true,
  );
}