import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
// ignore: depend_on_referenced_packages
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:imboy/app_core/routing/organization_invite_link.dart';
import 'package:imboy/component/chat/chat_web_links.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart' show cachedImageProvider;
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/helper/safe_launcher.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_bubble_style.dart'
    show MessageBubbleStyle;
import 'package:imboy/page/chat/chat/utils/message_status_icon_rules.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/chat/widget/message_semantics.dart';
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

void webMessageLinkTap(BuildContext context, String url, String title) async {
  var opened = false;
  try {
    final uri = Uri.tryParse(url);
    final externalWeb =
        kIsWeb &&
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        organizationInviteLocation(url) == null;
    if (externalWeb) {
      if (uri.host.isNotEmpty && uri.userInfo.isEmpty) {
        opened = await launchUrl(uri, webOnlyWindowName: '_blank');
      }
    } else {
      opened = await SafeLauncher.safeLaunchUrlString(url, context: context);
    }
  } on Object {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppLoading.showToast(t.common.cannotOpenWebpage);
  }
}

Widget? webMessageContent({
  required BuildContext context,
  required Message message,
  required int index,
  required String currentUserId,
  required ChatTheme theme,
}) {
  final isMe = message.authorId == currentUserId;
  final time = message.resolvedTime;
  final hasTime = time != null && time.millisecondsSinceEpoch > 0;
  if (message is TextMessage) {
    // F1（SC 4.1.2，属主裁决 uxfix-batch1）：文本气泡此前无 Semantics 包装，
    // 读屏 name 只有裸内容拼接（引擎对 leaf button 用 domText 呈现），没有
    // "谁发的 + 什么类型"框架。与图片/语音/视频/文件分支同一 semanticMessage
    // 模式，detail 携带内容前缀摘要（全文仍由气泡内文本节点兜底，不吞子节点）。
    return semanticMessage(
      isSentByMe: isMe,
      kind: t.chat.chatMessage,
      isButton: false,
      detail: message.text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: MessageBubbleStyle.getBubbleDecoration(
          context: context,
          isSentByMe: isMe,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GptMarkdown(
              ChatWebLinks.projectText(message.text),
              styleSheet: GptMarkdownStyleSheet(
                link: LinkStyle(
                  color: _linkColor(context, isMe),
                  hoverColor: _linkColor(context, isMe),
                  decoration: TextDecoration.underline,
                ),
              ),
              style: MessageBubbleStyle.getMessageTextStyle(
                context: context,
                isSentByMe: isMe,
              ),
              onLinkTap: (url, title) => webMessageLinkTap(context, url, title),
              imageBuilder: (_, _, _, _) => Semantics(
                label: t.chat.image,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
            if (hasTime)
              Text(
                DateTimeHelper.dateTimeFmt(time),
                style: MessageBubbleStyle.getTimestampStyle(context),
              ),
          ],
        ),
      ),
    );
  }
  if (message is ImageMessage) {
    final viewport = MediaQuery.sizeOf(context);
    final maxSize = Size(viewport.width * .65, viewport.height * .5);
    final width = message.width;
    final height = message.height;
    final declaredSize =
        width != null &&
            height != null &&
            width.isFinite &&
            height.isFinite &&
            width > 0 &&
            height > 0
        ? Size(width, height)
        : const Size(1, 1);
    final size = applyBoxFit(BoxFit.contain, declaredSize, maxSize).destination;
    Widget failure(BuildContext context) => ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.placeholderSurfaceDark
          : AppColors.placeholderSurfaceLight,
      child: Center(child: Text(t.common.imageLoadFailed)),
    );
    return semanticMessage(
      isSentByMe: isMe,
      kind: t.chat.image,
      isButton: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxSize.width,
          maxHeight: maxSize.height,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MessageSpacing.imageBorderRadius),
          child: message.metadata?['_e2ee_failed'] == true
              ? SizedBox(
                  width: size.width,
                  height: size.height,
                  child: failure(context),
                )
              : isMe && message.status == MessageStatus.sending
              ? SizedBox(
                  width: size.width,
                  height: size.height,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : message.source.isEmpty
              ? SizedBox(
                  width: size.width,
                  height: size.height,
                  child: failure(context),
                )
              : Image(
                  image: cachedImageProvider(message.source, w: size.width),
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame != null || synchronous
                      ? child
                      : SizedBox(
                          width: size.width,
                          height: size.height,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                  errorBuilder: (context, error, stack) => SizedBox(
                    width: size.width,
                    height: size.height,
                    child: failure(context),
                  ),
                ),
        ),
      ),
    );
  }
  if (message is AudioMessage || message is VideoMessage) {
    final audio = message is AudioMessage;
    final kind = audio ? t.chat.voiceMessage : t.chat.videoMessage;
    return semanticMessage(
      isSentByMe: isMe,
      kind: kind,
      isButton: false,
      child: Container(
        padding: MessageSpacing.bubblePaddingSymmetric,
        decoration: MessageBubbleStyle.getBubbleDecoration(
          context: context,
          isSentByMe: isMe,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kind),
            Text(
              audio
                  ? t.common.webAudioNotSupported
                  : t.chat.unsupportedMessageType,
              style: MessageBubbleStyle.getMessageTextStyle(
                context: context,
                isSentByMe: isMe,
              ),
            ),
          ],
        ),
      ),
    );
  }
  if (message is! FileMessage) return null;
  return semanticMessage(
    isSentByMe: isMe,
    kind: t.chat.file,
    child: MultiProvider(
      providers: [
        Provider<ChatTheme>.value(value: theme),
        Provider<UserID>.value(value: currentUserId),
        Provider<DateFormat>.value(value: RelativeDateFormat()),
      ],
      child: FlyerChatFileMessage(
        message: message,
        index: index,
        showTime: hasTime,
        showStatus: false,
      ),
    ),
  );
}

Color _linkColor(BuildContext context, bool isMe) {
  final brightness = Theme.of(context).brightness;
  // DSN-05 R06/R07 连带：亮色发送气泡改 primaryDark(#1565C0) 后，
  // 深色链接(lightTextPrimary)对比度仅 3.65:1；链接与正文同用
  // sentMessageText（#F5F7FA on #1565C0 = 5.354 ≥ 4.5）。
  if (isMe) return AppColors.sentMessageText;
  return AppColors.getTextColor(brightness);
}

Widget? webMessageStatus(
  Message message, {
  required Color Function(String) themeColor,
  required Color Function(String) chatColor,
}) {
  final uncertain = isMessageOutcomeUnknown(message);
  final spec = resolveMessageStatusIcon(
    message.status,
    outcomeUnknown: uncertain,
  );
  if (!spec.hasIcon) return null;
  final color = spec.colorKey == 'sendMessageBg'
      ? chatColor(spec.colorKey!)
      : themeColor(spec.colorKey!);
  if (uncertain) {
    return Text(
      spec.semanticLabel!,
      textAlign: TextAlign.end,
      style: TextStyle(color: color),
    );
  }
  return Icon(
    spec.iconData,
    size: 16,
    color: color,
    semanticLabel: spec.semanticLabel,
  );
}
