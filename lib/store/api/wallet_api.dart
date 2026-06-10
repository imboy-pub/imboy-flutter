import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class WalletBalance {
  final int balance; // 余额（分）
  final double balanceYuan; // 余额（元）
  final int frozen; // 冻结金额（分）

  const WalletBalance({
    required this.balance,
    required this.balanceYuan,
    required this.frozen,
  });

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      balanceYuan: (json['balance_yuan'] as num?)?.toDouble() ?? 0.0,
      frozen: (json['frozen'] as num?)?.toInt() ?? 0,
    );
  }
}

class WalletApi extends HttpClient {
  /// 查询余额
  Future<WalletBalance?> getBalance() async {
    IMBoyHttpResponse resp = await get(API.walletBalance);
    if (kDebugMode) {}
    if (!resp.ok) {
      return null;
    }
    return WalletBalance.fromJson(resp.payload as Map<String, dynamic>);
  }

  /// 分页查询流水记录
  Future<Map<String, dynamic>?> getTransactions({
    int page = 1,
    int size = 10,
  }) async {
    IMBoyHttpResponse resp = await get(
      API.walletTransactions,
      queryParameters: {'page': page, 'size': size},
    );
    if (kDebugMode) {}
    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }

  /// 充值
  /// [amountFen] 充值金额（分），范围 100-1000000
  Future<bool> topup(int amountFen) async {
    IMBoyHttpResponse resp = await post(
      API.walletTopup,
      data: {'amount': amountFen},
    );
    if (kDebugMode) {}
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok;
  }
}
