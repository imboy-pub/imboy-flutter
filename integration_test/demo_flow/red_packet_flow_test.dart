// DF-18 红包本地 API 闭环（demo flow 自动化）。
//
// 链路：发红包（最小金额 100 分、DEMO-FLOW 标记）→ 第二账号领取 → 重复领取拒绝
//   → 双方余额回读 → 红包详情回读（发送方/领取方/金额/状态一致性）。
//
// 默认跳过。仅允许同时满足以下条件时运行：
//   1. dart test（非 flutter test harness）；
//   2. API_BASE_URL 为本地/开发地址（api_test_client 白名单校验）；
//   3. TEST_ALLOW_API_WRITES=true（业务写入门禁）；
//   4. TEST_PHONE/TEST_PASSWORD（发送方 A）与 TEST_PHONE2/TEST_PASSWORD2（领取方 B）齐备。
// 生产地址一律拒绝；金额全部为最小测试金额（100 分）。
//
// 运行（本地后端 127.0.0.1:9800，账号同 DF-17）：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   IMBOY_SOLIDIFIED_KEY=<.env.local 提取> \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   TEST_PHONE2=smoke_bob TEST_PASSWORD2=demoflow888 \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/red_packet_flow_test.dart \
//     --concurrency=1 -r expanded

@TestOn('vm')
library;

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

const _marker = 'DEMO-FLOW-20260819';

String? _gateReason() {
  if (ApiTestConfig.isFlutterTestHarness) {
    return '需用 dart test 运行（flutter test 的 mock HTTP 会恒返 400）';
  }
  if (!ApiTestConfig.allowBusinessWrites) {
    return '业务写入门禁未开启：需 TEST_ALLOW_API_WRITES=true 且本地/开发地址';
  }
  if (ApiTestConfig.targetsProductionOrUnknown) {
    return '资金写入门禁：目标地址不是已识别的本地/开发环境，拒绝执行';
  }
  if (!ApiTestConfig.isDualConfigured) {
    return '双测试账号未配置：需 TEST_PHONE/TEST_PASSWORD + TEST_PHONE2/TEST_PASSWORD2';
  }
  return null;
}

void _ev(String msg) => print('[DEMO-FLOW-EVIDENCE][DF-18] $msg');

Map<String, dynamic> _payloadMap(Map<String, dynamic> resp) {
  final p = resp['payload'];
  return p is Map<String, dynamic> ? p : <String, dynamic>{};
}

int _balanceOf(Map<String, dynamic> resp) {
  final p = _payloadMap(resp);
  return (p['balance'] as num?)?.toInt() ?? -1;
}

List<Map<String, dynamic>> _txList(Map<String, dynamic> resp) {
  final payload = resp['payload'];
  Object? list;
  if (payload is List) {
    list = payload;
  } else if (payload is Map) {
    list = payload['list'] ?? payload['data'];
  }
  if (list is! List) return const [];
  return [
    for (final e in list)
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}

void main() {
  late ApiTestClient clientA;
  late ApiTestClient clientB;
  String? gate;

  setUpAll(() {
    gate = _gateReason();
    clientA = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demoflow-df18-a',
    );
    clientB = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demoflow-df18-b',
    );
  });

  tearDownAll(() {
    clientA.close();
    clientB.close();
  });

  test('DF-18 本地红包闭环：send → open → 重复领取拒绝 → 详情与双方余额一致', () async {
    if (gate != null) return markTestSkipped(gate!);
    final reason = ApiTestConfig.skipReasonIfNoRealNetwork;
    if (reason != null) return markTestSkipped(reason);

    final loginA = await clientA.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    expect(loginA['code'], 0, reason: '发送方 A 登录失败: ${loginA['msg']}');
    final loginB = await clientB.login(
      account: ApiTestConfig.testPhone2,
      password: ApiTestConfig.testPassword2,
      type: 'account',
    );
    expect(loginB['code'], 0, reason: '领取方 B 登录失败: ${loginB['msg']}');
    final uidA = clientA.currentUid!;
    final uidB = clientB.currentUid!;
    _ev('登录成功 A(uid=$uidA) B(uid=$uidB)');

    // 0. 确保发送方余额（mock topup 100 分，仅本地可用）
    final bBefore = _balanceOf(await clientA.get('/api/v1/wallet/balance'));
    final topup = await clientA.post(
      '/api/v1/wallet/topup',
      data: {'amount': 100},
    );
    expect(topup['code'], 0, reason: '本地 mock topup 失败: ${topup['msg']}');
    final bAfterTopup = _balanceOf(await clientA.get('/api/v1/wallet/balance'));
    expect(bAfterTopup - bBefore, 100, reason: 'topup 后 A 余额应 +100 分');
    _ev('topup 后 A 余额=$bAfterTopup 分');

    // 1. A 发最小红包（100 分 1 个，DEMO-FLOW 标记祝福语）
    final cBefore = _balanceOf(await clientB.get('/api/v1/wallet/balance'));
    final send = await clientA.post(
      '/api/v1/wallet/red_packet/send',
      data: {
        'amount': 100,
        'count': 1,
        'type': 'fixed',
        'greeting': '$_marker 红包验收',
      },
    );
    expect(send['code'], 0, reason: '红包发送失败: ${send['msg']}');
    final packetId = '${_payloadMap(send)['red_packet_id'] ?? ''}';
    expect(packetId.isNotEmpty, isTrue, reason: '缺少 red_packet_id');
    _ev('red_packet/send 成功 red_packet_id=$packetId amount=100 分 count=1');

    // 2. 发送后 A 余额即时扣减
    final bAfterSend = _balanceOf(await clientA.get('/api/v1/wallet/balance'));
    expect(
      bAfterTopup - bAfterSend,
      100,
      reason: '发红包后 A 余额应 -100 分：$bAfterTopup → $bAfterSend',
    );
    _ev('send 后 A 余额=$bAfterSend 分（-100）');

    // 3. B 领取红包
    final open = await clientB.post(
      '/api/v1/wallet/red_packet/open',
      data: {'red_packet_id': packetId},
    );
    expect(open['code'], 0, reason: '红包领取失败: ${open['msg']}');
    final grabAmount =
        (_payloadMap(open)['grab_amount'] as num?)?.toInt() ?? -1;
    expect(grabAmount, 100, reason: '单个固定红包领取金额应为 100 分');
    _ev('red_packet/open 成功 grab_amount=$grabAmount 分');

    // 4. B 余额回读
    final cAfterOpen = _balanceOf(await clientB.get('/api/v1/wallet/balance'));
    expect(
      cAfterOpen - cBefore,
      100,
      reason: '领取后 B 余额应 +100 分：$cBefore → $cAfterOpen',
    );
    _ev('open 后 B 余额=$cAfterOpen 分（+100）');

    // 5. B 重复领取被结构化拒绝，余额不变
    final reopen = await clientB.post(
      '/api/v1/wallet/red_packet/open',
      data: {'red_packet_id': packetId},
    );
    expect(reopen['code'], isNot(0), reason: '重复领取不应成功');
    final cAfterReopen = _balanceOf(
      await clientB.get('/api/v1/wallet/balance'),
    );
    expect(cAfterReopen, cAfterOpen, reason: '重复领取不得改变余额');
    _ev(
      '重复 open 拒绝 code=${reopen['code']} msg=${reopen['msg']}，'
      'B 余额保持 $cAfterReopen 分',
    );

    // 6. 红包详情回读：发送方视角 + 领取方视角一致
    final detailA = await clientA.get(
      '/api/v1/wallet/red_packet/$packetId/detail',
    );
    ApiAssert.success(detailA, context: '发送方红包详情');
    final detailB = await clientB.get(
      '/api/v1/wallet/red_packet/$packetId/detail',
    );
    ApiAssert.success(detailB, context: '领取方红包详情');
    final packetA = _payloadMap(detailA)['packet'];
    final packetB = _payloadMap(detailB)['packet'];
    final pktA = packetA is Map
        ? Map<String, dynamic>.from(packetA)
        : const <String, dynamic>{};
    final pktB = packetB is Map
        ? Map<String, dynamic>.from(packetB)
        : const <String, dynamic>{};
    final recvA = _payloadMap(detailA)['receivers'];
    final recvList = recvA is List
        ? [
            for (final e in recvA)
              if (e is Map) Map<String, dynamic>.from(e),
          ]
        : const <Map<String, dynamic>>[];
    expect(pktB['status'], pktA['status'], reason: '发送方与领取方详情 status 不一致');
    expect(pktB['amount'], pktA['amount'], reason: '发送方与领取方详情 amount 不一致');
    expect(
      '${pktA['id'] ?? pktA['red_packet_id'] ?? ''}'.contains(packetId) ||
          packetId.contains('${pktA['id'] ?? ''}'),
      isTrue,
      reason: '详情 packet.id 与发送返回 id 不一致: ${pktA['id']}',
    );
    expect(
      '${pktA['sender_uid']}',
      contains(uidA),
      reason: '详情 sender_uid=$uidA 不一致',
    );
    expect(
      ((pktA['amount'] as num?)?.toInt() ?? -1),
      100,
      reason: '详情 amount 应为 100 分',
    );
    expect(recvList.length, 1, reason: '领取记录应为 1 条');
    expect(
      '${recvList.first['receiver_uid'] ?? recvList.first['uid'] ?? ''}',
      contains(uidB),
      reason: '领取记录应含领取方 B($uidB)：${recvList.first}',
    );
    _ev(
      '详情一致：sender=$uidA amount=100 receivers=1(B=$uidB) '
      'status=${pktA['status']}',
    );

    // 7. 双方流水回读（±100 分红包条目）
    final txA = _txList(
      await clientA.get(
        '/api/v1/wallet/transactions',
        queryParameters: {'page': 1, 'size': 20},
      ),
    );
    final txB = _txList(
      await clientB.get(
        '/api/v1/wallet/transactions',
        queryParameters: {'page': 1, 'size': 20},
      ),
    );
    expect(
      txA.any((e) => (e['amount'] as num?)?.toInt() == -100),
      isTrue,
      reason: 'A 流水缺 -100 分红包条目',
    );
    expect(
      txB.any((e) => (e['amount'] as num?)?.toInt() == 100),
      isTrue,
      reason: 'B 流水缺 +100 分领取条目',
    );
    _ev('双方流水均含 ±100 分红包条目');
  }, timeout: const Timeout(Duration(minutes: 5)));

  group('DF-18 红包错误分支（本地）', () {
    test('低于最低总额 99 分被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final resp = await clientA.post(
        '/api/v1/wallet/red_packet/send',
        data: {
          'amount': 99,
          'count': 1,
          'type': 'fixed',
          'greeting': '$_marker 非法红包',
        },
      );
      ApiAssert.failure(resp, context: '低于最低总额红包');
      _ev('amount=99 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('count=0 被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final resp = await clientA.post(
        '/api/v1/wallet/red_packet/send',
        data: {
          'amount': 100,
          'count': 0,
          'type': 'fixed',
          'greeting': '$_marker 非法个数',
        },
      );
      ApiAssert.failure(resp, context: '红包个数为 0');
      _ev('count=0 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('打开不存在的红包被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientB.login(
        account: ApiTestConfig.testPhone2,
        password: ApiTestConfig.testPassword2,
        type: 'account',
      );
      expect(login['code'], 0);
      final resp = await clientB.post(
        '/api/v1/wallet/red_packet/open',
        data: {'red_packet_id': '0'},
      );
      ApiAssert.failure(resp, context: '打开不存在的红包');
      _ev('red_packet_id=0 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });
  });
}
