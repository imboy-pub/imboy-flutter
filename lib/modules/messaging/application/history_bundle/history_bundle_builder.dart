/// `HistoryBundleBuilder` —— 合并转发快照构建器（W2-G / chat_history_bundle_v1）。
///
/// 冻结契约：PLAN_SNAPSHOT §4.4 类型矩阵「合并转发」列 + §4.5 bundle 合同 +
/// backend `docs/reference/chat-history-bundle-contract.md`。
///
/// ## 类型矩阵（合并转发列）
///
/// | 类别 | 处理 |
/// |------|------|
/// | text | 支持快照（全量 payload 递归清理后深拷贝） |
/// | location / expression | 支持快照（拷贝安全显示字段） |
/// | quote | 扁平化可见文本（正文 + 被引用文本，丢弃引用结构） |
/// | image / imageMulti / voice(audio) / video / file | 占位快照 + 附件转发任务（真实重传/重封装走 `BundleAttachmentForwarder`） |
/// | 系统/控制、WebRTC、E2EE 失败占位、发送中/失败/撤回、阅后即焚、红包、转账、业务卡片 | **整体拒绝**（稳定错误码） |
///
/// 语义：进入构建的消息必须**全部可合并**——上层多选阶段已过滤；仍出现
/// 不可合并项时不跳过、不降级，直接整体失败并返回错误码 + 违规条目下标。
///
/// ## 顺序与上限（§4.2/§4.3）
///
/// - 按 `sentAtMs` 从旧到新稳定排序（同时间戳保持输入顺序）；
/// - 条目 1..50（0 条与 51 条构建前拒绝）；
/// - 序列化后 ≤ 256 KiB（UTF-8 字节长度，边界值合法，与后端同一常量）。
///
/// ## 每目标独立
///
/// `buildForTarget` 每次调用产出**全新 bundle 实例**（entry payload 全层
/// 深拷贝，不与源 payload 或其他目标的 bundle 共享可变引用）；目标标识
/// 仅用于任务绑定回执，不写入 bundle JSON。
library;

import 'package:imboy/modules/messaging/application/history_bundle/bundle_attachment_forwarder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_v1.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_sanitizer.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 构建成功。
class HistoryBundleBuildSuccess {
  const HistoryBundleBuildSuccess({
    required this.targetConversationUk3,
    required this.bundle,
    required this.attachmentTasks,
    required this.sanitizedFieldCount,
  });

  /// 本次构建的目标会话（回执用，不在 bundle JSON 内）。
  final String targetConversationUk3;

  /// 构建好的 v1 bundle（不可变；entries 已按从旧到新稳定排序）。
  final HistoryBundleV1 bundle;

  /// 附件转发任务（按 entries 顺序；无附件时为空列表）。
  final List<BundleAttachmentForwardTask> attachmentTasks;

  /// sanitizer 在全部 entry payload 中移除的禁止字段总数（埋点/断言用）。
  final int sanitizedFieldCount;
}

/// 构建失败（整体拒绝；无任何 bundle 产出）。
class HistoryBundleBuildFailure {
  const HistoryBundleBuildFailure(
    this.errorCode, {
    this.messageIndex,
    this.detail,
  });

  /// 稳定错误码（[HistoryBundleBuildErrorCode]）。
  final String errorCode;

  /// 违规消息在输入列表中的下标（类型/状态拒绝时给出；越界/超限时 null）。
  final int? messageIndex;

  /// 违规详情（如违规 msg_type），仅供日志/测试，不含 PII。
  final String? detail;
}

/// 构建结果（sealed：成功 / 失败二选一）。
sealed class HistoryBundleBuildResult {
  const HistoryBundleBuildResult();
}

final class HistoryBundleBuildSuccessResult extends HistoryBundleBuildResult {
  const HistoryBundleBuildSuccessResult(this.success);
  final HistoryBundleBuildSuccess success;
}

final class HistoryBundleBuildFailureResult extends HistoryBundleBuildResult {
  const HistoryBundleBuildFailureResult(this.failure);
  final HistoryBundleBuildFailure failure;
}

/// 协议/历史别称归一表（与 W1-C `chat_export_admission.dart` 同一映射本地
/// 内联，保持纯 Dart 零日志；新增别称两处同步）。
const Map<String, String> _kTypeAliases = <String, String>{
  MessageType.audio: MessageType.voice,
  MessageType.legacyChannelMessage: MessageType.channelCard,
  'webrtc_audio': MessageType.webrtcAudio,
  'webrtc_video': MessageType.webrtcVideo,
};

/// 合并转发可快照类型（§4.4：text / location / expression / quote）。
const Set<String> _kSnapshotTypes = <String>{
  MessageType.text,
  MessageType.location,
  MessageType.expression,
  MessageType.quote,
};

/// 附件占位类型（构建期占位 + 任务；audio 已归一为 voice）。
const Set<String> _kAttachmentTypes = <String>{
  MessageType.image,
  MessageType.imageMulti,
  MessageType.voice,
  MessageType.video,
  MessageType.file,
};

/// 系统/控制类型全集（与 W1-C `_kSystemOrControlTypes` 同集本地内联：
/// C2S/S2C action 值可能被历史落库为 msg_type）。
const Set<String> _kSystemOrControlTypes = <String>{
  C2SAction.messageRead,
  C2SAction.messageReadAck,
  C2SAction.messageRevoke,
  C2SAction.messageRevokeAck,
  C2SAction.messageEdit,
  C2SAction.messageEditAck,
  C2SAction.messageInput,
  C2SAction.e2eeRoomKey,
  C2SAction.messageReaction,
  S2CAction.pullOfflineMsg,
  S2CAction.c2cRevoke,
  S2CAction.c2cDelEveryone,
  S2CAction.c2gDelEveryone,
  S2CAction.c2gDelForMe,
  S2CAction.groupMemberJoin,
  S2CAction.groupDissolve,
  S2CAction.groupMemberLeave,
  S2CAction.groupMemberAlias,
  S2CAction.applyFriend,
  S2CAction.applyFriendConfirm,
  S2CAction.userCancel,
  S2CAction.inDenylist,
  S2CAction.notAFriend,
  S2CAction.online,
  S2CAction.offline,
  S2CAction.hide,
  S2CAction.loggedAnotherDevice,
  S2CAction.deviceForceOffline,
  S2CAction.pleaseRefreshToken,
  S2CAction.appUpgrade,
  S2CAction.momentNew,
  S2CAction.momentLike,
  S2CAction.momentComment,
  S2CAction.momentDeleted,
  'revoked',
};

/// 业务卡片集合（与 W1-A `_kBusinessCardMsgTypes` 同集本地内联）。
const Set<String> _kBusinessCardTypes = <String>{
  MessageType.businessActionCard,
  MessageType.linkCard,
  MessageType.channelCard,
  MessageType.legacyChannelMessage,
  MessageType.talkRecordCard,
  MessageType.visitCard,
  MessageType.groupSchedule,
  MessageType.groupVote,
  MessageType.groupTask,
  MessageType.groupNotice,
};

/// 深度超限稳定码（S1-M1，契约只增不改语义）：消息 payload 嵌套深度
/// 超过 [BundleSanitizer.defaultMaxDepth]（默认 16）时构建整体拒绝。
///
/// 攻击链：深嵌套 JSON 消息体（不受 bundle 256 KiB 约束）→ 多选合并
/// 转发 → 无界递归清理/深拷贝/序列化 → 栈溢出（DoS）。上限后走稳定
/// 失败：构建侧本码拒绝违规条目；dispatcher writeback 路径消费
/// `BundleSanitizeResult.depthExceeded` 时按 sendFailed 口径整目标失败
/// （接线在 BundleForwardDispatcher，G4 lane）。命名与
/// [HistoryBundleBuildErrorCode] 的 `bundle_*` 机器契约风格一致；常量
/// 定义在 builder 侧是因为 types.dart 归 G4 lane 所有权（集成时可上移）。
const String bundlePayloadDepthExceeded = 'bundle_payload_depth_exceeded';

/// 快照构建器（无状态，线程安全；每次调用独立产出）。
abstract final class HistoryBundleBuilder {
  /// 为单个目标会话构建 bundle。
  ///
  /// [targetConversationUk3] 目标会话标识（每目标单独构建，附件任务绑定）；
  /// [messages] 待合并消息（进入构建必须全部可合并）；[title] 可选标题
  /// （如来源会话名快照）；[senderName] 可选转发者展示名（顶层
  /// `sender_name` 预留键，详情页来源行，空白省略键）；[exportedAtMs]
  /// 可选导出时间（默认当前不填，由上层决定）。
  static HistoryBundleBuildResult buildForTarget(
    String targetConversationUk3,
    List<HistoryBundleSourceMessage> messages, {
    String? title,
    String? senderName,
    int? exportedAtMs,
  }) {
    if (targetConversationUk3.trim().isEmpty) {
      return const HistoryBundleBuildFailureResult(
        HistoryBundleBuildFailure(HistoryBundleBuildErrorCode.invalidTarget),
      );
    }
    if (messages.length < HistoryBundleContract.minEntries ||
        messages.length > HistoryBundleContract.maxEntries) {
      return const HistoryBundleBuildFailureResult(
        HistoryBundleBuildFailure(
          HistoryBundleBuildErrorCode.entriesOutOfRange,
        ),
      );
    }

    // 1. 准入：全部消息必须可合并（输入顺序；任一违规整体拒绝）。
    final rejected = _admitAll(messages);
    if (rejected != null) {
      return HistoryBundleBuildFailureResult(rejected);
    }

    // 2+3. 稳定排序 + 逐条构建 entry（快照/扁平化/占位+任务）。
    //    深度守护失败（S1-M1）时整体拒绝（稳定码 + 违规下标）。
    final (depthFailure, entries, tasks, sanitizedCount) =
        _buildEntriesAndTasks(messages);
    if (depthFailure != null) {
      return HistoryBundleBuildFailureResult(depthFailure);
    }

    // 4. 组装 + 尺寸守护（UTF-8 字节长度，边界 256×1024 合法）。
    // senderName = 转发者展示名（合同顶层预留键，详情页来源行；S1-L5）。
    // 空白归一为 null——键整体省略，既有快照字节形态零变化。
    final normalizedSenderName = (senderName?.trim().isEmpty ?? true)
        ? null
        : senderName;
    final bundle = HistoryBundleV1(
      title: title,
      senderName: normalizedSenderName,
      exportedAt: exportedAtMs,
      entries: entries,
    );
    if (bundle.serializedByteLength > HistoryBundleContract.maxPayloadBytes) {
      return const HistoryBundleBuildFailureResult(
        HistoryBundleBuildFailure(HistoryBundleBuildErrorCode.payloadTooLarge),
      );
    }
    return HistoryBundleBuildSuccessResult(
      HistoryBundleBuildSuccess(
        targetConversationUk3: targetConversationUk3,
        bundle: bundle,
        attachmentTasks: List.unmodifiable(tasks),
        sanitizedFieldCount: sanitizedCount,
      ),
    );
  }

  /// 准入循环：全部消息必须可合并；任一违规即整体失败（返回携带违规
  /// 下标与 msg_type 的失败对象），全部可合并返回 null。
  static HistoryBundleBuildFailure? _admitAll(
    List<HistoryBundleSourceMessage> messages,
  ) {
    for (var i = 0; i < messages.length; i++) {
      final code = _admit(messages[i]);
      if (code != null) {
        return HistoryBundleBuildFailure(
          code,
          messageIndex: i,
          detail: messages[i].msgType,
        );
      }
    }
    return null;
  }

  /// 排序 + 构建：按 (sentAtMs, 输入下标) 双键稳定排序后逐条产出
  /// entries 与附件任务（快照/扁平化/占位+任务），并累计 sanitizer
  /// 移除字段总数。
  ///
  /// 深度守护（S1-M1）：任一消息 payload 嵌套深度超过
  /// [BundleSanitizer.defaultMaxDepth]（快照路径由 sanitize 的
  /// depthExceeded 标志给出；附件路径对源 payload 前置探测——深树可能
  /// 藏在占位不采集的键下，仍会在任务深拷贝处无界递归）→ 整体拒绝
  /// （[bundlePayloadDepthExceeded] + 违规下标），不得栈溢出。
  static (
    HistoryBundleBuildFailure?,
    List<HistoryBundleEntryV1>,
    List<BundleAttachmentForwardTask>,
    int,
  )
  _buildEntriesAndTasks(List<HistoryBundleSourceMessage> messages) {
    // 稳定排序：sentAtMs 升序，同时间戳保持输入顺序（Dart sort 不保证
    // 稳定，用 (sentAtMs, 输入下标) 双键显式稳定）。
    final order = List<int>.generate(messages.length, (i) => i);
    order.sort((a, b) {
      final byTime = messages[a].sentAtMs.compareTo(messages[b].sentAtMs);
      return byTime != 0 ? byTime : a.compareTo(b);
    });

    final entries = <HistoryBundleEntryV1>[];
    final tasks = <BundleAttachmentForwardTask>[];
    var sanitizedCount = 0;
    for (final index in order) {
      final msg = messages[index];
      final normalized = _normalizeType(msg.msgType);
      final bool isAttachment = _kAttachmentTypes.contains(normalized);
      if (isAttachment && BundleSanitizer.depthOverLimit(msg.payload)) {
        return (
          HistoryBundleBuildFailure(
            bundlePayloadDepthExceeded,
            messageIndex: index,
            detail: msg.msgType,
          ),
          const <HistoryBundleEntryV1>[],
          const <BundleAttachmentForwardTask>[],
          0,
        );
      }
      final (body, removed, depthExceeded) = isAttachment
          ? _attachmentPlaceholder(normalized, msg.payload)
          : _snapshotPayload(normalized, msg.payload);
      if (depthExceeded) {
        return (
          HistoryBundleBuildFailure(
            bundlePayloadDepthExceeded,
            messageIndex: index,
            detail: msg.msgType,
          ),
          const <HistoryBundleEntryV1>[],
          const <BundleAttachmentForwardTask>[],
          0,
        );
      }
      sanitizedCount += removed;
      entries.add(_entry(normalized, msg, body));
      if (isAttachment) {
        tasks.add(
          BundleAttachmentForwardTask(
            entryIndex: entries.length - 1,
            sourceMsgType: normalized,
            sourceMessageId: msg.sourceMessageId,
            sourceChatType: msg.sourceChatType,
            sourceFromUid: msg.sourceFromUid,
            sourceToUid: msg.sourceToUid,
            // 源 payload 只进内存任务（adapter 需要 descriptor/uri），
            // 绝不进入 bundle JSON。深拷贝隔离：任务快照与源 payload
            // 全层不共享可变引用（构建后源侧修改不影响任务）。
            sourcePayload: _deepCopySourcePayload(msg.payload),
          ),
        );
      }
    }
    return (null, entries, tasks, sanitizedCount);
  }

  /// sourcePayload 深拷贝入口（顶层必为 map）。
  ///
  /// ⚠️ 调用方必须先过深度前置闸（[BundleSanitizer.depthOverLimit]，
  /// S1-M1）：本拷贝与 [_snapshotPayload] 不同，会走遍源 payload 全部
  /// 键（含占位不采集的键），无界深树可把递归推成栈溢出。
  ///
  /// 不使用 json round-trip 拷贝：TSID 等 64-bit 大整数经
  /// `jsonEncode`/`jsonDecode` 会丢精度。
  static Map<String, dynamic> _deepCopySourcePayload(
    Map<String, dynamic> payload,
  ) {
    final out = <String, dynamic>{};
    payload.forEach((key, value) => out[key] = _deepCopyValue(value));
    return out;
  }

  /// 递归保型拷贝：map → 新 `Map<String, dynamic>`，list → 新
  /// `List<dynamic>`，标量/引用值原样返回（String/int 等本身不可变）。
  static Object? _deepCopyValue(Object? value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((rawKey, v) {
        final key = rawKey is String ? rawKey : rawKey.toString();
        out[key] = _deepCopyValue(v);
      });
      return out;
    }
    if (value is List) {
      return <dynamic>[for (final e in value) _deepCopyValue(e)];
    }
    return value;
  }

  /// 单条准入（优先级与 W1-A `evaluateMessageSelectability` 同口径：
  /// E2EE 失败占位 → 状态 → 焚毁 → 类型桶）。可合并返回 null。
  static String? _admit(HistoryBundleSourceMessage msg) {
    if (msg.e2eeFailedPlaceholder) {
      return HistoryBundleBuildErrorCode.rejectedE2eeFailed;
    }
    switch (msg.status) {
      case MessageStatus.sending:
        return HistoryBundleBuildErrorCode.rejectedStatusSending;
      case MessageStatus.error:
        return HistoryBundleBuildErrorCode.rejectedStatusFailed;
      case MessageStatus.revoked:
        return HistoryBundleBuildErrorCode.rejectedRevoked;
      case MessageStatus.sent:
      case MessageStatus.delivered:
      case MessageStatus.seen:
        break;
    }
    if (msg.burnReadAtMs > 0) {
      return HistoryBundleBuildErrorCode.rejectedBurnAfterRead;
    }
    final type = _normalizeType(msg.msgType);
    if (_kSnapshotTypes.contains(type) || _kAttachmentTypes.contains(type)) {
      return null;
    }
    if (type == MessageType.webrtcAudio || type == MessageType.webrtcVideo) {
      return HistoryBundleBuildErrorCode.rejectedWebrtc;
    }
    if (type == MessageType.redPacket || type == MessageType.transfer) {
      return HistoryBundleBuildErrorCode.rejectedPayment;
    }
    if (_kBusinessCardTypes.contains(type)) {
      return HistoryBundleBuildErrorCode.rejectedBusinessCard;
    }
    if (_kSystemOrControlTypes.contains(type)) {
      return HistoryBundleBuildErrorCode.rejectedSystemOrControl;
    }
    return HistoryBundleBuildErrorCode.rejectedUnsupportedType;
  }

  /// 类型准入（仅类型桶维度，不含状态/焚毁/E2EE 失败）。
  ///
  /// Central Wiring 多选 action bar 的合并转发按钮可用性策略用（计划 §12.5：
  /// 按动作策略分别 enable/disable，而非统一 selectable）。类型判定与
  /// [_admit] 同源（同一归一表与集合）；状态维度由调用方按 traits 自查。
  static bool isTypeBundleAdmissible(String? rawType) {
    final type = _normalizeType(rawType);
    return _kSnapshotTypes.contains(type) || _kAttachmentTypes.contains(type);
  }

  /// trim + 协议别称归一（null 视为不可合并类型，返回原 null 语义由
  /// 调用方兜底为 unsupported）。
  static String _normalizeType(String? raw) {
    if (raw == null) return MessageType.unsupported;
    final t = raw.trim();
    return _kTypeAliases[t] ?? t;
  }

  static HistoryBundleEntryV1 _entry(
    String msgType,
    HistoryBundleSourceMessage msg,
    Map<String, dynamic> payload,
  ) => HistoryBundleEntryV1(
    msgType: msgType,
    // null/空串发送者名归一为 null（序列化省略 sender_name 键）
    senderName: switch (msg.senderName) {
      null || '' => null,
      final name => name,
    },
    sentAt: msg.sentAtMs,
    payload: payload,
  );

  /// 快照类 entry payload（第三分量 = 深度超限标志，S1-M1）：
  /// - text：全量 payload 递归清理（真快照，sanitizer 深拷贝）；
  /// - quote：扁平化可见文本（正文 + 被引用文本，仅保留两个纯文本键）；
  /// - location：拷贝安全字段 title/address/latitude/longitude；
  /// - expression：拷贝可见文本 text。
  static (Map<String, dynamic>, int, bool) _snapshotPayload(
    String normalizedType,
    Map<String, dynamic> payload,
  ) {
    switch (normalizedType) {
      case MessageType.text:
        final r = BundleSanitizer.sanitize(payload);
        // 规范化正文键：历史文本可能只存 `content`（messagePreviewText 同款
        // 兜底）；保证渲染侧 `payload['text']` 恒有值，content 原样保留。
        final cleaned = r.cleaned;
        final text = _stringOf(cleaned['text']);
        if (text.trim().isEmpty) {
          final content = _stringOf(cleaned['content']);
          if (content.trim().isNotEmpty) {
            cleaned['text'] = content;
          }
        }
        return (cleaned, r.removedFieldCount, r.depthExceeded);
      case MessageType.quote:
        final body = _visibleText(payload, prefer: 'text', fallback: 'content');
        final quoted = _stringOf(payload['quote_text']);
        final r = BundleSanitizer.sanitize(<String, dynamic>{
          'text': body,
          'quote_text': quoted,
        });
        return (r.cleaned, r.removedFieldCount, r.depthExceeded);
      case MessageType.location:
        final picked = <String, dynamic>{};
        _pick(picked, payload, 'title');
        _pick(picked, payload, 'address');
        _pick(picked, payload, 'latitude');
        _pick(picked, payload, 'longitude');
        final r = BundleSanitizer.sanitize(picked);
        return (r.cleaned, r.removedFieldCount, r.depthExceeded);
      case MessageType.expression:
        final r = BundleSanitizer.sanitize(<String, dynamic>{
          'text': _visibleText(payload, prefer: 'text', fallback: null),
        });
        return (r.cleaned, r.removedFieldCount, r.depthExceeded);
      default:
        // 理论不可达（_admit 已白名单）；fail-closed 返回空快照。
        return (const <String, dynamic>{}, 0, false);
    }
  }

  /// 附件占位 entry payload（第三分量 = 深度超限标志，S1-M1）：仅显示
  /// 字段，**不含任何对象引用**（uri/url/object_key/file_hash256/
  /// descriptor 一律剥离——源引用是源会话 scope 的授权句柄；新引用由
  /// adapter 重传后经 `withEntryPayload` 写回）。
  static (Map<String, dynamic>, int, bool) _attachmentPlaceholder(
    String normalizedType,
    Map<String, dynamic> payload,
  ) {
    switch (normalizedType) {
      case MessageType.imageMulti:
        final images = <Map<String, dynamic>>[];
        final rawImages = payload['images'];
        if (rawImages is List) {
          for (final e in rawImages) {
            if (e is Map) {
              images.add(
                _displayFields(e, const ['name', 'size', 'width', 'height']),
              );
            }
          }
        }
        final placeholder = <String, dynamic>{'images': images};
        _pick(placeholder, payload, 'total');
        final r = BundleSanitizer.sanitize(placeholder);
        return (r.cleaned, r.removedFieldCount, r.depthExceeded);
      case MessageType.image:
        return _displayPlaceholder(payload, const [
          'name',
          'size',
          'width',
          'height',
        ]);
      case MessageType.voice:
        return _displayPlaceholder(payload, const [
          'name',
          'size',
          'duration_ms',
        ]);
      case MessageType.video:
        return _displayPlaceholder(payload, const [
          'name',
          'size',
          'width',
          'height',
          'duration_ms',
        ]);
      case MessageType.file:
        return _displayPlaceholder(payload, const ['filename', 'name', 'size']);
      default:
        return (const <String, dynamic>{}, 0, false);
    }
  }

  static (Map<String, dynamic>, int, bool) _displayPlaceholder(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    final r = BundleSanitizer.sanitize(_displayFields(payload, keys));
    return (r.cleaned, r.removedFieldCount, r.depthExceeded);
  }

  /// 从 [src] 拷贝显示字段（仅存在于 src 的键；值为 null 跳过）。
  static Map<String, dynamic> _displayFields(
    Map<dynamic, dynamic> src,
    List<String> keys,
  ) {
    final out = <String, dynamic>{};
    for (final key in keys) {
      if (src.containsKey(key) && src[key] != null) {
        out[key] = src[key];
      }
    }
    return out;
  }

  static void _pick(
    Map<String, dynamic> out,
    Map<String, dynamic> src,
    String key,
  ) {
    final v = src[key];
    if (v != null) out[key] = v;
  }

  /// 可见正文：优先 [prefer] 键，空则回退 [fallback]（历史 text 可能存
  /// `content`），再退空串。只输出 String（非字符串值转字符串）。
  static String _visibleText(
    Map<String, dynamic> payload, {
    required String? prefer,
    required String? fallback,
  }) {
    if (prefer != null) {
      final v = _stringOf(payload[prefer]);
      if (v.trim().isNotEmpty) return v;
    }
    if (fallback != null) {
      final v = _stringOf(payload[fallback]);
      if (v.trim().isNotEmpty) return v;
    }
    return '';
  }

  static String _stringOf(Object? v) => v?.toString() ?? '';
}
