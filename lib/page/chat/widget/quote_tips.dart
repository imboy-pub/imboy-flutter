import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

// ignore: depend_on_referenced_packages
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart' show formatBytes;
import 'package:imboy/component/ui/image_view.dart';

// ignore: must_be_immutable
class QuoteTipsWidget extends StatelessWidget {
  const QuoteTipsWidget({
    super.key,
    required this.title,
    required this.message,
    this.close,
  });

  final String title;

  final Message? message;

  final void Function()? close;

  Widget animatedBuilder(bool visible, Widget child) {
    return AnimatedOpacity(
      duration: const Duration(seconds: 1),
      opacity: visible ? 1.0 : 0.0,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return animatedBuilder(false, const SizedBox.shrink());
    }
    Widget? body;
    if (message is TextMessage) {
      body = Text(
        (message as TextMessage).text,
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
      );
    } else if (message is ImageMessage) {
      body = Row(
        children: [
          Icon(
            Icons.image,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          ImageView(uri: (message as ImageMessage).source, height: 40),
        ],
      );
    } else if (message is FileMessage) {
      FileMessage fileMsg = message as FileMessage;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_file,
                size: 16,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "[${'file'.tr}] (${formatBytes(fileMsg.size!.truncate())})",
                  style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 24), // 与图标对齐
              Expanded(
                child: Text(
                  fileMsg.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      );
    } else if (message is AudioMessage) {
      body = Row(
        children: [
          Icon(
            Icons.mic,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
            "[${'voiceMessage'.tr}]",
            style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
          ),
        ],
      );
    }

    String customType = message?.metadata?['custom_type'] ?? '';
    if (customType == 'quote') {
      String txt = message?.metadata?['quote_text'] ?? '';
      body = Row(
        children: [
          Icon(
            Icons.format_quote,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "[${'quote'.tr}] $txt",
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (customType == 'audio' || customType == 'voice') {
      double durationMS = (message?.metadata?["duration_ms"] ?? 0) / 1000;
      body = Row(
        children: [
          Icon(
            Icons.mic,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
            "[${'voiceMessage'.tr}] ${durationMS.toStringAsFixed(1)}''",
            style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
          ),
        ],
      );
    } else if (customType == 'location') {
      body = Row(
        children: [
          Icon(
            Icons.location_on,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "[${'location'.tr}] ${message?.metadata?['title'] ?? ''}",
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (customType == 'video') {
      body = Row(
        children: [
          Icon(
            Icons.videocam,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
            "[${'video'.tr}] ",
            style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
          ),
          const SizedBox(width: 4),
          if (message?.metadata?['thumb']?['uri'] != null)
            ImageView(uri: message?.metadata?['thumb']['uri'], height: 40)
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.play_arrow,
                color: Theme.of(context).colorScheme.tertiary,
                size: 20,
              ),
            ),
        ],
      );
    } else if (customType == 'visit_card') {
      body = Row(
        children: [
          Icon(
            Icons.person,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "[${'businessCard'.tr}] ${message?.metadata?['title'] ?? ''}",
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (customType == 'revoked' || customType == 'my_revoked' || customType == 'peer_revoked') {
      body = Row(
        children: [
          Icon(
            Icons.block,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
  '${'messageRevoked'.tr}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.tertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
    if (body == null) {
      return animatedBuilder(false, const SizedBox.shrink());
    }
    return animatedBuilder(
      true,
      Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8),
            child: const SizedBox(
              height: 64,
              width: 4,
              child: VerticalDivider(
                thickness: 2, // 分割线的厚度
                // color: AppColors.ItemOnColor,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          // color: AppColors.primaryText,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(children: [Expanded(child: body)]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: close,
              child: const Icon(Icons.close_rounded, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
