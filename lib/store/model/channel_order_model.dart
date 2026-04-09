import 'package:imboy/store/model/model_parse_utils.dart';

/// 频道订单模型（付费频道）
class ChannelOrderModel {
  final int id;
  final int channelId;
  final int userId;
  final String orderNo;
  final double amount;
  final String currency;
  final int status;
  final String paymentMethod;
  final String? paymentNo;
  final DateTime? paymentAt;
  final DateTime? subscriptionStartAt;
  final DateTime? subscriptionEndAt;
  final DateTime? expiresAt;
  final String? refundReason;
  final DateTime? refundAt;
  final Map<String, dynamic>? extraData;
  final String? channelName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChannelOrderModel({
    required this.id,
    required this.channelId,
    required this.userId,
    required this.orderNo,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    this.paymentNo,
    this.paymentAt,
    this.subscriptionStartAt,
    this.subscriptionEndAt,
    this.expiresAt,
    this.refundReason,
    this.refundAt,
    this.extraData,
    this.channelName,
    required this.createdAt,
    this.updatedAt,
  });

  factory ChannelOrderModel.fromJson(Map<String, dynamic> json) {
    return ChannelOrderModel(
      id: parseModelInt(json['id']),
      channelId: parseModelInt(json['channel_id']),
      userId: parseModelInt(json['user_id']),
      orderNo: parseModelString(json['order_no']),
      amount: parseModelDouble(json['amount']),
      currency: parseModelString(json['currency'], defaultValue: 'CNY'),
      status: parseModelInt(json['status']),
      paymentMethod: parseModelString(
        json['payment_method'],
        defaultValue: 'unknown',
      ),
      paymentNo: parseModelNullableString(json['payment_no']),
      paymentAt: parseModelNullableDateTime(json['payment_at']),
      subscriptionStartAt: parseModelNullableDateTime(
        json['subscription_start_at'],
      ),
      subscriptionEndAt: parseModelNullableDateTime(
        json['subscription_end_at'],
      ),
      expiresAt: parseModelNullableDateTime(json['expires_at']),
      refundReason: parseModelNullableString(json['refund_reason']),
      refundAt: parseModelNullableDateTime(json['refund_at']),
      extraData: parseModelJsonMap(json['extra_data']),
      channelName: parseModelNullableString(json['channel_name']),
      createdAt: parseModelDateTime(json['created_at']),
      updatedAt: parseModelNullableDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channel_id': channelId,
      'user_id': userId,
      'order_no': orderNo,
      'amount': amount,
      'currency': currency,
      'status': status,
      'payment_method': paymentMethod,
      'payment_no': paymentNo,
      'payment_at': paymentAt?.millisecondsSinceEpoch,
      'subscription_start_at': subscriptionStartAt?.millisecondsSinceEpoch,
      'subscription_end_at': subscriptionEndAt?.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'refund_reason': refundReason,
      'refund_at': refundAt?.millisecondsSinceEpoch,
      'extra_data': extraData,
      'channel_name': channelName,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }
}

/// 频道订单状态
abstract class ChannelOrderStatus {
  static const int pending = 0;
  static const int paid = 1;
  static const int refunded = 2;
  static const int cancelled = 3;
  static const int expired = 4;
}
