import 'dart:convert';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 反馈类型枚举
enum FeedbackType { bugReport, featureRequest }

/// IMBoy 反馈数据类
/// 用于构建反馈信息和计算评级描述
class IMBoyFeedback {
  IMBoyFeedback({
    this.feedbackType,
    this.feedbackText = '',
    this.rating = '3.0',
    this.contactDetail = '',
  });

  FeedbackType? feedbackType;
  String feedbackText;
  String rating;
  String contactDetail;

  @override
  String toString() {
    return {
      'rating': rating,
      'feedback_type': feedbackType.toString(),
      'feedback_text': feedbackText,
      'contact_detail': contactDetail,
    }.toString();
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rating': rating,
      'feedback_type': feedbackType.toString(),
      'feedback_text': feedbackText,
      'contact_detail': contactDetail,
    };
  }

  /// 获取评级描述
  String get ratingDesc {
    if (double.parse(rating) == 5.0) {
      return t.great;
    } else if (double.parse(rating) >= 4.0) {
      return t.good;
    } else if (double.parse(rating) >= 3.0) {
      return t.notBad;
    } else if (double.parse(rating) >= 2.0) {
      return t.needContinueWorkHard;
    } else {
      return t.tooBad;
    }
  }
}

class FeedbackModel {
  int feedbackId;

  // String deviceId;
  // String clientOperatingSystem;
  // String clientOperatingSystemVsn;
  String appVsn;

  //   bugReport,
  //   featureRequest,
  String type;
  String rating;
  String body;
  List<dynamic> attach;
  int replyCount;
  int status;
  int updatedAt;
  int createdAt;

  FeedbackModel({
    required this.feedbackId,
    // required this.deviceId,
    // required this.clientOperatingSystem,
    // required this.clientOperatingSystemVsn,
    required this.appVsn,
    required this.type,
    required this.rating,
    required this.body,
    required this.attach,
    required this.replyCount,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    var deviceVsn = json['device_vsn'] ?? '{}';
    try {
      deviceVsn = jsonDecode(deviceVsn);
    } catch (e) {
      deviceVsn = {};
    }
    return FeedbackModel(
      feedbackId: json['feedback_id'] ?? (json['id'] ?? 0),
      // deviceId: json['device_id'],
      // clientOperatingSystem: json['client_operating_system'],
      // clientOperatingSystemVsn: json['client_operating_system_vsn'],
      appVsn: json['app_vsn'],
      type: json['type'],
      rating: json['rating'].toString(),
      body: json['body'],
      attach: json['attach'] ?? [],
      replyCount: json['reply_count'],
      status: json['status'],
      updatedAt: DateTimeHelper.parseTimestamp(json['updated_at']),
      createdAt: DateTimeHelper.parseTimestamp(json['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['feedback_id'] = feedbackId;
    data['app_vsn'] = appVsn;
    data['type'] = type;
    data['rating'] = rating;
    data['body'] = body;
    data['attach'] = attach;
    data['reply_count'] = replyCount;
    data['status'] = status;
    data['updated_at'] = updatedAt;
    data['created_at'] = createdAt;
    return data;
  }

  String get statusDesc {
    // 1 启用 (待回复）  2 已回复  3 已完结
    if (status == 1) {
      return t.awaitingReply;
    } else if (status == 2) {
      return t.replied;
    } else if (status == 3) {
      return t.completed;
    } else {
      return '';
    }
  }

  // 评级描述
  String get ratingDesc {
    return IMBoyFeedback(rating: rating).ratingDesc;
  }
}
