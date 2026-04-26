import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide VideoMessageBuilder, AudioMessageBuilder;
import 'package:octo_image/octo_image.dart';
import 'package:open_file/open_file.dart';
import 'package:shimmer/shimmer.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/plugins/builtin/register_builtin_plugins.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'message_spacing.dart';
import 'message_audio_builder.dart';
import 'message_location_builder.dart';
import 'message_revoked_builder.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 构建自定义消息主入口
class CustomMessageBuilder extends StatelessWidget {
  const CustomMessageBuilder({
    super.key,
    required this.type, // C2C C2G
    required this.message,
    this.registry,
    this.onPlayPause,
    // 播放状态参数（用于语音消息）
    this.isPlaying = false,
    this.isPaused = false,
    this.currentPositionMs = 0,
    this.currentDurationMs = 0,
    // 当前会话的所有消息（用于图片预览时获取其他图片）
    this.messages,
  });

  final String type; // C2C C2G
  final CustomMessage message;
  final MessageTypeRegistry? registry;
  final Function(String audioPath, CustomMessage msg, Duration totalDuration)?
  onPlayPause;
  // 播放状态参数（用于语音消息）
  final bool isPlaying;
  final bool isPaused;
  final int currentPositionMs;
  final int currentDurationMs;
  // 当前会话的所有消息
  final List<dynamic>? messages;

  Widget _wrapWithDefaultBubble(
    BuildContext context,
    Widget child,
    bool isSentByMe,
  ) {
    final theme = Theme.of(context);
    final borderRadius = MessageSpacing.getBubbleBorderRadius(isSentByMe);
    // DESIGN.md 第 9/10 章：气泡背景统一走 AppColors，
    // 发送=品牌蓝 / 接收=surface（暗色映射对应 darkSurface）
    final backgroundColor = AppColors.getChatBubbleBackground(
      isSentByMe,
      false,
      theme.brightness,
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        // DESIGN.md §9.1 聊天气泡：iOS 气泡 **不带阴影**（与 message_bubble_style 一致）
      ),
      padding: MessageSpacing.bubblePaddingSymmetric,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = User(
      id: UserRepoLocal.to.currentUid,
      name: UserRepoLocal.to.current.nickname,
      imageSource: UserRepoLocal.to.current.avatar,
    );
    bool isSentByMe = message.authorId == user.id;
    Widget content = const SizedBox.shrink();
    try {
      final effectiveMsgType =
          message.metadata?['effective_msg_type'] ??
          message.metadata?['msg_type'] ??
          '';
      final status = message.metadata?['status'] as int?;

      // 方案 D: 检查 status 字段（撤回状态 30-39）
      if (IMBoyMessageStatus.isRevokedStatus(status)) {
        // status = 30 (peer_revoked) 或 31 (my_revoked)
        content = _wrapWithDefaultBubble(
          context,
          RevokedMessageBuilder(message: message, user: user),
          isSentByMe,
        );
      } else {
        final messageType = effectiveMsgType.toString();
        final pluginRegistry = registry ?? defaultMessageTypeRegistry;
        final renderContext = MessageRenderContext(
          context: context,
          type: type,
          user: user,
          isSentByMe: isSentByMe,
          bubbleWrapper: (child) =>
              _wrapWithDefaultBubble(context, child, isSentByMe),
          onPlayPause: onPlayPause,
          isPlaying: isPlaying,
          isPaused: isPaused,
          currentPositionMs: currentPositionMs,
          currentDurationMs: currentDurationMs,
          messages: messages,
        );
        final plugin = pluginRegistry.resolve(
          messageType.isEmpty ? MessageType.unsupported : messageType,
        );
        final builtContent = plugin.build(message, renderContext);
        content = plugin.surface == MessagePluginSurface.bubble
            ? _wrapWithDefaultBubble(context, builtContent, isSentByMe)
            : builtContent;
      }
    } catch (e) {
      iPrint("> on CustomMessageBuilder error: ${e.runtimeType}");
      final fallbackPlugin = (registry ?? defaultMessageTypeRegistry).resolve(
        MessageType.unsupported,
      );
      final fallbackContext = MessageRenderContext(
        context: context,
        type: type,
        user: user,
        isSentByMe: isSentByMe,
        bubbleWrapper: (child) =>
            _wrapWithDefaultBubble(context, child, isSentByMe),
        onPlayPause: onPlayPause,
        isPlaying: isPlaying,
        isPaused: isPaused,
        currentPositionMs: currentPositionMs,
        currentDurationMs: currentDurationMs,
        messages: messages,
      );
      final fallbackContent = fallbackPlugin.build(message, fallbackContext);
      content = fallbackPlugin.surface == MessagePluginSurface.bubble
          ? _wrapWithDefaultBubble(context, fallbackContent, isSentByMe)
          : fallbackContent;
    }
    return content;
  }
}

/// 构建被引用消息Widget
Widget messageMsgWidget(BuildContext context, Message msg, {Color? txtColor}) {
  final user = User(
    id: UserRepoLocal.to.currentUid,
    name: UserRepoLocal.to.current.nickname,
    imageSource: UserRepoLocal.to.current.avatar,
  );

  // DESIGN.md §3.4：中文正文行高 1.4（多行预览可读性）
  final textStyle = TextStyle(
    fontSize: 14.0,
    color: txtColor,
    height: 1.4,
  );

  // 【重构】WebSocket API v2.0: 优先使用 effective_msg_type（归一化后的类型）
  final effectiveMsgType =
      msg.metadata?['effective_msg_type'] ?? msg.metadata?['msg_type'] ?? '';

  Widget content;
  switch (effectiveMsgType) {
    case 'voice':
      return AudioMessageBuilder(
        type: msg.metadata?['type'] ?? 'C2C',
        user: user,
        message: msg as CustomMessage,
      );
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
          placeholderBuilder: (context) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(color: Colors.white),
          ),
          errorBuilder: (context, error, stacktrace) => const Icon(Icons.error),
        );
      } else {
        content = const SizedBox.shrink();
      }
      break;
  }
  // 新增：所有引用消息都包裹圆角
  return ClipRRect(
    borderRadius: BorderRadius.circular(MessageSpacing.bubbleBorderRadius),
    child: content,
  );
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
            final tmpF = await IMBoyCacheManager().getSingleFile(
              uri,
              validateImageData: false, // 文件下载不验证图片格式
            );
            await OpenFile.open(tmpF.path);
          },
        ),
      ],
    ),
    barrierDismissible: true,
  );
}
