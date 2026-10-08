import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/task/group_task_detail_page.dart';
import 'package:imboy/service/group_task_service.dart';

class _TaskService implements IGroupTaskService {
  _TaskService(this.assignmentStatus);
  final int assignmentStatus;

  @override
  Future<Map<String, dynamic>?> getTask({
    required String groupId,
    required dynamic taskId,
  }) async => {
    'task_id': taskId,
    'title': '团队作业',
    'status': 1,
    'my_assignment': {'status': assignmentStatus},
  };

  @override
  Future<List<Map<String, dynamic>>> getPendingReview({
    required String taskId,
    int page = 1,
    int size = 20,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(GroupTaskService.resetInstance);
  for (final status in [0, 2, 3]) {
    testWidgets('个人分配状态 $status 决定是否展示提交入口', (tester) async {
      GroupTaskService.testInstance = _TaskService(status);
      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: const MaterialApp(
              home: GroupTaskDetailPage(groupId: '123', taskId: 'task_owned'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('提交作业'), status == 0 ? findsOneWidget : findsNothing);
      if (status == 2) expect(find.text('任务已提交'), findsOneWidget);
    });
  }
}
