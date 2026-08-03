import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:octo_image/octo_image.dart';
import 'package:imboy/component/ui/shimmer_box.dart';

import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';

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
    final String url = metadata['url'] as String? ?? '';
    final String text = metadata['text'] as String? ?? '';

    // 从 metadata 中获取尺寸，如果没有则使用默认值
    final widthVal = metadata['width'];
    final heightVal = metadata['height'];
    final double width = widthVal is num ? widthVal.toDouble() : 120.0;
    final double height = heightVal is num ? heightVal.toDouble() : 120.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // url 为空 = 对端发的是纯文本贴图（历史数据）。本端已不再生产这种消息，
    // 见 attachment_handler 里 sendExpressionMessage 的删除说明。
    if (url.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        child: Text(
          text.isNotEmpty ? text : '[${t.common.expression}]',
          style: const TextStyle(fontSize: AppSizes.iconSizeXLarge),
        ),
      );
    }

    return Semantics(
      label: text.isNotEmpty ? text : t.common.expression,
      image: true,
      child: Tooltip(
        message: text,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: OctoImage(
            image: cachedImageProvider(url),
            width: width,
            height: height,
            fit: BoxFit.contain,
            placeholderBuilder: (context) => ShimmerBox(
              baseColor: AppColors.shimmerBase,
              highlightColor: AppColors.shimmerHighlight,
              child: Container(
                width: width,
                height: height,
                color: AppColors.shimmerBase,
              ),
            ),
            errorBuilder: (context, error, stackTrace) => Container(
              width: width,
              height: height,
              color: isDark
                  ? AppColors.placeholderSurfaceDark
                  : AppColors.placeholderSurfaceLight,
              child: const Icon(Icons.broken_image, color: AppColors.iosGray),
            ),
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
