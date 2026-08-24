// DF-17 钱包转账本地 API 闭环（demo flow 自动化）。
//
// 链路：mock topup 最小金额充值 → 付款方余额回读 → 向第二测试账号转账最小金额
//   → 收款方 accept 收取 → 双方余额/流水回读 + 金额错误分支验证。
//
// 默认跳过。仅允许同时满足以下条件时运行：
//   1. dart test（非 flutter test harness）；
//   2. API_BASE_URL 为本地/开发地址（127.0.0.1 等，api_test_client 白名单校验）；
//   3. TEST_ALLOW_API_WRITES=true（业务写入门禁）；
//   4. TEST_PHONE/TEST_PASSWORD（付款方 A）与 TEST_PHONE2/TEST_PASSWORD2（收款方 B）齐备。
// 生产地址一律拒绝；金额全部为最小测试金额（100 分），内容带 DEMO-FLOW 标记。
//
// 运行（本地后端 127.0.0.1:9800）：
//   read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' .env.local; }
//   API_BASE_URL=http://127.0.0.1:9800 \
//   IMBOY_SOLIDIFIED_KEY="$(read_env SOLIDIFIED_KEY)" \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   TEST_PHONE2=smoke_bob TEST_PASSWORD2=demoflow888 \
//   TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/wallet_transfer_flow_test.dart \
//     --concurrency=1 -r expanded
// 后端 BUG-A（transfer/accept 恒报「转账订单不存在」）已于 alpha.36 修复并复验
// （2026-08-18，见 test/demo_flow/wallet_flow.md 第 6.1 节）。启用 accept 收款
// 闭环用例的方式：环境变量 TEST_EXPECT_TRANSFER_ACCEPT_FIXED=true
// （dart test 不支持 --dart-define，2026-08-19 已按文档建议改为环境变量门禁）。

@TestOn('vm')
library;

import 'dart:io' show Platform;

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

const _marker = 'DEMO-FLOW-20260819';

/// 后端 BUG-A 修复后置 true 才执行 accept 收款闭环。
/// 兼容两种打开方式：--dart-define（flutter test）或环境变量（dart test）。
const _expectAcceptFixedFromDefine = bool.fromEnvironment(
  'TEST_EXPECT_TRANSFER_ACCEPT_FIXED',
  defaultValue: false,
);

bool get _expectAcceptFixed =>
    _expectAcceptFixedFromDefine ||
    (Platform.environment['TEST_EXPECT_TRANSFER_ACCEPT_FIXED'] ?? '')
            .toLowerCase() ==
        'true';

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

void _ev(String msg) => print('[DEMO-FLOW-EVIDENCE][DF-17] $msg');

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
      deviceId: 'demoflow-df17-a',
    );
    clientB = ApiTestClient(
      baseUrl: ApiTestConfig.apiBaseUrl,
      deviceId: 'demoflow-df17-b',
    );
  });

  tearDownAll(() {
    clientA.close();
    clientB.close();
  });

  test(
    'DF-17 本地转账闭环：topup → send → accept → 双方余额/流水回读',
    () async {
      if (gate != null) return markTestSkipped(gate!);
      final reason = ApiTestConfig.skipReasonIfNoRealNetwork;
      if (reason != null) return markTestSkipped(reason);

      // A：本地契约账号（mobile 登录）；B：smoke_bob（account 登录）
      final loginA = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(loginA['code'], 0, reason: '付款方 A 登录失败: ${loginA['msg']}');
      final loginB = await clientB.login(
        account: ApiTestConfig.testPhone2,
        password: ApiTestConfig.testPassword2,
        type: 'account',
      );
      expect(loginB['code'], 0, reason: '收款方 B 登录失败: ${loginB['msg']}');
      final uidA = clientA.currentUid!;
      final uidB = clientB.currentUid!;
      _ev('登录成功 A(uid=$uidA) B(uid=$uidB)');

      // 1. 转账前双方余额
      final bBefore = _balanceOf(await clientA.get('/api/v1/wallet/balance'));
      final cBefore = _balanceOf(await clientB.get('/api/v1/wallet/balance'));
      _ev('转账前余额 A=$bBefore 分, B=$cBefore 分');

      // 2. mock topup 最小金额 100 分（仅本地环境可用）
      final topup = await clientA.post(
        '/api/v1/wallet/topup',
        data: {'amount': 100},
      );
      expect(topup['code'], 0, reason: '本地 mock topup 失败: ${topup['msg']}');
      _ev('topup 100 分成功 reference_no=${_payloadMap(topup)['reference_no']}');

      // 3. A 余额回读（充值后）
      final bAfterTopup = _balanceOf(
        await clientA.get('/api/v1/wallet/balance'),
      );
      expect(
        bAfterTopup - bBefore,
        100,
        reason: 'topup 后余额应 +100 分：$bBefore → $bAfterTopup',
      );
      _ev('topup 后 A 余额=$bAfterTopup 分（+100）');

      // 4. A → B 转账最小金额 100 分（带 DEMO-FLOW 标记）
      final send = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {'receiver_uid': uidB, 'amount': 100, 'remark': '$_marker 转账验收'},
      );
      expect(send['code'], 0, reason: '转账发送失败: ${send['msg']}');
      final transferId = '${_payloadMap(send)['transfer_id'] ?? ''}';
      expect(transferId.isNotEmpty, isTrue, reason: '缺少 transfer_id');
      _ev('transfer/send 成功 transfer_id=$transferId amount=100 分');

      // 5. A 余额回读（转账扣款即时发生）
      final bAfterSend = _balanceOf(
        await clientA.get('/api/v1/wallet/balance'),
      );
      expect(
        bAfterTopup - bAfterSend,
        100,
        reason: '转账后 A 余额应 -100 分：$bAfterTopup → $bAfterSend',
      );
      _ev('send 后 A 余额=$bAfterSend 分（-100）');

      // 6. A 流水回读（含 -100 分转账转出条目）
      //    注：历史 BUG-A（transfer/accept 恒报「转账订单不存在」）已在 alpha.36
      //    修复（transfer_repo accept 事务内 SELECT 改用 elib_pg:query），2026-08-18
      //    复验通过，详见 test/demo_flow/wallet_flow.md 第 6.1 节。
      final txA = _txList(
        await clientA.get(
          '/api/v1/wallet/transactions',
          queryParameters: {'page': 1, 'size': 20},
        ),
      );
      final outEntry = txA.where((e) {
        final amt = (e['amount'] as num?)?.toInt();
        return amt == -100;
      }).toList();
      expect(outEntry.isNotEmpty, isTrue, reason: 'A 流水缺 -100 分转账条目');
      _ev(
        'A 流水含 -100 分转账条目 remark=${outEntry.first['remark'] ?? ''} '
        'tx_type=${outEntry.first['tx_type'] ?? '?'}',
      );

      final cAfterSend = _balanceOf(
        await clientB.get('/api/v1/wallet/balance'),
      );
      expect(
        cAfterSend,
        cBefore,
        reason: 'accept 前 B 余额应不变（pending 语义）：$cBefore → $cAfterSend',
      );
      _ev('send 后 B 余额=$cAfterSend 分（accept 前未入账，符合 pending 语义）');

      // 7. gate 打开时由 B accept 回收本笔转账，避免套件遗留悬挂 pending。
      //    （BUG-A 已修复，2026-08-18 复验；门禁保留以显式标记 accept 写入意图。）
      if (_expectAcceptFixed) {
        final accept = await clientB.post(
          '/api/v1/wallet/transfer/accept',
          data: {'transfer_id': transferId},
        );
        expect(accept['code'], 0, reason: '收款方 accept 失败: ${accept['msg']}');
        final cAfterAccept = _balanceOf(
          await clientB.get('/api/v1/wallet/balance'),
        );
        expect(
          cAfterAccept - cBefore,
          100,
          reason: 'accept 后 B 余额应 +100 分：$cBefore → $cAfterAccept',
        );
        final reAccept = await clientB.post(
          '/api/v1/wallet/transfer/accept',
          data: {'transfer_id': transferId},
        );
        expect(reAccept['code'], isNot(0), reason: '重复 accept 不应成功');
        final cAfterRe = _balanceOf(
          await clientB.get('/api/v1/wallet/balance'),
        );
        expect(cAfterRe, cAfterAccept, reason: '重复 accept 不得改变余额');
        _ev(
          'accept 回收 transfer_id=$transferId：B $cBefore→$cAfterAccept（+100），'
          '重复 accept 拒绝 code=${reAccept['code']} msg=${reAccept['msg']}，'
          'B 余额保持 $cAfterRe 分',
        );
      } else {
        _ev('accept 门禁未开：本笔 transfer_id=$transferId 留为 pending（历史行为）');
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'DF-17 收款方 accept 入账闭环（独立用例：TEST_EXPECT_TRANSFER_ACCEPT_FIXED 门禁）',
    () async {
      if (gate != null) return markTestSkipped(gate!);
      if (!_expectAcceptFixed) {
        return markTestSkipped(
          'accept 收款闭环门禁未打开：设置环境变量 '
          'TEST_EXPECT_TRANSFER_ACCEPT_FIXED=true（后端 BUG-A 已于 alpha.36 修复，'
          '2026-08-18 复验通过；门禁保留用于明确标记 accept 写入意图）',
        );
      }

      final loginA = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(loginA['code'], 0);
      final loginB = await clientB.login(
        account: ApiTestConfig.testPhone2,
        password: ApiTestConfig.testPassword2,
        type: 'account',
      );
      expect(loginB['code'], 0);
      final uidB = clientB.currentUid!;

      final cBefore = _balanceOf(await clientB.get('/api/v1/wallet/balance'));
      final topup = await clientA.post(
        '/api/v1/wallet/topup',
        data: {'amount': 100},
      );
      expect(topup['code'], 0, reason: '本地 mock topup 失败: ${topup['msg']}');
      final send = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {
          'receiver_uid': uidB,
          'amount': 100,
          'remark': '$_marker 转账 accept 验收',
        },
      );
      expect(send['code'], 0, reason: '转账发送失败: ${send['msg']}');
      final transferId = '${_payloadMap(send)['transfer_id'] ?? ''}';
      expect(transferId.isNotEmpty, isTrue);

      final accept = await clientB.post(
        '/api/v1/wallet/transfer/accept',
        data: {'transfer_id': transferId},
      );
      expect(accept['code'], 0, reason: '收款方 accept 失败: ${accept['msg']}');
      _ev('transfer/accept 成功（B 收取 transfer_id=$transferId）');

      final cAfterAccept = _balanceOf(
        await clientB.get('/api/v1/wallet/balance'),
      );
      expect(
        cAfterAccept - cBefore,
        100,
        reason: 'accept 后 B 余额应 +100 分：$cBefore → $cAfterAccept',
      );
      _ev('accept 后 B 余额=$cAfterAccept 分（+100）');

      final txB = _txList(
        await clientB.get(
          '/api/v1/wallet/transactions',
          queryParameters: {'page': 1, 'size': 20},
        ),
      );
      expect(
        txB.any((e) => (e['amount'] as num?)?.toInt() == 100),
        isTrue,
        reason: 'B 流水缺 +100 分转账条目',
      );
      _ev('B 流水含 +100 分转账入账条目');

      final reAccept = await clientB.post(
        '/api/v1/wallet/transfer/accept',
        data: {'transfer_id': transferId},
      );
      expect(reAccept['code'], isNot(0), reason: '重复 accept 不应成功');
      final cAfterReAccept = _balanceOf(
        await clientB.get('/api/v1/wallet/balance'),
      );
      expect(cAfterReAccept, cAfterAccept, reason: '重复 accept 不得改变余额');
      _ev(
        '重复 accept 被拒绝 code=${reAccept['code']} msg=${reAccept['msg']}，'
        'B 余额保持 $cAfterReAccept 分',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  group('DF-17 转账错误分支（本地）', () {
    test('低于最低金额 99 分被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      // 金额校验（>=100）先于资金动作；收款方用固定测试 UID 占位即可
      final resp = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {
          'receiver_uid': '1000000056',
          'amount': 99,
          'remark': '$_marker 非法金额',
        },
      );
      ApiAssert.failure(resp, context: '低于最低金额转账');
      _ev('amount=99 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('非法格式金额（字符串小数）被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final resp = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {
          'receiver_uid': '1000000056',
          'amount': '10.5',
          'remark': '$_marker 非法格式',
        },
      );
      ApiAssert.failure(resp, context: '非法格式金额转账');
      _ev('amount="10.5" 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('金额缺失（0）被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final resp = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {
          'receiver_uid': '1000000056',
          'amount': 0,
          'remark': '$_marker 空金额',
        },
      );
      ApiAssert.failure(resp, context: '空金额转账');
      _ev('amount=0 拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('超出余额被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final resp = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {
          'receiver_uid': '1000000056',
          'amount': 100000000000, // 100 万元（分），远超测试账号余额
          'remark': '$_marker 超额',
        },
      );
      ApiAssert.failure(resp, context: '超出余额转账');
      _ev('超余额拒绝 code=${resp['code']} msg=${resp['msg']}');
    });

    test('空/非法 receiver_uid 被拒绝且不崩溃', () async {
      if (gate != null) return markTestSkipped(gate!);
      final login = await clientA.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      );
      expect(login['code'], 0);
      final empty = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {'receiver_uid': '', 'amount': 100},
      );
      ApiAssert.failure(empty, context: '空 receiver_uid');
      final invalid = await clientA.post(
        '/api/v1/wallet/transfer/send',
        data: {'receiver_uid': 'abc', 'amount': 100},
      );
      ApiAssert.failure(invalid, context: '非法 receiver_uid');
      _ev('receiver_uid 空/非法均拒绝 code=${empty['code']}/${invalid['code']}');
    });
  });
}
