/// ChannelPurchaseNotifier 购买编排契约测试。
///
/// 覆盖：
/// - CP-1 createOrder 返回 null → purchase 失败，且不调 payOrder/getOrder
/// - CP-2 payOrder 返回 null → purchase 失败，不进入轮询
/// - CP-3 全成功（getOrder 命中 paid）→ 返回订单，payOrder 收到 paymentMethod
/// - CP-4 终态 cancelled → 返回 null
/// - CP-5 isPurchasing 完成后回到 false
/// - CP-6 paymentMethod 默认 wallet，可自定义透传
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/channel/channel_purchase_provider.dart';
import 'package:imboy/store/api/channel_order_api.dart';
import 'package:imboy/store/model/channel_order_model.dart';

ChannelOrderModel _order(String orderNo, int status) => ChannelOrderModel(
  id: 1,
  channelId: 3001,
  userId: 9,
  orderNo: orderNo,
  amount: 9.9,
  currency: 'CNY',
  status: status,
  paymentMethod: 'wallet',
  createdAt: DateTime(2026, 1, 1),
);

/// ChannelOrderApi fake：可控各步返回值并记录调用。
class _FakeOrderApi extends ChannelOrderApi {
  _FakeOrderApi({this.createResult, this.payResult, this.getStatus});

  final ChannelOrderModel? Function()? createResult;
  final Map<String, dynamic>? payResult;
  final int? getStatus;

  final List<String> createCalls = <String>[];
  final List<(String, String)> payCalls = <(String, String)>[];
  final List<String> getCalls = <String>[];

  @override
  Future<ChannelOrderModel?> createOrder(String channelId) async {
    createCalls.add(channelId);
    return createResult?.call();
  }

  @override
  Future<Map<String, dynamic>?> payOrder(
    String orderNo, {
    String paymentMethod = 'wallet',
  }) async {
    payCalls.add((orderNo, paymentMethod));
    return payResult;
  }

  @override
  Future<ChannelOrderModel?> getOrder(String orderNo) async {
    getCalls.add(orderNo);
    if (getStatus == null) return null;
    return _order(orderNo, getStatus!);
  }

  @override
  Future<Map<String, dynamic>?> myOrders({int page = 1, int size = 20}) async =>
      null;
}

ProviderContainer _containerWith(_FakeOrderApi fake) {
  final container = ProviderContainer(
    overrides: [channelOrderApiProvider.overrideWithValue(fake)],
  );
  return container;
}

void main() {
  group('ChannelPurchaseState', () {
    test('CP-S1 默认 isPurchasing=false', () {
      const s = ChannelPurchaseState();
      expect(s.isPurchasing, false);
    });

    test('CP-S2 copyWith 覆盖且不可变', () {
      const s = ChannelPurchaseState();
      final s2 = s.copyWith(isPurchasing: true);
      expect(s2.isPurchasing, true);
      expect(s.isPurchasing, false);
    });
  });

  group('ChannelPurchaseNotifier.purchase', () {
    test('CP-1 createOrder 失败 → null，不调 payOrder/getOrder', () async {
      final fake = _FakeOrderApi(createResult: () => null);
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final result = await container
          .read(channelPurchaseProvider.notifier)
          .purchase('ch-1');

      expect(result, isNull);
      expect(fake.createCalls, ['ch-1']);
      expect(fake.payCalls, isEmpty);
      expect(fake.getCalls, isEmpty);
    });

    test('CP-2 payOrder 失败 → null，不进入轮询', () async {
      final fake = _FakeOrderApi(
        createResult: () => _order('CH-2', ChannelOrderStatus.pending),
        payResult: null,
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final result = await container
          .read(channelPurchaseProvider.notifier)
          .purchase('ch-2');

      expect(result, isNull);
      expect(fake.payCalls, hasLength(1));
      expect(fake.getCalls, isEmpty);
    });

    test('CP-3 全成功 → 返回已支付订单，payOrder 透传 paymentMethod', () async {
      final fake = _FakeOrderApi(
        createResult: () => _order('CH-3', ChannelOrderStatus.pending),
        payResult: const <String, dynamic>{},
        getStatus: ChannelOrderStatus.paid,
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final result = await container
          .read(channelPurchaseProvider.notifier)
          .purchase('ch-3', paymentMethod: 'wallet');

      expect(result, isNotNull);
      expect(result!.status, ChannelOrderStatus.paid);
      expect(fake.payCalls.single.$2, 'wallet');
    });

    test('CP-4 终态 cancelled → null', () async {
      final fake = _FakeOrderApi(
        createResult: () => _order('CH-4', ChannelOrderStatus.pending),
        payResult: const <String, dynamic>{},
        getStatus: ChannelOrderStatus.cancelled,
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      final result = await container
          .read(channelPurchaseProvider.notifier)
          .purchase('ch-4');

      expect(result, isNull);
    });

    test('CP-5 完成后 isPurchasing 回到 false', () async {
      final fake = _FakeOrderApi(
        createResult: () => _order('CH-5', ChannelOrderStatus.pending),
        payResult: const <String, dynamic>{},
        getStatus: ChannelOrderStatus.paid,
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      await container.read(channelPurchaseProvider.notifier).purchase('ch-5');

      expect(container.read(channelPurchaseProvider).isPurchasing, false);
    });

    test('CP-6 默认 paymentMethod 为 wallet', () async {
      final fake = _FakeOrderApi(
        createResult: () => _order('CH-6', ChannelOrderStatus.pending),
        payResult: const <String, dynamic>{},
        getStatus: ChannelOrderStatus.paid,
      );
      final container = _containerWith(fake);
      addTearDown(container.dispose);

      await container.read(channelPurchaseProvider.notifier).purchase('ch-6');

      expect(fake.payCalls.single.$2, 'wallet');
    });
  });
}
