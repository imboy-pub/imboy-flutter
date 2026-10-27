import 'dart:typed_data';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/modules/customer_service/presentation/cs_attachment_views.dart';

/// Persisted messages: sent means server accepted, never a visitor read receipt.
class CsMessageBubble extends StatelessWidget {
  const CsMessageBubble({
    super.key,
    required this.message,
    required this.isSeat,
    required this.actorLabel,
    required this.assets,
    required this.bytesLoader,
    required this.onView,
    this.serverReadAt,
  });
  final EnterpriseMessage message;
  final DateTime? serverReadAt;
  final bool isSeat;
  final String actorLabel;
  final List<CsMessageAsset> assets;
  final Future<Uint8List?> Function(String) bytesLoader;
  final ValueChanged<CsMessageAsset> onView;

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Align(
      alignment: isSeat ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.tiny,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        constraints: BoxConstraints(
          maxWidth: min(
            AppSizes.messageBubbleMaxWidth,
            MediaQuery.sizeOf(context).width * 0.72,
          ),
        ),
        decoration: BoxDecoration(
          color: isSeat
              ? AppColors.primary
              : AppColors.getSurfaceColor(Theme.of(context).brightness),
          borderRadius: AppRadius.borderRadiusLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.content.isNotEmpty)
              Text(
                m.content,
                style: context.textStyle(
                  FontSizeType.body,
                  color: isSeat
                      ? AppColors.sentMessageText
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            for (final asset in assets)
              Padding(
                padding: EdgeInsets.only(
                  top: m.content.isEmpty ? AppSpacing.none : AppSpacing.tiny,
                ),
                child: CsAssetAttachmentView(
                  asset: asset,
                  bytesLoader: bytesLoader,
                  onView: () => onView(asset),
                ),
              ),
            // sender-actor 展示：业务身份名（非自然人好友，EB-D03/D05）
            Text(
              [
                isSeat
                    ? (m.senderBusinessIdentityName.trim().isEmpty
                          ? context.t.customerService.seatLabel
                          : actorLabel)
                    : context.t.customerService.visitorLabel,
                // R08-FL：epoch 毫秒（0=未知不显示），本地时区展示。
                if (m.createdAtMs > 0)
                  DateFormat('MM/dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(m.createdAtMs)
                        .toLocal(),
                  ),
                if (isSeat && m.id.isNotEmpty)
                  serverReadAt == null
                      ? context.t.main.sent
                      : context.t.chat.chatStatusSeen,
              ].join(' · '),
              style: context.textStyle(
                FontSizeType.caption2,
                color: isSeat
                    ? AppColors.sentMessageText
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
