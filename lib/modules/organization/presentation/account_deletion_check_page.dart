import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:go_router/go_router.dart';

import '../domain/organization_models.dart';
import 'account_deletion_check_provider.dart';

import 'org_async_state.dart';

import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Read-only account check. This screen never submits an account deletion.
class AccountDeletionCheckPage extends ConsumerWidget {
  const AccountDeletionCheckPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IosPageTemplate(
    title: context.t.organization.experienceUi.accountCheck,
    body: ref
        .watch(accountDeletionCheckProvider)
        .when(
          loading: () => const WorkspaceLoadingView(),
          error: (e, _) => OrgAsyncAdapter(
            loading: false,
            empty: false,
            error: e,
            child: const SizedBox.shrink(),
            onRetry: () =>
                ref.read(accountDeletionCheckProvider.notifier).refresh(),
          ),
          data: (report) => ListView(
            padding: const EdgeInsets.all(AppSpacing.regular),
            children: [
              Text(context.t.organization.detail.deletionPreflightDesc),
              AppSpacing.verticalRegular,
              if (report.blockers.isEmpty)
                Text(context.t.organization.detail.noBlockers)
              else ...[
                Text(context.t.organization.detail.blockers),
                for (final blocker in report.blockers)
                  _BlockerTile(blocker: blocker, report: report),
              ],
            ],
          ),
        ),
  );
}

class _BlockerTile extends ConsumerWidget {
  final PreflightBlocker blocker;
  final DeletionPreflightReport report;
  const _BlockerTile({required this.blocker, required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> open(String route) async {
      await context.push(route);
      if (context.mounted) {
        await ref.read(accountDeletionCheckProvider.notifier).refresh();
      }
    }

    final t = context.t.organization.experienceUi;
    final (title, body) = switch (blocker.code) {
      'TALK_RECORD_PERSONAL_PENDING' => (
        t.talkRecordPersonalPendingTitle,
        t.talkRecordPersonalPendingBody,
      ),
      'TALK_RECORD_CLEANUP_PENDING' => (
        t.talkRecordCleanupPendingTitle,
        t.talkRecordCleanupPendingBody,
      ),
      'TALK_RECORD_ORGANIZATION_OWNER_PENDING' => (
        t.talkRecordOrganizationOwnerPendingTitle,
        t.talkRecordOrganizationOwnerPendingBody,
      ),
      'TALK_RECORD_RETAINED_IDENTITY_PENDING' => (
        t.talkRecordRetainedIdentityPendingTitle,
        t.talkRecordRetainedIdentityPendingBody,
      ),
      _ => (t.unknownBlockerTitle, blocker.code),
    };
    return ExpansionTile(
      title: Text(title),
      leading: const Icon(CupertinoIcons.nosign),
      childrenPadding: const EdgeInsets.all(AppSpacing.regular),
      children: [
        Align(alignment: Alignment.centerLeft, child: Text(body)),
        if (blocker.code == 'TALK_RECORD_PERSONAL_PENDING')
          ListTile(
            title: Text(t.openPersonalTalkRecords),
            trailing: const Icon(CupertinoIcons.chevron_right),
            onTap: () => open('/talk_record?scope=personal'),
          ),
        if (blocker.code == 'TALK_RECORD_CLEANUP_PENDING') ...[
          for (final resource in report.cleanupResources)
            ListTile(
              title: Text('${t.cleanupRecordLabel} ${resource.recordId}'),
              subtitle: Text(t.viewTalkRecordCleanup),
              trailing: const Icon(CupertinoIcons.chevron_right),
              onTap: () =>
                  open('/talk_record/detail/${resource.recordId}/cleanup'),
            ),
          if (report.cleanupResourcesTruncated)
            Text(t.cleanupResourcesTruncated),
        ],
      ],
    );
  }
}
