import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FeedbackModel {
  int feedbackId;

  // String deviceId;
  // String clientOperatingSystem;
  // String clientOperatingSystemVsn;
  String appVsn;
  String type;
  String rating;
  String title;
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
    required this.title,
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
      rating: json['rating'],
      title: json['title'],
      body: json['body'],
      attach: json['attach'],
      replyCount: json['reply_count'],
      status: json['status'],
      updatedAt: json['updated_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['feedback_id'] = feedbackId;
    data['app_vsn'] = appVsn;
    data['type'] = type;
    data['rating'] = rating;
    data['title'] = title;
    data['body'] = body;
    data['attach'] = attach;
    data['reply_count'] = replyCount;
    data['status'] = status;
    data['updated_at'] = updatedAt;
    data['created_at'] = createdAt;
    return data;
  }

  get statusDesc {
    // 1 启用 (待回复）  2 已回复  3 已完结
    if (status == 1) {
      return '待回复'.tr;
    } else if (status == 2) {
      return '已回复'.tr;
    } else if (status == 3) {
      return '已完结'.tr;
    } else {
      return 'xx';
    }
  }

  get ratingIcon {
    late IconData icon;
    switch (rating) {
      case 'bad':
        icon = Icons.mood_bad; // 情绪不满的
        break;
      case 'neutral':
        icon = Icons.sentiment_neutral; // 情绪中立的
        break;
      case 'good':
        icon = Icons.mood; // 满意的
        break;
    }
    return icon;
  }
}
