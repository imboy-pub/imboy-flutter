import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';

import 'org_async_state.dart';

import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

final _deletionCheck = FutureProvider.autoDispose((ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  return ref.watch(organizationApiProvider).deletionPreflight();
}, retry: (_, _) => null);

/// Read-only account check. This screen never submits an account deletion.
class AccountDeletionCheckPage extends ConsumerWidget {
  const AccountDeletionCheckPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IosPageTemplate(
    title: context.t.organization.experienceUi.accountCheck,
    body: ref
        .watch(_deletionCheck)
        .when(
          loading: () => const WorkspaceLoadingView(),
          error: (e, _) => OrgAsyncAdapter(
            loading: false,
            empty: false,
            error: e,
            child: const SizedBox.shrink(),
            onRetry: () => ref.invalidate(_deletionCheck),
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
                  ExpansionTile(
                    title: Text(blocker.resourceType),
                    leading: const Icon(CupertinoIcons.nosign),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.regular),
                        child: SelectableText(blocker.code),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
  );
}
