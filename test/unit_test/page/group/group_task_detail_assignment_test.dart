import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/task/group_task_detail_page.dart';
import 'package:imboy/service/group_task_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:shared_preferences/shared_preferences.dart';

class _TaskService implements IGroupTaskService {
  _TaskService(this.assignmentStatus, {this.creatorId = 'member'});
  final int assignmentStatus;
  final String creatorId;
  int pendingRequests = 0;

  @override
  Future<Map<String, dynamic>?> getTask({
    required String groupId,
    required dynamic taskId,
  }) async => {
    'task_id': taskId,
    'title': '团队作业',
    'status': 1,
    'creator_id': creatorId,
    'my_assignment': {'status': assignmentStatus},
  };

  @override
  Future<List<Map<String, dynamic>>> getPendingReview({
    required String taskId,
    int page = 1,
    int size = 20,
  }) async {
    pendingRequests++;
    if (creatorId != 'member') throw Exception('无权限操作此作业');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: 'member'});
    await StorageService.init();
  });
  tearDown(GroupTaskService.resetInstance);
  testWidgets('普通成员详情不请求创建者审核接口', (tester) async {
    final service = _TaskService(0, creatorId: 'other');
    GroupTaskService.testInstance = service;
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
    expect(find.text('团队作业'), findsOneWidget);
    expect(find.text('提交作业'), findsOneWidget);
    expect(service.pendingRequests, 0);
  });
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
      if (status == 2) expect(find.text('作业已提交'), findsOneWidget);
    });
  }
}
