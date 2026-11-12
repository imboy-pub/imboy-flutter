/// `chat_history_bundle` v1 DTO —— 纯数据、不可变（W2-G / W2 bundle core）。
///
/// JSON 形态冻结于 backend `docs/reference/chat-history-bundle-contract.md` §2
/// + PLAN_SNAPSHOT §4.5，本 DTO 在合同最小形态上增加可选展示字段
/// `title` / `exported_at`（后端透传管道不深解，允许存在）：
///
/// ```json
/// {
///   "bundle_version": 1,
///   "title": "…可选…",
///   "exported_at": 1760000000000,
///   "entries": [
///     {"msg_type": "text", "sender_name": "…可选…",
///      "sent_at": 1760000000000, "payload": {"text": "…"}}
///   ]
/// }
/// ```
///
/// ⚠️ 条目 payload 必须是**安全快照**：构建时已经过 `BundleSanitizer`
/// 递归清理（禁止字段清单见 sanitizer 文档）。本 DTO 不再做二次清理，
/// 序列化字节长度以 [HistoryBundleV1.serializedByteLength] 为准
/// （UTF-8 字节，与后端 `byte_size(jsone:encode(payload))` 同口径）。
library;

import 'dart:convert';

import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_sanitizer.dart'
    show BundleSanitizer;
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';

export 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart'
    show HistoryBundleContract;

/// v1 不可变条目（entries 元素）。
class HistoryBundleEntryV1 {
  HistoryBundleEntryV1({
    required this.msgType,
    required Map<String, dynamic> payload,
    this.senderName,
    this.sentAt,
  }) : payload = Map.unmodifiable(payload);

  /// 原消息内容类型快照（归一后的 msg_type，如 text/image/voice）。
  final String msgType;

  /// 发送者显示名（昵称/群名片）；可为空。
  final String? senderName;

  /// 原消息发送时间（毫秒时间戳）；可为空。
  final int? sentAt;

  /// 安全快照 payload（经 sanitizer 清理；顶层 Map 不可变）。
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'msg_type': msgType,
    if (senderName != null) 'sender_name': senderName,
    if (sentAt != null) 'sent_at': sentAt,
    'payload': payload,
  };

  /// 返回替换 payload 后的新条目（copy-on-write，原条目不变）。
  HistoryBundleEntryV1 withPayload(Map<String, dynamic> newPayload) =>
      HistoryBundleEntryV1(
        msgType: msgType,
        senderName: senderName,
        sentAt: sentAt,
        payload: newPayload,
      );
}

/// v1 不可变 bundle 根对象。
class HistoryBundleV1 {
  HistoryBundleV1({
    required List<HistoryBundleEntryV1> entries,
    this.title,
    this.exportedAt,
  }) : entries = List.unmodifiable(entries);

  /// 恒为 [HistoryBundleContract.bundleVersion]（=1）。
  final int bundleVersion = HistoryBundleContract.bundleVersion;

  /// 可选标题（如来源会话名快照，由上层决定是否填写）。
  final String? title;

  /// 导出/构建时间（毫秒时间戳）；可为空。
  final int? exportedAt;

  /// 条目列表（1..50，已按 createdAt 从旧到新稳定排序；不可变）。
  final List<HistoryBundleEntryV1> entries;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'bundle_version': bundleVersion,
    if (title != null) 'title': title,
    if (exportedAt != null) 'exported_at': exportedAt,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  /// 序列化后的 UTF-8 字节长度（尺寸上限判定口径）。
  ///
  /// 必须与后端一致：后端对整个 payload JSON 做 `byte_size`，此处对
  /// `jsonEncode(toJson())` 的 UTF-8 编码取长度，边界值 256×1024 合法。
  ///
  /// 深度前置闸（S1-M1）：`jsonEncode` 对深嵌套 map/list 递归下栈，
  /// 病态深 payload（不受 256 KiB 尺寸闸保护）可把序列化推成栈溢出。
  /// 与 [BundleSanitizer.sanitize] **同一口径**逐 entry 检查 payload
  /// （payload 顶层不计层、其下超过 [BundleSanitizer.defaultMaxDepth]
  /// 层容器即超限；其余字段均为标量，无嵌套面）。超限时保守返回
  /// `maxPayloadBytes + 1`——走既有 payloadTooLarge 尺寸守护**稳定
  /// 失败**，绝不栈溢出、绝不静默放行。
  int get serializedByteLength {
    for (final entry in entries) {
      if (BundleSanitizer.depthOverLimit(entry.payload)) {
        return HistoryBundleContract.maxPayloadBytes + 1;
      }
    }
    return utf8.encode(jsonEncode(toJson())).length;
  }

  /// 返回替换某条目 payload 后的新 bundle（copy-on-write）。
  ///
  /// 附件转发适配器（`BundleAttachmentForwarder`）执行完成后，发送入口
  /// 用它把新 uri/file_hash256/descriptor 写回对应条目；原 bundle 不受影响。
  ///
  /// [index] 越界（<0 或 ≥entries.length）抛 [ArgumentError]（携带
  /// index/length，防止适配器静默写错位置）。
  HistoryBundleV1 withEntryPayload(int index, Map<String, dynamic> newPayload) {
    if (index < 0 || index >= entries.length) {
      throw ArgumentError.value(
        index,
        'index',
        'out of range: index=$index, length=${entries.length}',
      );
    }
    final next = List<HistoryBundleEntryV1>.of(entries);
    next[index] = entries[index].withPayload(newPayload);
    return HistoryBundleV1(title: title, exportedAt: exportedAt, entries: next);
  }
}
