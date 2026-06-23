import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/component/ui/image_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
      duration: const Duration(milliseconds: 300),
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
        style: TextStyle(color: AppColors.iosGray, fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    } else if (message is ImageMessage) {
      body = Row(
        children: [
          Icon(CupertinoIcons.photo, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          ImageView(uri: (message as ImageMessage).source, height: 32),
        ],
      );
    } else if (message is FileMessage) {
      FileMessage fileMsg = message as FileMessage;
      body = Row(
        children: [
          Icon(CupertinoIcons.doc, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileMsg.name,
              style: TextStyle(color: AppColors.iosGray, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (message is AudioMessage) {
      body = Row(
        children: [
          Icon(CupertinoIcons.mic, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          Text(
            "[${t.chat.voiceMessage}]",
            style: TextStyle(color: AppColors.iosGray, fontSize: 14),
          ),
        ],
      );
    }

    String msgType = message?.metadata?['msg_type'] as String? ?? '';
    final status = message?.metadata?['status'] as int?;

    if (IMBoyMessageStatus.isRevokedStatus(status)) {
      body = Row(
        children: [
          Icon(CupertinoIcons.slash_circle, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          Text(
            t.common.messageRevoked,
            style: TextStyle(
              color: AppColors.iosGray,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ],
      );
    } else if (msgType == MessageType.quote) {
      String txt = message?.metadata?['quote_text'] as String? ?? '';
      body = Row(
        children: [
          Icon(CupertinoIcons.quote_bubble, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "[${t.main.quote}] $txt",
              style: TextStyle(color: AppColors.iosGray, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (msgType == MessageType.voice) {
      double durationMS =
          (message?.metadata?["duration_ms"] as int? ?? 0) / 1000;
      body = Row(
        children: [
          Icon(CupertinoIcons.mic, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          Text(
            "[${t.chat.voiceMessage}] ${durationMS.toStringAsFixed(1)}''",
            style: TextStyle(color: AppColors.iosGray, fontSize: 14),
          ),
        ],
      );
    } else if (msgType == MessageType.location) {
      body = Row(
        children: [
          Icon(CupertinoIcons.location, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "[${t.groupSchedule.location}] ${message?.metadata?['title'] ?? ''}",
              style: TextStyle(color: AppColors.iosGray, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (msgType == MessageType.video) {
      body = Row(
        children: [
          Icon(CupertinoIcons.videocam, size: 16, color: AppColors.iosGray),
          const SizedBox(width: 8),
          Text(
            "[${t.chat.video}]",
            style: TextStyle(color: AppColors.iosGray, fontSize: 14),
          ),
        ],
      );
    } else if (msgType == MessageType.visitCard) {
      body = Row(
        children: [
          Icon(
            CupertinoIcons.person_crop_circle,
            size: 16,
            color: AppColors.iosGray,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "[${t.chat.businessCard}] ${message?.metadata?['title'] ?? ''}",
              style: TextStyle(color: AppColors.iosGray, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: AppColors.getIosSeparator(
                Theme.of(context).brightness,
              ).withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getIosBlue(Theme.of(context).brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  body,
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: close,
              minimumSize: Size(44, 44),
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: AppColors.iosGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
