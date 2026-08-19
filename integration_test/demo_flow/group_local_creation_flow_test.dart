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
//   2. 面对面建群（group/face2face 同暗号同位置）：A 创建 → A/B 凭暗号加入同一群
//      → face2face_save 落库（2026-08-18 加严：断言响应 group map 与 member_list
//      非空、group/detail 回读群行、面对面群进入 attr=join 群列表——本地后端
//      alpha.36 起已含 21af8e78/41034a52 修复，alpha.27 时代该接口静默不落库）。
// 后端 group_member 无独立 invite/confirm 端点：邀请直接生效，无"确认后入群"
// 二段式链路（见 flow 文档记录）。
// 群名使用 DEMO-FLOW 前缀；本地创建的测试群不执行解散（保留可回收数据）。

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

const _groupPrefix = 'DEMO-FLOW-20260819';

void main() {
  late ApiTestClient clientA;
  late ApiTestClient clientB;
  bool ready = false;
  String skipReason = '';
  String uidA = '';
  String uidB = '';
  String createdGid = '';
  String createdTitle = '';
  String f2fGid = '';

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

  /// markTestSkipped 只标记不中断：未就绪时返回 false，调用方必须立即 return，
  /// 避免带着空 uid 继续发起写请求（历史踩坑：空 member_uids 触发 500）。
  bool requireReady() {
    if (!ready) markTestSkipped(skipReason);
    return ready;
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
    if (!requireReady()) return;
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
    if (!requireReady()) return;
    if (createdGid.isEmpty) {
      markTestSkipped('依赖 DF-07-1 建群先完成（限流间隔）');
      return;
    }
    await throttleGap();
    final code = '${1000 + DateTime.now().millisecondsSinceEpoch % 9000}';
    const lng = '113.951220';
    const lat = '22.553590';

    // 后端语义（本地 alpha.36 起含 21af8e78/41034a52 修复）：
    // - face2face 登记暗号：group_random_code 落库 + 内存缓存成员，不建 group 行；
    // - 同暗号再次 face2face：join 路径写 group_member 行（仍不建 group 行）；
    // - face2face_save：创建缺失的 group 行并幂等入群——2026-08-18 加严断言
    //   （修复前 alpha.27 返回 code=0 但 group/member_list 为空且不落库）。
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

    // A 凭同暗号再次 face2face → join 路径写 group_member 行。
    await throttleGap();
    final respA2 = await clientA.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(respA2, context: 'group/face2face A 加入');
    final gidA2 = '${(respA2['payload'] as Map)['gid'] ?? ''}';
    expect(gidA2, gidA, reason: 'A 同暗号应加入同一群：登记=$gidA 加入=$gidA2');

    // B 凭同暗号加入同一群（join 路径）。
    final respB = await clientB.get(
      '/api/v1/group/face2face',
      queryParameters: {'code': code, 'longitude': lng, 'latitude': lat},
    );
    ApiAssert.success(respB, context: 'group/face2face B');
    final gidB = '${(respB['payload'] as Map)['gid'] ?? ''}';
    expect(gidB, gidA, reason: '同暗号同位置应加入同一群：A=$gidA B=$gidB');
    f2fGid = gidA;

    // face2face_save 落库（2026-08-18 加严）：此时 group 表仍无该群行，
    // save 应创建 group 行并幂等确认成员；响应必须携带完整 group map 与
    // member_list（修复前为空 map + 空列表），随后 group/detail 可回读。
    final save = await clientB.post(
      '/api/v1/group/face2face_save',
      data: {'code': code, 'gid': gidB},
    );
    ApiAssert.success(save, context: 'group/face2face_save');
    final savePayload = save['payload'] as Map;
    final savedGroup = (savePayload['group'] ?? const {}) as Map;
    expect(
      '${savedGroup['id'] ?? savedGroup['gid'] ?? ''}',
      gidA,
      reason: 'face2face_save 响应 group 应为已落库群（id=$gidA），实际=${savePayload}',
    );
    final savedUids = memberUids(memberRows(savePayload['member_list']));
    expect(
      savedUids,
      containsAll(<String>{uidA, uidB}),
      reason: 'face2face_save 响应 member_list 应包含双方（join 路径已落库），实际=$savedUids',
    );

    // group 行创建后的独立回读（修复前此处会报“你不是群成员”或群不存在）。
    final detail = await clientA.get(
      '/api/v1/group/detail',
      queryParameters: {'gid': gidA},
    );
    ApiAssert.success(detail, context: 'group/detail(f2f)');
    expect(
      '${(detail['payload'] as Map)['id'] ?? ''}',
      gidA,
      reason: 'face2face_save 落库后 group/detail 应回读到群行',
    );

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
    if (!requireReady()) return;
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
    // 2026-08-18 加严：face2face_save 修复后 group 表有行，面对面群应可从
    // join 群列表回读。注意 owner 语义：group 行由 face2face_save 调用方创建
    // （owner_uid=B），而 page_joined 排除自己是群主的群，因此 f2f 群要在
    // A（非群主成员）的 join 列表断言；普通建群群 owner=A，在 B 侧断言。
    if (f2fGid.isNotEmpty) {
      final pageA = await clientA.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 50, 'attr': 'join'},
      );
      ApiAssert.success(pageA, context: 'group/page A');
      final gidsA = memberRows(
        pageA['payload'],
      ).map((g) => '${g['group_id'] ?? g['gid'] ?? g['id'] ?? ''}').toSet();
      expect(
        gidsA,
        contains(f2fGid),
        reason: 'face2face_save 落库后面对面群应出现在 A 的 join 群列表，实际=${gidsA.take(10)}',
      );
    }
  });
}
