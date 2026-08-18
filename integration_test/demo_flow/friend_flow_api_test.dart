// integration_test/demo_flow/friend_flow_api_test.dart
//
// DF-02 添加好友并建立关系 —— API 级闭环（纯 dart test，无设备）
//
// 覆盖：搜索（按账号搜用户）→ 清理旧关系（本地允许）→ A 申请 B →
//       重复申请被拒 → B 确认 → 双方 friend/list 回读 is_friend=1 →
//       无结果搜索边界。
//
// 运行（本地后端 + 双测试账号，凭据经环境注入，禁止指向生产）：
//   read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env.local; }
//   API_BASE_URL="$(read_env API_BASE_URL)" \
//   IMBOY_ENV_PRO=.env.local \
//   TEST_PHONE=<A账号> TEST_PASSWORD=<A密码> \
//   TEST_PHONE2=<B账号> TEST_PASSWORD2=<B密码> \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/friend_flow_api_test.dart --concurrency=1
//
// 门禁：TEST_ALLOW_API_WRITES=true 且目标为已识别的本地/开发地址，
//       且双账号齐备；任一缺失即 SKIP（生产 URL 永远拒绝写入）。
// 双端 UI 通知验证（B 收到申请通知的设备侧证据）不在本文件范围。

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

/// 从 user/search 结果项提取 uid 字符串。
String _uidOf(Map<Object?, Object?> u) =>
    '${u['uid'] ?? u['id'] ?? u['user_id'] ?? ''}';

void main() {
  late ApiTestClient clientA;
  late ApiTestClient clientB;
  String uidA = '';
  String uidB = '';
  bool ready = false;
  String? skipReason;

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
      deviceId: 'demo-flow-df02-a',
    );
    clientB = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demo-flow-df02-b',
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
    // 前置：新用户 fts_user.allow_search 缺省 2（不允许被搜索），
    // B 自己开启 allow_search=1 后 A 才能按账号搜到（产品隐私设计）。
    final allow = await clientB.post(
      '/api/v1/user/update',
      data: {'field': 'allow_search', 'value': '1'},
    );
    if (allow['code'] != 0) {
      skipReason = 'B 开启 allow_search 失败: ${allow['msg']}';
      return;
    }
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

  /// 读取当前登录用户好友列表（payload.friend 数组）。
  Future<List<Map<Object?, Object?>>> friendList(ApiTestClient c) async {
    final resp = await c.get('/api/v1/friend/list');
    ApiAssert.success(resp, context: 'friend/list');
    final payload = resp['payload'];
    expect(
      payload,
      isA<Map<Object?, Object?>>(),
      reason: 'friend/list payload 应为 Map',
    );
    final friends = (payload as Map)['friend'];
    expect(
      friends,
      isA<List<dynamic>>(),
      reason: 'friend/list payload.friend 应为 List',
    );
    return [
      for (final f in friends as List<dynamic>)
        if (f is Map) f,
    ];
  }

  /// 在好友列表中查找目标 uid 的项。
  Map<Object?, Object?>? findFriend(
    List<Map<Object?, Object?>> friends,
    String uid,
  ) {
    for (final f in friends) {
      final id = '${f['uid'] ?? f['from_id'] ?? f['peer_id'] ?? f['id'] ?? ''}';
      if (id == uid) return f;
    }
    return null;
  }

  test('DF-02 步骤1 A 按账号搜索到 B', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    // 先按 B 的手机号搜，搜不到再按昵称兜底（允许被搜索开关等差异）
    Map<Object?, Object?>? hit;
    for (final keyword in [ApiTestConfig.testPhone2, '$kFlowMark-B']) {
      final resp = await clientA.get(
        '/api/v1/user/search',
        queryParameters: {'page': 1, 'size': 20, 'keyword': keyword},
      );
      ApiAssert.success(resp, context: 'user/search(keyword=$keyword)');
      final list = _extractList(resp['payload']);
      for (final u in list) {
        if (u is Map && _uidOf(u) == uidB) {
          hit = u;
          break;
        }
      }
      if (hit != null) break;
    }
    expect(hit, isNotNull, reason: '搜索结果应包含 B(uid=$uidB)');
  });

  test('DF-02 步骤2 前置清理：若 A/B 已是好友则删除（本地允许）', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final friends = await friendList(clientA);
    final existed = findFriend(friends, uidB) != null;
    if (!existed) {
      return;
    }
    final resp = await clientA.post(
      '/api/v1/friend/delete',
      data: {'uid': uidB},
    );
    ApiAssert.success(resp, context: 'friend/delete(清理旧关系)');
    final after = await friendList(clientA);
    expect(findFriend(after, uidB), isNull, reason: '删除后 A 列表不应再有 B');
  });

  test('DF-02 步骤3 A 向 B 发送好友申请 — code=0', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final resp = await clientA.post(
      '/api/v1/friend/add',
      data: {
        'to': uidB,
        'payload': {
          'from': {'source': 'search', 'msg': '$kFlowMark 好友申请（API 闭环）'},
        },
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    ApiAssert.success(resp, context: 'friend/add');
  });

  test('DF-02 步骤4 重复申请被服务端拒绝（不误显示成功）', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final resp = await clientA.post(
      '/api/v1/friend/add',
      data: {
        'to': uidB,
        'payload': {
          'from': {'source': 'search', 'msg': '$kFlowMark 重复申请（应被拒）'},
        },
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
    ApiAssert.failure(resp, context: '重复 friend/add');
  });

  test('DF-02 步骤5 B 确认好友申请 — code=0 且 is_friend=1', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final resp = await clientB.post(
      '/api/v1/friend/confirm',
      data: {
        'from': uidA,
        'to': uidB,
        'payload': {
          'from': {'remark': '$kFlowMark-A'},
          'to': {'remark': '$kFlowMark-B'},
          'source': 'search',
        },
      },
    );
    ApiAssert.success(resp, context: 'friend/confirm');
    final payload = resp['payload'];
    expect(
      payload,
      isA<Map<Object?, Object?>>(),
      reason: 'confirm payload 应为 Map',
    );
    expect(
      (payload as Map<Object?, Object?>)['is_friend'],
      equals(1),
      reason: 'confirm 响应应回 is_friend=1，实际 payload=$payload',
    );
  });

  test('DF-02 步骤6 双方 friend/list 回读 is_friend=1（服务端一致）', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final listA = await friendList(clientA);
    final friendB = findFriend(listA, uidB);
    expect(friendB, isNotNull, reason: 'A 的好友列表应包含 B');
    expect(
      '${friendB!['is_friend'] ?? ''}',
      anyOf(equals('1'), equals(1).toString()),
      reason: 'A 侧 B.is_friend 应为 1，实际=${friendB['is_friend']}',
    );

    final listB = await friendList(clientB);
    final friendA = findFriend(listB, uidA);
    expect(friendA, isNotNull, reason: 'B 的好友列表应包含 A');
    expect(
      '${friendA!['is_friend'] ?? ''}',
      anyOf(equals('1'), equals(1).toString()),
      reason: 'B 侧 A.is_friend 应为 1，实际=${friendA['is_friend']}',
    );
  });

  test('DF-02 边界 无结果搜索不崩、不误报', () async {
    if (!ready) {
      return markTestSkipped(skipReason ?? '环境未就绪');
    }
    final resp = await clientA.get(
      '/api/v1/user/search',
      queryParameters: {
        'page': 1,
        'size': 10,
        'keyword': '$kFlowMark-NO-SUCH-USER-XYZ',
      },
    );
    ApiAssert.success(resp, context: 'user/search(无结果)');
    final list = _extractList(resp['payload']);
    expect(list, isEmpty, reason: '无结果搜索应返回空列表');
  });
}
