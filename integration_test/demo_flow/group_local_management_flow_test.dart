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
// 落在 A+B 双成员的既有 DEMO-FLOW 测试群上，群名用 DEMO-FLOW 前缀）：
//   1. 群名+公告（introduction）写入 → detail 回读；
//   2. 成员角色 B role 1→3 → member/page 回读 → 恢复 1 → 回读；
//   3. 成员移除（leave 移除 B）→ 成员列表回读 B 消失 → 重新邀请入群 → 回读恢复；
//   4. 群主转让（2026-08-18 新增）：专用一次性面对面群 A→B 单向转让，
//      owner_uid/角色回读 + 立即转回被 per_hour_once 限流拒绝的负向断言。
// 不执行解散、退群（owner leave）和危险权限操作；转让因 per_hour_once
// 按 gid 限流一小时内不可转回，转让后的专用群保留为可回收数据。

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
      // smoke_bob 是 account 型登录（mobile 字段为空），与 moments/wallet 等
      // demo_flow 测试一致；13900001002 走默认 mobile。
      type: 'account',
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

  // markTestSkipped 只标记不中断：未就绪时返回 false，调用方必须立即 return。
  bool requireReady() {
    if (!ready) markTestSkipped(skipReason);
    return ready;
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
    if (!requireReady()) return;
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
    if (!requireReady()) return;
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
    if (!requireReady()) return;
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

  // 2026-08-18 新增：群主转让（历史未覆盖项）。
  // 安全设计：在专用一次性面对面群上执行，不动 DF-09-1..3 复跑依赖的
  // A+B 去重主测试群（其群主必须保持为 A）。转让接口 per_hour_once 按
  // gid 限流，转回同一群一小时内不可行，因此本用例为单向转让（A→B）+
  // 立即转回的负向断言；转让后的群保留为可回收测试数据（不解散）。
  test('DF-09-4 群主转让：专用面对面群 A→B 单向，立即转回被限流拒绝', () async {
    if (!requireReady()) return;
    if (gid.isEmpty) return markTestSkipped('依赖 DF-09-1 建群（限流间隔）');

    // 专用一次性面对面群：B 登记暗号 → A 凭暗号加入 → B 凭暗号加入 →
    // A face2face_save 落库建群（save 调用方成为 group 行 owner，即 A）。
    await throttleGap();
    final code = '${1000 + DateTime.now().millisecondsSinceEpoch % 9000}';
    const lng = '113.951220';
    const lat = '22.553590';
    final reg = await clientB.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(reg, context: 'group/face2face B 登记暗号');
    final fGid = '${(reg['payload'] as Map)['gid'] ?? ''}';
    expect(fGid.isNotEmpty, isTrue, reason: 'face2face B 未返回 gid');

    final joinA = await clientA.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(joinA, context: 'group/face2face A 加入');

    await throttleGap();
    final joinB = await clientB.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(joinB, context: 'group/face2face B 加入');

    final save = await clientA.post(
      '/api/v1/group/face2face_save',
      data: {'code': code, 'gid': fGid},
    );
    ApiAssert.success(save, context: 'group/face2face_save A 建群行');

    // 前置回读：save 调用方 A 为群主（role=4），B 为普通成员（role=1）。
    var detail = await clientA.get(
      '/api/v1/group/detail',
      queryParameters: {'gid': fGid},
    );
    ApiAssert.success(detail, context: 'group/detail before transfer');
    expect(
      '${(detail['payload'] as Map)['owner_uid'] ?? ''}',
      uidA,
      reason: '转让前 owner 应为 save 调用方 A',
    );

    // 群主转让 A→B。
    final transfer = await clientA.post(
      '/api/v1/group/transfer',
      data: {'gid': fGid, 'new_owner_uid': uidB},
    );
    ApiAssert.success(transfer, context: 'group/transfer A->B');

    detail = await clientA.get(
      '/api/v1/group/detail',
      queryParameters: {'gid': fGid},
    );
    ApiAssert.success(detail, context: 'group/detail after transfer');
    expect(
      '${(detail['payload'] as Map)['owner_uid'] ?? ''}',
      uidB,
      reason: '转让后 owner_uid 应为新群主 B',
    );

    // 角色回读：新群主 role=4，原群主降为 role=1。
    final page = await clientA.get(
      '/api/v1/group_member/page',
      queryParameters: {'gid': fGid, 'page': 1, 'size': 20},
    );
    ApiAssert.success(page, context: 'group_member/page(f2f transfer)');
    final rows = memberRows(page['payload']);
    Map<String, dynamic> memberRow(String uid) => rows.firstWhere(
      (r) => '${r['user_id'] ?? r['uid'] ?? r['id']}' == uid,
      orElse: () => <String, dynamic>{},
    );
    expect(memberRow(uidB)['role'], 4, reason: '转让后新群主 B 角色应为 4（ROLE_OWNER）');
    expect(memberRow(uidA)['role'], 1, reason: '转让后原群主 A 角色应降为 1（ROLE_MEMBER）');

    // 负向断言：per_hour_once 按 gid 限流，一小时内转回同群被拒绝
    // （B 现为群主、权限校验可通过，被限流拦截证明不可立即回收）。
    final back = await clientB.post(
      '/api/v1/group/transfer',
      data: {'gid': fGid, 'new_owner_uid': uidA},
    );
    ApiAssert.failure(back, context: 'group/transfer 立即转回应被限流拒绝');
  });
}
