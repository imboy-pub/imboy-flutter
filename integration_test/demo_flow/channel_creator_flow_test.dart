// DF-12 频道创建者闭环（API 级，本地环境写入验证）。
//
// 纯 Dart 测试：不依赖 Flutter/设备，复用 test/unit_test/api/api_test_client.dart，
// 用 `dart test integration_test/demo_flow/channel_creator_flow_test.dart --concurrency=1`
// 显式路径运行；`flutter test` 递归扫描 test/ 不会扫到本文件。
//
// 安全门禁（默认全部 SKIP）：
//   TEST_ALLOW_CHANNEL_WRITES=true —— 频道写入开关（对齐 P0_EXECUTION_PLAN 的闸门命名）
//   TEST_ALLOW_API_WRITES=true     —— api_test_client.post 的通用写入门禁
//   API_BASE_URL 必须是本地/开发地址（api_test_client 拒绝生产写入）
//   TEST_PHONE / TEST_PASSWORD     —— 测试账号
//
// 运行示例（本地后端 + scripts/test.env 账号 + .env.local 签名密钥）：
//   read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$2"; }
//   API_BASE_URL="$(read_env API_BASE_URL scripts/test.env | tr -d ' ' | sed 's/ *#.*//')" \
//   TEST_PHONE="$(read_env TEST_PHONE scripts/test.env)" \
//   TEST_PASSWORD="$(read_env TEST_PASSWORD scripts/test.env)" \
//   IMBOY_ENV_PRO=.env.local \
//   TEST_ALLOW_CHANNEL_WRITES=true TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/channel_creator_flow_test.dart \
//     --concurrency=1 --reporter expanded
//
// 覆盖：创建频道(type=0/type=2) → 详情回读 → 编辑 → 发布内容 → 评论 → 管理列表回读。
// 未覆盖：第二订阅者账号视角评论、邀请接受（本地无第二可登录测试账号）。
// 清理策略：频道与内容保留在本地库（marker=DEMO-FLOW-20260817），不做删除写操作。

@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

const _marker = 'DEMO-FLOW-20260817';

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? channelId;
  String? paidChannelId;
  String? messageId;

  String? skipOr({required bool needChannel}) {
    final guard = _writeGuard();
    if (guard != null) {
      markTestSkipped(guard);
      return guard;
    }
    if (!loggedIn) {
      markTestSkipped('测试账号登录失败');
      return 'login-failed';
    }
    if (needChannel && channelId == null) {
      markTestSkipped('前置频道未创建');
      return 'no-channel';
    }
    return null;
  }

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    final guard = _writeGuard();
    if (guard != null) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (loggedIn) {
      _log('登录成功 uid=${client.currentUid}');
    }
  });

  tearDownAll(() => client.close());

  test('DF-12.1 创建免费频道（type=0，DEMO-FLOW-20260817 命名）', () async {
    if (skipOr(needChannel: false) != null) return;
    final resp = await client.post(
      '/api/v1/channel/create',
      data: {
        'name': '$_marker 频道创作者验证',
        'description': '$_marker 自动化创建的测试频道',
        'type': 0,
      },
    );
    ApiAssert.success(resp, context: '创建频道');
    final payload = _payload(resp);
    channelId = '${payload['id'] ?? ''}';
    expect(channelId!.isNotEmpty, isTrue, reason: '创建成功必须返回频道 id');
    expect('${payload['name']}', contains(_marker));
    expect(_readInt(payload['type']), 0);
    _log('创建频道成功 id=$channelId name=${payload['name']}');
  });

  test('DF-12.2 创建付费类型频道 smoke（type=2 可创建，价格为空）', () async {
    if (skipOr(needChannel: false) != null) return;
    final resp = await client.post(
      '/api/v1/channel/create',
      data: {
        'name': '$_marker 付费类型冒烟',
        'description': '$_marker type=2 创建能力验证（价格需 fixture 写入）',
        'type': 2,
      },
    );
    ApiAssert.success(resp, context: '创建付费类型频道');
    final payload = _payload(resp);
    paidChannelId = '${payload['id'] ?? ''}';
    expect(_readInt(payload['type']), 2);
    _log('创建 type=2 频道成功 id=$paidChannelId（无 channel_price 行，订单会被价格校验拒绝）');
  });

  test('DF-12.3 频道详情回读与编辑（update → 再回读）', () async {
    if (skipOr(needChannel: true) != null) return;
    final before = await client.get('/api/v1/channel/$channelId');
    ApiAssert.success(before, context: '编辑前详情回读');
    expect('${_payload(before)['name']}', contains(_marker));

    // channel_handler.update 不校验 HTTP 方法，elib_param:post 只解析 body，
    // 与 lib 客户端的 PUT 等价。
    final updated = await client.post(
      '/api/v1/channel/$channelId/update',
      data: {'description': '$_marker 编辑后的简介 v2'},
    );
    ApiAssert.success(updated, context: '编辑频道简介');

    final after = await client.get('/api/v1/channel/$channelId');
    ApiAssert.success(after, context: '编辑后详情回读');
    expect(
      '${_payload(after)['description']}',
      contains('v2'),
      reason: '编辑必须以服务端回读为准',
    );
    _log('频道编辑回读一致 id=$channelId');
  });

  test('DF-12.4 发布文本内容并回读', () async {
    if (skipOr(needChannel: true) != null) return;
    final published = await client.post(
      '/api/v1/channel/$channelId/message',
      data: {
        'content': '$_marker 发布内容 #1',
        'msg_type': 'text',
        'request_id': '$_marker-${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    ApiAssert.success(published, context: '发布频道内容');
    messageId = '${_payload(published)['id'] ?? ''}';
    expect(messageId!.isNotEmpty, isTrue, reason: '发布成功必须返回消息 id');

    final messages = await client.get(
      '/api/v1/channel/$channelId/messages',
      queryParameters: {'limit': 20},
    );
    ApiAssert.success(messages, context: '频道消息列表回读');
    final list = _payload(messages)['list'];
    expect(list, isA<List<dynamic>>());
    expect(
      (list as List<dynamic>).any((m) => '$m'.contains('$_marker 发布内容 #1')),
      isTrue,
      reason: '发布的内容必须出现在服务端消息列表',
    );
    _log('发布内容成功 messageId=$messageId，服务端列表回读命中');
  });

  test('DF-12.5 发表评论并回读（创作者视角；第二订阅者账号缺失，见文档）', () async {
    if (skipOr(needChannel: true) != null) return;
    if (messageId == null) {
      markTestSkipped('前序发布步骤未产生 messageId');
      return;
    }
    final commented = await client.post(
      '/api/v1/channel/$channelId/message/$messageId/comment',
      data: {'content': '$_marker 评论 #1', 'parent_id': 0},
    );
    ApiAssert.success(commented, context: '发表频道评论');
    final commentId = '${_payload(commented)['id'] ?? ''}';
    expect(commentId.isNotEmpty, isTrue);

    final comments = await client.get(
      '/api/v1/channel/$channelId/message/$messageId/comments',
      queryParameters: {'cursor': 0, 'limit': 20},
    );
    ApiAssert.success(comments, context: '评论列表回读');
    final list = _payload(comments)['list'];
    expect(
      list == null || list is List,
      isTrue,
      reason: '评论列表 payload.list 应为 List 或 null',
    );
    expect(
      '$list'.contains('$_marker 评论 #1'),
      isTrue,
      reason: '评论必须出现在服务端评论列表',
    );
    _log('评论成功 commentId=$commentId，服务端回读命中');
  });

  test('DF-12.6 管理列表、订阅回读与订阅者列表', () async {
    if (skipOr(needChannel: true) != null) return;
    final managed = await client.get('/api/v1/channels/managed');
    ApiAssert.success(managed, context: '我管理的频道列表');
    expect(
      '$managed'.contains('$channelId'),
      isTrue,
      reason: '新创建的频道必须出现在 channels/managed',
    );

    // 服务端权限边界：creator 未订阅时订阅者列表返回 403
    // （只有订阅者才能查看订阅者列表）。先让创作者订阅自己的免费频道，
    // 再回读订阅者列表与管理员列表。
    final beforeSubscribers = await client.get(
      '/api/v1/channel/$channelId/subscribers',
      queryParameters: {'limit': 20},
    );
    expect(
      beforeSubscribers['code'],
      isNot(0),
      reason: '未订阅的 creator 访问订阅者列表应被权限拒绝',
    );

    final subscribed = await client.post(
      '/api/v1/channel/$channelId/subscribe',
      data: <String, dynamic>{},
    );
    ApiAssert.success(subscribed, context: 'creator 订阅自己的免费频道');

    final subscribers = await client.get(
      '/api/v1/channel/$channelId/subscribers',
      queryParameters: {'limit': 20},
    );
    ApiAssert.success(subscribers, context: '频道订阅者列表');
    final subList = _payload(subscribers)['list'] as List?;
    expect(
      subList != null && subList.isNotEmpty,
      isTrue,
      reason: '订阅后订阅者列表至少包含 creator 自己',
    );

    final admins = await client.get('/api/v1/channel/$channelId/admins');
    ApiAssert.success(admins, context: '频道管理员列表');
    _log(
      'managed 命中新频道；订阅后 subscribers=${subList?.length} 条；'
      'admins=${(_payload(admins)['list'] as List?)?.length ?? 0} 条',
    );
  });

  test('DF-12.7 汇总证据输出', () {
    if (channelId == null && paidChannelId == null) {
      markTestSkipped('本轮未产生频道写入');
      return;
    }
    _log(
      'DF-12 闭环汇总: freeChannelId=$channelId paidChannelId=$paidChannelId '
      'messageId=$messageId marker=$_marker',
    );
  });
}

String? _writeGuard() {
  final channelWrites =
      (Platform.environment['TEST_ALLOW_CHANNEL_WRITES'] ?? '').toLowerCase() ==
      'true';
  if (!channelWrites) return '未设置 TEST_ALLOW_CHANNEL_WRITES=true';
  if (!ApiTestConfig.allowBusinessWrites) {
    return '未设置 TEST_ALLOW_API_WRITES=true';
  }
  if (ApiTestConfig.targetsProductionOrUnknown) return '目标地址不是本地/开发环境';
  if (!ApiTestConfig.isConfigured) return '未配置测试账号';
  return null;
}

Map<String, dynamic> _payload(Map<String, dynamic> resp) {
  final payload = resp['payload'];
  if (payload is Map) return Map<String, dynamic>.from(payload);
  return <String, dynamic>{};
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? -1;
}

void _log(String msg) => stderr.writeln('[DF-12] $msg');
