import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'personal_attachment_repository.dart';

class PersonalAttachmentsView extends StatelessWidget {
  const PersonalAttachmentsView({
    super.key,
    required this.search,
    required this.items,
    required this.loading,
    required this.hasMore,
    required this.hasError,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onMore,
    required this.onOpen,
  });

  final TextEditingController search;
  final List<PersonalAttachment> items;
  final bool loading;
  final bool hasMore;
  final bool hasError;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onMore;
  final ValueChanged<PersonalAttachment> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: AppSpacing.allRegular,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
          child: CupertinoSearchTextField(
            key: const ValueKey('personal-attachment-search'),
            controller: search,
            placeholder: context.t.attachmentManager.searchHint,
            backgroundColor: _surface(context),
            borderRadius: AppRadius.borderRadiusCell,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.getTextColor(Theme.of(context).brightness),
            ),
            padding: const EdgeInsets.all(AppSpacing.medium),
            onChanged: onSearchChanged,
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(onRefresh: onRefresh, child: _list(context)),
      ),
    ],
  );

  Widget _list(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.regular,
      AppSpacing.none,
      AppSpacing.regular,
      AppSpacing.regular,
    ),
    children: [
      if (hasError || items.isEmpty) _state(context),
      for (var index = 0; index < items.length; index++)
        PersonalAttachmentRow(
          key: ValueKey('personal-attachment-${items[index].message.id}'),
          item: items[index],
          first: index == 0,
          last: index == items.length - 1,
          onTap: () => onOpen(items[index]),
        ),
      if (loading && items.isNotEmpty)
        const Padding(
          padding: EdgeInsets.all(AppSpacing.regular),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      if (hasMore && !loading && !hasError)
        CupertinoButton(
          key: const ValueKey('personal-attachment-more'),
          onPressed: onMore,
          child: Text(context.t.attachmentManager.loadMore),
        ),
      const _AttachmentNotice(),
    ],
  );

  Widget _state(BuildContext context) {
    final t = context.t.attachmentManager;
    if (hasError) {
      return _AttachmentState(
        icon: CupertinoIcons.wifi_exclamationmark,
        label: t.moreFailed,
        action: onRefresh,
      );
    }
    return _AttachmentState(
      loading: loading,
      icon: search.text.trim().isEmpty
          ? CupertinoIcons.folder
          : CupertinoIcons.search,
      label: search.text.trim().isEmpty ? t.emptyLocal : t.emptySearch,
    );
  }
}

class PersonalAttachmentRow extends StatelessWidget {
  const PersonalAttachmentRow({
    super.key,
    required this.item,
    required this.onTap,
    this.first = false,
    this.last = false,
  });

  final PersonalAttachment item;
  final VoidCallback onTap;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.vertical(
      top: first ? const Radius.circular(AppRadius.cell) : Radius.zero,
      bottom: last ? const Radius.circular(AppRadius.cell) : Radius.zero,
    ),
    child: ColoredBox(
      color: _surface(context),
      child: Column(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.medium,
            ),
            minimumSize: const Size.square(AppSizes.touchTarget),
            onPressed: onTap,
            child: _content(context),
          ),
          if (!last)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start:
                    AppSpacing.regular +
                    AppSizes.avatarSizeMedium +
                    AppSpacing.medium,
              ),
              child: Divider(
                height: AppSizes.dividerThickness,
                color: AppColors.getDividerColor(Theme.of(context).brightness),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _content(BuildContext context) => Row(
    children: [
      Container(
        width: AppSizes.avatarSizeMedium,
        height: AppSizes.touchTarget,
        decoration: BoxDecoration(
          color: AppColors.primaryAlpha10,
          borderRadius: AppRadius.borderRadiusSmall,
        ),
        child: Icon(
          _icon,
          color: AppColors.primary,
          size: AppSizes.iconSizeMedium,
        ),
      ),
      AppSpacing.horizontalMedium,
      Expanded(child: _copy(context)),
      AppSpacing.horizontalSmall,
      Icon(
        CupertinoIcons.chevron_right,
        size: AppSizes.iconSizeXSmall,
        color: AppColors.getTextColor(
          Theme.of(context).brightness,
          isSecondary: true,
        ),
      ),
    ],
  );

  Widget _copy(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        item.name.isEmpty ? context.t.chat.file : item.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.subheadline,
          color: AppColors.getTextColor(Theme.of(context).brightness),
        ),
      ),
      AppSpacing.verticalTiny,
      Text(
        '${DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(item.message.createdAt))} · ${context.t.attachmentManager.openSource}',
        style: context.textStyle(
          FontSizeType.small,
          color: AppColors.getTextColor(
            Theme.of(context).brightness,
            isSecondary: true,
          ),
        ),
      ),
    ],
  );

  IconData get _icon => switch (item.message.msgType) {
    'image' || 'imageMulti' => CupertinoIcons.photo,
    'video' => CupertinoIcons.videocam,
    'voice' || 'audio' => CupertinoIcons.waveform,
    _ => CupertinoIcons.doc_text,
  };
}

class _AttachmentState extends StatelessWidget {
  const _AttachmentState({
    required this.icon,
    required this.label,
    this.loading = false,
    this.action,
  });
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.allXLarge,
    decoration: BoxDecoration(
      color: _surface(context),
      borderRadius: AppRadius.borderRadiusCell,
    ),
    child: loading
        ? const Center(child: CupertinoActivityIndicator())
        : Column(
            children: [
              Icon(
                icon,
                size: AppSizes.iconSizeLarge,
                color: AppColors.getTextColor(
                  Theme.of(context).brightness,
                  isSecondary: true,
                ),
              ),
              AppSpacing.verticalSmall,
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.textStyle(
                  FontSizeType.normal,
                  color: AppColors.getTextColor(
                    Theme.of(context).brightness,
                    isSecondary: true,
                  ),
                ),
              ),
              if (action != null)
                CupertinoButton(
                  key: const ValueKey('personal-attachment-retry'),
                  onPressed: action,
                  child: Text(context.t.attachmentManager.retryAction),
                ),
            ],
          ),
  );
}

class _AttachmentNotice extends StatelessWidget {
  const _AttachmentNotice();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: AppSpacing.medium,
      horizontal: AppSpacing.tiny,
    ),
    child: Text.rich(
      TextSpan(
        text: context.t.attachmentManager.personalHint,
        children: [
          TextSpan(
            text: '\n${context.t.attachmentManager.personalBoundary}',
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.getTextColor(
                Theme.of(context).brightness,
                isSecondary: true,
              ),
            ),
          ),
        ],
      ),
      style: context.textStyle(
        FontSizeType.footnote,
        color: AppColors.getTextColor(
          Theme.of(context).brightness,
          isSecondary: true,
        ),
      ),
    ),
  );
}

Color _surface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppColors.darkSurfaceGroupedTertiary
    : AppColors.getSurfaceColor(Brightness.light);
