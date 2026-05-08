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
        .whereType<Map>()
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

  /// 充值
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
}

final walletProvider = NotifierProvider<WalletNotifier, WalletState>(
  WalletNotifier.new,
);
