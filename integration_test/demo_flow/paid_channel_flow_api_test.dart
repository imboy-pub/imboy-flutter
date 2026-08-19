// DF-13 付费频道 API 闭环（纯 Dart 版，本地环境写入验证）。
//
// 与 integration_test/demo_flow/paid_channel_flow_test.dart（flutter test -d 设备版）
// 覆盖同一链路，但本文件用 `dart test` 显式路径运行，无设备依赖：
//   paywall → mock topup → 余额回读 → 订单创建(wallet) → 支付 → 订单列表回读
//   → 内容解锁回读 → 钱包扣款回读 → 退款回收 → 权限/余额回收。
//
// 安全门禁（默认全部 SKIP）：
//   TEST_ALLOW_PAID_CHANNEL_WRITES=true —— 付费频道写入开关（对齐 flutter 版命名）
//   TEST_ALLOW_API_WRITES=true          —— api_test_client.post 的通用写入门禁
//   TEST_PAID_CHANNEL_ID                —— fixture 脚本输出的付费频道 ID
//   API_BASE_URL 必须是本地/开发地址；payment_method 固定 wallet（本地 mock 资金）
//
// 运行示例（fixture: imboy/scripts/paid_channel_fixture.sh create）：
//   read_env() { awk -F= -v key="$1" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$2"; }
//   API_BASE_URL="$(read_env API_BASE_URL scripts/test.env | tr -d ' ' | sed 's/ *#.*//')" \
//   TEST_PHONE="$(read_env TEST_PHONE scripts/test.env)" \
//   TEST_PASSWORD="$(read_env TEST_PASSWORD scripts/test.env)" \
//   IMBOY_ENV_PRO=.env.local TEST_PAID_CHANNEL_ID=<fixture-channel-id> \
//   TEST_ALLOW_PAID_CHANNEL_WRITES=true TEST_ALLOW_API_WRITES=true \
//   dart test integration_test/demo_flow/paid_channel_flow_api_test.dart \
//     --concurrency=1 --reporter expanded
//
// 资金红线：本测试只允许本地 mock topup 与 wallet 网关（本地环境资金为 mock），
// 对生产地址一律 SKIP；测试结束通过退款把余额与权益恢复原状。

@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../test/unit_test/api/api_test_client.dart';

/// flutter 版用 --dart-define；纯 dart test 不支持 -D，优先读环境变量。
final String _channelId =
    Platform.environment['TEST_PAID_CHANNEL_ID'] ??
    String.fromEnvironment('TEST_PAID_CHANNEL_ID');
const _paymentMethod = 'wallet';

/// fixture 价格 9.90 元 = 990 分（channel_price.price 以元存储）。
const _priceFen = 990;

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? orderNo;
  bool paid = false;
  int balanceBeforeTopup = 0;

  String? skipOr() {
    final guard = _writeGuard();
    if (guard != null) {
      markTestSkipped(guard);
      return guard;
    }
    if (!loggedIn) {
      markTestSkipped('测试账号登录失败');
      return 'login-failed';
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
      _log('buyer 登录成功 uid=${client.currentUid}');
    }
  });

  tearDownAll(() => client.close());

  test('DF-13.1 购买前 paywall：详情可读、内容被拒', () async {
    if (skipOr() != null) return;
    final before = await client.get('/api/v1/channel/$_channelId');
    ApiAssert.success(before, context: '购买前频道详情');
    final channel = _payload(before);
    expect(_readInt(channel['type']), 2, reason: '目标必须是付费频道');
    expect(
      _readInt(channel['price']),
      _priceFen,
      reason: 'fixture 价格 9.90 元(990 分)',
    );
    expect(_readBool(channel['is_subscribed']), isFalse);
    expect(_readBool(channel['has_purchased']), isFalse);

    final messages = await client.get(
      '/api/v1/channel/$_channelId/messages',
      queryParameters: {'limit': 20},
    );
    ApiAssert.failure(messages, context: '购买前频道内容必须被 paywall 拒绝');
    expect(
      '${messages['msg'] ?? ''}',
      contains('购买'),
      reason: 'paywall 拒绝原因必须指向购买',
    );
    _log(
      'paywall 生效：详情 price=${channel['price']} 分，内容被拒 msg=${messages['msg']}',
    );
  });

  test('DF-13.2 本地 mock topup 最小可用金额并回读余额', () async {
    if (skipOr() != null) return;
    final before = await client.get('/api/v1/wallet/balance');
    ApiAssert.success(before, context: '充值前余额');
    balanceBeforeTopup = _readInt(_payload(before)['balance']);
    expect(balanceBeforeTopup, greaterThanOrEqualTo(0));

    final topup = await client.post(
      '/api/v1/wallet/topup',
      data: {'amount': _priceFen},
    );
    ApiAssert.success(topup, context: '本地 mock topup');
    expect(
      _readInt(_payload(topup)['balance']),
      balanceBeforeTopup + _priceFen,
      reason: 'topup 后余额必须增加 990 分',
    );

    final after = await client.get('/api/v1/wallet/balance');
    ApiAssert.success(after, context: '充值后余额回读');
    expect(
      _readInt(_payload(after)['balance']),
      balanceBeforeTopup + _priceFen,
      reason: '余额回读必须与 topup 响应一致',
    );
    _log(
      'mock topup 990 分成功：$balanceBeforeTopup -> ${_payload(after)['balance']}',
    );
  });

  test('DF-13.3 创建订单并支付（wallet 网关）', () async {
    if (skipOr() != null) return;
    final created = await client.post(
      '/api/v1/channel/$_channelId/order',
      data: {'payment_method': _paymentMethod},
    );
    ApiAssert.success(created, context: '创建付费频道订单');
    orderNo = '${_payload(created)['order_no'] ?? ''}';
    expect(orderNo!.isNotEmpty, isTrue, reason: '创建订单必须返回 order_no');
    expect(
      _readNum(_payload(created)['amount']),
      9.90,
      reason: '订单金额应为频道价格 9.90 元',
    );

    final payResp = await client.post(
      '/api/v1/channel/order/pay',
      data: {'order_no': orderNo},
    );
    ApiAssert.success(payResp, context: 'wallet 支付订单');
    paid = true;

    final order = await _waitForFinalOrder(client, orderNo!);
    expect(_readInt(order['status']), 1, reason: '支付后订单必须为 paid(1)');
    _log('订单支付成功 orderNo=$orderNo status=${order['status']}');
  });

  test('DF-13.4 订单列表回读包含新订单', () async {
    if (skipOr() != null || orderNo == null) {
      if (skipOr() == null) markTestSkipped('前序未创建订单');
      return;
    }
    final orders = await client.get(
      '/api/v1/channel/orders/my',
      queryParameters: {'page': 1, 'size': 20},
    );
    ApiAssert.success(orders, context: '我的订单列表');
    expect(
      '$orders'.contains(orderNo!),
      isTrue,
      reason: '新订单必须出现在 orders/my 列表',
    );
    _log('orders/my 回读命中 orderNo=$orderNo');
  });

  test('DF-13.5 购买后内容解锁与钱包扣款回读', () async {
    if (skipOr() != null || !paid) {
      if (skipOr() == null) markTestSkipped('前序未完成支付');
      return;
    }
    final after = await client.get('/api/v1/channel/$_channelId');
    ApiAssert.success(after, context: '购买后频道详情');
    final channel = _payload(after);
    expect(_readBool(channel['has_purchased']), isTrue, reason: '支付后必须以购买态解锁');
    expect(_readBool(channel['is_subscribed']), isTrue, reason: '支付后订阅权益生效');

    final messages = await client.get(
      '/api/v1/channel/$_channelId/messages',
      queryParameters: {'limit': 20},
    );
    ApiAssert.success(messages, context: '购买后频道内容解锁');
    final list = _payload(messages)['list'];
    expect(list, isA<List<dynamic>>(), reason: '解锁后必须返回消息列表');
    expect(
      '$list'.contains('paid-channel-fixture-content'),
      isTrue,
      reason: '解锁后必须能读到 fixture 内容',
    );

    final balance = await client.get('/api/v1/wallet/balance');
    ApiAssert.success(balance, context: '支付后余额回读');
    expect(
      _readInt(_payload(balance)['balance']),
      balanceBeforeTopup,
      reason: 'wallet 支付必须扣减 990 分，余额回到充值前水平',
    );
    _log('解锁回读通过；余额扣减 990 分回到 $balanceBeforeTopup');
  });

  test('DF-13.6 退款回收：权益与余额恢复', () async {
    if (skipOr() != null || !paid || orderNo == null) {
      if (skipOr() == null) markTestSkipped('前序未完成支付');
      return;
    }
    final refund = await client.post(
      '/api/v1/channel/order/refund',
      data: {'order_no': orderNo, 'refund_reason': 'DEMO-FLOW-20260819 自动化回收'},
    );
    ApiAssert.success(refund, context: '退款回收 mock 订单');

    final restored = await client.get('/api/v1/channel/$_channelId');
    ApiAssert.success(restored, context: '退款后频道详情');
    expect(
      _readBool(_payload(restored)['has_purchased']),
      isFalse,
      reason: '退款后购买权益必须回收',
    );
    expect(
      _readBool(_payload(restored)['is_subscribed']),
      isFalse,
      reason: '退款后订阅状态必须回收',
    );

    final messages = await client.get(
      '/api/v1/channel/$_channelId/messages',
      queryParameters: {'limit': 20},
    );
    ApiAssert.failure(messages, context: '退款后频道内容必须重新受 paywall 保护');

    final balance = await client.get('/api/v1/wallet/balance');
    ApiAssert.success(balance, context: '退款后余额回读');
    expect(
      _readInt(_payload(balance)['balance']),
      balanceBeforeTopup + _priceFen,
      reason: '退款必须把 990 分退回钱包',
    );
    final refundedOrder = await client.get('/api/v1/channel/order/$orderNo');
    ApiAssert.success(refundedOrder, context: '退款后订单详情');
    _log(
      '退款回收通过：has_purchased=false，余额回补至 '
      '${_payload(balance)['balance']}，订单 status=${_payload(refundedOrder)['status']}',
    );
  });
}

String? _writeGuard() {
  final paidWrites =
      (Platform.environment['TEST_ALLOW_PAID_CHANNEL_WRITES'] ?? '')
          .toLowerCase() ==
      'true';
  if (!paidWrites) return '未设置 TEST_ALLOW_PAID_CHANNEL_WRITES=true';
  if (!ApiTestConfig.allowBusinessWrites)
    return '未设置 TEST_ALLOW_API_WRITES=true';
  if (ApiTestConfig.targetsProductionOrUnknown) return '目标地址不是本地/开发环境';
  if (!ApiTestConfig.isConfigured) return '未配置测试账号';
  if (_channelId.isEmpty) return '未设置 TEST_PAID_CHANNEL_ID（用 fixture 脚本创建）';
  return null;
}

Future<Map<String, dynamic>> _waitForFinalOrder(
  ApiTestClient client,
  String orderNo,
) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    final response = await client.get('/api/v1/channel/order/$orderNo');
    ApiAssert.success(response, context: '查询付费频道订单');
    final payload = _payload(response);
    final status = _readInt(payload['status']);
    if (status == 1 || status == 2 || status == 3 || status == 4)
      return payload;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('付费频道订单在轮询窗口内未进入终态');
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

double _readNum(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? -1;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch ('$value'.toLowerCase()) {
    'true' || '1' => true,
    _ => false,
  };
}

void _log(String msg) => stderr.writeln('[DF-13] $msg');
