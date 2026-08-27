import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/store/api/project_api.dart';
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/api/workspace_api.dart';

class FakeP extends ProjectApi {
  @override
  Future<ProjectModel> detail(EntityId projectId) async {
    throw const WorkspaceApiException(404, '项目不存在');
  }
}

void main() {
  testWidgets('probe container', (tester) async {
    final container = ProviderContainer(
      overrides: [projectApiProvider.overrideWith((ref) => FakeP())],
    );
    addTearDown(container.dispose);
    try {
      final v = await container.read(projectDetailProvider('5001').future);
      debugPrint('RESULT data=$v');
    } catch (e) {
      debugPrint('RESULT error=$e');
    }
    await tester.pump();
  });
}
