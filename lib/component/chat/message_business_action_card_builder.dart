/// V3-23 业务操作卡片消息渲染器（企业应用代发点名类型，含跳转，
/// matrix spec §5 D1/D2；DELIVERY_SCOPE D06「业务操作卡片跳转」）。
///
/// payload（wire `business_action_card`，schema 冻结于 spec §5 A2/D1）：
/// `title`（必填）/ `action_type`（必填）/ `url?`（http/https 且带 host 时可跳）/
/// `description?` / `action_params?`（业务参数，原样保留不解释）。
///
/// 跳转语义的现状边界（依赖登记）：
/// - `url` 为合法 http/https → 经 [openCardUrl]（SafeLauncher 白名单）打开；
/// - spec 提到的「跳转 deeplink」scheme/路由语义**尚未由 backend/产品冻结**
///   （backend 白名单与 payload 校验在 A2 车道），客户端不做任意字符串路由
///   跳转（伪造跳转面）；无合法 url 时按钮置灰并提示「暂无可执行操作」，
///   待语义冻结后在此接入。
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

/// 结构化的业务操作卡片 payload（[BusinessActionCardPayload.tryParse] 校验
/// 通过才有值）。
class BusinessActionCardPayload {
  const BusinessActionCardPayload({
    required this.title,
    required this.actionType,
    this.url = '',
    this.description = '',
    this.actionParams = const <String, dynamic>{},
  });

  final String title;
  final String actionType;
  final String url;
  final String description;
  final Map<String, dynamic> actionParams;

  /// spec A2 口径校验：title/action_type 必填；url 出现时必须合法；
  /// action_params 必须是 Map（出现非 Map 视为畸形，整体拒绝——不猜测）。
  static BusinessActionCardPayload? tryParse(Map<String, dynamic> meta) {
    final String title = cardString(meta['title']);
    final String actionType = cardString(meta['action_type']);
    if (title.isEmpty || actionType.isEmpty) return null;
    final String url = cardString(meta['url']);
    if (url.isNotEmpty && !isValidCardUrl(url)) return null;
    final dynamic rawParams = meta['action_params'];
    final Map<String, dynamic>? params = rawParams is Map
        ? Map<String, dynamic>.from(rawParams)
        : (rawParams == null ? const <String, dynamic>{} : null);
    if (params == null) return null;
    return BusinessActionCardPayload(
      title: title,
      actionType: actionType,
      url: isValidCardUrl(url) ? url : '',
      description: cardString(meta['description']),
      actionParams: params,
    );
  }
}

class BusinessActionCardMessageBuilder extends StatelessWidget {
  const BusinessActionCardMessageBuilder({
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
    final BusinessActionCardPayload? payload =
        BusinessActionCardPayload.tryParse(flattenCardMeta(msg.metadata));
    if (payload == null) {
      // 畸形 payload：安全降级，不崩溃、不猜测。
      return EnterpriseCardFallback(sentByMe: sentByMe);
    }
    return _BusinessActionCardView(payload: payload, sentByMe: sentByMe);
  }
}

class _BusinessActionCardView extends StatelessWidget {
  const _BusinessActionCardView({
    required this.payload,
    required this.sentByMe,
  });

  final BusinessActionCardPayload payload;
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
    final bool canAct = payload.url.isNotEmpty;

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
          // 卡片类型徽标：与代发徽标（HostedSenderKindChip）同样的胶囊形态，
          // 让「这是一张业务操作卡」在气泡层之外再有一个类型级标识。
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.tiny,
              vertical: AppSpacing.tiny / 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.tagAccent.withValues(alpha: 0.14),
              borderRadius: AppRadius.borderRadiusTiny,
            ),
            child: Text(
              t.enterpriseApp.cardActionBadge,
              style: context.textStyle(
                FontSizeType.tiny,
                color: AppColors.tagAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.small),
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
          // 操作行：action_type 以等宽感的次要文本如实展示（不翻译不猜测），
          // url 合法时可点跳转；否则按钮置灰 + 明确提示（不静默吞掉）。
          Row(
            children: [
              Expanded(
                child: Text(
                  payload.actionType,
                  style: context.textStyle(
                    FontSizeType.tiny,
                    color: subTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: canAct ? () => openCardUrl(context, payload.url) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.small,
                    vertical: AppSpacing.tiny,
                  ),
                  decoration: BoxDecoration(
                    color: canAct
                        ? AppColors.tagAccent.withValues(alpha: 0.14)
                        : (isDark
                              ? AppColors.darkTextSecondary.withValues(
                                  alpha: 0.12,
                                )
                              : AppColors.iosGray5),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Text(
                    canAct
                        ? t.enterpriseApp.cardActionOpen
                        : t.enterpriseApp.cardActionUnavailable,
                    style: context.textStyle(
                      FontSizeType.tiny,
                      color: canAct ? AppColors.tagAccent : subTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
