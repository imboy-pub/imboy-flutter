/// 面聊记录（talk_record）说话人模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record_speaker（UNIQUE(record_id,
/// local_label)；不暴露 voice embedding）+ §4 speakers 端点。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';

class TalkRecordSpeakerModel {
  final EntityId id;
  final EntityId recordId;

  /// 自动分配的匿名标签（如「说话人 1」）。
  final String localLabel;

  /// 人工命名/认领后的展示名。
  final String displayName;
  final EntityId matchedUserId;
  final TalkRecordSpeakerIdentitySource identitySource;
  final EntityId confirmedBy;

  /// 声纹建议置信度 [0,1]；仅建议来源可能有值（§1 自动建议不得直接变确认）。
  final double? confidence;
  final int revision;

  const TalkRecordSpeakerModel({
    required this.id,
    this.recordId = '',
    this.localLabel = '',
    this.displayName = '',
    this.matchedUserId = '',
    this.identitySource = TalkRecordSpeakerIdentitySource.unknown,
    this.confirmedBy = '',
    this.confidence,
    this.revision = 1,
  });

  factory TalkRecordSpeakerModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordSpeakerModel(
      id: entityIdOf(json['id']),
      recordId: entityIdOf(json['record_id']),
      localLabel: parseModelString(json['local_label']),
      displayName: parseModelString(json['display_name']),
      matchedUserId: entityIdOf(json['matched_user_id']),
      identitySource: TalkRecordSpeakerIdentitySource.parse(
        json['identity_source'],
      ),
      confirmedBy: entityIdOf(json['confirmed_by']),
      confidence: _parseConfidence(json['confidence']),
      revision: parseModelInt(json['revision'], defaultValue: 1),
    );
  }

  /// 宽松置信度解析：非 num/数字串一律 null（不伪造 0.0 精确值，§11.2）。
  static double? _parseConfidence(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String && value.isNotEmpty) return double.tryParse(value);
    return null;
  }

  bool get isClaimed =>
      matchedUserId.isNotEmpty &&
      identitySource != TalkRecordSpeakerIdentitySource.anonymous;

  Map<String, dynamic> toJson() => {
    'id': id,
    'record_id': recordId,
    'local_label': localLabel,
    'display_name': displayName,
    'matched_user_id': matchedUserId,
    'identity_source': identitySource.wireName,
    'confirmed_by': confirmedBy,
    'confidence': confidence,
    'revision': revision,
  };
}
