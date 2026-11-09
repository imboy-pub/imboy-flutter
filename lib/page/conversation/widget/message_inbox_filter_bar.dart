import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
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
        children: [
          for (final entry in labels.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.small),
              child: Semantics(
                selected: selected == entry.key,
                child: CupertinoButton(
                  key: ValueKey('message-filter-${entry.key.name}'),
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.medium,
                    vertical: AppSpacing.small,
                  ),
                  borderRadius: AppRadius.borderRadiusLarge,
                  color: selected == entry.key
                      ? AppColors.primaryDark
                      : AppColors.getSurfaceGrouped(brightness),
                  onPressed: () => onChanged(entry.key),
                  child: Text(
                    entry.value,
                    style: context.textStyle(
                      FontSizeType.subheadline,
                      fontWeight: selected == entry.key
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected == entry.key
                          ? AppColors.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
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
