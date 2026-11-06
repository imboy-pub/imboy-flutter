import 'package:flutter/cupertino.dart';
import 'package:highlight_text/highlight_text.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'web_search_state.dart';

/// 搜索结果列表的分组标题，与结果项共用展示层。
class WebSearchSectionHeader extends StatelessWidget {
  const WebSearchSectionHeader({
    super.key,
    required this.title,
    required this.isDark,
  });

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: isDark
        ? AppColors.chatWebBackgroundDark
        : AppColors.chatWebBackgroundLight,
    child: Text(
      title,
      style: context.textStyle(
        FontSizeType.footnote,
        fontWeight: FontWeight.w500,
        color: isDark
            ? AppColors.chatWebSecondaryDark
            : AppColors.chatWebSecondaryLight,
      ),
    ),
  );
}

/// Web 搜索结果的展示；点击与消息可见性校验由页面处理。
class WebSearchResultTile extends StatelessWidget {
  const WebSearchResultTile({
    super.key,
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  final SearchItem item;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final words = <String, HighlightedWord>{};
    if (item.highlightText != null && item.highlightText!.isNotEmpty) {
      words[item.highlightText!.toLowerCase()] = HighlightedWord(
        textStyle: TextStyle(
          color: isDark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          backgroundColor: AppColors.chatWebBrand.withAlpha(50),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 图标或头像
            _buildItemIcon(item, isDark),
            AppSpacing.horizontalMedium,

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  TextHighlight(
                    text: item.title,
                    words: words,
                    textStyle: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    TextHighlight(
                      text: item.subtitle!,
                      words: words,
                      textStyle: context.textStyle(
                        FontSizeType.footnote,
                        color: isDark
                            ? AppColors.chatWebSecondaryDark
                            : AppColors.chatWebSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // 时间戳（消息类型）
            if (item.type == SearchItemType.message &&
                item.metadata?['timestamp'] != null) ...[
              AppSpacing.horizontalSmall,
              Text(
                DateTimeHelper.lastTimeFmt(
                  parseModelInt(item.metadata?['timestamp']),
                ),
                style: context.textStyle(
                  FontSizeType.small,
                  color: isDark
                      ? AppColors.chatWebSecondaryDark
                      : AppColors.chatWebSecondaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建项目图标
  Widget _buildItemIcon(SearchItem item, bool isDark) {
    if (item.avatar != null && item.avatar!.isNotEmpty) {
      return Avatar(imgUri: item.avatar!);
    }

    IconData iconData;
    switch (item.type) {
      case SearchItemType.conversation:
        iconData = CupertinoIcons.chat_bubble;
      case SearchItemType.message:
        iconData = CupertinoIcons.chat_bubble_fill;
      case SearchItemType.contact:
        iconData = CupertinoIcons.person;
      case SearchItemType.group:
        iconData = CupertinoIcons.group;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.chatWebSurfaceDark
            : AppColors.chatWebBackgroundLight,
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: isDark
            ? AppColors.chatWebSecondaryDark
            : AppColors.chatWebSecondaryLight,
        size: 24,
      ),
    );
  }
}
