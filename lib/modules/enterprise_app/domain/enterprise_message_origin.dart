/// 企业托管消息的「真实 Application origin」事实层（FULL-05 / plan-full §3.3、§7）。
///
/// 后端真源：`enterprise_message_origin`（migration 00000140）+ 消息 payload 的
/// 顶层 `origin` 结构（`enterprise_message_logic:origin/3`）。字段与语义逐条对齐：
///
/// | wire 字段            | 语义 |
/// |----------------------|------|
/// | `origin.kind`        | 恒 `enterprise_application`（企业托管固定值） |
/// | `origin.application_id` | 真实 Application origin（**永不 NULL**） |
/// | `origin.sender_kind` | `application`（应用代发）/ `human`（应用代同组织已映射 Human 发送） |
/// | `origin.sender_user_id` | 仅 `sender_kind=human` 存在（DB CHECK 强制双痕迹一致） |
///
/// 三条硬边界（本文件是它们唯一的判定点，UI 不得自行解释）：
///
/// 1. **不得伪装成普通 Human E2EE 消息**：只要 `origin.kind` 是企业托管值，
///    该消息**恒**归类为企业托管、**恒**非 E2EE——即便同时出现 e2ee 载荷
///    （那是不一致状态，[HostedMessageFacts.originContradictsE2ee] 如实标记，
///    而不是把消息降级成「Human 直发的加密消息」）。INV-6：OA-origin 消息
///    永久非 E2EE，Human-Human E2EE 路径不受影响。
/// 2. **「Application 代发」与「Human 直发」可区分**：前者
///    [HostedMessageClass.applicationDelegated]，后者
///    [HostedMessageClass.humanDirect]——两者在枚举层就不同值，任何展示面
///    都必须能区分，且判定只经本文件的纯函数。
/// 3. **失败不伪造**：`origin` 缺失但形态可疑（例如存在 `kind` 却不认识）时
///    归 [HostedMessageClass.enterpriseOriginUnrecognized]，**不**回落成
///    humanDirect（回落等于把企业托管消息洗成普通消息）。
///
/// 纯 Dart（零 Flutter / 零 IO），可被单测直接驱动。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

export 'package:imboy/store/model/workspace_model.dart'
    show EntityId, entityIdOf;

/// 企业托管消息的 sender 痕迹类型。
///
/// 与后端 `enterprise_message_origin.sender_kind` CHECK 的两个取值逐字对齐。
enum HostedSenderKind {
  /// 应用直接代发（无 Human sender）。
  application('application'),

  /// 应用代同组织已映射 active Human 发送（名义 sender 是人）。
  human('human');

  final String wireName;

  const HostedSenderKind(this.wireName);

  static HostedSenderKind? tryParse(dynamic raw) {
    final String s = raw is String ? raw : raw?.toString() ?? '';
    for (final HostedSenderKind kind in HostedSenderKind.values) {
      if (kind.wireName == s) return kind;
    }
    return null;
  }
}

/// 消息来源分类（UI 区分「Application 代发 / Human 经应用 / Human 直发」的唯一枚举）。
enum HostedMessageClass {
  /// 无企业来源：普通 Human-Human（或 Human-群）消息。
  humanDirect('humanDirect'),

  /// 企业托管 + `sender_kind=application`：**Application 代发**。
  applicationDelegated('applicationDelegated'),

  /// 企业托管 + `sender_kind=human`：应用代已映射 Human 发送。
  humanDelegated('humanDelegated'),

  /// 存在来源结构但无法识别为企业托管（形态不符 / kind 不匹配）。
  /// fail-closed：不回落 humanDirect。
  enterpriseOriginUnrecognized('enterpriseOriginUnrecognized');

  final String wireName;

  const HostedMessageClass(this.wireName);

  /// 是否企业托管（后两者不是）。
  bool get isEnterpriseHosted =>
      this == HostedMessageClass.applicationDelegated ||
      this == HostedMessageClass.humanDelegated;
}

/// 企业托管消息的 Application origin（payload 顶层 `origin` 的结构化形态）。
class EnterpriseMessageOrigin {
  const EnterpriseMessageOrigin({
    required this.kind,
    required this.applicationId,
    required this.senderKind,
    this.senderUserId = '',
    this.rawSenderKind = '',
  });

  /// 企业托管 origin 的固定 kind 值（与后端 `?ORIGIN_KIND` 同源）。
  static const String wireKind = 'enterprise_application';

  final String kind;
  final EntityId applicationId;
  final HostedSenderKind senderKind;

  /// 仅 `sender_kind=human` 有值（企业托管 Human 痕迹）。
  final EntityId senderUserId;

  /// 服务端原样下发的 `sender_kind` 字面量（未识别时为未知值）。
  ///
  /// 保留原值是为了让 [senderKindKnown] 成为**真判定**而不是枚举自证。
  final String rawSenderKind;

  /// 形态是否自洽：kind 匹配 + application_id 非空 + human 必带 sender_user_id
  /// + sender_kind 在枚举内。
  ///
  /// 与 migration 00000140 的 `ck_emo_human_sender`
  /// （`(sender_kind='human') = (sender_user_id IS NOT NULL)`）同语义。
  bool get isWellFormed =>
      kind == wireKind &&
      applicationId.isNotEmpty &&
      senderKindKnown &&
      (senderKind != HostedSenderKind.human || senderUserId.isNotEmpty);

  /// 服务端 `sender_kind` 是否落在枚举内（未知 → false，展示层提示形态异常）。
  bool get senderKindKnown => HostedSenderKind.tryParse(rawSenderKind) != null;

  /// 从 payload 的 `origin` 值解析；不是企业托管 origin 时返回 null。
  ///
  /// 「存在 kind 但不等于企业托管值」→ 返回 null，由调用方经
  /// [resolveHostedMessageFacts] 归入 unrecognized（不静默当普通消息）。
  static EnterpriseMessageOrigin? tryParse(dynamic raw) {
    final Map<String, dynamic>? map = _asMap(raw);
    if (map == null) return null;
    final String kind = parseModelString(map['kind']);
    if (kind != wireKind) return null;
    final String rawSenderKind = parseModelString(map['sender_kind']);
    final HostedSenderKind? senderKind = HostedSenderKind.tryParse(
      rawSenderKind,
    );
    return EnterpriseMessageOrigin(
      kind: kind,
      applicationId: entityIdOf(map['application_id']),
      // 未知 sender_kind 归 application（后端 `sender_kind_atom/1` 同款兜底）；
      // 是否自洽由 isWellFormed / senderKindKnown 另行如实表达。
      senderKind: senderKind ?? HostedSenderKind.application,
      senderUserId: entityIdOf(map['sender_user_id']),
      rawSenderKind: rawSenderKind,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind,
    'application_id': applicationId,
    'sender_kind': senderKind.wireName,
    if (senderUserId.isNotEmpty) 'sender_user_id': senderUserId,
  };
}

/// 消息来源事实（UI 唯一数据源）。
class HostedMessageFacts {
  const HostedMessageFacts({
    required this.messageClass,
    required this.hasE2eePayload,
    required this.originContradictsE2ee,
    this.origin,
    this.senderDisplayName = '',
  });

  final HostedMessageClass messageClass;

  /// 消息是否带 e2ee 载荷（Human-Human E2EE 路径的正常形态）。
  final bool hasE2eePayload;

  /// **不一致标记**：企业托管 origin 与 e2ee 载荷同时存在。
  ///
  /// 真值时仍按企业托管（非 E2EE）展示——不因载荷存在就改判成加密消息；
  /// UI 用 [HostedMessageFacts.needsDualTraceWarning] 提示，不静默吞掉。
  final bool originContradictsE2ee;

  final EnterpriseMessageOrigin? origin;

  /// 消息主视图的 sender 展示名（Human 代发时为该 Human 显示名）。
  final String senderDisplayName;

  bool get isEnterpriseHosted => messageClass.isEnterpriseHosted;

  /// 是否「Application 代发」（应用直接代发，无 Human sender 名义）。
  bool get isApplicationDelegated =>
      messageClass == HostedMessageClass.applicationDelegated;

  /// 是否「Human 经应用发送」（名义 sender 是已映射 Human）。
  bool get isHumanDelegated =>
      messageClass == HostedMessageClass.humanDelegated;

  /// 是否普通 Human 直发（非企业托管）。
  bool get isHumanDirect => messageClass == HostedMessageClass.humanDirect;

  /// **非 E2EE 事实**：企业托管消息恒真；否则等于「没有 e2ee 载荷」。
  ///
  /// 企业托管分支**先于** e2ee 判断——这是 INV-6 的落点，不是疏漏。
  bool get isNonE2ee => isEnterpriseHosted || !hasE2eePayload;

  /// 是否需要在气泡上展示「应用代发 / 人工经应用」徽标。
  bool get showsDelegationBadge => isEnterpriseHosted;

  /// 是否需要在气泡上展示「非 E2EE」标记。
  ///
  /// 覆盖企业托管（恒非 E2EE）与来源不可识别（形态可疑、不得暗示已加密）。
  bool get showsNoE2eeMarker => isEnterpriseHosted || needsOriginWarning;

  /// 是否应提示来源信息异常（形态不符 / 双痕迹冲突）。
  bool get needsOriginWarning =>
      originContradictsE2ee ||
      messageClass == HostedMessageClass.enterpriseOriginUnrecognized ||
      (origin != null && !origin!.isWellFormed);

  /// 审计/详情面的事实行（i18n 渲染所需的分类，不含文案）。
  HostedAuditFacts get audit => HostedAuditFacts(
    messageClass: messageClass,
    applicationId: origin?.applicationId ?? '',
    senderKind: origin?.senderKind,
    senderUserId: origin?.senderUserId ?? '',
    senderDisplayName: senderDisplayName,
    isNonE2ee: isNonE2ee,
    hasE2eePayload: hasE2eePayload,
    originContradictsE2ee: originContradictsE2ee,
    originWellFormed: origin?.isWellFormed ?? false,
  );
}

/// 审计/详情面的结构化事实（文案由 i18n 层渲染，本对象不做文案）。
class HostedAuditFacts {
  const HostedAuditFacts({
    required this.messageClass,
    required this.applicationId,
    required this.senderKind,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.isNonE2ee,
    required this.hasE2eePayload,
    required this.originContradictsE2ee,
    required this.originWellFormed,
  });

  final HostedMessageClass messageClass;
  final EntityId applicationId;
  final HostedSenderKind? senderKind;
  final EntityId senderUserId;
  final String senderDisplayName;
  final bool isNonE2ee;
  final bool hasE2eePayload;
  final bool originContradictsE2ee;
  final bool originWellFormed;

  /// 审计面**必须**保留的事实键集合（测试以集合相等钉死，防止 UI 侧悄悄丢字段）。
  Map<String, Object?> get traceableFields => <String, Object?>{
    'message_class': messageClass.wireName,
    'application_id': applicationId,
    'sender_kind': senderKind?.wireName ?? '',
    'sender_user_id': senderUserId,
    'non_e2ee': isNonE2ee,
    'has_e2ee_payload': hasE2eePayload,
    'origin_contradicts_e2ee': originContradictsE2ee,
    'origin_well_formed': originWellFormed,
  };
}

/// **唯一判定入口**：把消息的 payload / e2ee 载荷解析成展示事实。
///
/// [payload] 为消息 payload（Map 或 JSON 字符串；非 Map 时按「无来源」处理，
/// 与解密失败/密文形态一致——密文形态下不可能读出 origin）。
/// [e2ee] 为消息的 e2ee 载荷（存在即视为带加密载荷）。
HostedMessageFacts resolveHostedMessageFacts({
  dynamic payload,
  Map<String, dynamic>? e2ee,
  String senderDisplayName = '',
}) {
  final bool hasE2ee = e2ee != null && e2ee.isNotEmpty;
  final Map<String, dynamic>? map = _asMap(payload);
  final dynamic rawOrigin = map?['origin'];
  final EnterpriseMessageOrigin? origin = EnterpriseMessageOrigin.tryParse(
    rawOrigin,
  );

  // 存在 origin 结构，但不是企业托管 origin（无 kind 字段 → 视为无来源；
  // 有 kind 却不匹配 → 不可识别，fail-closed）。
  if (origin == null) {
    final bool suspicious =
        rawOrigin != null &&
        _asMap(rawOrigin) != null &&
        _asMap(rawOrigin)!.containsKey('kind');
    return HostedMessageFacts(
      messageClass: suspicious
          ? HostedMessageClass.enterpriseOriginUnrecognized
          : HostedMessageClass.humanDirect,
      hasE2eePayload: hasE2ee,
      originContradictsE2ee: false,
      senderDisplayName: senderDisplayName,
    );
  }

  return HostedMessageFacts(
    messageClass: origin.senderKind == HostedSenderKind.human
        ? HostedMessageClass.humanDelegated
        : HostedMessageClass.applicationDelegated,
    hasE2eePayload: hasE2ee,
    // 企业托管 origin + e2ee 载荷 → 真（不因此改判消息分类）。
    originContradictsE2ee: hasE2ee,
    origin: origin,
    senderDisplayName: senderDisplayName,
  );
}

/// payload 承载形态归一（Map / JSON 字符串 → Map；其余 → null）。
Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return parseModelJsonMap(raw);
}
