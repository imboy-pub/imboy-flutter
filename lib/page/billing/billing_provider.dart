import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/service/payment_launcher.dart';
import 'package:imboy/store/api/billing_api.dart';

/// 套餐订阅 API 依赖注入（默认真实 [BillingApi]）。
///
/// 抽成 Provider 以便测试通过 `ProviderContainer(overrides: [...])` 注入
/// fake，使订阅编排（订阅 → 生成账单 → 支付 → 轮询）可脱离网络单测。
final billingApiProvider = Provider<BillingApi>((ref) {
  return BillingApi();
});

/// 第三方支付唤起器依赖注入（默认真实 fluwx/tobias 网关）。
///
/// 命名带 billing 前缀：channel_purchase_provider.dart 已有顶层
/// `paymentLauncherProvider`，同名顶层符号在同时 import 两个文件时会
/// 编译冲突，故本文件独立持有。
final billingPaymentLauncherProvider = Provider<PaymentLauncher>((ref) {
  return PaymentLauncher();
});

/// 套餐订阅页状态。
class BillingState {
  /// 套餐列表加载中
  final bool isLoading;

  /// 套餐列表加载失败信息（非 null 时页面渲染错误态）
  final String? error;

  /// 可售套餐列表
  final List<BillingPlan> plans;

  /// 当前订阅（null = 无订阅或未加载）
  final BillingSubscription? subscription;

  /// 订阅+支付编排进行中（防重复提交）
  final bool paying;

  /// 最近一次第三方支付唤起结果；mock 支付或未发起时为 `null`。
  final PaymentLaunchResult? lastLaunchResult;

  const BillingState({
    this.isLoading = false,
    this.error,
    this.plans = const [],
    this.subscription,
    this.paying = false,
    this.lastLaunchResult,
  });

  BillingState copyWith({
    bool? isLoading,
    String? error,
    List<BillingPlan>? plans,
    BillingSubscription? subscription,
    bool? paying,
    PaymentLaunchResult? lastLaunchResult,
  }) => BillingState(
    isLoading: isLoading ?? this.isLoading,
    error: error ?? this.error,
    plans: plans ?? this.plans,
    subscription: subscription ?? this.subscription,
    paying: paying ?? this.paying,
    lastLaunchResult: lastLaunchResult ?? this.lastLaunchResult,
  );
}

/// 套餐订阅 Notifier。
///
/// 闭环照搬钱包充值范式（[WalletNotifier.recharge] / ChannelPurchaseNotifier）：
/// 订阅 → 生成账单 → 取账单号 → 支付（mock 即时入账 / 第三方唤起收银台）
/// → 轮询账单入账 → 刷新当前订阅。
///
/// 契约差异（对 wallet）：后端 subscribe 只回 `subscription_id`，账单号
/// 须经 generate（幂等，只回 invoice_id）+ list 两步取得。
class BillingNotifier extends Notifier<BillingState> {
  late final BillingApi _api = ref.read(billingApiProvider);
  late final PaymentLauncher _launcher = ref.read(
    billingPaymentLauncherProvider,
  );

  @override
  BillingState build() => const BillingState();

  /// 加载套餐列表（页面下拉刷新/初始进入）。
  Future<void> loadPlans() async {
    state = state.copyWith(isLoading: true, error: null);
    final plans = await _api.fetchPlans();
    if (plans != null) {
      state = state.copyWith(isLoading: false, plans: plans);
    } else {
      state = state.copyWith(isLoading: false, error: 'load_failed');
    }
  }

  /// 加载当前订阅。
  Future<void> loadSubscription() async {
    final sub = await _api.fetchSubscription();
    state = state.copyWith(subscription: sub);
  }

  /// 订阅套餐并走完支付闭环。成功返回 `true`。
  ///
  /// [paymentMethod] 支付方式。`mock` 开发即时入账（后端白名单限制非生产）；
  /// `alipay`/`wechat` 走第三方收银台（fluwx/tobias）→ 回调入账后轮询命中。
  ///
  /// 第三方唤起结果记录在 [BillingState.lastLaunchResult]，UI 据此区分
  /// "已取消"与"即将开通"提示。
  Future<bool> subscribePlan(
    BillingPlan plan, {
    String paymentMethod = 'mock',
  }) async {
    if (state.paying) return false;
    // 重建 state 清空上一次唤起结果（copyWith 无法置回 null）
    state = BillingState(
      isLoading: state.isLoading,
      plans: state.plans,
      subscription: state.subscription,
      paying: true,
    );
    try {
      // 1. 订阅（后端只回 subscription_id，owner 由 JWT 决定）
      final subId = await _api.subscribe(plan.id);
      if (subId == null || subId <= 0) return false;

      // 2. 确保当前周期账单存在（幂等；generate 不回 invoice_no）
      if (!await _api.generateInvoice(subId)) return false;

      // 3. 从账单列表取待支付账单号
      final invoiceNo = await _pendingInvoiceNo(subId);
      if (invoiceNo == null) {
        // 无待支付账单（重复订阅且已付清）：视为成功，刷新订阅即可
        await loadSubscription();
        return true;
      }

      // 4. 支付（mock 即时入账；第三方返回参数供唤起收银台）
      final payResult = await _api.payInvoice(invoiceNo, paymentMethod);
      if (payResult == null) return false;

      // 5. 第三方：唤起原生收银台，取消/未配置则中止（不轮询）
      if (paymentMethod != 'mock' && paymentMethod != 'wallet') {
        final launched = await _launchThirdParty(paymentMethod, payResult);
        if (launched != PaymentLaunchResult.success &&
            launched != PaymentLaunchResult.failed) {
          return false;
        }
      }

      // 6. 轮询账单入账，成功后刷新当前订阅
      final paid = await _pollInvoicePaid(subId, invoiceNo);
      if (paid) {
        await loadSubscription();
      }
      return paid;
    } finally {
      state = state.copyWith(paying: false);
    }
  }

  /// 取订阅下第一张待支付账单号；全部已付返回 `null`。
  Future<String?> _pendingInvoiceNo(int subscriptionId) async {
    final invoices = await _api.listInvoices(subscriptionId);
    if (invoices == null) return null;
    for (final inv in invoices) {
      if (!inv.isPaid && inv.invoiceNo.isNotEmpty) return inv.invoiceNo;
    }
    return null;
  }

  /// 唤起第三方收银台并记录结果到 state。
  Future<PaymentLaunchResult> _launchThirdParty(
    String method,
    Map<String, dynamic> payResult,
  ) async {
    final payParams = payResult['pay_params'];
    final result = await _launcher.launch(
      method,
      payParams is Map ? payParams : const <dynamic, dynamic>{},
    );
    state = state.copyWith(lastLaunchResult: result);
    return result;
  }

  /// 轮询账单支付入账（模仿 wallet_provider._pollRechargeOrder）。
  ///
  /// 说明：原方案"轮询 subscription"，但后端 subscribe 即把订阅置为
  /// active（订阅状态与支付解耦），轮询订阅无法反映入账；账单 status
  /// 才是支付入账的权威信号，故轮询 invoice/list 中该账单的 paid 状态。
  /// 命中已支付返回 `true`；命中逾期终态或超时返回 `false`。
  Future<bool> _pollInvoicePaid(
    int subscriptionId,
    String invoiceNo, {
    int maxAttempts = 6,
    int intervalMs = 800,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final invoices = await _api.listInvoices(subscriptionId);
      if (invoices != null) {
        for (final inv in invoices) {
          if (inv.invoiceNo != invoiceNo) continue;
          if (inv.isPaid) return true;
          if (inv.status == BillingInvoiceStatus.overdue) return false;
          break; // 命中目标但未支付：等下一轮
        }
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: intervalMs));
      }
    }
    return false;
  }
}

final billingProvider = NotifierProvider<BillingNotifier, BillingState>(
  BillingNotifier.new,
);
