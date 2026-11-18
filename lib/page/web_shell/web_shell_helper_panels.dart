import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/page/personal_info/personal_info/personal_info_page.dart';

/// Web Shell 复用现有设置与只读个人资料页面。
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
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Center(child: Text(context.t.common.notLoggedIn));
    }
    return switch (section) {
      'setting' || 'settings' => const SettingPage(webMode: true),
      _ => PersonalInfoPage(
        key: ValueKey('web-personal-info:${user.uid}'),
        readOnly: true,
      ),
    };
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
            CupertinoIcons.hammer,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          AppSpacing.verticalRegular,
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          AppSpacing.verticalSmall,
          Text(
            t.common.featureInDevelopment,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
