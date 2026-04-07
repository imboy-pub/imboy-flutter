import 'package:flutter/foundation.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';

/// 举报 API
class ReportApi extends HttpClient {
  /// 提交投诉举报
  /// [targetType] 类型: 'group'|'user'|'channel'|'moment'
  /// [targetId] 目标ID（群ID/用户ID等）
  /// [reason] 原因: 'spam'|'harassment'|'inappropriate'|'other'
  /// [description] 补充描述（可选）
  Future<bool> create({
    required String targetType,
    required String targetId,
    required String reason,
    String description = '',
  }) async {
    final resp = await post(
      API.reportCreate,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'description': description,
      },
    );
    debugPrint("> on ReportApi/create resp: ${resp.payload}");
    return resp.ok;
  }
}
