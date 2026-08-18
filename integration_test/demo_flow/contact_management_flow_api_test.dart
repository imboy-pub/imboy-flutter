// integration_test/demo_flow/contact_management_flow_api_test.dart
//
// DF-19 联系人备注、标签和分组管理 —— API 级写入闭环（纯 dart test，无设备）
//
// 覆盖：前置好友关系自愈建立 → 修改备注并回读 → 创建标签 → 打标 →
//       标签关系分页回读（按标签筛选）→ 好友分组创建 → 移动好友入分组 →
//       friend/list 回读 category_id。
//
// 运行（本地后端 + 双测试账号，凭据经环境注入，禁止指向生产）：
//   read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env.local; }
//   API_BASE_URL="$(read_env API_BASE_URL)" \
//   IMBOY_ENV_PRO=.env.local \
//   TEST_PHONE=<A账号> TEST_PASSWORD=<A密码> \
//   TEST_PHONE2=<B账号> TEST_PASSWORD2=<B密码> \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/contact_management_flow_api_test.dart --concurrency=1
//
// 门禁：TEST_ALLOW_API_WRITES=true 且目标为已识别的本地/开发地址，
//       且双账号齐备；任一缺失即 SKIP（生产 URL 永远拒绝写入）。
// 说明：产品无独立「好友分组」客户端页面，移动端分组能力由好友标签
//       （scene=friend）承担；后端另提供 friend/category + friend/move
//       分组 API，本测试一并验证。标签/分组删除为破坏性动作，默认不执行。

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

/// 写入数据的统一标记前缀（本地可回收测试数据）。
const kFlowMark = 'DEMO-FLOW-20260817';

/// 从 payload 提取 list（兼容 List / {list:[]} / {data:[]}）。
List<dynamic> _extractList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map) {
    final l = payload['list'] ?? payload['data'] ?? payload['rows'];
    if (l is List) return l;
  }
  return const [];
}

void main() {
  late ApiTestClient clientA;
  late ApiTestClient clientB;
  String uidA = '';
  String uidB = '';
  bool ready = false;
  String? skipReason;

  // 跨用例共享状态（--concurrency=1 顺序执行）
  String tagName = '';
  int tagId = 0;
  int categoryId = 0;
  String remarkV2 = '';

  setUpAll(() async {
    if (!ApiTestConfig.isDualConfigured) {
      skipReason = '缺少 A/B 双测试账号（TEST_PHONE/TEST_PHONE2/TEST_PASSWORD2）';
      return;
    }
    if (!ApiTestConfig.allowBusinessWrites) {
      skipReason = '未显式设置 TEST_ALLOW_API_WRITES=true，写入门禁拒绝';
      return;
    }
    if (ApiTestConfig.targetsProductionOrUnknown) {
      skipReason = '目标地址不是已识别的本地/开发环境，拒绝写入';
      return;
    }
    clientA = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demo-flow-df19-a',
    );
    clientB = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demo-flow-df19-b',
    );
    final ra = await clientA.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
      type: 'mobile',
    );
    if (ra['code'] != 0) {
      skipReason = '账号 A 登录失败: ${ra['msg']}';
      return;
    }
    uidA = clientA.currentUid ?? '';
    final rb = await clientB.login(
      account: ApiTestConfig.testPhone2,
      password: ApiTestConfig.testPassword2,
      type: 'mobile',
    );
    if (rb['code'] != 0) {
      skipReason = '账号 B 登录失败: ${rb['msg']}';
      return;
    }
    uidB = clientB.currentUid ?? '';
    ready = true;
  });

  tearDownAll(() {
    // setUpAll 门禁提前退出时 late client 可能未初始化，close 需容忍
    try {
      clientA.close();
    } on Object {
      // late 未初始化时 close 无意义
    }
    try {
      clientB.close();
    } on Object {
      // late 未初始化时 close 无意义
    }
  });

  /// A 的好友列表项。
  Future<Map<Object?, Object?>?> friendOfA() async {
    final resp = await clientA.get('/api/v1/friend/list');
    ApiAssert.success(resp, context: 'friend/list');
    final friends =
        (resp['payload'] as Map<Object?, Object?>)['friend'] as List<dynamic>;
    for (final f in friends) {
      if (f is Map && '${f['uid'] ?? f['id']}' == uidB) return f;
    }
    return null;
  }

  test('DF-19 前置 A/B 好友关系自愈建立（无则申请+确认）', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    if (await friendOfA() != null) return;

    // B 允许被搜索不是申请的硬前置（source=search 不受控），直接申请
    final add = await clientA.post(
      '/api/v1/friend/add',
      data: {
        'to': uidB,
        'payload': {
          'from': {'source': 'search', 'msg': '$kFlowMark 好友申请（DF-19 前置）'},
        },
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    ApiAssert.success(add, context: 'friend/add(DF-19 前置)');
    final confirm = await clientB.post(
      '/api/v1/friend/confirm',
      data: {
        'from': uidA,
        'to': uidB,
        'payload': {
          'from': <String, dynamic>{},
          'to': <String, dynamic>{},
          'source': 'search',
        },
      },
    );
    ApiAssert.success(confirm, context: 'friend/confirm(DF-19 前置)');
    expect(await friendOfA(), isNotNull, reason: '前置建立后 A 应有好友 B');
  });

  test('DF-19 步骤1 修改好友备注并回读一致', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    remarkV2 = '$kFlowMark-备注-v2';
    final resp = await clientA.post(
      '/api/v1/friend/change_remark',
      data: {'uid': uidB, 'remark': remarkV2},
    );
    ApiAssert.success(resp, context: 'friend/change_remark');

    final friend = await friendOfA();
    expect(friend, isNotNull, reason: '好友列表应包含 B');
    expect(
      friend!['remark'],
      equals(remarkV2),
      reason: 'friend/list 回读 remark 应为新备注，实际=${friend['remark']}',
    );
  });

  test('DF-19 步骤2 创建好友标签 — tagId>0', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    tagName = 'DF0817标签';
    final resp = await clientA.post(
      '/api/v1/user_tag/add',
      data: {'scene': 'friend', 'tag': tagName},
    );
    ApiAssert.success(resp, context: 'user_tag/add');
    final payload = resp['payload'];
    expect(
      payload,
      isA<Map<Object?, Object?>>(),
      reason: 'user_tag/add payload 应为 Map',
    );
    tagId =
        ((payload as Map<Object?, Object?>)['tagId'] as num?)?.toInt() ??
        ((payload['tag_id'] as num?)?.toInt() ?? 0);
    expect(tagId, greaterThan(0), reason: '应返回有效 tagId，实际 payload=$payload');
  });

  test('DF-19 步骤3 给好友打标签 — code=0', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    expect(tagId, greaterThan(0), reason: '依赖步骤2的 tagId');
    final resp = await clientA.post(
      '/api/v1/user_tag_relation/add',
      data: {
        'scene': 'friend',
        'objectId': uidB,
        'tag': [tagName],
      },
    );
    ApiAssert.success(resp, context: 'user_tag_relation/add');
  });

  test('DF-19 步骤4 标签保存回读：tag/page 含新标签', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final resp = await clientA.get(
      '/api/v1/user_tag/page',
      queryParameters: {'page': 1, 'size': 50, 'scene': 'friend', 'kwd': ''},
    );
    ApiAssert.success(resp, context: 'user_tag/page');
    final list = _extractList(resp['payload']);
    final names = [
      for (final t in list)
        if (t is Map) '${t['name'] ?? t['tag'] ?? t['tag_name'] ?? ''}',
    ];
    expect(names, contains(tagName), reason: '标签分页应包含新标签 $tagName，实际=$names');
  });

  test('DF-19 步骤5 按标签筛选联系人 — friend_page 含 B', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    expect(tagId, greaterThan(0), reason: '依赖步骤2的 tagId');
    final resp = await clientA.get(
      '/api/v1/user_tag_relation/friend_page',
      queryParameters: {
        'page': 1,
        'size': 50,
        'scene': 'friend',
        'tag_id': tagId,
        'kwd': '',
      },
    );
    ApiAssert.success(resp, context: 'user_tag_relation/friend_page');
    final list = _extractList(resp['payload']);
    final ids = [
      for (final r in list)
        if (r is Map)
          '${r['uid'] ?? r['user_id'] ?? r['id'] ?? r['object_id'] ?? ''}',
    ];
    expect(ids, contains(uidB), reason: '按标签筛选结果应包含 B(uid=$uidB)，实际=$ids');
  });

  test('DF-19 步骤6 创建好友分组 — id>0', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final resp = await clientA.post(
      '/api/v1/friend/category/add',
      data: {'name': 'DF0817分组'},
    );
    ApiAssert.success(resp, context: 'friend/category/add');
    final payload = resp['payload'];
    expect(
      payload,
      isA<Map<Object?, Object?>>(),
      reason: 'category/add payload 应为 Map',
    );
    // 后端契约注意（2026-08-17 本地实测）：payload.id 不是 TSID 整数，
    // 而是嵌套 map {id: <真实TSID>, name, groupname}——handler 把
    // friend_category_logic:add 返回的 LastInsertId（实为整行 map）直接放入
    // #{<<"id">> => LastInsertId}。此处兼容两种形状，并在文档记录该问题。
    final rawId = (payload as Map<Object?, Object?>)['id'];
    if (rawId is num) {
      categoryId = rawId.toInt();
    } else if (rawId is Map) {
      categoryId = ((rawId['id'] ?? rawId['categoryId']) as num?)?.toInt() ?? 0;
    }
    expect(
      categoryId,
      greaterThan(0),
      reason: '应返回有效分组 id，实际 payload=$payload',
    );
  });

  test('DF-19 步骤7 移动好友入分组并回读 category_id', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    expect(categoryId, greaterThan(0), reason: '依赖步骤6的分组 id');
    final resp = await clientA.post(
      '/api/v1/friend/move',
      data: {'user_id': uidB, 'category_id': categoryId},
    );
    ApiAssert.success(resp, context: 'friend/move');

    final friend = await friendOfA();
    expect(friend, isNotNull, reason: '好友列表应包含 B');
    expect(
      '${friend!['category_id'] ?? ''}',
      equals('$categoryId'),
      reason: 'friend/list 回读 category_id 应为新分组，实际=${friend['category_id']}',
    );
  });
}
