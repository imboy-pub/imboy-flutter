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

/// 充值订单状态
abstract class RechargeOrderStatus {
  static const int pending = 0; // 待支付
  static const int paid = 1; // 已支付（已入账）
  static const int cancelled = 2; // 已取消
  static const int expired = 3; // 已过期
  static const int failed = 4; // 支付失败
}

/// 充值订单模型
class RechargeOrder {
  final String orderNo;
  final int amount; // 充值金额（分）
  final int status;
  final String paymentMethod;

  const RechargeOrder({
    required this.orderNo,
    required this.amount,
    required this.status,
    required this.paymentMethod,
  });

  bool get isPaid => status == RechargeOrderStatus.paid;

  factory RechargeOrder.fromJson(Map<String, dynamic> json) {
    return RechargeOrder(
      orderNo: json['order_no']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? RechargeOrderStatus.pending,
      paymentMethod: json['payment_method']?.toString() ?? '',
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

  /// 充值（旧版 mock 内循环，保留以兼容回退）
  ///
  /// 真实链路请使用 [createRechargeOrder] + [payRecharge] + [getRechargeOrder]。
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

  /// 创建充值订单
  ///
  /// [amountFen] 充值金额（分），范围 100-1000000
  /// [paymentMethod] 支付方式：wechat / alipay / stripe（沙箱阶段后端即时入账）
  Future<RechargeOrder?> createRechargeOrder(
    int amountFen, {
    String paymentMethod = 'sandbox',
  }) async {
    IMBoyHttpResponse resp = await post(
      API.walletRechargeOrder,
      data: {'amount': amountFen, 'payment_method': paymentMethod},
    );
    if (!resp.ok || resp.payload == null) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    return RechargeOrder.fromJson(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
    );
  }

  /// 拉起充值支付
  ///
  /// 返回后端返回的支付参数（沙箱网关即时入账；真实环境为各支付 SDK 所需参数）。
  /// TODO(真机/真实SDK)：真实接入微信/支付宝/Stripe 时，需将返回的支付参数
  ///   交给对应 SDK（fluwx/tobias/flutter_stripe）唤起原生收银台，本方法仅负责
  ///   向后端请求支付参数。沙箱阶段后端即时置为已支付，无需 SDK。
  Future<Map<String, dynamic>?> payRecharge(String orderNo) async {
    IMBoyHttpResponse resp = await post(
      API.walletRechargePay,
      data: {'order_no': orderNo},
    );
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    if (resp.payload is Map) {
      return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
    }
    // payload 为空也视为成功（沙箱即时入账可能不返回参数）
    return <String, dynamic>{};
  }

  /// 查询充值订单状态
  Future<RechargeOrder?> getRechargeOrder(String orderNo) async {
    IMBoyHttpResponse resp = await get(API.walletRechargeOrderStatus(orderNo));
    if (!resp.ok || resp.payload == null) {
      return null;
    }
    return RechargeOrder.fromJson(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
    );
  }
}
