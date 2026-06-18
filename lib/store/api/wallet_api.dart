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
  /// [paymentMethod] 支付方式：mock（开发联调，后端即时入账）/ alipay / wechat
  ///   / stripe。必须与后端 recharge_logic 白名单一致，禁止传 `sandbox`。
  Future<RechargeOrder?> createRechargeOrder(
    int amountFen, {
    String paymentMethod = 'mock',
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
  /// 本方法仅负责向后端请求支付参数。SDK 唤起（fluwx/tobias）由
  /// PaymentLauncher.launch() 负责；沙箱阶段后端即时置为已支付，无需 SDK。
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

  /// 发送红包
  /// [amount] 总金额（分）
  /// [count] 红包个数
  /// [type] random (拼手气), fixed (普通红包)
  /// [greeting] 祝福语
  /// 返回 新建红包ID (String) 或 null
  Future<String?> sendRedPacket({
    required int amount,
    required int count,
    String type = 'fixed',
    String greeting = '恭喜发财，大吉大利',
  }) async {
    IMBoyHttpResponse resp = await post(
      API.walletRedPacketSend,
      data: {
        'amount': amount,
        'count': count,
        'type': type,
        'greeting': greeting,
      },
    );
    if (!resp.ok || resp.payload == null) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    return resp.payload['red_packet_id']?.toString();
  }

  /// 抢红包 / 拆红包
  /// 返回抢到的金额（分）或 null
  Future<int?> openRedPacket(String packetId) async {
    IMBoyHttpResponse resp = await post(
      API.walletRedPacketOpen,
      data: {'red_packet_id': packetId},
    );
    if (!resp.ok || resp.payload == null) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    return (resp.payload['grab_amount'] as num?)?.toInt();
  }

  /// 查询红包领取详情
  Future<Map<String, dynamic>?> getRedPacketDetail(String packetId) async {
    IMBoyHttpResponse resp = await get(API.walletRedPacketDetail(packetId));
    if (!resp.ok || resp.payload == null) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
  }

  /// 发起单聊转账
  /// [receiverUid] 接收者 UID
  /// [amount] 金额（分）
  /// [remark] 转账说明备注
  Future<String?> sendTransfer({
    required String receiverUid,
    required int amount,
    String remark = '转账给好友',
  }) async {
    IMBoyHttpResponse resp = await post(
      API.walletTransferSend,
      data: {'receiver_uid': receiverUid, 'amount': amount, 'remark': remark},
    );
    if (!resp.ok || resp.payload == null) {
      EasyLoading.showError(resp.msg);
      return null;
    }
    return resp.payload['transfer_id']?.toString();
  }

  /// 收取转账
  Future<bool> acceptTransfer(String transferId) async {
    IMBoyHttpResponse resp = await post(
      API.walletTransferAccept,
      data: {'transfer_id': transferId},
    );
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok;
  }

  /// 提现至支付宝/微信
  Future<bool> withdraw({
    required int amount,
    required String method, // alipay / wechat
    required String account, // 支付宝/微信账号
  }) async {
    IMBoyHttpResponse resp = await post(
      API.walletWithdraw,
      data: {'amount': amount, 'payment_method': method, 'account': account},
    );
    if (!resp.ok) {
      EasyLoading.showError(resp.msg);
    }
    return resp.ok;
  }
}
