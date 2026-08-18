// DF-16 朋友圈本地 API 闭环（demo flow 自动化）。
//
// 链路：发布文本动态（DEMO-FLOW 标记）→ 自己 feed 回读 → 第二账号经
//   /moments/user/:uid 可见性回读 → 点赞 → 评论 → 详情/评论列表回读。
// 不执行删除动态（红线）。
//
// 默认跳过。仅允许同时满足以下条件时运行：
//   1. dart test（非 flutter test harness）；
//   2. API_BASE_URL 为本地/开发地址（api_test_client 白名单校验）；
//   3. TEST_ALLOW_API_WRITES=true（业务写入门禁）；
//   4. TEST_PHONE/TEST_PASSWORD（作者 A）与 TEST_PHONE2/TEST_PASSWORD2（访客 B）齐备。
// 生产地址一律拒绝（生产动态写入禁止）。
//
// 运行（本地后端 127.0.0.1:9800，账号同 DF-17）：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   IMBOY_SOLIDIFIED_KEY=<.env.local 提取> \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   TEST_PHONE2=smoke_bob TEST_PASSWORD2=demoflow888 \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/moments_flow_test.dart \
//     --concurrency=1 -r expanded

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

const _marker = 'DEMO-FLOW-20260817';

String? _gateReason() {
  if (ApiTestConfig.isFlutterTestHarness) {
    return '需用 dart test 运行（flutter test 的 mock HTTP 会恒返 400）';
  }
  if (!ApiTestConfig.allowBusinessWrites) {
    return '业务写入门禁未开启：需 TEST_ALLOW_API_WRITES=true 且本地/开发地址';
  }
  if (ApiTestConfig.targetsProductionOrUnknown) {
    return '动态写入门禁：目标地址不是已识别的本地/开发环境，拒绝执行';
  }
  if (!ApiTestConfig.isDualConfigured) {
    return '双测试账号未配置：需 TEST_PHONE/TEST_PASSWORD + TEST_PHONE2/TEST_PASSWORD2';
  }
  return null;
}

void _ev(String msg) => print('[DEMO-FLOW-EVIDENCE][DF-16] $msg');

Map<String, dynamic> _payloadMap(Map<String, dynamic> resp) {
  final p = resp['payload'];
  return p is Map<String, dynamic> ? p : <String, dynamic>{};
}

List<Map<String, dynamic>> _postList(Map<String, dynamic> resp) {
  final payload = resp['payload'];
  final list = payload is Map ? payload['list'] : payload;
  if (list is! List) return const [];
  return [
    for (final e in list)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

String _postIdOf(Map<String, dynamic> post) {
  for (final k in ['id', 'moment_id', 'post_id']) {
    final v = post[k];
    if (v != null && '$v'.isNotEmpty) return '$v';
  }
  return '';
}

void main() {
  late ApiTestClient clientA;
  late ApiTestClient clientB;
  String? gate;

  setUpAll(() {
    gate = _gateReason();
    clientA = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demoflow-df16-a',
    );
    clientB = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demoflow-df16-b',
    );
  });

  tearDownAll(() {
    clientA.close();
    clientB.close();
  });

  test('DF-16 本地朋友圈闭环：create → feed 回读 → 他人可见 → 点赞 → 评论 → 回读', () async {
    if (gate != null) return markTestSkipped(gate!);
    final reason = ApiTestConfig.skipReasonIfNoRealNetwork;
    if (reason != null) return markTestSkipped(reason);

    final loginA = await clientA.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    expect(loginA['code'], 0, reason: '作者 A 登录失败: ${loginA['msg']}');
    final loginB = await clientB.login(
      account: ApiTestConfig.testPhone2,
      password: ApiTestConfig.testPassword2,
      type: 'account',
    );
    expect(loginB['code'], 0, reason: '访客 B 登录失败: ${loginB['msg']}');
    final uidA = clientA.currentUid!;
    final uidB = clientB.currentUid!;
    _ev('登录成功 A(uid=$uidA) B(uid=$uidB)');

    // 0. 好友前置（服务端 visibility=1 为"仅好友可见"，非好友不可见且点赞/评论
    //    会被 ACL 拒绝）。幂等：已是好友时 add/confirm 返回业务错误也放行，
    //    由后续 B 可见性断言做功能证明。
    final addResp = await clientA.post(
      '/api/v1/friend/add',
      data: {
        'to': uidB,
        'payload': {
          'from': {'source': 'qrcode', 'msg': '$_marker 好友前置'},
        },
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    final confirmResp = await clientB.post(
      '/api/v1/friend/confirm',
      data: {
        'from': uidA,
        'to': uidB,
        'payload': {
          'from': {'source': 'qrcode', 'msg': '$_marker 好友前置'},
        },
      },
    );
    _ev(
      '好友前置 add code=${addResp['code']}(${addResp['msg']}), '
      'confirm code=${confirmResp['code']}(${confirmResp['msg']})',
    );

    // 1. A 发布文本动态（visibility=1 好友可见，允许评论）
    final content =
        '$_marker 朋友圈发布验收 '
        'run=${DateTime.now().millisecondsSinceEpoch}';
    final create = await clientA.post(
      '/api/v1/moment/create',
      data: {
        'content': content,
        'media': <dynamic>[],
        'visibility': 1,
        'allow_comment': true,
      },
    );
    ApiAssert.success(create, context: 'moment/create');
    final created = _payloadMap(create);
    final momentId = _postIdOf(created);
    expect(momentId.isNotEmpty, isTrue, reason: 'create 返回缺 id: $created');
    expect(content.contains(_marker), isTrue);
    _ev('moment/create 成功 moment_id=$momentId（含 $_marker 标记）');

    // 2. A 自己 feed 回读包含该动态
    final feedA = await clientA.get(
      '/api/v1/moments/feed',
      queryParameters: {'limit': 20},
    );
    ApiAssert.success(feedA, context: 'A feed 回读');
    final inFeedA = _postList(feedA).any(
      (p) =>
          _postIdOf(p) == momentId ||
          (p['content'] is String && '${p['content']}'.contains(_marker)),
    );
    expect(inFeedA, isTrue, reason: 'A 的 feed 首页未找到新动态');
    _ev('A feed 回读命中新动态（limit=20 首页）');

    // 3. B 经 /moments/user/:uid 可见性回读（visibility=1 好友可见，非好友不可见）
    final userFeedB = await clientB.get('/api/v1/moments/user/$uidA');
    ApiAssert.success(userFeedB, context: 'B 查看他人动态');
    final postsB = _postList(userFeedB);
    final hitB = postsB.where(
      (p) =>
          _postIdOf(p) == momentId ||
          (p['content'] is String && '${p['content']}'.contains(_marker)),
    );
    expect(hitB.isNotEmpty, isTrue, reason: 'B 看不到 A 的好友可见动态（好友前置失效？）');
    _ev('B 经 moments/user/$uidA 命中该动态（visibility=1 好友可见）');

    // 4. B 点赞
    final like = await clientB.post('/api/v1/moment/$momentId/like', data: {});
    ApiAssert.success(like, context: 'B 点赞');
    _ev('moment/$momentId/like 成功（B=$uidB）');

    // 5. B 评论
    final commentContent = '$_marker 评论验收';
    final comment = await clientB.post(
      '/api/v1/moment/$momentId/comment',
      data: {'content': commentContent},
    );
    ApiAssert.success(comment, context: 'B 评论');
    _ev('moment/$momentId/comment 成功（B=$uidB）');

    // 6. A 详情回读：点赞数/评论数一致
    final detail = await clientA.get('/api/v1/moment/$momentId');
    ApiAssert.success(detail, context: 'A 动态详情回读');
    final detailMap = _payloadMap(detail);
    final stats = detailMap['stats'];
    final statsMap = stats is Map
        ? Map<String, dynamic>.from(stats)
        : const <String, dynamic>{};
    final likeCount = (statsMap['like_count'] as num?)?.toInt() ?? -1;
    final commentCount = (statsMap['comment_count'] as num?)?.toInt() ?? -1;
    expect(likeCount, greaterThanOrEqualTo(1), reason: '点赞数未增长');
    expect(commentCount, greaterThanOrEqualTo(1), reason: '评论数未增长');
    _ev('详情回读 stats.like_count=$likeCount stats.comment_count=$commentCount');

    // 7. B 评论列表回读包含标记评论
    final comments = await clientB.get('/api/v1/moment/$momentId/comments');
    ApiAssert.success(comments, context: '评论列表回读');
    final commentItems = _postList(comments);
    final markerComment = commentItems.any(
      (c) =>
          (c['content'] is String && '${c['content']}'.contains(_marker)) ||
          (c['comment'] is Map &&
              '${(c['comment'] as Map)['content'] ?? ''}'.contains(_marker)),
    );
    expect(markerComment, isTrue, reason: '评论列表未找到标记评论');
    _ev('评论列表回读命中 $_marker 标记评论');

    // 红线：不执行删除动态。
  }, timeout: const Timeout(Duration(minutes: 5)));

  group('DF-16 朋友圈错误分支（本地）', () {
    test('空内容发布被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final resp = await clientA.post(
        '/api/v1/moment/create',
        data: {'content': '', 'media': <dynamic>[], 'visibility': 1},
      );
      ApiAssert.failure(resp, context: '空内容发布');
      _ev('空内容拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('无效可见性参数被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final resp = await clientA.post(
        '/api/v1/moment/create',
        data: {
          'content': '$_marker visibility 非法值验收',
          'media': <dynamic>[],
          'visibility': 9,
        },
      );
      ApiAssert.failure(resp, context: '无效可见性');
      _ev('visibility=9 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('对不存在动态点赞被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientB.login(
        account: ApiTestConfig.testPhone2,
        password: ApiTestConfig.testPassword2,
        type: 'account',
      );
      expect(login['code'], 0);
      final resp = await clientB.post('/api/v1/moment/0/like', data: {});
      ApiAssert.failure(resp, context: '对不存在动态点赞');
      _ev('moment/0/like 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('空评论被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientB.login(
        account: ApiTestConfig.testPhone2,
        password: ApiTestConfig.testPassword2,
        type: 'account',
      );
      expect(login['code'], 0);
      final resp = await clientB.post(
        '/api/v1/moment/0/comment',
        data: {'content': ''},
      );
      ApiAssert.failure(resp, context: '空评论');
      _ev('空评论拒绝 code=${resp['code']} msg=${resp['msg']}');
    });
  });
}
