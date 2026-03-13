import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

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
      feedbackReplyId: parseModelInt(json['feedback_reply_id'] ?? json['id']),
      feedbackId: parseModelInt(json['feedback_id']),
      feedbackReplyPid: parseModelInt(json['feedback_reply_pid']),
      replierUserId: parseModelInt(json['replier_user_id']),
      replierName: parseModelString(json['replier_name']),
      body: parseModelString(json['body']),
      status: parseModelInt(json['status']),
      updatedAt: DateTimeHelper.parseTimestamp(json['updated_at']),
      createdAt: DateTimeHelper.parseTimestamp(json['created_at']),
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

  String get statusDesc {
    // 状态: -1 删除  0 禁用  1 启用
    if (status == 1) {
      return t.enable;
    } else if (status == 0) {
      return t.disable;
    } else if (status == -1) {
      return t.buttonDelete;
    } else {
      return '';
    }
  }
}
