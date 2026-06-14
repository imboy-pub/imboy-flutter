import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/api/wallet_api.dart';

class WalletTransaction {
  final int id;
  final int amount; // 金额（分），正数=收入，负数=支出
  final int txType; // 1=topup, 2=deduct
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

  bool get isIncome => txType == 1;
}

class WalletState {
  final bool isLoading;
  final int balance; // 余额（分）
  final String? error;
  final List<WalletTransaction> transactions;
  final bool isTxLoading;
  final int txPage;
  final bool txHasMore;

  const WalletState({
    this.isLoading = false,
    this.balance = 0,
    this.error,
    this.transactions = const [],
    this.isTxLoading = false,
    this.txPage = 1,
    this.txHasMore = true,
  });

  WalletState copyWith({
    bool? isLoading,
    int? balance,
    String? error,
    List<WalletTransaction>? transactions,
    bool? isTxLoading,
    int? txPage,
    bool? txHasMore,
  }) => WalletState(
    isLoading: isLoading ?? this.isLoading,
    balance: balance ?? this.balance,
    error: error ?? this.error,
    transactions: transactions ?? this.transactions,
    isTxLoading: isTxLoading ?? this.isTxLoading,
    txPage: txPage ?? this.txPage,
    txHasMore: txHasMore ?? this.txHasMore,
  );
}

class WalletNotifier extends Notifier<WalletState> {
  final _api = WalletApi();

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
  /// [paymentMethod] 支付方式（沙箱默认 sandbox）
  /// 返回 `true` 表示充值已入账成功。
  Future<bool> recharge(
    int amountFen, {
    String paymentMethod = 'sandbox',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    // 1. 创建充值订单
    final order = await _api.createRechargeOrder(
      amountFen,
      paymentMethod: paymentMethod,
    );
    if (order == null || order.orderNo.isEmpty) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    // 2. 拉起支付（沙箱网关即时入账；真实环境返回 SDK 参数）
    // TODO(真机/真实SDK)：真实接入时，用 payParams 唤起对应支付 SDK 原生收银台，
    //   待用户完成支付后再进入轮询；沙箱阶段后端在此即置为已支付。
    final payParams = await _api.payRecharge(order.orderNo);
    if (payParams == null) {
      state = state.copyWith(isLoading: false);
      return false;
    }

    // 3. 轮询订单状态，直到入账成功或超时
    final paid = await _pollRechargeOrder(order.orderNo);

    // 4. 刷新余额与流水
    if (paid) {
      await loadBalance();
      await loadTransactions();
    } else {
      state = state.copyWith(isLoading: false);
    }
    return paid;
  }

  /// 轮询充值订单状态。
  ///
  /// 最多轮询 [maxAttempts] 次，每次间隔 [intervalMs] 毫秒。
  /// 命中已支付返回 `true`；命中失败/取消/过期或超时返回 `false`。
  Future<bool> _pollRechargeOrder(
    String orderNo, {
    int maxAttempts = 6,
    int intervalMs = 800,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final order = await _api.getRechargeOrder(orderNo);
      if (order != null) {
        if (order.isPaid) return true;
        // 终态失败：无需继续轮询
        if (order.status == RechargeOrderStatus.failed ||
            order.status == RechargeOrderStatus.cancelled ||
            order.status == RechargeOrderStatus.expired) {
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
