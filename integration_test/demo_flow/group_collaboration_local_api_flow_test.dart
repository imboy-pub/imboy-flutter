// DF-10 群协作（群日程 → 群任务 → 群投票）本地后端 API 闭环 flow 测试。
//
// 与 integration_test/demo_flow/group_collaboration_flow_test.dart（生产双账号
// + 真机 UI 挂载）互补：本文件是纯 Dart API 级闭环，无需设备，用 `dart test` 运行：
//
//   read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, "");
//     sub(/[[:space:]]*#.*$/, ""); print; exit}' <file>; }
//   API_BASE_URL="$(read_env API_BASE_URL scripts/test.env)" \
//   TEST_PHONE="$(read_env TEST_PHONE scripts/test.env)" \
//   TEST_PASSWORD="$(read_env TEST_PASSWORD scripts/test.env)" \
//   IMBOY_SOLIDIFIED_KEY="$(read_env SOLIDIFIED_KEY .env.local)" \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/group_collaboration_local_api_flow_test.dart \
//     --concurrency=1
//
// 安全约束：
// - 只允许本地/开发后端（ApiTestClient.ensureBusinessWriteAllowed 门禁校验 host）；
//   生产 URL 一律拒绝。
// - 必须显式 TEST_ALLOW_API_WRITES=true。
// - 测试数据命名带 DEMO-FLOW-20260817 前缀；不取消日程、不删除任务、不撤销投票。
// - 单账号闭环：创建者本人确认日程/提交任务/投票；无第二本地可登录账号时，
//   记录单账号覆盖范围（双账号互补证据见生产 group_collaboration_flow_test.dart）。

@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import '../../test/unit_test/api/api_test_client.dart';

const _prefix = 'DEMO-FLOW-20260817';
final _runTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

void _log(String msg) => stderr.writeln('[DF10-LOCAL] $msg');

String _rfc3339(int seconds) => DateTime.fromMillisecondsSinceEpoch(
  seconds * 1000,
  isUtc: true,
).toIso8601String();

List<Map<String, dynamic>> _asList(dynamic payload) {
  final list = payload is Map
      ? (payload['list'] ?? payload['items'] ?? payload['data'])
      : payload;
  if (list is! List) return const [];
  return list
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
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

String _readId(Map<String, dynamic>? value, List<String> keys) {
  if (value == null) return '';
  for (final key in keys) {
    final id = value[key]?.toString().trim() ?? '';
    if (id.isNotEmpty) return id;
  }
  return '';
}

bool _containsMarker(dynamic value, String marker) {
  if (value is Map) return value.values.any((v) => _containsMarker(v, marker));
  if (value is Iterable) return value.any((v) => _containsMarker(v, marker));
  return value?.toString().contains(marker) ?? false;
}

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String uid = '';
  String gid = '';
  String groupTitle = '';

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) {
      _log('缺少 TEST_PHONE/TEST_PASSWORD，未登录');
      return;
    }
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (!loggedIn) {
      _log('登录失败: ${resp['msg']}');
      return;
    }
    uid = client.currentUid ?? '';
    _log('登录成功 uid=$uid');

    final page = await client.get(
      '/api/v1/group/page',
      queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
    );
    if (page['code'] != 0) {
      _log('group/page 失败 code=${page['code']} msg=${page['msg']}');
    } else {
      final list = _asList(page['payload']);
      _log('group/page 返回 ${list.length} 个群');
      if (list.isNotEmpty) {
        final first = list.first;
        final raw = first['group_id'] ?? first['gid'] ?? first['id'];
        if (raw != null) {
          gid = raw.toString();
          groupTitle = first['title']?.toString() ?? '';
        }
      }
    }

    if (gid.isEmpty) {
      // 本地账号没有可复用群：创建专属测试群（空成员集合，由群主本人构成，
      // 后端按成员集合幂等，与 DF-14/DF-15 本地 flow 共用同一 gid），
      // 并显式命名以便与并行的其他测试会话区分。
      const newTitle = 'DEMO-FLOW-20260817-COLLAB';
      final created = await client.post(
        '/api/v1/group/add',
        data: {'member_uids': <String>[]},
      );
      ApiAssert.success(created, context: '创建测试群');
      final group = created['payload'] is Map
          ? (created['payload'] as Map)['group']
          : null;
      final raw = group is Map
          ? (group['group_id'] ?? group['gid'] ?? group['id'])
          : null;
      expect(raw, isNotNull, reason: '建群响应缺少 group.id: ${created['payload']}');
      gid = raw.toString();
      final edit = await client.post(
        '/api/v1/group/edit',
        data: {'gid': gid, 'title': newTitle},
      );
      ApiAssert.success(edit, context: '命名测试群');
      groupTitle = newTitle;
      _log('已创建测试群 gid=$gid title=$newTitle');
    }
    _log('测试群: gid=$gid title=$groupTitle');
  });

  tearDownAll(() => client.close());

  test('前置：登录并定位本地测试群', () {
    expect(loggedIn, isTrue, reason: '本地测试账号必须登录成功');
    expect(gid, isNotEmpty, reason: '本地测试账号必须至少加入一个群');
    expect(BigInt.tryParse(gid), isNotNull, reason: 'gid 应为可解析 TSID');
    _log('前置通过 gid=$gid');
  });

  test('日程闭环：创建 → 列表回读 → 确认参加 → 详情回读', () async {
    final title = '$_prefix-SCHEDULE-$_runTs';
    final marker = '$_prefix-SCHED-MARK-$_runTs';
    final created = await client.post(
      '/api/v1/group_schedule/create',
      data: {
        'group_id': gid,
        'title': title,
        'start_at': _runTs + 3600,
        'end_at': _runTs + 7200,
        'description': marker,
        'location': 'DEMO-FLOW 本地测试地点',
        'participant_ids': [uid],
      },
    );
    ApiAssert.success(created, context: '创建日程');
    _log('创建日程 code=${created['code']} title=$title');

    final scheduleId = _readId(created['payload'] as Map<String, dynamic>?, [
      'schedule_id',
      'id',
    ]);
    expect(scheduleId, isNotEmpty, reason: '创建日程响应缺少 schedule_id/id');

    final listResp = await client.get(
      '/api/v1/group_schedule/list',
      queryParameters: {'group_id': gid, 'page': 1, 'size': 20},
    );
    ApiAssert.success(listResp, context: '日程列表');
    final fromList = _findByTitle(_asList(listResp['payload']), title);
    expect(fromList, isNotNull, reason: '列表回读必须包含新建日程');
    final listId = _readId(fromList, ['schedule_id', 'id']);
    _log('列表回读命中 schedule_id=$listId');

    final confirm = await client.post(
      '/api/v1/group_schedule/confirm',
      data: {'group_id': gid, 'schedule_id': scheduleId, 'accept': true},
    );
    ApiAssert.success(confirm, context: '确认参加日程');
    _log('确认参加 code=${confirm['code']}');

    final detail = await client.get(
      '/api/v1/group_schedule/detail',
      queryParameters: {'group_id': gid, 'schedule_id': scheduleId},
    );
    ApiAssert.success(detail, context: '日程详情');
    final payload = detail['payload'];
    final schedule = payload is Map && payload['schedule'] is Map
        ? payload['schedule'] as Map
        : (payload is Map ? payload : null);
    // participants/participant_count 在 payload 顶层（本地 alpha.27 契约）
    final participants = payload is Map ? payload['participants'] : null;
    final participantCount = payload is Map
        ? payload['participant_count']
        : null;
    expect(
      schedule?['title']?.toString(),
      title,
      reason: '详情回读标题不一致: $schedule',
    );
    expect(participants, isA<List<dynamic>>(), reason: '详情应返回 participants 列表');
    final joined = (participants as List).any((p) {
      if (p is! Map) return false;
      return (p['user_id'] ?? p['uid'] ?? p['id'])?.toString() == uid;
    });
    expect(joined, isTrue, reason: 'participants 应包含确认参加的自己(uid=$uid)');
    _log(
      '详情回读通过 participant_count=$participantCount '
      'participants=${participants.length} 含自己',
    );
  });

  test('任务闭环：创建 → 分配 → 列表回读 → 提交 → 详情回读', () async {
    final title = '$_prefix-TASK-$_runTs';
    final marker = '$_prefix-TASK-MARK-$_runTs';
    final created = await client.post(
      '/api/v1/group/task/create',
      data: {
        'group_id': gid,
        'title': title,
        'description': marker,
        'deadline': _rfc3339(_runTs + 86400),
        'user_ids': [uid],
      },
    );
    ApiAssert.success(created, context: '创建任务');
    _log('创建任务 code=${created['code']} title=$title');

    final taskMap = created['payload'] is Map
        ? Map<String, dynamic>.from(created['payload'] as Map<dynamic, dynamic>)
        : null;
    final taskId = _readId(taskMap, ['task_id']);
    final routeId = _readId(taskMap, ['id', 'task_id']);
    expect(taskId, isNotEmpty, reason: '创建任务响应缺少 task_id: $taskMap');

    final assign = await client.post(
      '/api/v1/group/task/assign',
      data: {
        'group_id': gid,
        'task_id': taskId,
        'user_ids': [uid],
      },
    );
    ApiAssert.success(assign, context: '分配任务');
    _log('分配任务给自己 code=${assign['code']}');

    final listResp = await client.get(
      '/api/v1/group/task/list',
      queryParameters: {'group_id': gid, 'page': 1, 'size': 20},
    );
    ApiAssert.success(listResp, context: '任务列表');
    final fromList = _findByTitle(_asList(listResp['payload']), title);
    expect(fromList, isNotNull, reason: '列表回读必须包含新建任务');
    _log('列表回读命中任务');

    final submit = await client.post(
      '/api/v1/group/task/submit',
      data: {'group_id': gid, 'task_id': taskId, 'content': marker},
    );
    ApiAssert.success(submit, context: '提交任务');
    _log('提交任务 code=${submit['code']}');

    final detail = await client.get(
      '/api/v1/group/task/detail',
      queryParameters: {'group_id': gid, 'task_id': routeId},
    );
    ApiAssert.success(detail, context: '任务详情');
    expect(
      _containsMarker(detail['payload'], marker),
      isTrue,
      reason: '任务详情应包含提交内容标记',
    );
    _log('详情回读包含提交标记');
  });

  test('投票闭环：创建 → 列表回读 → 投票 → 我的投票回读', () async {
    final title = '$_prefix-VOTE-$_runTs';
    final created = await client.post(
      '/api/v1/group/vote/create',
      data: {
        'gid': gid,
        'title': title,
        'options': [
          {'option_text': '参加', 'sort_order': 1},
          {'option_text': '不参加', 'sort_order': 2},
        ],
        'is_anonymous': false,
        'vote_type': 1,
        'end_at': _rfc3339(_runTs + 86400),
      },
    );
    ApiAssert.success(created, context: '创建投票');
    _log('创建投票 code=${created['code']} title=$title');

    final listResp = await client.get(
      '/api/v1/group/vote/list',
      queryParameters: {'gid': gid, 'page': 1, 'size': 20},
    );
    ApiAssert.success(listResp, context: '投票列表');
    final fromList = _findByTitle(_asList(listResp['payload']), title);
    expect(fromList, isNotNull, reason: '列表回读必须包含新建投票');
    final voteId = _readId(fromList, ['vote_id', 'id']);
    expect(voteId, isNotEmpty, reason: '投票列表项缺少 vote_id/id');
    _log('列表回读命中 vote_id=$voteId');

    final detail = await client.get(
      '/api/v1/group/vote/detail',
      queryParameters: {'gid': gid, 'vote_id': voteId},
    );
    ApiAssert.success(detail, context: '投票详情');
    final options = detail['payload'] is Map
        ? (detail['payload'] as Map)['options']
        : null;
    expect(options, isA<List<dynamic>>(), reason: '投票详情应返回选项列表');
    expect((options as List), isNotEmpty, reason: '投票选项不应为空');
    final option = options.first as Map;
    final optionId = (option['option_id'] ?? option['id'])?.toString() ?? '';
    expect(optionId, isNotEmpty, reason: '投票选项缺少 option_id/id');

    final cast = await client.post(
      '/api/v1/group/vote/cast',
      data: {
        'gid': gid,
        'vote_id': voteId,
        'option_ids': [optionId],
      },
    );
    ApiAssert.success(cast, context: '投票');
    _log('投票提交 code=${cast['code']} option_id=$optionId');

    final myVote = await client.get(
      '/api/v1/group/vote/my_vote',
      queryParameters: {'vote_id': voteId},
    );
    ApiAssert.success(myVote, context: '我的投票回读');
    final payload = myVote['payload'];
    final optionIds = payload is Map ? payload['option_ids'] : null;
    expect(
      optionIds is List &&
          optionIds.map((e) => e.toString()).contains(optionId),
      isTrue,
      reason: '我的投票应包含已投选项 option_id=$optionId, payload=$payload',
    );
    _log('我的投票回读包含已投选项');
  });
}
