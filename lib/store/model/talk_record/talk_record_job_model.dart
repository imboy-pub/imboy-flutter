/// 面聊记录（talk_record）处理任务模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record_job + §4 jobs 端点（归一化错误码，
/// 不回传外部服务原始异常/秘钥）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';

class TalkRecordJobModel {
  final EntityId id;
  final EntityId recordId;
  final TalkRecordJobKind kind;
  final String inputVersion;
  final TalkRecordJobState state;
  final int attempt;
  final DateTime? retryAt;

  /// 归一化业务错误码（55xx 域；外部原始异常不出域）。
  final int? errorCode;
  final bool canRetry;
  final DateTime? createdAt;
  final DateTime? finishedAt;

  const TalkRecordJobModel({
    required this.id,
    this.recordId = '',
    this.kind = TalkRecordJobKind.unknown,
    this.inputVersion = '',
    this.state = TalkRecordJobState.unknown,
    this.attempt = 0,
    this.retryAt,
    this.errorCode,
    this.canRetry = false,
    this.createdAt,
    this.finishedAt,
  });

  factory TalkRecordJobModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordJobModel(
      id: entityIdOf(json['id']),
      recordId: entityIdOf(json['record_id']),
      kind: TalkRecordJobKind.parse(json['kind']),
      inputVersion: parseModelString(json['input_version']),
      state: TalkRecordJobState.parse(json['state']),
      attempt: parseModelInt(json['attempt']),
      retryAt: parseModelNullableDateTime(json['retry_at']),
      errorCode: parseModelNullableInt(json['error_code']),
      canRetry: parseModelBool(
        json['can_retry'],
        defaultValue: TalkRecordJobState.parse(json['state']).retryable,
      ),
      createdAt: parseModelNullableDateTime(json['created_at']),
      finishedAt: parseModelNullableDateTime(json['finished_at']),
    );
  }

  /// GET /:id/jobs 前台轮询的退避节奏（§6：2→5→10 秒；本地由调用方执行）。
  bool get needsPolling =>
      state == TalkRecordJobState.queued ||
      state == TalkRecordJobState.running ||
      state == TalkRecordJobState.retryWait;

  Map<String, dynamic> toJson() => {
    'id': id,
    'record_id': recordId,
    'kind': kind.wireName,
    'input_version': inputVersion,
    'state': state.wireName,
    'attempt': attempt,
    if (retryAt != null) 'retry_at': retryAt!.toIso8601String(),
    'error_code': errorCode,
    'can_retry': canRetry,
  };
}
