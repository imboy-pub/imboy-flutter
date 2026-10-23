import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import '../profile_provider.dart';

/// A quiet summary retains the provider's score and all completion actions.
class ProfileCompletionWidget extends ConsumerWidget {
  const ProfileCompletionWidget({super.key, this.onSuggestionTap});
  final void Function(String key)? onSuggestionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final suggestions = ref
        .read(profileProvider.notifier)
        .getCompletionSuggestions();
    return Container(
      key: const ValueKey('profile-completion'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(Theme.of(context).brightness),
        borderRadius: AppRadius.borderRadiusCell,
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.all(AppSpacing.regular),
        onPressed: suggestions.isEmpty || onSuggestionTap == null
            ? null
            : () => _showSuggestions(context, suggestions),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summary(context, state, suggestions),
            AppSpacing.verticalMedium,
            _progress(context, state),
          ],
        ),
      ),
    );
  }

  Widget _summary(
    BuildContext context,
    ProfileState state,
    List<ProfileSuggestion> suggestions,
  ) => Row(
    children: [
      Expanded(child: _title(context, suggestions)),
      AppSpacing.horizontalSmall,
      Text(
        '${state.completeness}%',
        style: context.textStyle(
          FontSizeType.normal,
          color: AppColors.getTextColor(
            Theme.of(context).brightness,
            isSecondary: true,
          ),
        ),
      ),
      if (suggestions.isNotEmpty && onSuggestionTap != null) ...[
        AppSpacing.horizontalSmall,
        const CupertinoListTileChevron(),
      ],
    ],
  );

  Widget _title(BuildContext context, List<ProfileSuggestion> suggestions) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.chat.profileCompleteness,
            style: context.textStyle(
              FontSizeType.body,
              color: AppColors.getTextColor(Theme.of(context).brightness),
            ),
          ),
          AppSpacing.verticalTiny,
          Text(
            suggestions.isEmpty
                ? context.t.chat.profileCompleted
                : suggestions.take(2).map((s) => s.label).join(' · '),
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.getTextColor(
                Theme.of(context).brightness,
                isSecondary: true,
              ),
            ),
          ),
        ],
      );

  Widget _progress(
    BuildContext context,
    ProfileState state,
  ) => LinearProgressIndicator(
    value: (state.completeness / 100).clamp(0, 1),
    minHeight: AppSpacing.tiny,
    color: AppColors.primary,
    backgroundColor: AppColors.getIosSeparator(Theme.of(context).brightness),
    semanticsLabel:
        '${context.t.chat.profileCompleteness} · ${state.completenessLevel}',
    semanticsValue: '${state.completeness}%',
  );

  Future<void> _showSuggestions(
    BuildContext context,
    List<ProfileSuggestion> suggestions,
  ) => showCupertinoModalPopup<void>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: Text(context.t.common.completionSuggestions),
      actions: [
        for (final suggestion in suggestions)
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheet);
              onSuggestionTap!(suggestion.key);
            },
            child: Text(suggestion.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: Text(context.t.common.cancel),
      ),
    ),
  );
}
