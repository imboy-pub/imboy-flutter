import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 资料完善度组件 - iOS 17 Premium 风格
class ProfileCompletionWidget extends ConsumerWidget {
  const ProfileCompletionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightTextPrimary.withValues(
              alpha: isDark ? 0.2 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.chat.profileCompleteness,
                style: TextStyle(
                  fontSize: FontSizeType.body.size,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: AppSpacing.tiny,
                ),
                decoration: BoxDecoration(
                  color: profileState.completenessColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  profileState.completenessLevel,
                  style: TextStyle(
                    fontSize: FontSizeType.small.size,
                    fontWeight: FontWeight.w600,
                    color: profileState.completenessColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.regular),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.iosGray4 : AppColors.iosGray5,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (profileState.completeness / 100).clamp(
                          0.05,
                          1.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: profileState.completenessColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      t.chat.profileProgress(
                        percent: profileState.completeness,
                      ),
                      style: TextStyle(
                        fontSize: FontSizeType.footnote.size,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.regular),
              Text(
                '${profileState.completeness}%',
                style: TextStyle(
                  fontSize: FontSizeType.largeTitle.size,
                  fontWeight: FontWeight.bold,
                  color: profileState.completenessColor,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.regular),

          _buildSuggestions(context, profileNotifier, isDark),
        ],
      ),
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
    dynamic profileNotifier,
    bool isDark,
  ) {
    final List<dynamic> suggestions =
        profileNotifier.getCompletionSuggestions() as List<dynamic>;
    if (suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: AppColors.iosGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.iosGreen, size: 18),
            const SizedBox(width: AppSpacing.small),
            Text(
              t.chat.profileCompleted,
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
                color: AppColors.iosGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.common.completionSuggestions,
          style: TextStyle(
            fontSize: FontSizeType.footnote.size,
            fontWeight: FontWeight.w500,
            color: AppColors.iosGray,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (suggestions as List<String>)
              .take(3)
              .map(
                (suggestion) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: FontSizeType.small.size,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
