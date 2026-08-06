import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/wallet/wallet_provider.dart';

/// WalletState / WalletTransaction 纯不可变数据 + 派生逻辑单测。
///
/// WalletNotifier 依赖 WalletApi() 网络请求，不可测；仅覆盖纯内存部分。
void main() {
  group('WalletTransaction', () {
    test('WT-1 fromJson 解析与缺省回退', () {
      final tx = WalletTransaction.fromJson({
        'id': 12,
        'amount': -500,
        'tx_type': 2,
        'remark': '扣款',
        'created_at': '2026-01-01',
      });
      expect(tx.id, 12);
      expect(tx.amount, -500);
      expect(tx.txType, 2);
      expect(tx.remark, '扣款');
      expect(tx.createdAt, '2026-01-01');
    });

    test('WT-2 fromJson 空 json 全部走默认值', () {
      final tx = WalletTransaction.fromJson({});
      expect(tx.id, 0);
      expect(tx.amount, 0);
      expect(tx.txType, 0);
      expect(tx.remark, '');
      expect(tx.createdAt, '');
    });

    test('WT-3 isIncome 仅 txType==1 为真', () {
      const income = WalletTransaction(
        id: 1,
        amount: 100,
        txType: 1,
        remark: '',
        createdAt: '',
      );
      const expense = WalletTransaction(
        id: 2,
        amount: -100,
        txType: 2,
        remark: '',
        createdAt: '',
      );
      expect(income.isIncome, true);
      expect(expense.isIncome, false);
    });
  });

  group('WalletState', () {
    test('WS-1 默认值', () {
      const s = WalletState();
      expect(s.isLoading, false);
      expect(s.balance, 0);
      expect(s.error, isNull);
      expect(s.transactions, isEmpty);
      expect(s.isTxLoading, false);
      expect(s.txPage, 1);
      expect(s.txHasMore, true);
    });

    test('WS-2 copyWith 覆盖余额/分页且不可变', () {
      const s = WalletState();
      final s2 = s.copyWith(balance: 8888, txPage: 2, txHasMore: false);
      expect(s2.balance, 8888);
      expect(s2.txPage, 2);
      expect(s2.txHasMore, false);
      expect(s2.isLoading, false);
      // 原对象不变
      expect(s.balance, 0);
      expect(s.txPage, 1);
      expect(s.txHasMore, true);
    });

    test('WS-3 copyWith 不传参保留原值；error 用 ?? 无法清空', () {
      const s = WalletState(balance: 100, error: 'boom', isLoading: true);
      final s2 = s.copyWith();
      expect(s2.balance, 100);
      expect(s2.error, 'boom');
      expect(s2.isLoading, true);
    });
  });
}
