import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace/workspace_overview_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/workspace_model.dart';

void main() {
  for (final entry in {
    'projects': WorkspaceProjectsPage,
    'groups': WorkspaceGroupsPage,
    'channels': WorkspaceChannelsPage,
  }.entries) {
    testWidgets('概览 ${entry.key} 入口直接打开资源页，可返回，不依赖旧五项导航', (tester) async {
      AppFeatureRegistry.replaceSnapshotForTest({'project': true});
      addTearDown(() => AppFeatureRegistry.replaceSnapshotForTest({}));
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              currentWorkspaceProvider.overrideWithValue(
                const WorkspaceModel(
                  id: 'ws-a',
                  name: 'synthetic',
                  ownerId: 'mode-a',
                ),
              ),
              workspaceOverviewProvider.overrideWith(
                (ref, id) async => const WorkspaceOverview(),
              ),
              workspaceGroupsProvider.overrideWith((ref, id) async => []),
              workspaceChannelsProvider.overrideWith((ref, id) async => []),
              projectListPageProvider.overrideWith(
                (ref, scope) async => const WorkspacePageResult(),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: WorkspaceOverviewPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('workspace-overview-${entry.key}')));
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
      expect(
        find.byKey(const ValueKey('workspace-shell-bottom-nav')),
        findsNothing,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceOverviewPage), findsOneWidget);
    });
  }
}
