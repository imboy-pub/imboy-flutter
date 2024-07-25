import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/image_view.dart';

import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class QuoteTipsWidget extends StatelessWidget {
  const QuoteTipsWidget({
    super.key,
    required this.title,
    required this.message,
    this.close,
  });

  final String title;

  final types.Message? message;

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
    if (message is types.TextMessage) {
      body = Text(
        (message as types.TextMessage).text,
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
        maxLines: 8,
        overflow: TextOverflow.ellipsis,
      );
    } else if (message is types.ImageMessage) {
      body = ImageView(
        uri: (message as types.ImageMessage).uri,
        height: 40,
      );
    } else if (message is types.FileMessage) {
      types.FileMessage fileMsg = message as types.FileMessage;
      body = n.Column([
        n.Row([
          Text(
            "[${'file'.tr}] (${formatBytes(fileMsg.size.truncate())})",
            style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
          ),
        ]),
        n.Row([
          Expanded(
            child: Text(
              fileMsg.name,
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
        ])
      ]);
    } else if (message is types.AudioMessage) {
      //
    }

    String customType = message?.metadata?['custom_type'] ?? '';
    if (customType == 'quote') {
      String txt = message?.metadata?['quote_text'] ?? '';
      body = Text(
        "[${'quote'.tr}] $txt",
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
      );
    } else if (customType == 'audio') {
      double durationMS = message?.metadata?["duration_ms"] / 1000;
      body = Text(
        "[${'voice_message'.tr}] $durationMS''",
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
      );
    } else if (customType == 'location') {
      body = Text(
        "[${'location'.tr}] ${message?.metadata?['title'] ?? ''}",
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
      );
    } else if (customType == 'video') {
      body = n.Row([
        Text(
          "[${'video'.tr}] ",
          style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
        ),
        ImageView(
          uri: message?.metadata?['thumb']['uri'],
          height: 40,
        ),
      ]);
    }
    if (body == null) {
      return animatedBuilder(false, const SizedBox.shrink());
    }
    return animatedBuilder(
        true,
        n.Row(
          [
            n.Padding(
              left: 20,
              right: 8,
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
              child: n.Column([
                n.Row([
                  Expanded(
                      child: Text(
                    title,
                    style: const TextStyle(
                      // color: AppColors.primaryText,
                      fontSize: 16,
                    ),
                  ))
                ]),
                n.Row([
                  Expanded(
                    child: body,
                  )
                ])
              ]),
            ),
            n.Padding(
              right: 8,
              child: InkWell(
                onTap: close,
                child: const Icon(
                  Icons.close_rounded,
                  size: 24,
                ),
              ),
            ),
          ],
        ));
  }
}
