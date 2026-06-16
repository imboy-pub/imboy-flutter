import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/store/api/channel_order_api.dart';
import 'package:imboy/store/model/channel_order_model.dart';

/// 频道购买 API 依赖注入（默认真实 [ChannelOrderApi]）。
///
/// 抽成 Provider 以便测试通过 `ProviderContainer(overrides: [...])` 注入 fake，
/// 使购买编排逻辑（创建→支付→轮询）可在不依赖网络的情况下单测。
final channelOrderApiProvider = Provider<ChannelOrderApi>((ref) {
  return ChannelOrderApi();
});

/// 频道购买状态（仅一个进行中标志，UI loading 由调用方自行决定是否复用）。
class ChannelPurchaseState {
  final bool isPurchasing;

  const ChannelPurchaseState({this.isPurchasing = false});

  ChannelPurchaseState copyWith({bool? isPurchasing}) =>
      ChannelPurchaseState(isPurchasing: isPurchasing ?? this.isPurchasing);
}

/// 频道购买 Notifier。
///
/// 闭环照搬钱包充值范式（[WalletNotifier.recharge]）：
/// 创建订单 → 支付（钱包余额即时扣款 / 第三方异步回调）→ 轮询订单状态
/// → 返回已支付订单。金额由后端按频道配置确定，前端不传价格。
class ChannelPurchaseNotifier extends Notifier<ChannelPurchaseState> {
  late final ChannelOrderApi _api = ref.read(channelOrderApiProvider);

  @override
  ChannelPurchaseState build() => const ChannelPurchaseState();

  /// 购买频道。成功返回已支付订单，失败/取消返回 null。
  ///
  /// [paymentMethod] 支付方式。`wallet` 走钱包余额即时扣款；
  ///   `alipay`/`wechat` 等第三方需后端配置凭据并由回调入账（待 S4）。
  Future<ChannelOrderModel?> purchase(
    String channelId, {
    String paymentMethod = 'wallet',
  }) async {
    if (state.isPurchasing) return null;
    state = state.copyWith(isPurchasing: true);
    try {
      // 1. 创建订单（价格后端定）
      final order = await _api.createOrder(channelId);
      if (order == null || order.orderNo.isEmpty) return null;

      // 2. 发起支付（钱包即时扣款；第三方返回 SDK 参数，待 S4 唤起收银台）
      final payResult = await _api.payOrder(
        order.orderNo,
        paymentMethod: paymentMethod,
      );
      if (payResult == null) return null;

      // 3. 轮询订单状态，直到入账成功或终态/超时
      final paid = await _pollOrder(order.orderNo);
      if (!paid) return null;

      // 4. 返回最终已支付订单
      return await _api.getOrder(order.orderNo);
    } finally {
      state = state.copyWith(isPurchasing: false);
    }
  }

  /// 轮询订单状态。
  ///
  /// 最多轮询 [maxAttempts] 次，每次间隔 [intervalMs] 毫秒。
  /// 命中已支付返回 `true`；命中退款/取消/过期或超时返回 `false`。
  /// 钱包/模拟支付后端即时置为已支付，首轮即命中（无 delay）。
  Future<bool> _pollOrder(
    String orderNo, {
    int maxAttempts = 6,
    int intervalMs = 800,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final order = await _api.getOrder(orderNo);
      if (order != null) {
        if (order.status == ChannelOrderStatus.paid) return true;
        // 终态失败：无需继续轮询
        if (order.status == ChannelOrderStatus.refunded ||
            order.status == ChannelOrderStatus.cancelled ||
            order.status == ChannelOrderStatus.expired) {
          return false;
        }
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: intervalMs));
      }
    }
    return false;
  }
}

final channelPurchaseProvider =
    NotifierProvider<ChannelPurchaseNotifier, ChannelPurchaseState>(
      ChannelPurchaseNotifier.new,
    );
