// P0 群协作双账号 flow：117 创建/回读，118 确认日程、提交任务、投票。
// 只使用授权测试账号和既有 P0 测试群；不取消日程、不删除任务、不撤销投票。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/schedule/group_schedule_detail_page.dart';
import 'package:imboy/page/group/schedule/group_schedule_page.dart';
import 'package:imboy/page/group/task/group_task_detail_page.dart';
import 'package:imboy/page/group/task/group_task_page.dart';
import 'package:imboy/page/group/vote/group_vote_detail_page.dart';
import 'package:imboy/page/group/vote/group_vote_page.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_schedule_api.dart';
import 'package:imboy/store/api/group_task_api.dart';
import 'package:imboy/store/api/group_vote_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _ownerUid = '50';
const _memberUid = '4';
const _role = String.fromEnvironment('TEST_COLLAB_ROLE', defaultValue: '');
const _groupTitle = String.fromEnvironment(
  'TEST_GROUP_TITLE',
  defaultValue: '',
);
const _scheduleTitle = String.fromEnvironment(
  'TEST_SCHEDULE_TITLE',
  defaultValue: '',
);
const _taskTitle = String.fromEnvironment('TEST_TASK_TITLE', defaultValue: '');
const _voteTitle = String.fromEnvironment('TEST_VOTE_TITLE', defaultValue: '');
const _marker = String.fromEnvironment('TEST_COLLAB_MARKER', defaultValue: '');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '群日程、任务、投票双账号协作 flow',
    (tester) async {
      if (!_requireAuthorization()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final actualUid = UserRepoLocal.to.currentUid;
      final expectedUid = _role == 'owner' ? _ownerUid : _memberUid;
      if (actualUid != expectedUid) {
        markTestSkipped('当前 App UID=$actualUid，不是授权的 $_role 账号 $expectedUid');
        return;
      }

      final group = await _findGroup(attr: _role == 'owner' ? 'owner' : 'join');
      if (group == null) {
        fail('未找到 P0 测试群：$_groupTitle');
      }

      if (_role == 'owner') {
        await _runOwnerFlow(tester, group);
      } else {
        await _runMemberFlow(tester, group);
      }
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

bool _requireAuthorization() {
  const allow = String.fromEnvironment(
    'TEST_ALLOW_DUAL_ACCOUNT_GROUP_COLLAB_PROD_WRITES',
    defaultValue: 'false',
  );
  if (allow.toLowerCase() != 'true') {
    markTestSkipped(
      '群协作生产写入必须显式设置 TEST_ALLOW_DUAL_ACCOUNT_GROUP_COLLAB_PROD_WRITES=true',
    );
    return false;
  }
  if (!FlowConfig.hasCredentials || !FlowConfig.hasExplicitTestEnvironment) {
    markTestSkipped('缺少群协作测试凭证或显式环境');
    return false;
  }
  if (!FlowConfig.targetsProduction) {
    markTestSkipped('本 flow 只接受已明确授权的生产双账号验证');
    return false;
  }
  if (_role != 'owner' && _role != 'member') {
    markTestSkipped('TEST_COLLAB_ROLE 必须是 owner 或 member');
    return false;
  }
  if (!_groupTitle.startsWith('P0-TEST-GROUP-') ||
      !_scheduleTitle.startsWith('P0-SCHEDULE-') ||
      !_taskTitle.startsWith('P0-TASK-') ||
      !_voteTitle.startsWith('P0-VOTE-') ||
      !_marker.startsWith('P0-COLLAB-')) {
    markTestSkipped('群协作标题和标记必须使用 P0 测试前缀');
    return false;
  }
  return true;
}

Future<void> _runOwnerFlow(WidgetTester tester, String groupId) async {
  final schedule = await _findOrCreateSchedule(groupId);
  final task = await _findOrCreateTask(groupId);
  final vote = await _findOrCreateVote(groupId);

  expect(schedule, isNotNull, reason: '117 必须创建或定位测试日程');
  expect(task, isNotNull, reason: '117 必须创建或定位测试任务');
  expect(vote, isNotNull, reason: '117 必须创建或定位测试投票');

  final scheduleId = _readId(schedule, primary: 'schedule_id');
  final taskId = _readTaskRouteId(task);
  final voteId = _readId(vote, primary: 'vote_id');
  expect(scheduleId, isNotEmpty);
  expect(taskId, isNotEmpty);
  expect(voteId, isNotEmpty);

  final scheduleDetail = await GroupScheduleApi().getSchedule(
    groupId: groupId,
    scheduleId: scheduleId,
  );
  expect(_readTitle(scheduleDetail), _scheduleTitle);
  expect(_containsMarker(scheduleDetail, _marker), isTrue);

  final taskDetail = await GroupTaskApi().getTask(
    groupId: groupId,
    taskId: taskId,
  );
  expect(_readTitle(taskDetail), _taskTitle);
  expect(_containsMarker(taskDetail, _marker), isTrue);

  final voteDetail = await GroupVoteApi().getVote(
    groupId: groupId,
    voteId: voteId,
  );
  expect(_readTitle(voteDetail), _voteTitle);

  await _mountAndPop(
    tester,
    GroupSchedulePage(groupId: groupId),
    find.byType(GroupSchedulePage),
    '117 已回读群日程列表',
  );
  await _mountAndPop(
    tester,
    GroupTaskPage(groupId: groupId),
    find.byType(GroupTaskPage),
    '117 已回读群任务列表',
  );
  await _mountAndPop(
    tester,
    GroupVotePage(groupId: groupId),
    find.byType(GroupVotePage),
    '117 已回读群投票列表',
  );
}

Future<void> _runMemberFlow(WidgetTester tester, String groupId) async {
  final schedules = await GroupScheduleApi().getSchedules(groupId: groupId);
  final schedule = _findByTitle(schedules, _scheduleTitle);
  final scheduleId = _readId(schedule, primary: 'schedule_id');
  expect(scheduleId, isNotEmpty, reason: '118 必须回读管理员创建的日程');

  expect(
    await GroupScheduleApi().confirmSchedule(
      groupId: groupId,
      scheduleId: scheduleId,
      confirm: true,
    ),
    isTrue,
    reason: '118 确认参加必须收到服务端成功响应',
  );
  final scheduleDetail = await GroupScheduleApi().getSchedule(
    groupId: groupId,
    scheduleId: scheduleId,
  );
  expect(_hasParticipant(scheduleDetail, _memberUid), isTrue);

  final tasks = await GroupTaskApi().getTasks(
    groupId: groupId,
    assigneeId: _memberUid,
  );
  final task = _findByTitle(tasks, _taskTitle);
  final taskRouteId = _readTaskRouteId(task);
  final taskSubmitId = _readTaskSubmitId(task);
  expect(taskRouteId, isNotEmpty, reason: '118 必须回读任务详情 ID');
  expect(taskSubmitId, isNotEmpty, reason: '118 必须回读任务提交 ID');
  final taskBeforeSubmit = await GroupTaskApi().getTask(
    groupId: groupId,
    taskId: taskRouteId,
  );
  if (!_containsMarker(taskBeforeSubmit, _marker)) {
    expect(
      await GroupTaskApi().submitTask(
        groupId: groupId,
        taskId: taskSubmitId,
        content: _marker,
      ),
      isTrue,
      reason: '118 提交任务必须收到服务端成功响应',
    );
  }
  final taskDetail = await GroupTaskApi().getTask(
    groupId: groupId,
    taskId: taskRouteId,
  );
  expect(_containsMarker(taskDetail, _marker), isTrue);

  final votes = await GroupVoteApi().getVotes(groupId: groupId);
  final vote = _findByTitle(votes, _voteTitle);
  final voteId = _readId(vote, primary: 'vote_id');
  expect(voteId, isNotEmpty, reason: '118 必须回读管理员创建的测试投票');
  flowLog(
    '投票 ID 字段：vote_id=${vote?['vote_id']} id=${vote?['id']} vote_uid=${vote?['vote_uid']}',
  );
  final voteDetail = await GroupVoteApi().getVote(
    groupId: groupId,
    voteId: voteId,
  );
  final optionId = _firstOptionId(voteDetail);
  expect(optionId, isNotEmpty, reason: '投票详情必须返回可投选项');
  final existing = await GroupVoteApi().getMyVotes(
    voteId: voteId,
    numericVoteId: vote?['id'],
  );
  if (!_containsOption(existing, optionId)) {
    expect(
      await GroupVoteApi().castVote(
        groupId: groupId,
        voteId: voteId,
        optionIds: [optionId],
      ),
      isTrue,
      reason: '118 投票必须收到服务端成功响应',
    );
  }
  final myVote = await GroupVoteApi().getMyVotes(
    voteId: voteId,
    numericVoteId: vote?['id'],
  );
  expect(_containsOption(myVote, optionId), isTrue);

  await _mountAndPop(
    tester,
    GroupScheduleDetailPage(groupId: groupId, scheduleId: scheduleId),
    find.byType(GroupScheduleDetailPage),
    '118 已挂载并回读日程详情',
  );
  await _mountAndPop(
    tester,
    GroupTaskDetailPage(groupId: groupId, taskId: taskRouteId),
    find.byType(GroupTaskDetailPage),
    '118 已挂载并回读任务详情',
  );
  await _mountAndPop(
    tester,
    GroupVoteDetailPage(groupId: groupId, voteId: voteId),
    find.byType(GroupVoteDetailPage),
    '118 已挂载并回读投票详情',
  );
  flowLog('118 已完成日程确认、任务提交和投票，并完成详情页回读');
}

Future<Map<String, dynamic>?> _findOrCreateSchedule(String groupId) async {
  final existing = _findByTitle(
    await GroupScheduleApi().getSchedules(groupId: groupId),
    _scheduleTitle,
  );
  if (existing != null) return existing;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return GroupScheduleApi().createSchedule(
    groupId: groupId,
    title: _scheduleTitle,
    startTime: now + 3600,
    endTime: now + 7200,
    description: _marker,
    location: 'P0 test location',
    participantIds: const [_memberUid],
  );
}

Future<Map<String, dynamic>?> _findOrCreateTask(String groupId) async {
  final existing = _findByTitle(
    await GroupTaskApi().getTasks(groupId: groupId, assigneeId: 'all'),
    _taskTitle,
  );
  if (existing != null) return existing;
  Map<String, dynamic>? task;
  try {
    task = await GroupTaskApi().createTask(
      groupId: groupId,
      title: _taskTitle,
      description: _marker,
      deadline: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
      assigneeIds: const [_memberUid],
    );
  } catch (error) {
    flowLog('任务客户端解析异常：${error.runtimeType}');
  }
  final taskId = _readId(task, primary: 'task_id');
  if (taskId.isNotEmpty) {
    await GroupTaskApi().assignTask(
      groupId: groupId,
      taskId: taskId,
      assigneeIds: const [_memberUid],
    );
  }
  return task;
}

Future<Map<String, dynamic>?> _findOrCreateVote(String groupId) async {
  final existing = _findByTitle(
    await GroupVoteApi().getVotes(groupId: groupId),
    _voteTitle,
  );
  if (existing != null) return existing;
  return GroupVoteApi().createVote(
    groupId: groupId,
    title: _voteTitle,
    options: const ['参加', '不参加'],
    endTime: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400,
  );
}

Future<String?> _findGroup({required String attr}) async {
  final payload = await GroupApi().page(page: 1, size: 100, attr: attr);
  for (final item in _asList(payload)) {
    if (item is Map && item['title']?.toString() == _groupTitle) {
      final id = _readId(item);
      if (id.isNotEmpty) return id;
    }
  }
  return null;
}

Future<void> _mountAndPop(
  WidgetTester tester,
  Widget page,
  Finder pageFinder,
  String message,
) async {
  final navigatorFinder = find.byType(Navigator);
  if (!tester.any(navigatorFinder)) fail('App 未找到根 Navigator');
  final navigator = Navigator.of(
    tester.element(navigatorFinder.first),
    rootNavigator: true,
  );
  final routeResult = navigator.push<void>(
    CupertinoPageRoute<void>(builder: (_) => page),
  );
  expect(
    await _waitFor(tester, () => tester.any(pageFinder), maxAttempts: 40),
    isTrue,
  );
  await settle(tester, maxSeconds: 4);
  flowLog(message);
  if (navigator.canPop()) navigator.pop();
  await settle(tester, maxSeconds: 1);
  await routeResult;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Map) {
    final nested = value['list'] ?? value['items'] ?? value['data'];
    return nested is List ? nested : const [];
  }
  return const [];
}

Map<String, dynamic>? _findByTitle(
  Iterable<Map<String, dynamic>> items,
  String title,
) {
  for (final item in items) {
    if (item['title']?.toString() == title) return item;
  }
  return null;
}

String _readId(dynamic value, {String? primary}) {
  if (value is! Map) return '';
  final keys = <String>['schedule_id', 'task_id', 'vote_id', 'id'];
  if (primary != null) keys.insert(0, primary);
  for (final key in keys) {
    final id = value[key]?.toString().trim() ?? '';
    if (id.isNotEmpty) return id;
  }
  return '';
}

String _readTaskRouteId(dynamic value) {
  if (value is! Map) return '';
  return value['id']?.toString().trim().isNotEmpty == true
      ? value['id'].toString().trim()
      : value['task_id']?.toString().trim() ?? '';
}

String _readTaskSubmitId(dynamic value) {
  if (value is! Map) return '';
  return value['task_id']?.toString().trim().isNotEmpty == true
      ? value['task_id'].toString().trim()
      : value['id']?.toString().trim() ?? '';
}

String _readTitle(dynamic value) {
  if (value is Map) {
    final nested = value['schedule'] ?? value['task'] ?? value['vote'];
    if (nested is Map) return _readTitle(nested);
    return value['title']?.toString() ?? '';
  }
  return '';
}

bool _containsMarker(dynamic value, String marker) {
  if (value is Map) {
    return value.values.any((item) => _containsMarker(item, marker));
  }
  if (value is Iterable) {
    return value.any((item) => _containsMarker(item, marker));
  }
  return value?.toString().contains(marker) ?? false;
}

bool _hasParticipant(dynamic detail, String uid) {
  if (detail is! Map) return false;
  final participants = detail['participants'];
  if (participants is! List) return false;
  return participants.any((item) {
    if (item is! Map) return false;
    return (item['user_id'] ?? item['uid'] ?? item['id'])?.toString() == uid;
  });
}

String _firstOptionId(dynamic detail) {
  if (detail is! Map) return '';
  final options = detail['options'];
  if (options is! List || options.isEmpty || options.first is! Map) return '';
  final option = options.first as Map;
  return (option['option_id'] ?? option['id'])?.toString() ?? '';
}

bool _containsOption(Iterable<Map<String, dynamic>> votes, String optionId) {
  return votes.any((vote) {
    final options = vote['option_ids'];
    return options is List &&
        options.map((item) => item.toString()).contains(optionId);
  });
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() predicate, {
  required int maxAttempts,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return predicate();
}
