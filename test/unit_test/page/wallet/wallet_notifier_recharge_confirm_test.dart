import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/store/api/wallet_api.dart';

class MockWalletApi extends Mock implements WalletApi {}

/// 造一个注入 mock API 的 notifier（Riverpod 3 Notifier 须经容器初始化）。
WalletNotifier notifierWith(MockWalletApi api) {
  final container = ProviderContainer(
    overrides: [walletProvider.overrideWith(() => WalletNotifier(api: api))],
  );
  addTearDown(container.dispose);
  return container.read(walletProvider.notifier);
}

/// recharge() 主动查单确认（confirm）轮询路径单测。
///
/// 背景：异步回调（notify）丢失时订单永远待支付，客户端轮询改为调
/// confirm 让服务端主动向网关查单入账。覆盖三态：已付命中 / 终态退出 /
/// 超时未付。
void main() {
  late MockWalletApi api;

  setUp(() {
    api = MockWalletApi();
  });

  RechargeOrder order() => RechargeOrder(
    orderNo: 'RCH_T1',
    amount: 100,
    status: RechargeOrderStatus.pending,
    paymentMethod: 'mock',
  );

  test('RC-1 confirm 返回已支付 → recharge 成功并刷新余额', () async {
    when(
      () => api.createRechargeOrder(100, paymentMethod: 'mock'),
    ).thenAnswer((_) async => order());
    when(
      () => api.payRecharge('RCH_T1'),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(() => api.confirmRechargeOrder('RCH_T1')).thenAnswer(
      (_) async => {
        'order_no': 'RCH_T1',
        'status': RechargeOrderStatus.paid,
        'balance': 100,
      },
    );
    when(() => api.getBalance()).thenAnswer(
      (_) async =>
          const WalletBalance(balance: 100, balanceYuan: 1.0, frozen: 0),
    );
    when(
      () => api.getTransactions(page: 1, size: 20),
    ).thenAnswer((_) async => null);

    final notifier = notifierWith(api);
    final ok = await notifier.recharge(100, paymentMethod: 'mock');

    expect(ok, true);
    verify(() => api.confirmRechargeOrder('RCH_T1')).called(1);
  });

  test('RC-2 confirm 返回终态（已退款）→ recharge 失败且停止轮询', () async {
    when(
      () => api.createRechargeOrder(100, paymentMethod: 'mock'),
    ).thenAnswer((_) async => order());
    when(
      () => api.payRecharge('RCH_T1'),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(() => api.confirmRechargeOrder('RCH_T1')).thenAnswer(
      (_) async => {
        'order_no': 'RCH_T1',
        'status': RechargeOrderStatus.refunded,
      },
    );

    final notifier = notifierWith(api);
    final ok = await notifier.recharge(100, paymentMethod: 'mock');

    expect(ok, false);
    verify(() => api.confirmRechargeOrder('RCH_T1')).called(1);
  });

  test('RC-3 confirm 持续待支付 → 轮询到上限后失败', () async {
    when(
      () => api.createRechargeOrder(100, paymentMethod: 'mock'),
    ).thenAnswer((_) async => order());
    when(
      () => api.payRecharge('RCH_T1'),
    ).thenAnswer((_) async => <String, dynamic>{});
    when(() => api.confirmRechargeOrder('RCH_T1')).thenAnswer(
      (_) async => {
        'order_no': 'RCH_T1',
        'status': RechargeOrderStatus.pending,
      },
    );

    final notifier = notifierWith(api);
    final ok = await notifier.recharge(100, paymentMethod: 'mock');

    expect(ok, false);
    verify(() => api.confirmRechargeOrder('RCH_T1')).called(6);
  });
}
