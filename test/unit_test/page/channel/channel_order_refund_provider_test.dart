/// ChannelRefundNotifier 退款编排契约测试。
///
/// 覆盖：成功 / 失败 / 并发守卫 / reason 透传。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/channel/channel_order_detail_page.dart';
import 'package:imboy/page/channel/channel_purchase_provider.dart';
import 'package:imboy/store/api/channel_order_api.dart';

class _FakeOrderApi extends ChannelOrderApi {
  _FakeOrderApi({this.result = true, this.gate});

  final bool result;
  final Completer<void>? gate;
  final List<(String, String?)> refundCalls = <(String, String?)>[];

  @override
  Future<bool> refundOrder(String orderNo, {String? reason}) async {
    refundCalls.add((orderNo, reason));
    if (gate != null) await gate!.future;
    return result;
  }
}

ProviderContainer _container(_FakeOrderApi fake) {
  final c = ProviderContainer(
    overrides: [channelOrderApiProvider.overrideWithValue(fake)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ChannelRefundNotifier.refund', () {
    test('RF-1 成功 → true，isRefunding 复位', () async {
      final fake = _FakeOrderApi(result: true);
      final c = _container(fake);

      final ok = await c
          .read(channelRefundProvider.notifier)
          .refund('ORD-1', reason: '不想要了');

      expect(ok, isTrue);
      expect(fake.refundCalls.single, ('ORD-1', '不想要了'));
      expect(c.read(channelRefundProvider), isFalse);
    });

    test('RF-2 失败 → false', () async {
      final fake = _FakeOrderApi(result: false);
      final c = _container(fake);

      final ok = await c.read(channelRefundProvider.notifier).refund('ORD-2');

      expect(ok, isFalse);
      expect(c.read(channelRefundProvider), isFalse);
    });

    test('RF-3 并发守卫：进行中再次调用立即返回 false', () async {
      final gate = Completer<void>();
      final fake = _FakeOrderApi(result: true, gate: gate);
      final c = _container(fake);
      final notifier = c.read(channelRefundProvider.notifier);

      final first = notifier.refund('ORD-3');
      await Future<void>.delayed(Duration.zero);
      final second = await notifier.refund('ORD-3');

      expect(second, isFalse);
      expect(fake.refundCalls, hasLength(1));

      gate.complete();
      expect(await first, isTrue);
    });

    test('RF-4 reason 为空时不传 reason（null）', () async {
      final fake = _FakeOrderApi(result: true);
      final c = _container(fake);

      await c.read(channelRefundProvider.notifier).refund('ORD-4');

      expect(fake.refundCalls.single, ('ORD-4', null));
    });
  });
}
