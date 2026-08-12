/// ChannelCancelNotifier 取消订单编排契约测试。
///
/// 覆盖：成功 / 失败 / 并发守卫 / 状态复位。
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
  final List<String> cancelCalls = <String>[];

  @override
  Future<bool> cancelOrder(String orderNo) async {
    cancelCalls.add(orderNo);
    if (gate != null) await gate!.future;
    return result;
  }
}

ProviderContainer _container(_FakeOrderApi fake) {
  final container = ProviderContainer(
    overrides: [channelOrderApiProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ChannelCancelNotifier.cancel', () {
    test('CO-1 成功 → true，isCancelling 复位', () async {
      final fake = _FakeOrderApi(result: true);
      final container = _container(fake);

      final ok = await container
          .read(channelCancelProvider.notifier)
          .cancel('ORD-CANCEL-1');

      expect(ok, isTrue);
      expect(fake.cancelCalls, ['ORD-CANCEL-1']);
      expect(container.read(channelCancelProvider), isFalse);
    });

    test('CO-2 失败 → false，isCancelling 复位', () async {
      final fake = _FakeOrderApi(result: false);
      final container = _container(fake);

      final ok = await container
          .read(channelCancelProvider.notifier)
          .cancel('ORD-CANCEL-2');

      expect(ok, isFalse);
      expect(container.read(channelCancelProvider), isFalse);
    });

    test('CO-3 并发守卫：进行中再次调用立即返回 false', () async {
      final gate = Completer<void>();
      final fake = _FakeOrderApi(result: true, gate: gate);
      final container = _container(fake);
      final notifier = container.read(channelCancelProvider.notifier);

      final first = notifier.cancel('ORD-CANCEL-3');
      await Future<void>.delayed(Duration.zero);
      final second = await notifier.cancel('ORD-CANCEL-3');

      expect(second, isFalse);
      expect(fake.cancelCalls, ['ORD-CANCEL-3']);

      gate.complete();
      expect(await first, isTrue);
      expect(container.read(channelCancelProvider), isFalse);
    });
  });
}
