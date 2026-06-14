import 'package:imboy/store/model/model_parse_utils.dart';

/// 红包主模型 / Red Packet Model
class RedPacketModel {
  final String id;
  final int senderUid;
  final String type; // 'random' (拼手气) or 'fixed' (普通红包)
  final int amount; // 金额（分）
  final int count; // 红包个数
  final int remainAmount; // 剩余金额（分）
  final int remainCount; // 剩余个数
  final String greeting; // 祝福语
  final String status; // 'active' (可抢), 'finished' (抢光), 'expired' (已过期)
  final DateTime createdAt;
  final DateTime expiresAt;

  const RedPacketModel({
    required this.id,
    required this.senderUid,
    required this.type,
    required this.amount,
    required this.count,
    required this.remainAmount,
    required this.remainCount,
    required this.greeting,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isRandom => type == 'random';
  bool get isFixed => type == 'fixed';
  bool get isFinished => status == 'finished';
  bool get isExpired => status == 'expired';
  bool get isActive => status == 'active';
  double get amountYuan => amount / 100.0;
  double get remainAmountYuan => remainAmount / 100.0;

  factory RedPacketModel.fromJson(Map<String, dynamic> json) {
    return RedPacketModel(
      id: parseModelString(json['id']),
      senderUid: parseModelInt(json['sender_uid']),
      type: parseModelString(json['type'], defaultValue: 'fixed'),
      amount: parseModelInt(json['amount']),
      count: parseModelInt(json['count']),
      remainAmount: parseModelInt(json['remain_amount']),
      remainCount: parseModelInt(json['remain_count']),
      greeting: parseModelString(json['greeting'], defaultValue: '恭喜发财，大吉大利'),
      status: parseModelString(json['status'], defaultValue: 'active'),
      createdAt: parseModelDateTime(json['created_at']),
      expiresAt: parseModelDateTime(json['expires_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_uid': senderUid,
      'type': type,
      'amount': amount,
      'count': count,
      'remain_amount': remainAmount,
      'remain_count': remainCount,
      'greeting': greeting,
      'status': status,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
    };
  }
}

/// 红包领取明细模型 / Red Packet Receive Detail Model
class RedPacketReceiveModel {
  final int id;
  final String redPacketId;
  final int receiverUid;
  final int amount; // 领到的金额（分）
  final DateTime receivedAt;

  const RedPacketReceiveModel({
    required this.id,
    required this.redPacketId,
    required this.receiverUid,
    required this.amount,
    required this.receivedAt,
  });

  double get amountYuan => amount / 100.0;

  factory RedPacketReceiveModel.fromJson(Map<String, dynamic> json) {
    return RedPacketReceiveModel(
      id: parseModelInt(json['id']),
      redPacketId: parseModelString(json['red_packet_id']),
      receiverUid: parseModelInt(json['receiver_uid']),
      amount: parseModelInt(json['amount']),
      receivedAt: parseModelDateTime(json['received_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'red_packet_id': redPacketId,
      'receiver_uid': receiverUid,
      'amount': amount,
      'received_at': receivedAt.millisecondsSinceEpoch,
    };
  }
}
