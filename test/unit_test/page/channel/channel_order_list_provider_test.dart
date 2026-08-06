/// channelMyOrdersProvider 解析契约测试。
///
/// 覆盖：
/// - 正常 {list:[...]} → 解析为 ChannelOrderModel 列表
/// - 缺失/非 List 的 list 字段 → 返回空列表（不抛）
/// - api 返回 null（请求失败）→ 返回空列表
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/channel/channel_order_list_page.dart';
import 'package:imboy/page/channel/channel_purchase_provider.dart';
import 'package:imboy/store/api/channel_order_api.dart';
import 'package:imboy/store/model/channel_order_model.dart';

class _FakeOrderApi extends ChannelOrderApi {
  _FakeOrderApi(this.payload);

  final Map<String, dynamic>? payload;

  @override
  Future<Map<String, dynamic>?> myOrders({int page = 1, int size = 20}) async =>
      payload;
}

Map<String, dynamic> _orderJson(String orderNo, int status) => {
  'id': 1,
  'channel_id': 3001,
  'user_id': 9,
  'order_no': orderNo,
  'amount': 9.9,
  'currency': 'CNY',
  'status': status,
  'payment_method': 'wallet',
  'channel_name': '付费频道A',
  'created_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
};

Future<List<ChannelOrderModel>> _read(Map<String, dynamic>? payload) async {
  final container = ProviderContainer(
    overrides: [
      channelOrderApiProvider.overrideWithValue(_FakeOrderApi(payload)),
    ],
  );
  addTearDown(container.dispose);
  return container.read(channelMyOrdersProvider.future);
}

void main() {
  group('channelMyOrdersProvider', () {
    test('MO-1 正常列表 → 解析为订单模型', () async {
      final orders = await _read({
        'list': [
          _orderJson('CH-1', ChannelOrderStatus.paid),
          _orderJson('CH-2', ChannelOrderStatus.pending),
        ],
      });

      expect(orders, hasLength(2));
      expect(orders.first.orderNo, 'CH-1');
      expect(orders.first.status, ChannelOrderStatus.paid);
      expect(orders.first.channelName, '付费频道A');
    });

    test('MO-2 缺失 list 字段 → 空列表', () async {
      final orders = await _read(const {'other': 1});
      expect(orders, isEmpty);
    });

    test('MO-3 list 非 List 类型 → 空列表', () async {
      final orders = await _read(const {'list': 'oops'});
      expect(orders, isEmpty);
    });

    test('MO-4 api 返回 null（请求失败）→ 空列表', () async {
      final orders = await _read(null);
      expect(orders, isEmpty);
    });

    test('MO-5 list 内含非 Map 项 → 跳过', () async {
      final orders = await _read({
        'list': [_orderJson('CH-1', ChannelOrderStatus.paid), 'junk', 42],
      });
      expect(orders, hasLength(1));
      expect(orders.single.orderNo, 'CH-1');
    });
  });
}
