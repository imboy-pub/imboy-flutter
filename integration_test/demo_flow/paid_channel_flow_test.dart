// DF-13 付费频道 API 闭环：paywall → mock 订单 → 支付 → 解锁 → 退款回收。
//
// 默认跳过。只允许在显式授权的本地/开发地址运行，且支付方式固定为 mock，
// 不触碰生产地址和真实资金。

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';

const _channelId = String.fromEnvironment(
  'TEST_PAID_CHANNEL_ID',
  defaultValue: '',
);
const _paymentMethod = String.fromEnvironment(
  'TEST_PAID_CHANNEL_PAYMENT_METHOD',
  defaultValue: 'mock',
);
const _allowWrites = bool.fromEnvironment(
  'TEST_ALLOW_PAID_CHANNEL_WRITES',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '付费频道 mock 购买、解锁、退款回收闭环',
    (tester) async {
      if (!_isAuthorized()) return;

      final client = FlowApiClient(baseUrl: FlowApiConfig.apiBaseUrl);
      String? orderNo;
      var paid = false;
      try {
        final login = await client.login(
          account: FlowApiConfig.testPhone,
          password: FlowApiConfig.testPassword,
        );
        if (login['code'] != 0) {
          markTestSkipped('测试账号登录失败，无法执行付费频道闭环');
          return;
        }

        final before = await client.get('/api/v1/channel/$_channelId');
        FlowApiAssert.success(before, context: '购买前频道详情');
        final beforeChannel = _payloadMap(before);
        _assertPaidChannel(beforeChannel, '购买前');
        if (_readBool(beforeChannel['is_subscribed']) ||
            _readBool(beforeChannel['has_purchased'])) {
          markTestSkipped('测试账号已拥有该频道权限，无法证明未购买 paywall 前置条件');
          return;
        }

        final beforeMessages = await client.get(
          '/api/v1/channel/$_channelId/messages',
          queryParameters: {'limit': 20},
        );
        FlowApiAssert.failure(beforeMessages, context: '购买前频道内容必须被 paywall 拒绝');
        expect(
          '${beforeMessages['msg'] ?? ''}',
          contains('购买'),
          reason: '购买前内容接口应返回明确的购买门禁原因',
        );

        final created = await client.post(
          '/api/v1/channel/$_channelId/order',
          data: {'payment_method': _paymentMethod},
        );
        FlowApiAssert.success(created, context: '创建付费频道订单');
        final createdOrderNo = '${_payloadMap(created)['order_no'] ?? ''}';
        orderNo = createdOrderNo;
        if (createdOrderNo.isEmpty) fail('创建订单成功但缺少 order_no');

        final paidResponse = await client.post(
          '/api/v1/channel/order/pay',
          data: {'order_no': createdOrderNo},
        );
        FlowApiAssert.success(paidResponse, context: 'mock 支付订单');
        // 支付接口成功后即视为需要回收；轮询或后续断言失败也必须尝试退款。
        paid = true;

        final order = await _waitForPaidOrder(client, createdOrderNo);
        expect(order['status'], 1, reason: 'mock 支付后订单必须为 paid');

        final after = await client.get('/api/v1/channel/$_channelId');
        FlowApiAssert.success(after, context: '购买后频道详情');
        final afterChannel = _payloadMap(after);
        expect(
          afterChannel.containsKey('has_purchased'),
          isTrue,
          reason: '频道详情必须返回 has_purchased 购买权限字段',
        );
        expect(
          _readBool(afterChannel['has_purchased']),
          isTrue,
          reason: '支付成功后频道必须以购买态解锁',
        );

        final afterMessages = await client.get(
          '/api/v1/channel/$_channelId/messages',
          queryParameters: {'limit': 20},
        );
        FlowApiAssert.success(afterMessages, context: '购买后频道内容解锁');
        expect(
          _payloadMap(afterMessages)['list'],
          isA<List<dynamic>>(),
          reason: '购买后内容接口必须返回消息列表，即使测试频道暂时没有消息',
        );
      } finally {
        if (orderNo != null && !paid) {
          final pendingOrder = await client.get(
            '/api/v1/channel/order/$orderNo',
          );
          FlowApiAssert.success(pendingOrder, context: '取消前查询待支付订单');
          expect(
            _readInt(_payloadMap(pendingOrder)['status']),
            0,
            reason: '取消前测试订单必须仍为 pending 状态',
          );
          final cancelled = await client.post(
            '/api/v1/channel/order/cancel',
            data: {'order_no': orderNo},
          );
          FlowApiAssert.success(cancelled, context: '支付失败后取消待支付订单');
          final cancelledOrder = await client.get(
            '/api/v1/channel/order/$orderNo',
          );
          FlowApiAssert.success(cancelledOrder, context: '查询已取消订单');
          expect(
            _readInt(_payloadMap(cancelledOrder)['status']),
            3,
            reason: '支付失败后的测试订单必须进入 cancelled 状态',
          );
        }
        if (paid && orderNo != null) {
          final refund = await client.post(
            '/api/v1/channel/order/refund',
            data: {'order_no': orderNo, 'refund_reason': '自动化测试回收'},
          );
          FlowApiAssert.success(refund, context: '回收 mock 订单');

          final restored = await client.get('/api/v1/channel/$_channelId');
          FlowApiAssert.success(restored, context: '退款后频道详情');
          expect(
            _readBool(_payloadMap(restored)['has_purchased']),
            isFalse,
            reason: '退款后测试账号购买权限必须回收',
          );
          expect(
            _readBool(_payloadMap(restored)['is_subscribed']),
            isFalse,
            reason: '退款后测试账号订阅状态必须回收',
          );
          final restoredMessages = await client.get(
            '/api/v1/channel/$_channelId/messages',
            queryParameters: {'limit': 20},
          );
          FlowApiAssert.failure(
            restoredMessages,
            context: '退款后频道内容必须重新受 paywall 保护',
          );
        }
        client.close();
      }
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

bool _isAuthorized() {
  if (!_allowWrites) {
    markTestSkipped(
      '付费频道测试会创建并退款 mock 订单，需显式设置 TEST_ALLOW_PAID_CHANNEL_WRITES=true',
    );
    return false;
  }
  if (!FlowApiConfig.isConfigured || _channelId.isEmpty) {
    markTestSkipped('缺少测试账号或 TEST_PAID_CHANNEL_ID');
    return false;
  }
  if (_paymentMethod != 'mock') {
    markTestSkipped('付费频道闭环只允许 payment_method=mock');
    return false;
  }
  if (!_isSafeNonProductionUrl(FlowApiConfig.apiBaseUrl)) {
    markTestSkipped('付费频道写入测试只允许本地/开发地址');
    return false;
  }
  return true;
}

Future<Map<String, dynamic>> _waitForPaidOrder(
  FlowApiClient client,
  String orderNo,
) async {
  for (var attempt = 0; attempt < 5; attempt++) {
    final response = await client.get('/api/v1/channel/order/$orderNo');
    FlowApiAssert.success(response, context: '查询付费频道订单');
    final payload = _payloadMap(response);
    final status = _readInt(payload['status']);
    if (status == 1 || status == 2 || status == 3 || status == 4) {
      return payload;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('付费频道订单在轮询窗口内未进入终态');
}

void _assertPaidChannel(Map<String, dynamic> channel, String phase) {
  expect(_readInt(channel['type']), 2, reason: '$phase目标必须是付费频道');
  expect(
    channel.containsKey('is_subscribed'),
    isTrue,
    reason: '$phase频道详情缺少 is_subscribed',
  );
  expect(
    channel.containsKey('has_purchased'),
    isTrue,
    reason: '$phase频道详情缺少 has_purchased',
  );
}

Map<String, dynamic> _payloadMap(Map<String, dynamic> response) {
  final payload = response['payload'];
  if (payload is Map) return Map<String, dynamic>.from(payload);
  return <String, dynamic>{};
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch ('$value'.toLowerCase()) {
    'true' || '1' => true,
    _ => false,
  };
}

bool _isSafeNonProductionUrl(String value) {
  final host = Uri.tryParse(value)?.host.toLowerCase();
  if (host == null || host.isEmpty) return false;
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final octets = host.split('.');
  if (octets.length != 4) return false;
  final numbers = octets.map(int.tryParse).toList();
  if (numbers.any((value) => value == null || value < 0 || value > 255)) {
    return false;
  }
  final first = numbers[0]!;
  final second = numbers[1]!;
  return first == 127 ||
      first == 10 ||
      (first == 192 && second == 168) ||
      (first == 172 && second >= 16 && second <= 31);
}
