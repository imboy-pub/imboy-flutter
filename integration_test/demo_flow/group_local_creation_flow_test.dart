// DF-07 建群 → 面对面建群 → 入群 本地 API 闭环（纯 dart test，无设备）。
//
// 运行（本地后端 http://127.0.0.1:9800，双账号来自本地测试环境）：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   IMBOY_SOLIDIFIED_KEY=<本地签名密钥> \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   TEST_PHONE2=test_886209702@example.com TEST_PASSWORD2=<B 密码> \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/group_local_creation_flow_test.dart \
//     --concurrency=1
//
// 覆盖：
//   1. 普通建群（group/add 邀请 B）→ 服务端 detail/member 回读；
//   2. 面对面建群（group/face2face 同暗号同位置）：A 创建 → B 凭暗号加入同一群
//      → face2face_save → 成员回读（join_mode=face2face_join）。
// 后端 group_member 无独立 invite/confirm 端点：邀请直接生效，无"确认后入群"
// 二段式链路（见 flow 文档记录）。
// 群名使用 DEMO-FLOW-20260817 前缀；本地创建的测试群不执行解散（保留可回收数据）。

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
  String createdGid = '';
  String createdTitle = '';

  setUpAll(() async {
    clientA = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    clientB = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured || !ApiTestConfig.isDualConfigured) {
      skipReason =
          '需要 TEST_PHONE/TEST_PASSWORD 与 TEST_PHONE2/TEST_PASSWORD2 双账号';
      return;
    }
    if (!ApiTestConfig.allowBusinessWrites) {
      skipReason = '建群写入需要 TEST_ALLOW_API_WRITES=true';
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

  /// 后端对建群/入群有 three_second_once 限流（按 uid），连续写操作间等待。
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

  Set<String> memberUids(List<Map<String, dynamic>> rows) => rows
      .map((r) => '${r['user_id'] ?? r['uid'] ?? r['id'] ?? ''}')
      .where((v) => v.isNotEmpty)
      .toSet();

  test('DF-07-1 普通建群并邀请 B，服务端回读群与成员', () async {
    requireReady();
    final resp = await clientA.post(
      '/api/v1/group/add',
      data: {
        'member_uids': [uidB],
      },
    );
    ApiAssert.success(resp, context: 'group/add');
    final payload = resp['payload'] as Map<String, dynamic>;
    final group = (payload['group'] ?? const {}) as Map;
    final gid = '${group['id'] ?? group['gid'] ?? ''}';
    expect(gid.isNotEmpty, isTrue, reason: 'group/add 响应缺少群 id: $payload');
    createdGid = gid;

    final members = memberRows(payload['member_list']);
    final uids = memberUids(members);
    expect(
      uids,
      containsAll(<String>{uidA, uidB}),
      reason: '建群响应成员应包含建群者与被邀请者，实际=$uids',
    );

    // 验收标准"重复提交不会产生幽灵群"：后端 find_by_creator_and_sum 对
    // 相同创建者+相同成员集合去重，重复 add 应返回同一 gid。
    await throttleGap();
    final again = await clientA.post(
      '/api/v1/group/add',
      data: {
        'member_uids': [uidB],
      },
    );
    ApiAssert.success(again, context: 'group/add repeat');
    final gidAgain =
        '${(((again['payload'] as Map)['group'] ?? const {}) as Map)['id'] ?? ''}';
    expect(gidAgain, gid, reason: '重复提交相同成员集合应复用同一群，不产生幽灵群');

    await throttleGap();
    createdTitle =
        '${_groupPrefix}-CREATE-${DateTime.now().millisecondsSinceEpoch}';
    final edit = await clientA.post(
      '/api/v1/group/edit',
      data: {'gid': gid, 'title': createdTitle},
    );
    ApiAssert.success(edit, context: 'group/edit title');

    final detail = await clientA.get(
      '/api/v1/group/detail',
      queryParameters: {'gid': gid},
    );
    ApiAssert.success(detail, context: 'group/detail');
    final g = detail['payload'] as Map<String, dynamic>;
    expect('${g['title']}', createdTitle, reason: '回读群名应与写入一致: $g');

    final page = await clientA.get(
      '/api/v1/group_member/page',
      queryParameters: {'gid': gid, 'page': 1, 'size': 20},
    );
    ApiAssert.success(page, context: 'group_member/page');
    final uids2 = memberUids(memberRows(page['payload']));
    expect(
      uids2,
      containsAll(<String>{uidA, uidB}),
      reason: '成员分页回读应包含双方，实际=$uids2',
    );
  });

  test('DF-07-2 面对面建群：A/B 凭同暗号加入同一群并落库回读', () async {
    requireReady();
    if (createdGid.isEmpty) {
      markTestSkipped('依赖 DF-07-1 建群先完成（限流间隔）');
      return;
    }
    await throttleGap();
    final code = '${1000 + DateTime.now().millisecondsSinceEpoch % 9000}';
    const lng = '113.951220';
    const lat = '22.553590';

    // 后端语义：face2face 登记暗号（group_random_code）+ 内存缓存；
    // group_member 落库由"同暗号再次 face2face"（join_group 路径）完成。
    // 本地 alpha.27 的 face2face_save 存在已修复待部署的静默不落库 bug
    // （上游 21af8e78/41034a52，parse_result 形态错 → 建群 INSERT 失败被吞，
    // 返回空 group+空 member_list 的 code=0），因此本用例走 join 路径闭环。
    final respA = await clientA.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(respA, context: 'group/face2face A 登记暗号');
    final gidA = '${(respA['payload'] as Map)['gid'] ?? ''}';
    expect(
      gidA.isNotEmpty,
      isTrue,
      reason: 'face2face A 未返回 gid: ${respA['payload']}',
    );

    // A 凭同暗号再次 face2face → join_group 落库入群。
    await throttleGap();
    final respA2 = await clientA.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(respA2, context: 'group/face2face A 加入');
    final gidA2 = '${(respA2['payload'] as Map)['gid'] ?? ''}';
    expect(gidA2, gidA, reason: 'A 同暗号应加入同一群：登记=$gidA 加入=$gidA2');

    // B 凭同暗号加入同一群。
    final respB = await clientB.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(respB, context: 'group/face2face B');
    final gidB = '${(respB['payload'] as Map)['gid'] ?? ''}';
    expect(gidB, gidA, reason: '同暗号同位置应加入同一群：A=$gidA B=$gidB');

    // face2face_save 幂等确认（B 已是成员；alpha.27 返回空数据不落群行，
    // 仅验证接口可达且不报错，落库断言由 member/page 承担）。
    final save = await clientB.post(
      '/api/v1/group/face2face_save',
      data: {'code': code, 'gid': gidB},
    );
    ApiAssert.success(save, context: 'group/face2face_save');

    final page = await clientA.get(
      '/api/v1/group_member/page',
      queryParameters: {'gid': gidA, 'page': 1, 'size': 20},
    );
    ApiAssert.success(page, context: 'group_member/page(f2f)');
    final rows = memberRows(page['payload']);
    final uids = memberUids(rows);
    expect(
      uids,
      containsAll(<String>{uidA, uidB}),
      reason: '面对面群成员应包含双方，实际=$uids',
    );
    final rowB = rows.firstWhere(
      (r) => '${r['user_id'] ?? r['uid'] ?? r['id']}' == uidB,
      orElse: () => <String, dynamic>{},
    );
    expect(
      '${rowB['join_mode'] ?? ''}',
      'face2face_join',
      reason: 'B 的进群方式应为 face2face_join，实际 row=$rowB',
    );
  });

  test('DF-07-3 B 侧群列表回读包含普通建群创建的群', () async {
    requireReady();
    if (createdGid.isEmpty) {
      markTestSkipped('依赖 DF-07-1 建群产出');
      return;
    }
    final page = await clientB.get(
      '/api/v1/group/page',
      queryParameters: {'page': 1, 'size': 50, 'attr': 'join'},
    );
    ApiAssert.success(page, context: 'group/page B');
    final list = memberRows(page['payload']);
    final gids = list
        .map((g) => '${g['group_id'] ?? g['gid'] ?? g['id'] ?? ''}')
        .toSet();
    expect(
      gids,
      contains(createdGid),
      reason: 'B 加入的群列表应包含普通建群创建的群，实际=${gids.take(10)}',
    );
    // 注：面对面群在本地 alpha.27 上 group 表无行（face2face_save 静默 bug），
    // page_joined 的 LEFT JOIN 查不到它，不计入断言；成员关系以
    // group_member 表与 member/page 回读为准（DF-07-2 已覆盖）。
  });
}
