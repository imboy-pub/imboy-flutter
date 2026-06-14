import 'package:imboy/store/model/model_parse_utils.dart';

/// 单聊转账订单模型 / P2P Transfer Model
class TransferModel {
  final String id;
  final int senderUid;
  final int receiverUid;
  final int amount; // 金额（分）
  final String remark; // 备注
  final String status; // 'pending' (待收款), 'accepted' (已收取), 'refunded' (已退回)
  final DateTime createdAt;
  final DateTime? completedAt;

  const TransferModel({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    required this.amount,
    required this.remark,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRefunded => status == 'refunded';
  double get amountYuan => amount / 100.0;

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: parseModelString(json['id']),
      senderUid: parseModelInt(json['sender_uid']),
      receiverUid: parseModelInt(json['receiver_uid']),
      amount: parseModelInt(json['amount']),
      remark: parseModelString(json['remark'], defaultValue: '转账给好友'),
      status: parseModelString(json['status'], defaultValue: 'pending'),
      createdAt: parseModelDateTime(json['created_at']),
      completedAt: parseModelNullableDateTime(json['completed_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_uid': senderUid,
      'receiver_uid': receiverUid,
      'amount': amount,
      'remark': remark,
      'status': status,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
  }
}
