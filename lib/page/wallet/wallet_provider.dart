import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/payment_launcher.dart';
import 'package:imboy/store/api/wallet_api.dart';

class WalletTransaction {
  final int id;
  final int amount; // 金额（分），正数=收入，负数=支出（后端借记腿写负数）
  // 流水类型（后端 wallet_transaction.chk_wallet_tx_type 值域）：
  // 1充值 2充值退款 3订单退款 5转账转出 6转账转入 7发红包 8领红包
  // 9红包/转账退回 10提现 11提现退款 20 agent支付借记 21 agent支付贷记
  final int txType;
  final String remark;
  final String createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.txType,
    required this.remark,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      txType: (json['tx_type'] as num?)?.toInt() ?? 0,
      remark: json['remark']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  /// 收支判定以金额符号为准（权威：后端借记腿写负数、贷记腿写正数）。
  /// 此前按 txType==1 判定，把退款/转入/领红包/退回等正入账全部
  /// 误判为支出（tx_type 值域早已不止 1/2）。
  bool get isIncome => amount >= 0;
}

class WalletState {
  final bool isLoading;
  final int balance; // 余额（分）
  final String? error;
  final List<WalletTransaction> transactions;
  final bool isTxLoading;
  final int txPage;
  final bool txHasMore;

  /// 最近一次第三方充值唤起结果；钱包/mock 充值或未发起时为 `null`。
  final PaymentLaunchResult? lastLaunchResult;

  const WalletState({
    this.isLoading = false,
    this.balance = 0,
    this.error,
    this.transactions = const [],
    this.isTxLoading = false,
    this.txPage = 1,
    this.txHasMore = true,
    this.lastLaunchResult,
  });

  WalletState copyWith({
    bool? isLoading,
    int? balance,
    String? error,
    List<WalletTransaction>? transactions,
    bool? isTxLoading,
    int? txPage,
    bool? txHasMore,
    PaymentLaunchResult? lastLaunchResult,
  }) => WalletState(
    isLoading: isLoading ?? this.isLoading,
    balance: balance ?? this.balance,
    error: error ?? this.error,
    transactions: transactions ?? this.transactions,
    isTxLoading: isTxLoading ?? this.isTxLoading,
    txPage: txPage ?? this.txPage,
    txHasMore: txHasMore ?? this.txHasMore,
    lastLaunchResult: lastLaunchResult ?? this.lastLaunchResult,
  );
}

class WalletNotifier extends Notifier<WalletState> {
  final WalletApi _api;

  /// [api] 测试注入用；生产走默认构造。
  WalletNotifier({WalletApi? api}) : _api = api ?? WalletApi();
  PaymentLauncher _launcher = PaymentLauncher();

  /// 测试注入第三方支付唤起器（隔离原生 SDK）。
  // ignore: use_setters_to_change_properties
  void debugSetLauncher(PaymentLauncher launcher) => _launcher = launcher;

  @override
  WalletState build() {
    return const WalletState();
  }

  /// 加载余额
  Future<void> loadBalance() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _api.getBalance();
    if (result != null) {
      state = state.copyWith(isLoading: false, balance: result.balance);
    } else {
      state = state.copyWith(isLoading: false, error: '加载失败');
    }
  }

  /// 加载第一页流水记录（刷新）
  Future<void> loadTransactions() async {
    if (state.isTxLoading) return;
    state = state.copyWith(isTxLoading: true, txPage: 1, transactions: []);
    await _loadTxPage(1, reset: true);
  }

  /// 加载更多流水记录
  Future<void> loadMoreTransactions() async {
    if (state.isTxLoading || !state.txHasMore) return;
    state = state.copyWith(isTxLoading: true);
    await _loadTxPage(state.txPage + 1, reset: false);
  }

  Future<void> _loadTxPage(int page, {required bool reset}) async {
    final result = await _api.getTransactions(page: page, size: 20);
    if (result == null) {
      state = state.copyWith(isTxLoading: false);
      return;
    }

    final rawList = result['list'] as List<dynamic>? ?? [];
    final newTxs = rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => WalletTransaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (result['total'] as num?)?.toInt() ?? 0;

    final allTxs = reset ? newTxs : [...state.transactions, ...newTxs];
    state = state.copyWith(
      isTxLoading: false,
      transactions: allTxs,
      txPage: page,
      txHasMore: allTxs.length < total,
    );
  }

  /// 充值（旧版 mock，保留以兼容回退）
  Future<bool> topup(int amountFen) async {
    state = state.copyWith(isLoading: true, error: null);
    final ok = await _api.topup(amountFen);
    if (ok) {
      await loadBalance();
      // 充值后刷新流水
      await loadTransactions();
    } else {
      state = state.copyWith(isLoading: false);
    }
    return ok;
  }

  /// 充值真实链路：创建订单 → 拉起支付 → 轮询订单状态 → 刷新余额。
  ///
  /// 沙箱阶段后端在 [WalletApi.payRecharge] 处即时入账，因此轮询通常首次即命中
  /// 已支付。真实接入支付 SDK 后，支付为异步过程，轮询用于等待回调入账。
  ///
  /// [amountFen] 充值金额（分）
  /// [paymentMethod] 支付方式。开发联调默认 `mock`（后端即时入账，须与后端
  ///   非生产白名单一致）；生产由调用方显式传 `alipay`/`wechat`/`stripe`。
  /// 返回 `true` 表示充值已入账成功。
  Future<bool> recharge(int amountFen, {String paymentMethod = 'mock'}) async {
    // 重置上一次唤起结果（const 重建以清空 lastLaunchResult）
    state = const WalletState().copyWith(
      balance: state.balance,
      transactions: state.transactions,
      txPage: state.txPage,
      txHasMore: state.txHasMore,
      isLoading: true,
    );

    // 1. 创建充值订单
    final order = await _api.createRechargeOrder(
      amountFen,
      paymentMethod: paymentMethod,
    );
    if (order == null || order.orderNo.isEmpty) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    // 2. 拉起支付（mock 网关即时入账；第三方返回 pay_params 供唤起收银台）
    final payParams = await _api.payRecharge(order.orderNo);
    if (payParams == null) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    // 3. 第三方：唤起原生收银台（fluwx/tobias），取消/未配置则中止（不轮询）
    if (paymentMethod != 'mock' && paymentMethod != 'wallet') {
      final launched = await _launchThirdParty(paymentMethod, payParams);
      if (launched != PaymentLaunchResult.success &&
          launched != PaymentLaunchResult.failed) {
        state = state.copyWith(isLoading: false);
        return false; // cancelled / notConfigured：不轮询
      }
    }

    // 4. 轮询订单状态，直到入账成功或超时（回调入账后命中）
    final paid = await _pollRechargeOrder(order.orderNo);

    // 5. 刷新余额与流水
    if (paid) {
      await loadBalance();
      await loadTransactions();
    } else {
      state = state.copyWith(isLoading: false);
    }
    return paid;
  }

  /// 唤起第三方收银台并记录结果到 state。
  Future<PaymentLaunchResult> _launchThirdParty(
    String method,
    Map<dynamic, dynamic> payParams,
  ) async {
    final params = payParams['pay_params'];
    final result = await _launcher.launch(
      method,
      params is Map ? params : const <dynamic, dynamic>{},
    );
    state = state.copyWith(lastLaunchResult: result);
    return result;
  }

  /// 轮询确认充值订单（主动查单）。
  ///
  /// 每轮调 confirm：服务端向网关查单（alipay.trade.query），已付款则
  /// 幂等入账——异步回调（notify）丢失时仅靠被动查询订单会永远待支付。
  /// 最多轮询 [maxAttempts] 次，每次间隔 [intervalMs] 毫秒。
  /// 命中已支付返回 `true`；命中取消/退款/过期等终态或超时返回 `false`。
  Future<bool> _pollRechargeOrder(
    String orderNo, {
    int maxAttempts = 6,
    int intervalMs = 800,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final result = await _api.confirmRechargeOrder(orderNo);
      if (result != null) {
        final status =
            (result['status'] as num?)?.toInt() ?? RechargeOrderStatus.pending;
        if (status == RechargeOrderStatus.paid) return true;
        // 终态：取消/退款/过期，均无需继续轮询
        // （2026-08-20 对齐后端枚举：3=已退款、4=已过期，此前 3/4 含义颠倒）
        if (status == RechargeOrderStatus.cancelled ||
            status == RechargeOrderStatus.refunded ||
            status == RechargeOrderStatus.expired) {
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

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(
  WalletNotifier.new,
);
