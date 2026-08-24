import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/service/payment_launcher.dart';
import 'package:imboy/store/api/channel_order_api.dart';
import 'package:imboy/store/model/channel_order_model.dart';

/// 频道购买 API 依赖注入（默认真实 [ChannelOrderApi]）。
///
/// 抽成 Provider 以便测试通过 `ProviderContainer(overrides: [...])` 注入 fake，
/// 使购买编排逻辑（创建→支付→轮询）可在不依赖网络的情况下单测。
final channelOrderApiProvider = Provider<ChannelOrderApi>((ref) {
  return ChannelOrderApi();
});

/// 第三方支付唤起器依赖注入（默认真实 fluwx/tobias 网关）。
///
/// 抽成 Provider 以便测试注入 fake 网关，使第三方支付分支可在不依赖原生 SDK
/// 的情况下单测。
final paymentLauncherProvider = Provider<PaymentLauncher>((ref) {
  return PaymentLauncher();
});

/// 频道购买进行中标志 + 最近一次第三方唤起结果（供 UI 区分提示）。
class ChannelPurchaseState {
  final bool isPurchasing;

  /// 最近一次第三方支付唤起结果；钱包支付或未发起时为 `null`。
  final PaymentLaunchResult? lastLaunchResult;

  /// 轮询超时标志：SDK 成功但服务端回调未确认，用户应稍后查看订单。
  final bool isPollTimedOut;

  const ChannelPurchaseState({
    this.isPurchasing = false,
    this.lastLaunchResult,
    this.isPollTimedOut = false,
  });

  ChannelPurchaseState copyWith({
    bool? isPurchasing,
    PaymentLaunchResult? lastLaunchResult,
    bool? isPollTimedOut,
  }) => ChannelPurchaseState(
    isPurchasing: isPurchasing ?? this.isPurchasing,
    lastLaunchResult: lastLaunchResult ?? this.lastLaunchResult,
    isPollTimedOut: isPollTimedOut ?? this.isPollTimedOut,
  );
}

/// 频道购买 Notifier。
///
/// 闭环照搬钱包充值范式（[WalletNotifier.recharge]）：
/// 创建订单 → 支付（钱包余额即时扣款 / 第三方异步回调）→ 轮询订单状态
/// → 返回已支付订单。金额由后端按频道配置确定，前端不传价格。
class ChannelPurchaseNotifier extends Notifier<ChannelPurchaseState> {
  late final ChannelOrderApi _api = ref.read(channelOrderApiProvider);
  late final PaymentLauncher _launcher = ref.read(paymentLauncherProvider);

  @override
  ChannelPurchaseState build() => const ChannelPurchaseState();

  /// 购买频道。成功返回已支付订单，失败/取消/未配置返回 null。
  ///
  /// [paymentMethod] 支付方式。`wallet` 走钱包余额即时扣款；
  ///   `alipay`/`wechat` 走第三方收银台（fluwx/tobias）→ 回调入账后轮询命中。
  ///
  /// 第三方唤起结果记录在 [ChannelPurchaseState.lastLaunchResult]，UI 据此区分
  /// "已取消"与"即将开通"提示。
  Future<ChannelOrderModel?> purchase(
    String channelId, {
    String paymentMethod = 'wallet',
  }) async {
    if (state.isPurchasing) return null;
    state = const ChannelPurchaseState(isPurchasing: true);
    try {
      // 1. 创建订单（价格后端定）
      final order = await _api.createOrder(
        channelId,
        paymentMethod: paymentMethod,
      );
      if (order == null || order.orderNo.isEmpty) return null;

      // 2. 发起支付：钱包即时扣款；第三方返回 pay_params 供唤起收银台
      final payResult = await _api.payOrder(
        order.orderNo,
        paymentMethod: paymentMethod,
      );
      if (payResult == null) {
        await _cancelPendingOrder(order.orderNo);
        return null;
      }

      // 3. 第三方：唤起原生收银台，取消/未配置则中止（不轮询）
      if (paymentMethod != 'wallet') {
        final launched = await _launchThirdParty(paymentMethod, payResult);
        if (launched != PaymentLaunchResult.success &&
            launched != PaymentLaunchResult.failed) {
          await _cancelPendingOrder(order.orderNo);
          return null; // cancelled / notConfigured：不轮询
        }
      }

      // 4. 轮询订单状态，直到入账成功或终态/超时（回调入账后命中）。
      // 轮询拿到的 paid 订单就是权威结果，直接返回，避免再发一次
      // getOrder；否则支付已成功但第二次查询瞬时失败时，UI 会误报购买失败。
      return await _pollOrder(order.orderNo);
    } finally {
      state = state.copyWith(isPurchasing: false);
    }
  }

  /// 回收尚未支付的订单；失败不覆盖原始购买结果。
  Future<void> _cancelPendingOrder(String orderNo) async {
    try {
      await _api.cancelOrder(orderNo);
    } catch (_) {
      // 订单可能已被异步回调推进到已支付，取消失败不能改变前端结论。
    }
  }

  /// 唤起第三方收银台并记录结果到 state。
  Future<PaymentLaunchResult> _launchThirdParty(
    String method,
    Map<dynamic, dynamic> payResult,
  ) async {
    final payParams = payResult['pay_params'];
    final result = await _launcher.launch(
      method,
      payParams is Map ? payParams : const <dynamic, dynamic>{},
    );
    state = state.copyWith(lastLaunchResult: result);
    return result;
  }

  /// 轮询订单状态。
  ///
  /// 退避间隔 [1, 2, 3, 5, 8] 秒 = 19s 总窗口（替代固定 6×800ms=4.8s），
  /// 给支付宝回调留出合理的入账时间。超时后做一次最终查询，防止恰恰在
  /// 最后间隔入账的订单被错过。
  ///
  /// 命中已支付返回该订单；命中退款/取消/过期或超时返回 `null`。
  /// 超时同时设置 `isPollTimedOut = true` 供 UI 区分"等待回调"和"支付失败"。
  /// 钱包/模拟支付后端即时置为已支付，首轮即命中（无 delay）。
  Future<ChannelOrderModel?> _pollOrder(String orderNo) async {
    // ponytail: 固定退避序列，无需引入指数退避库。
    // 上限：19s 总窗口仍不够时，用户可手动刷新订单详情页确认。
    const intervals = [1000, 2000, 3000, 5000, 8000];
    for (var attempt = 0; attempt < intervals.length; attempt++) {
      final order = await _api.getOrder(orderNo);
      if (order != null) {
        if (order.status == ChannelOrderStatus.paid) return order;
        // 终态失败：无需继续轮询
        if (order.status == ChannelOrderStatus.refunded ||
            order.status == ChannelOrderStatus.cancelled ||
            order.status == ChannelOrderStatus.expired) {
          return null;
        }
      }
      if (attempt < intervals.length - 1) {
        await Future<void>.delayed(Duration(milliseconds: intervals[attempt]));
      }
    }

    // 超时：做一次最终查询，然后标记超时
    final lastOrder = await _api.getOrder(orderNo);
    if (lastOrder != null && lastOrder.status == ChannelOrderStatus.paid) {
      return lastOrder;
    }
    state = state.copyWith(isPollTimedOut: true);
    return null;
  }
}

final channelPurchaseProvider =
    NotifierProvider<ChannelPurchaseNotifier, ChannelPurchaseState>(
      ChannelPurchaseNotifier.new,
    );
