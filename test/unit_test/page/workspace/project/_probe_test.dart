import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart'
    show workspaceApiProvider;
import 'package:imboy/page/workspace/project/home/project_detail_page.dart';
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/api/project_api.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show WorkspaceErrorView, WorkspaceLoadingView;

class FakeP extends ProjectApi {
  @override
  Future<ProjectModel> detail(EntityId projectId) async {
    throw const WorkspaceApiException(404, '项目不存在');
  }
}

class FakeW extends WorkspaceApi {
  @override
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId w, {
    int page = 1,
    int size = 20,
  }) async => const WorkspacePageResult<WorkspaceMemberModel>(
    list: [],
    total: 0,
    totalPage: 1,
  );
}

void main() {
  testWidgets('probe', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            projectApiProvider.overrideWith((ref) => FakeP()),
            workspaceApiProvider.overrideWith((ref) => FakeW()),
            currentWorkspaceProvider.overrideWithValue(
              const WorkspaceModel(id: '9001', name: 'x', ownerId: '1001'),
            ),
          ],
          child: const MaterialApp(home: ProjectDetailPage(projectId: '5001')),
        ),
      ),
    );
    for (final ms in const [16, 60, 200, 400, 1000]) {
      await tester.pump(Duration(milliseconds: ms));
    }
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    debugPrint('TEXTS: $texts');
    debugPrint(
      'spinner=${find.byType(CircularProgressIndicator).evaluate().length} '
      'errView=${find.byType(WorkspaceErrorView).evaluate().length} '
      'loadingView=${find.byType(WorkspaceLoadingView).evaluate().length}',
    );
  });
}
