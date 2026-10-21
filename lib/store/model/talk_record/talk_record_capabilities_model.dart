/// 面聊记录（talk_record）能力与创建上下文模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §4 GET /capabilities、§8 GET /creation-contexts、
/// GET /share-candidates、§11.4 首版能力清单与配额。能力关闭不能仅 UI
/// 禁用（§4）；秒/字节为服务器配置，运行中接近上限给保存提示（§11.4）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';

/// GET /capabilities 响应（§4 + §11.4）。
///
/// 服务器未给的键宽松缺省（0/空/false）；`raw` 保留原始 JSON 供后续
/// 字段对齐——本模型是 fixture 契约开发，实际键名以后端实施为准。
class TalkRecordCapabilitiesModel {
  final List<String> scopes;
  final List<String> languages;
  final int maxDurationMs;
  final int maxRecordingBytes;
  final int maxPartBytes;
  final int storageRemainingBytes;
  final bool processingAvailable;
  final int queueLimit;
  final String retentionPolicy;
  final String policyVersion;
  final String processorConfigVersion;

  /// 录音/ASR/summary/voice_id 是否启用；voice_id V1 恒 false 且无入口。
  final bool recordingEnabled;
  final bool asrEnabled;
  final bool summaryEnabled;
  final bool voiceIdEnabled;

  /// 处理器位置类别（§4：不返回密钥）。
  final String processorLocationCategory;
  final Map<String, dynamic> raw;

  const TalkRecordCapabilitiesModel({
    this.scopes = const [],
    this.languages = const [],
    this.maxDurationMs = 0,
    this.maxRecordingBytes = 0,
    this.maxPartBytes = 0,
    this.storageRemainingBytes = 0,
    this.processingAvailable = false,
    this.queueLimit = 0,
    this.retentionPolicy = '',
    this.policyVersion = '',
    this.processorConfigVersion = '',
    this.recordingEnabled = false,
    this.asrEnabled = false,
    this.summaryEnabled = false,
    this.voiceIdEnabled = false,
    this.processorLocationCategory = '',
    this.raw = const {},
  });

  factory TalkRecordCapabilitiesModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordCapabilitiesModel(
      scopes: _stringList(json['scopes']),
      languages: _stringList(json['languages']),
      maxDurationMs: parseModelInt(json['max_duration_ms']),
      maxRecordingBytes: parseModelInt(json['max_recording_bytes']),
      maxPartBytes: parseModelInt(json['max_part_bytes']),
      storageRemainingBytes: parseModelInt(json['storage_remaining_bytes']),
      processingAvailable: parseModelBool(json['processing_available']),
      queueLimit: parseModelInt(json['queue_limit']),
      retentionPolicy: parseModelString(json['retention_policy']),
      policyVersion: parseModelString(json['policy_version']),
      processorConfigVersion: parseModelString(
        json['processor_config_version'],
      ),
      recordingEnabled: parseModelBool(json['recording_enabled']),
      asrEnabled: parseModelBool(json['asr_enabled']),
      summaryEnabled: parseModelBool(json['summary_enabled']),
      voiceIdEnabled: parseModelBool(json['voice_id_enabled']),
      processorLocationCategory: parseModelString(
        json['processor_location_category'],
      ),
      raw: json,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList(growable: false);
  }

  /// §11.4：转写配额不足仅阻止处理，不误报录音丢失。
  bool get canProcess =>
      processingAvailable &&
      processorConfigVersion.isNotEmpty &&
      (asrEnabled || summaryEnabled);
}

/// GET /creation-contexts 列表元素（§8）。
///
/// 返回当前主体可创建的个人/企业/工作区集合与各自 capabilities、
/// retention_policy 摘要、processing_notice_version；不能传 org ID 获取
/// 未授权的工作区元数据。个人上下文 organization/workspace 均空。
class TalkRecordCreationContextModel {
  final TalkRecordScope scope;
  final EntityId organizationId;
  final EntityId workspaceId;

  /// 展示名（个人=「个人」/企业名/工作区名；可空由 UI 兜底）。
  final String displayName;
  final String retentionPolicy;
  final String processingNoticeVersion;
  final TalkRecordCapabilitiesForActorView capabilities;
  final Map<String, dynamic> raw;

  const TalkRecordCreationContextModel({
    this.scope = TalkRecordScope.unknown,
    this.organizationId = '',
    this.workspaceId = '',
    this.displayName = '',
    this.retentionPolicy = '',
    this.processingNoticeVersion = '',
    this.capabilities = const TalkRecordCapabilitiesForActorView(),
    this.raw = const {},
  });

  factory TalkRecordCreationContextModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordCreationContextModel(
      scope: TalkRecordScope.parse(json['scope']),
      organizationId: entityIdOf(json['organization_id']),
      workspaceId: entityIdOf(json['workspace_id']),
      displayName: parseModelString(json['display_name']).isEmpty
          ? parseModelString(json['name'])
          : parseModelString(json['display_name']),
      retentionPolicy: parseModelString(json['retention_policy']),
      processingNoticeVersion: parseModelString(
        json['processing_notice_version'],
      ),
      capabilities: TalkRecordCapabilitiesForActorView.fromJson(
        json['capabilities'],
      ),
      raw: json,
    );
  }

  /// 创建上下文键（scope+org+ws 的稳定组合）。
  String get contextKey => '${scope.wireName}:$organizationId:$workspaceId';
}

/// 创建上下文内的能力裁剪视图（§8：各自 capabilities）。
///
/// 具体键名未在契约中冻结（record/transcribe/summarize/export 组合），
/// 宽松解析常用 bool 并保留 raw。
class TalkRecordCapabilitiesForActorView {
  final bool record;
  final bool transcribe;
  final bool summarize;
  final bool exportAllowed;
  final Map<String, dynamic> raw;

  const TalkRecordCapabilitiesForActorView({
    this.record = false,
    this.transcribe = false,
    this.summarize = false,
    this.exportAllowed = false,
    this.raw = const {},
  });

  factory TalkRecordCapabilitiesForActorView.fromJson(dynamic value) {
    final json = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    return TalkRecordCapabilitiesForActorView(
      record: parseModelBool(json['record'], defaultValue: true),
      transcribe: parseModelBool(json['transcribe']),
      summarize: parseModelBool(json['summarize']),
      exportAllowed: parseModelBool(
        json['export'],
        defaultValue: parseModelBool(json['export_allowed']),
      ),
      raw: json,
    );
  }
}

/// share-candidates 响应元素（§8）：仅返回主体有权可见目录的最小信息；
/// 候选查询结果不是永久授权凭证（提交时重新验证）。
class TalkRecordShareCandidateModel {
  final EntityId userId;
  final String displayName;
  final String account;
  final String avatar;

  const TalkRecordShareCandidateModel({
    this.userId = '',
    this.displayName = '',
    this.account = '',
    this.avatar = '',
  });

  factory TalkRecordShareCandidateModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordShareCandidateModel(
      userId: entityIdOf(json['user_id']),
      displayName: parseModelString(json['display_name']).isEmpty
          ? parseModelString(json['nickname'])
          : parseModelString(json['display_name']),
      account: parseModelString(json['account']),
      avatar: parseModelString(json['avatar']),
    );
  }
}
