import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:octo_image/octo_image.dart';
import 'package:shimmer/shimmer.dart';

import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 表情/贴图消息构建器
class ExpressionMessageBuilder extends StatelessWidget {
  const ExpressionMessageBuilder({
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
    final String url = metadata['url'] ?? '';
    final String text = metadata['text'] ?? '';

    // 从 metadata 中获取尺寸，如果没有则使用默认值
    final widthVal = metadata['width'];
    final heightVal = metadata['height'];
    final double width = widthVal is num ? widthVal.toDouble() : 120.0;
    final double height = heightVal is num ? heightVal.toDouble() : 120.0;

    if (url.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Text(text.isNotEmpty ? text : '[表情]'),
      );
    }

    return Tooltip(
      message: text,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: OctoImage(
          image: cachedImageProvider(url),
          width: width,
          height: height,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(width: width, height: height, color: Colors.white),
          ),
          errorBuilder: (context, error, stackTrace) => Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

/// 表情消息插件注册
class ExpressionMessageTypePlugin implements MessageTypePlugin {
  const ExpressionMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.expression}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.expression;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return Padding(
      padding: MessageSpacing.bubblePaddingSymmetric,
      child: ExpressionMessageBuilder(
        type: context.type,
        message: message,
        user: context.user,
      ),
    );
  }
}
