/// V3-23 链接卡片消息渲染器（企业应用代发点名类型，matrix spec §5 D1/D2）。
///
/// payload（wire `link_card`，schema 冻结于 spec §5 A2/D1）：
/// `title`（必填）/ `url`（必填，http/https 且带 host）/ `description?` /
/// `thumb?`。畸形 payload 渲染 [EnterpriseCardFallback]（不崩溃、不猜测）。
///
/// 跳转只经 [openCardUrl]（SafeLauncher scheme 白名单 + 应用内 WebView）。
/// 企业托管来源徽标由 `HostedMessageBubbleDecoration.decorate` 在气泡层
/// 统一叠加（本组件不做来源解释）。
library;

import 'package:flutter/material.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/chat/enterprise_card_payload.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 结构化的链接卡片 payload（[LinkCardPayload.tryParse] 校验通过才有值）。
class LinkCardPayload {
  const LinkCardPayload({
    required this.title,
    required this.url,
    this.description = '',
    this.thumb = '',
  });

  final String title;
  final String url;
  final String description;
  final String thumb;

  /// spec A2 口径校验：title/url 必填，url 必须 http/https 且带 host。
  static LinkCardPayload? tryParse(Map<String, dynamic> meta) {
    final String title = cardString(meta['title']);
    final String url = cardString(meta['url']);
    if (title.isEmpty || !isValidCardUrl(url)) return null;
    return LinkCardPayload(
      title: title,
      url: url,
      description: cardString(meta['description']),
      thumb: isValidCardUrl(cardString(meta['thumb']))
          ? cardString(meta['thumb'])
          : '',
    );
  }
}

class LinkCardMessageBuilder extends StatelessWidget {
  const LinkCardMessageBuilder({
    super.key,
    required this.user,
    required this.message,
  });

  final User user;
  final CustomMessage? message;

  @override
  Widget build(BuildContext context) {
    final CustomMessage? msg = message;
    if (msg == null) {
      return EnterpriseCardFallback();
    }
    final bool sentByMe = user.id == msg.authorId;
    final LinkCardPayload? payload = LinkCardPayload.tryParse(
      flattenCardMeta(msg.metadata),
    );
    if (payload == null) {
      // 畸形 payload：安全降级，不崩溃、不猜测。
      return EnterpriseCardFallback(sentByMe: sentByMe);
    }
    return _LinkCardView(payload: payload, sentByMe: sentByMe);
  }
}

class _LinkCardView extends StatelessWidget {
  const _LinkCardView({required this.payload, required this.sentByMe});

  final LinkCardPayload payload;
  final bool sentByMe;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = sentByMe
        ? AppColors.sentMessageText
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final Color subTextColor = sentByMe
        ? AppColors.overlayWhite70
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final Uri url = Uri.parse(payload.url);
    final String host = url.host;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: AppColors.getChatBubbleBackground(
          sentByMe,
          false,
          Theme.of(context).brightness,
        ),
        borderRadius: MessageSpacing.getBubbleBorderRadius(sentByMe),
        border: !sentByMe && !isDark
            ? Border.all(color: AppColors.iosGray5, width: 0.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  payload.title,
                  style: context.textStyle(
                    FontSizeType.medium,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (payload.thumb.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.small),
                _LinkThumb(uri: payload.thumb),
              ],
            ],
          ),
          if (payload.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: Text(
                payload.description,
                style: context.textStyle(
                  FontSizeType.small,
                  color: subTextColor,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
            child: Divider(
              height: 1,
              color: subTextColor.withValues(alpha: 0.2),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openCardUrl(context, payload.url),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    host,
                    style: context.textStyle(
                      FontSizeType.tiny,
                      color: subTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.small),
                Icon(
                  Icons.open_in_new,
                  size: AppSpacing.regular,
                  color: AppColors.tagAccent,
                ),
                const SizedBox(width: AppSpacing.tiny),
                Text(
                  t.enterpriseApp.cardLinkOpen,
                  style: context.textStyle(
                    FontSizeType.tiny,
                    color: AppColors.tagAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 缩略图（48x48 圆角）；加载失败显示占位图标，不崩。
class _LinkThumb extends StatelessWidget {
  const _LinkThumb({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusSmall,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Image.network(
          uri,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: AppColors.iosGray5,
            child: Icon(
              Icons.link,
              size: AppSpacing.regular,
              color: AppColors.slateText,
            ),
          ),
        ),
      ),
    );
  }
}
