import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_duration.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import '../message_inbox_entry.dart';

/// A single, horizontally scrollable filter row. Large text never shrinks to fit.
class MessageInboxFilterBar extends StatelessWidget {
  const MessageInboxFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.showChannels,
  });

  final MessageInboxFilter selected;
  final ValueChanged<MessageInboxFilter> onChanged;
  final bool showChannels;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final selectedBackground = isDark
        ? AppColors.primaryAlpha20
        : AppColors.primaryLight;
    final selectedForeground = isDark
        ? AppColors.primaryContainer
        : AppColors.primaryDark;
    final duration = AppDuration.respectReducedMotion(
      MediaQuery.disableAnimationsOf(context),
      AppDuration.fast,
    );
    final labels = <MessageInboxFilter, String>{
      MessageInboxFilter.all: t.common.all,
      MessageInboxFilter.unread: t.workspace.filterUnread,
      MessageInboxFilter.direct: t.chat.inbox.filterDirect,
      MessageInboxFilter.group: t.chat.groupChat,
      if (showChannels) MessageInboxFilter.channel: t.channel.title,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Row(
        spacing: AppSpacing.tiny,
        children: [
          for (final entry in labels.entries)
            Semantics(
              selected: selected == entry.key,
              child: CupertinoButton(
                key: ValueKey('message-filter-${entry.key.name}'),
                minimumSize: const Size.square(AppSpacing.xxxLarge),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
                borderRadius: AppRadius.borderRadiusCell,
                onPressed: () => onChanged(entry.key),
                // Keep the fill compact while the entire 48pt button remains
                // tappable. Both layers can grow with accessibility text.
                child: AnimatedContainer(
                  duration: duration,
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.xxLarge,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.tiny,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == entry.key
                        ? selectedBackground
                        : AppColors.transparent,
                    borderRadius: AppRadius.borderRadiusCell,
                  ),
                  child: Text(
                    entry.value,
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: selected == entry.key
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: selected == entry.key
                          ? selectedForeground
                          : AppColors.getTextSecondary(brightness),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
