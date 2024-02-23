import 'package:get/get.dart';

class FeedbackReplyModel {
  int feedbackReplyId;
  int feedbackId;
  int feedbackReplyPid;
  int replierUserId;
  String replierName;
  String body;
  int status;
  int updatedAt;
  int createdAt;

  int get updatedAtLocal =>
      updatedAt + DateTime.now().timeZoneOffset.inMilliseconds;

  int get createdAtLocal =>
      createdAt + DateTime.now().timeZoneOffset.inMilliseconds;

  FeedbackReplyModel({
    this.feedbackReplyId = 0,
    required this.feedbackId,
    required this.feedbackReplyPid,
    required this.replierUserId,
    required this.replierName,
    required this.body,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
  });

  factory FeedbackReplyModel.fromJson(Map<String, dynamic> json) {
    return FeedbackReplyModel(
      feedbackReplyId: json['feedback_reply_id'] ?? (json['id'] ?? 0),
      feedbackId: json['feedback_id'],
      feedbackReplyPid: json['feedback_reply_pid'],
      replierUserId: json['replier_user_id'],
      replierName: json['replier_name'],
      body: json['body'],
      status: json['status'],
      updatedAt: json['updated_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['feedback_reply_id'] = feedbackReplyId;
    data['feedback_id'] = feedbackId;
    data['feedback_reply_pid'] = feedbackReplyPid;
    data['replier_user_id'] = replierUserId;
    data['replier_name'] = replierName;
    data['body'] = body;
    data['status'] = status;
    data['updated_at'] = updatedAt;
    data['created_at'] = createdAt;
    return data;
  }

  get statusDesc {
    // 状态: -1 删除  0 禁用  1 启用
    if (status == 1) {
      return 'enable'.tr;
    } else if (status == 0) {
      return 'disable'.tr;
    } else if (status == -1) {
      return 'button_delete'.tr;
    } else {
      return '';
    }
  }
}
