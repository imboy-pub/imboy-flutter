import 'package:flutter/material.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/public.dart'
    show HostedMessageFacts, HostedMessageFactsRow, resolveHostedMessageFacts;
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 消息搜索结果的展示卡片；联系人加载和点击校验仍由页面负责。
class MessageSearchResultCard extends StatelessWidget {
  const MessageSearchResultCard({
    super.key,
    required this.result,
    required this.sender,
    required this.highlightWords,
    required this.onTap,
  });

  final MessageSearchResult result;
  final ContactModel sender;
  final Map<String, HighlightedWord> highlightWords;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.tiny,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：会话信息和时间
              Row(
                children: [
                  // 会话图标
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.small,
                      vertical: AppSpacing.tiny,
                    ),
                    decoration: BoxDecoration(
                      color: result.type == 'C2G'
                          ? AppColors.secondary.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusTiny,
                    ),
                    child: Text(
                      result.type == 'C2G'
                          ? t.chat.groupChat
                          : t.chat.privateChat,
                      style: context.textStyle(
                        FontSizeType.tiny,
                        fontWeight: FontWeight.w500,
                        color: result.type == 'C2G'
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  AppSpacing.horizontalSmall,
                  // 发送者名称
                  Expanded(
                    child: Text(
                      sender.nickname,
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 时间
                  Text(
                    DateTimeHelper.lastTimeFmt(result.createdAt),
                    style: context.textStyle(
                      FontSizeType.tiny,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalSmall,
              // 消息内容（高亮显示）
              TextHighlight(
                text: _getMessageContent(result),
                words: highlightWords,
                textStyle: context
                    .textStyle(
                      FontSizeType.normal,
                      color: Theme.of(context).colorScheme.onSurface,
                    )
                    .copyWith(height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              // FULL-05：搜索面与企业托管消息保持一致——命中企业托管消息时
              // 同样展示来源徽标与非 E2EE 标记（plan §3.3「会话/详情/通知/
              // 搜索/历史一致」）。普通消息不渲染任何额外内容。
              _buildHostedFacts(result),
            ],
          ),
        ),
      ),
    );
  }

  /// 企业托管消息的来源事实行（复用 enterprise_app 的唯一判定与组件）。
  Widget _buildHostedFacts(MessageSearchResult result) {
    final Map<String, dynamic>? metadata = result.payload;
    if (metadata == null) return const SizedBox.shrink();
    final HostedMessageFacts facts = resolveHostedMessageFacts(
      payload: metadata,
    );
    if (!facts.showsDelegationBadge && !facts.needsOriginWarning) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.tiny),
      child: HostedMessageFactsRow(facts: facts),
    );
  }

  /// 获取消息内容
  String _getMessageContent(MessageSearchResult result) {
    if (result.payload != null && result.payload!['text'] != null) {
      return result.payload!['text'].toString();
    }
    return result.content;
  }
}
