// DF-09 群信息 → 成员 → 公告 → 可逆管理 本地 API 闭环（纯 dart test，无设备）。
//
// 运行（本地后端 http://127.0.0.1:9800）：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   IMBOY_SOLIDIFIED_KEY=<本地签名密钥> \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   TEST_PHONE2=test_886209702@example.com TEST_PASSWORD2=<B 密码> \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/group_local_management_flow_test.dart \
//     --concurrency=1
//
// 覆盖（后端 group/add 对相同创建者+成员集合去重复用同一群，因此管理操作
// 落在 A+B 双成员的既有 DEMO-FLOW 测试群上，群名用 DEMO-FLOW-20260817 前缀）：
//   1. 群名+公告（introduction）写入 → detail 回读；
//   2. 成员角色 B role 1→3 → member/page 回读 → 恢复 1 → 回读；
//   3. 成员移除（leave 移除 B）→ 成员列表回读 B 消失 → 重新邀请入群 → 回读恢复。
// 不执行解散、群主转让、退群（owner）和危险权限操作。

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

const _groupPrefix = 'DEMO-FLOW-20260817';

void main() {
  late ApiTestClient clientA;
  late ApiTestClient clientB;
  bool ready = false;
  String skipReason = '';
  String uidA = '';
  String uidB = '';
  String gid = '';

  setUpAll(() async {
    clientA = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    clientB = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isDualConfigured) {
      skipReason =
          '需要 TEST_PHONE/TEST_PASSWORD 与 TEST_PHONE2/TEST_PASSWORD2 双账号';
      return;
    }
    if (!ApiTestConfig.allowBusinessWrites) {
      skipReason = '群管理写入需要 TEST_ALLOW_API_WRITES=true';
      return;
    }
    final respA = await clientA.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    final respB = await clientB.login(
      account: ApiTestConfig.testPhone2,
      password: ApiTestConfig.testPassword2,
    );
    if (respA['code'] != 0 || respB['code'] != 0) {
      skipReason = '双账号登录失败（A=${respA['code']} B=${respB['code']}）';
      return;
    }
    uidA = clientA.currentUid ?? '';
    uidB = clientB.currentUid ?? '';
    ready = true;
  });

  tearDownAll(() async {
    clientA.close();
    clientB.close();
  });

  void requireReady() {
    if (!ready) markTestSkipped(skipReason);
  }

  /// add / join / leave / role 分别有 three_second_once 限流（按 uid/key），
  /// 连续写操作间等待。
  Future<void> throttleGap() =>
      Future<void>.delayed(const Duration(seconds: 4));

  List<Map<String, dynamic>> memberRows(dynamic payload) {
    final list = payload is List
        ? payload
        : payload is Map
        ? (payload['list'] ?? payload['data'] ?? const [])
        : const [];
    return [
      for (final row in list is List ? list : const <dynamic>[])
        if (row is Map) row.cast<String, dynamic>(),
    ];
  }

  Future<Map<String, dynamic>> fetchMember(String uid) async {
    final page = await clientA.get(
      '/api/v1/group_member/page',
      queryParameters: {'gid': gid, 'page': 1, 'size': 50},
    );
    ApiAssert.success(page, context: 'group_member/page');
    return memberRows(page['payload']).firstWhere(
      (r) => '${r['user_id'] ?? r['uid'] ?? r['id']}' == uid,
      orElse: () => <String, dynamic>{},
    );
  }

  test('DF-09-1 建群并写入群名与公告，服务端回读', () async {
    requireReady();
    // add/face2face 共用 uid 维度 three_second_once 限流桶；保护跨文件/上一轮
    // 运行的限流残留。
    await throttleGap();
    final add = await clientA.post(
      '/api/v1/group/add',
      data: {
        'member_uids': [uidB],
      },
    );
    ApiAssert.success(add, context: 'group/add');
    gid =
        '${(((add['payload'] as Map)['group'] ?? const {}) as Map)['id'] ?? ''}';
    expect(gid.isNotEmpty, isTrue, reason: 'group/add 缺少群 id');

    await throttleGap();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final title = '${_groupPrefix}-MGMT-$ts';
    final notice = '${_groupPrefix}-NOTICE-$ts';
    final edit = await clientA.post(
      '/api/v1/group/edit',
      data: {'gid': gid, 'title': title, 'introduction': notice},
    );
    ApiAssert.success(edit, context: 'group/edit title+introduction');

    final detail = await clientA.get(
      '/api/v1/group/detail',
      queryParameters: {'gid': gid},
    );
    ApiAssert.success(detail, context: 'group/detail');
    final g = detail['payload'] as Map<String, dynamic>;
    expect('${g['title']}', title, reason: '回读群名应与写入一致: $g');
    expect('${g['introduction']}', notice, reason: '回读公告应与写入一致: $g');
  });

  test('DF-09-2 B 角色提升 1→3 回读后恢复 1', () async {
    requireReady();
    if (gid.isEmpty) return markTestSkipped('依赖 DF-09-1 建群');
    await throttleGap();
    final up = await clientA.post(
      '/api/v1/group_member/role',
      data: {'gid': gid, 'user_id': uidB, 'role': 3},
    );
    ApiAssert.success(up, context: 'group_member/role 1->3');
    var rowB = await fetchMember(uidB);
    expect(rowB['role'], 3, reason: '提升后 B 角色应为 3，实际=$rowB');

    await throttleGap();
    final down = await clientA.post(
      '/api/v1/group_member/role',
      data: {'gid': gid, 'user_id': uidB, 'role': 1},
    );
    ApiAssert.success(down, context: 'group_member/role 3->1');
    rowB = await fetchMember(uidB);
    expect(rowB['role'], 1, reason: '恢复后 B 角色应为 1，实际=$rowB');
  });

  test('DF-09-3 移除成员 B 并回读，随后重新邀请入群恢复', () async {
    requireReady();
    if (gid.isEmpty) return markTestSkipped('依赖 DF-09-1 建群');
    await throttleGap();
    final remove = await clientA.post(
      '/api/v1/group_member/leave',
      data: {
        'gid': gid,
        'member_uids': [uidB],
      },
    );
    ApiAssert.success(remove, context: 'group_member/leave 移除 B');
    var rowB = await fetchMember(uidB);
    expect(rowB.isEmpty, isTrue, reason: '移除后成员列表不应再包含 B，实际=$rowB');

    await throttleGap();
    final rejoin = await clientA.post(
      '/api/v1/group_member/join',
      data: {
        'gid': gid,
        'member_uids': [uidB],
      },
    );
    ApiAssert.success(rejoin, context: 'group_member/join 重新邀请 B');
    rowB = await fetchMember(uidB);
    expect(rowB.isNotEmpty, isTrue, reason: '重新邀请后 B 应回到成员列表');
    expect(rowB['role'], 1, reason: '重新入群后 B 应为普通成员 role=1，实际=$rowB');
  });
}
