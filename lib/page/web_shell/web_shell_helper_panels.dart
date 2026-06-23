import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// Phase 3.2-min — Web Shell Mine Tab 最小面板
class WebMineMinPanel extends ConsumerWidget {
  final String? section;
  final String logoutLabel;

  const WebMineMinPanel({
    super.key,
    required this.section,
    required this.logoutLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final t = Translations.of(context);
    final uid = UserRepoLocal.to.currentUid;
    return Container(
      color: colorScheme.surface,
      padding: AppSpacing.allXLarge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          AppSpacing.verticalRegular,
          Text(
            uid.isEmpty ? t.common.notLoggedIn : 'UID: $uid',
            style: theme.textTheme.titleMedium,
          ),
          if (section != null) ...[
            AppSpacing.verticalSmall,
            Text(
              'section: $section',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          AppSpacing.verticalXLarge,
          OutlinedButton.icon(
            key: const ValueKey('web-mine-logout-btn'),
            onPressed: uid.isEmpty
                ? null
                : () async {
                    final ok = await UserRepoLocal.to.quitLogin();
                    if (!context.mounted) return;
                    if (ok) {
                      context.go(AppRoutes.signIn);
                    } else {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text(t.common.logoutFailed),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.logout),
            label: Text(logoutLabel),
            style: OutlinedButton.styleFrom(minimumSize: const Size(180, 44)),
          ),
        ],
      ),
    );
  }
}

/// Phase 2/3 实施真实 panel 前的占位 widget
class PlaceholderPanel extends StatelessWidget {
  final String label;

  const PlaceholderPanel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = Translations.of(context);
    return Container(
      color: colorScheme.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          AppSpacing.verticalRegular,
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalSmall,
          Text(
            t.common.featureInDevelopment,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
