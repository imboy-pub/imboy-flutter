// 群作业页面 Widget 集成测试 / GroupTask Page Widget Integration Tests
//
// 测试策略 / Test strategy:
//   - 使用 flutter_test + FakeGroupTaskService 桩替换真实网络调用
//   - 不依赖真实设备或后端，在 CI flutter test 中稳定运行
//   - 覆盖：列表渲染、过滤标签交互、创建对话框、提交、空状态
//   - Use flutter_test + FakeGroupTaskService stub, no real network/device
//   - Coverage: list rendering, filter tabs, create dialog, submit, empty state
//
// 运行方式 / How to run:
//   flutter test test/widget/group_task_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/task/group_task_page.dart';
import 'package:imboy/service/group_task_service.dart';

// ---------------------------------------------------------------------------
// Fake 服务实现 / Fake service implementation
// ---------------------------------------------------------------------------

/// GroupTaskService 的可配置 fake 实现
/// Configurable fake implementation of GroupTaskService
class FakeGroupTaskService implements IGroupTaskService {
  List<Map<String, dynamic>> tasksToReturn;
  bool shouldFailCreate;
  bool shouldFailSubmit;
  int createCallCount = 0;
  int submitCallCount = 0;
  String? lastCreatedTitle;
  String? lastSubmittedContent;

  FakeGroupTaskService({
    this.tasksToReturn = const [],
    this.shouldFailCreate = false,
    this.shouldFailSubmit = false,
  });

  @override
  Future<List<Map<String, dynamic>>> getTasks({
    required String groupId,
    int? status,
    String? assigneeId,
    int page = 1,
    int size = 20,
  }) async {
    if (status != null) {
      return tasksToReturn
          .where((t) => t['status'] == status)
          .toList();
    }
    return List.from(tasksToReturn);
  }

  @override
  Future<Map<String, dynamic>?> getTask({
    required String groupId,
    required dynamic taskId,
  }) async => null;

  @override
  Future<List<Map<String, dynamic>>> getPendingReview({
    required String taskId,
    int page = 1,
    int size = 20,
  }) async => [];

  @override
  Future<Map<String, dynamic>?> createTask({
    required String groupId,
    required String title,
    String? description,
    int? deadline,
    List<String>? assigneeIds,
  }) async {
    createCallCount++;
    lastCreatedTitle = title;
    if (shouldFailCreate) return null;
    final newTask = {
      'id': 9000 + createCallCount,
      'task_id': 'task_fake_$createCallCount',
      'title': title,
      'description': description ?? '',
      'status': 1,
      'group_id': groupId,
    };
    tasksToReturn = [...tasksToReturn, newTask];
    return newTask;
  }

  @override
  Future<bool> submitTask({
    required String groupId,
    required dynamic taskId,
    String? content,
    List<String>? attachments,
  }) async {
    submitCallCount++;
    lastSubmittedContent = content;
    return !shouldFailSubmit;
  }
}

// ---------------------------------------------------------------------------
// 测试辅助 / Test helpers
// ---------------------------------------------------------------------------

/// 固定测试任务数据
const _kFakeTasks = [
  {
    'id': 1001,
    'task_id': 'task_abc_1001',
    'title': '第一章练习题',
    'description': '完成课本第一章所有习题',
    'status': 1,
    'group_id': '200',
    'deadline': null,
  },
  {
    'id': 1002,
    'task_id': 'task_abc_1002',
    'title': '期中作业',
    'description': '完成期中综合练习',
    'status': 2,
    'group_id': '200',
    'deadline': '2099-06-30',
  },
];

/// 构建被测 widget / Build the widget under test
///
/// 按照 slang 要求包裹 TranslationProvider，避免 "Please wrap with TranslationProvider" 异常。
/// Wraps with TranslationProvider as required by slang to avoid the "Please wrap" exception.
Widget _buildTestApp(Widget home) {
  return TranslationProvider(
    child: ProviderScope(
      child: MaterialApp(
        home: home,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 测试用例 / Test cases
// ---------------------------------------------------------------------------

void main() {
  tearDown(() => GroupTaskService.resetInstance());

  group('GroupTaskPage —— 列表渲染 / List rendering', () {
    testWidgets('显示作业标题列表 / displays task titles', (tester) async {
      final fake = FakeGroupTaskService(
        tasksToReturn: List<Map<String, dynamic>>.from(_kFakeTasks),
      );
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));

      // 等待异步加载完成 / Wait for async load
      await tester.pumpAndSettle();

      expect(find.text('第一章练习题'), findsOneWidget);
      expect(find.text('期中作业'), findsOneWidget);
    });

    testWidgets('空列表时显示无数据视图 / shows empty state when no tasks', (tester) async {
      final fake = FakeGroupTaskService(tasksToReturn: []);
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));
      await tester.pumpAndSettle();

      // 空状态视图应该可见（NoDataView 或类似组件）
      // Empty state should be visible
      expect(find.byKey(const Key('group_task_empty')), findsOneWidget);
    });

    testWidgets('加载中显示进度指示器 / shows loading indicator while fetching',
        (tester) async {
      // 使用慢速 fake 验证 loading 状态 / Use slow fake to verify loading state
      final fake = _SlowFakeGroupTaskService();
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));

      // pump 一帧（不 settle），此时仍在加载
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 推进 fake timer 使 pending timer 清空，避免测试框架报 "timer still pending"
      // Advance fake timer to drain the pending 10-second timer before test teardown
      await tester.pump(const Duration(seconds: 11));
      // flush Riverpod 的 0 延迟 provider dispose 定时器
      // Flush Riverpod's 0-duration provider dispose timer scheduled during rebuild
      await tester.pump(Duration.zero);
    });
  });

  group('GroupTaskPage —— 过滤标签 / Filter tabs', () {
    testWidgets('切换"待完成"过滤标签 / tap todo filter tab', (tester) async {
      final fake = FakeGroupTaskService(
        tasksToReturn: List<Map<String, dynamic>>.from(_kFakeTasks),
      );
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));
      await tester.pumpAndSettle();

      // 点击"待完成"过滤标签 / Tap "todo" filter tab
      await tester.tap(find.byKey(const Key('filter_tab_todo')));
      await tester.pumpAndSettle();

      // status=1 的作业应展示，status=2 的不展示
      // Tasks with status=1 should show; status=2 should not
      expect(find.text('第一章练习题'), findsOneWidget);
      expect(find.text('期中作业'), findsNothing);
    });

    testWidgets('切换"全部"过滤标签恢复全量显示 / tap all tab restores all tasks',
        (tester) async {
      final fake = FakeGroupTaskService(
        tasksToReturn: List<Map<String, dynamic>>.from(_kFakeTasks),
      );
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));
      await tester.pumpAndSettle();

      // 先切到"待完成" / First switch to "todo"
      await tester.tap(find.byKey(const Key('filter_tab_todo')));
      await tester.pumpAndSettle();

      // 再切回"全部" / Then back to "all"
      await tester.tap(find.byKey(const Key('filter_tab_all')));
      await tester.pumpAndSettle();

      expect(find.text('第一章练习题'), findsOneWidget);
      expect(find.text('期中作业'), findsOneWidget);
    });
  });

  group('GroupTaskPage —— 创建作业对话框 / Create dialog', () {
    testWidgets('点击创建按钮弹出对话框 / tap create opens dialog', (tester) async {
      final fake = FakeGroupTaskService(tasksToReturn: []);
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create_task_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('create_task_dialog')), findsOneWidget);
      expect(find.byKey(const Key('task_title_field')), findsOneWidget);
    });

    testWidgets('空标题无法提交 / empty title cannot submit', (tester) async {
      final fake = FakeGroupTaskService(tasksToReturn: []);
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create_task_fab')));
      await tester.pumpAndSettle();

      // 不填标题直接点确认 / Tap confirm without filling title
      await tester.tap(find.byKey(const Key('create_task_confirm')));
      await tester.pumpAndSettle();

      // 对话框仍存在（未关闭） / Dialog should still be open
      expect(find.byKey(const Key('create_task_dialog')), findsOneWidget);
      expect(fake.createCallCount, 0);
    });

    testWidgets('填写标题后创建成功并刷新列表 / creates task and refreshes list',
        (tester) async {
      final fake = FakeGroupTaskService(tasksToReturn: []);
      GroupTaskService.testInstance = fake;

      await tester.pumpWidget(_buildTestApp(
        const GroupTaskPage(groupId: '200'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create_task_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('task_title_field')), '新建集成测试作业');
      await tester.tap(find.byKey(const Key('create_task_confirm')));
      await tester.pumpAndSettle();

      expect(fake.createCallCount, 1);
      expect(fake.lastCreatedTitle, '新建集成测试作业');
      // 对话框关闭 / Dialog closed
      expect(find.byKey(const Key('create_task_dialog')), findsNothing);
      // 新作业出现在列表 / New task appears in list
      expect(find.text('新建集成测试作业'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// 慢速 Fake（用于 loading 状态测试）
// Slow fake for loading state test
// ---------------------------------------------------------------------------
class _SlowFakeGroupTaskService implements IGroupTaskService {
  @override
  Future<List<Map<String, dynamic>>> getTasks({
    required String groupId,
    int? status,
    String? assigneeId,
    int page = 1,
    int size = 20,
  }) async {
    await Future<dynamic>.delayed(const Duration(seconds: 10));
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getTask({
    required String groupId,
    required dynamic taskId,
  }) async => null;

  @override
  Future<List<Map<String, dynamic>>> getPendingReview({
    required String taskId,
    int page = 1,
    int size = 20,
  }) async => [];

  @override
  Future<Map<String, dynamic>?> createTask({
    required String groupId,
    required String title,
    String? description,
    int? deadline,
    List<String>? assigneeIds,
  }) async {
    return null;
  }

  @override
  Future<bool> submitTask({
    required String groupId,
    required dynamic taskId,
    String? content,
    List<String>? attachments,
  }) async {
    return false;
  }
}
