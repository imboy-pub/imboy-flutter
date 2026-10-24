import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/personal_attachments_page.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_tiles.dart';
import 'package:imboy/page/mine/mine/mine_menu.dart';
import 'package:imboy/page/mine/mine/mine_profile.dart';
import 'package:imboy/page/mine/mine/mine_shortcut.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mine_page.g.dart';

class MineState {
  const MineState();
  MineState copyWith() => const MineState();
}

@riverpod
class MineNotifier extends _$MineNotifier {
  @override
  MineState build() => const MineState();
}

/// Personal and enterprise pages share geometry while keeping their entry gates.
class MinePage extends ConsumerWidget {
  const MinePage({
    super.key,
    this.enterprise = false,
    this.enterpriseName,
    this.enterpriseEntry,
  });

  final bool enterprise;
  final String? enterpriseName;
  final Widget? enterpriseEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureRevisionProvider);
    final user = ref.watch(currentUserProvider);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      child: SafeArea(
        top: !enterprise,
        bottom: !enterprise,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResourcePageLayout.maxWidth,
            ),
            child: _content(
              context,
              MineProfile(
                user: user,
                enterprise: enterprise,
                enterpriseName: enterpriseName,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Widget profile) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.regular,
          AppSpacing.none,
          AppSpacing.regular,
          AppSpacing.xxxLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            profile,
            MineSection(
              title: enterprise ? t.main.mineCommonEntries : t.main.mineContent,
              child: MineShortcutGrid(children: _shortcuts(context)),
            ),
            if (!enterprise) const CsWorkspaceEntryTile(asCard: true),
            _MineManagement(enterprise: enterprise),
          ],
        ),
      );

  List<Widget> _shortcuts(BuildContext context) => [
    MineShortcut(
      label: t.main.favorites,
      icon: CupertinoIcons.bookmark,
      onTap: () => context.push('/favorites'),
    ),
    if (enterprise) ...[
      ?enterpriseEntry,
    ] else ...[
      MineShortcut(
        label: t.talkRecord.entryTitle,
        icon: CupertinoIcons.mic,
        onTap: () => context.push(
          talkRecordListPathFor(const TalkRecordEntryContext.personal()),
        ),
      ),
      MineShortcut(
        label: t.attachmentManager.personalTitle,
        icon: CupertinoIcons.folder,
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => const PersonalAttachmentsPage(),
          ),
        ),
      ),
      if (AppFeatureRegistry.isEnabled(FeatureKeys.wallet))
        MineShortcut(
          label: t.account.wallet,
          icon: CupertinoIcons.creditcard,
          onTap: () => context.push('/wallet'),
        ),
    ],
  ];
}

class _MineManagement extends StatelessWidget {
  const _MineManagement({required this.enterprise});

  final bool enterprise;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (!enterprise) ...[
        (t.main.storageSpace, CupertinoIcons.archivebox, '/storage_space'),
        (
          t.account.loginDeviceManagement,
          CupertinoIcons.device_phone_portrait,
          '/devices',
        ),
        (t.appeal.title, CupertinoIcons.shield, '/mine/appeal'),
      ],
      (t.main.setting, CupertinoIcons.settings, '/mine/setting'),
      (t.common.feedback, CupertinoIcons.chat_bubble, '/feedback'),
    ];
    return MineSection(
      title: enterprise
          ? t.main.mineSettingsSupport
          : t.main.mineManagementSupport,
      child: Column(
        children: [
          for (final (index, item) in items.indexed)
            MineMenuTile(
              title: item.$1,
              icon: item.$2,
              detail: item.$3 == '/storage_space'
                  ? t.main.mineStorageUsage
                  : null,
              showDivider: index < items.length - 1,
              onTap: () => context.push(item.$3),
            ),
        ],
      ),
    );
  }
}
