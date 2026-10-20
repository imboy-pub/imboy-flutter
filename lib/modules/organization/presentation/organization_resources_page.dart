import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/resource_entry_tile.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';

import 'org_async_state.dart';

import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

final _resourceWorkspaces = FutureProvider.autoDispose
    .family<({bool archived, List<WorkspaceModel> items}), (String, String)>((
      ref,
      scope,
    ) async {
      // The organization detail read remains the permission gate, even for deep links.
      final org = await ref.watch(organizationApiProvider).detail(scope.$1);
      if (org.isArchived) {
        return (archived: true, items: const <WorkspaceModel>[]);
      }
      final api = WorkspaceApi();
      final result = <WorkspaceModel>[];
      var page = 1;
      while (true) {
        final batch = await api.mine(page: page, size: 100);
        result.addAll(batch.list.where((ws) => ws.belongsToOrg(scope.$1)));
        if (page >= batch.totalPage || batch.list.isEmpty) break;
        page++;
      }
      return (archived: false, items: result);
    }, retry: (_, _) => null);

/// A readable resource browser, separate from enterprise governance.
class OrganizationResourcesPage extends ConsumerWidget {
  const OrganizationResourcesPage({
    super.key,
    required this.organizationId,
    required this.channels,
  });

  final String organizationId;
  final bool channels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (organizationId, ref.watch(currentUserProvider)?.uid ?? '');
    final title = channels
        ? context.t.channel.title
        : context.t.workspace.navGroups;
    final workspaces = ref.watch(_resourceWorkspaces(scope));
    return IosPageTemplate(
      title: title,
      body: workspaces.when(
        loading: () => const WorkspaceLoadingView(),
        error: (e, _) => OrgAsyncAdapter(
          loading: false,
          empty: false,
          error: e,
          child: const SizedBox.shrink(),
          onRetry: () => ref.invalidate(_resourceWorkspaces(scope)),
        ),
        data: (result) => ListView(
          padding: const EdgeInsets.all(AppSpacing.regular),
          children: [
            Text(context.t.organization.tools.scopeNote),
            if (result.archived)
              Text(context.t.organization.tools.archivedNote)
            else if (result.items.isEmpty)
              Text(context.t.organization.tools.workspaceEmpty),
            for (final ws in result.items)
              ResourceEntryTile(
                title: ws.name,
                subtitle: ws.isArchived
                    ? context.t.organization.manage.archivedBadge
                    : title,
                icon: CupertinoIcons.square_stack_3d_up,
                onTap: ws.isArchived
                    ? null
                    : () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => IosPageTemplate(
                            title: '$title · ${ws.name}',
                            body: channels
                                ? WorkspaceChannelsPage(workspaceId: ws.id)
                                : WorkspaceGroupsPage(workspaceId: ws.id),
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
