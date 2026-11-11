// integration_test/helpers/chat_multi_fixtures.dart
//
// W3-K 多选消息集成测试 fixtures（RUN_ID=chat-multi-20261111）。
//
// 本文件是 **纯 Dart/Flutter** 助手，不 import `package:integration_test`，
// 因此 integration_test/ 设备用例与 test/unit_test/page/chat/integration_smoke/
// 本地 widget 冒烟用例共享同一套 fixtures（W3-K 验证策略：本地全绿 =
// 编译 + 逻辑锚；真机执行在 DEV-01 由主 Agent 编排）。
//
// 约定：
// - 全部使用合成数据（无真实手机号/秘密）；marker 带进程内 nonce，
//   支持同会话重复运行不串数据。
// - key 约定来自 w2-e receipt handoff：
//   勾选框 multi_select_check_<messageId>；action bar
//   multi_select_cancel / multi_select_count / multi_select_clear /
//   multi_select_forward_each / multi_select_forward_bundle / multi_select_export。
// - feature flag：rollout flag 走 AppFeatureRegistry.isRolloutFlagEnabled，
//   测试经 replaceSnapshotForTest 开启（与 w2-e 验证方式一致）。
//   chat_history_bundle_v1 的 FeatureKeys 常量由 Central Wiring 补充
//   （计划 §12.4），此处按冻结键名使用裸字符串。

import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as core;

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/application/export/chat_share_gateway.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart' as domain;
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/message_model.dart';

/// 导出准入结果查看器（W1-C evaluateChatExportAdmission 的最小包装）。
(bool, String) chatMultiExportAdmissionOf(core.Message message) {
  final entry = chatMultiExportEntry(message: message, senderName: 'w3k');
  final admission = evaluateChatExportAdmission(entry);
  return (admission.allowed, admission.reasonCode);
}

/// 合成账号（W0C §2.3：setup_test_data.sh 幂等建号，与生产数据隔离）。
abstract final class ChatMultiAccounts {
  /// Alice（SMOKE_FROM）。
  static const String alice = '1000000051';

  /// Bob（SMOKE_TO）。
  static const String bob = '1000000056';
}

/// 多选/合并/导出 rollout flag 键（chat_multi_select_v1 已在 FeatureKeys；
/// 其余两键由 Central Wiring 落 FeatureKeys 常量，字符串按计划冻结）。
abstract final class ChatMultiFlags {
  static const String multiSelect = 'chat_multi_select_v1';
  static const String historyBundle = 'chat_history_bundle_v1';
  static const String exportShare = 'chat_export_share_v1';
}

/// feature flag 开关（测试内 override；用例结束必须调 [restore]）。
///
/// snapshot 整体替换语义：先暂存当前 snapshot，开启时并入多选三键，
/// restore 时整体还原 —— 不污染登录期服务端下发的真实开关。
class ChatMultiFlagOverride {
  Map<String, dynamic>? _previous;

  /// 开启多选 / 合并转发 / 导出三个 rollout flag。
  void enableAll({
    bool multiSelect = true,
    bool bundle = true,
    bool export = true,
  }) {
    _previous = Map<String, dynamic>.from(AppFeatureRegistry.snapshot);
    AppFeatureRegistry.replaceSnapshotForTest({
      ...?_previous,
      ChatMultiFlags.multiSelect: multiSelect,
      ChatMultiFlags.historyBundle: bundle,
      ChatMultiFlags.exportShare: export,
    });
  }

  /// 还原开启前 snapshot（幂等； tearDown 必调）。
  void restore() {
    final prev = _previous;
    if (prev == null) return;
    AppFeatureRegistry.replaceSnapshotForTest(prev);
    _previous = null;
  }
}

/// 合成消息构造器（MessageModel → flutter_chat_core Message 各类型）。
///
/// 构造出的消息必须满足：
/// - `messageSelectionTraitsOf`（W2-E）判可选（status 正向、非 E2EE 失败、
///   非阅后即焚）；
/// - `HistoryBundleBuilder.buildForTarget`（W2-G）判可合并
///   （text/image/file/voice 均在 §4.4 合并转发白名单）；
/// - `ChatExportAdmission`（W1-C）判可导出。
abstract final class ChatMultiMessageFixtures {
  /// 进程内 nonce（重复运行不与存量会话数据串）。
  static int _nonce = DateTime.now().millisecondsSinceEpoch;

  static int nextNonce() => _nonce++;

  /// marker 文本（真机用例以此定位气泡； RichText 需 findRichText）。
  static String marker(String prefix) => '$prefix-${nextNonce()}';

  /// 文本消息（metadata 带 msg_type，与线上消息同构）。
  static core.TextMessage text({
    required String id,
    required String text,
    required String authorId,
    required DateTime createdAt,
    String? peerId,
    core.MessageStatus status = core.MessageStatus.sent,
  }) {
    return core.TextMessage(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      text: text,
      status: status,
      metadata: {'msg_type': MessageType.text, 'peer_id': ?peerId},
    );
  }

  /// 图片消息（占位 uri；真机用例不做像素断言，仅定位/勾选/转发）。
  static core.ImageMessage image({
    required String id,
    required String authorId,
    required DateTime createdAt,
    required String remoteUri,
    String? peerId,
    double width = 64,
    double height = 64,
    core.MessageStatus status = core.MessageStatus.sent,
  }) {
    return core.ImageMessage(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      source: remoteUri,
      width: width,
      height: height,
      size: 1024,
      status: status,
      metadata: {
        'msg_type': MessageType.image,
        'uri': remoteUri,
        'peer_id': ?peerId,
      },
    );
  }

  /// 文件消息。
  static core.FileMessage file({
    required String id,
    required String authorId,
    required DateTime createdAt,
    required String remoteUri,
    required String name,
    String? peerId,
    core.MessageStatus status = core.MessageStatus.sent,
  }) {
    return core.FileMessage(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      source: remoteUri,
      name: name,
      size: 2048,
      status: status,
      metadata: {
        'msg_type': MessageType.file,
        'uri': remoteUri,
        'peer_id': ?peerId,
      },
    );
  }

  /// 语音消息（msg_type 归一前缀 voice；W2-G 将 audio 归一为 voice）。
  static core.AudioMessage voice({
    required String id,
    required String authorId,
    required DateTime createdAt,
    required String remoteUri,
    String? peerId,
    core.MessageStatus status = core.MessageStatus.sent,
  }) {
    return core.AudioMessage(
      id: id,
      authorId: authorId,
      createdAt: createdAt,
      source: remoteUri,
      duration: const Duration(seconds: 2),
      status: status,
      metadata: {
        'msg_type': MessageType.audio,
        'uri': remoteUri,
        'peer_id': ?peerId,
      },
    );
  }

  /// 一组按时间递增的标准 fixtures：text → image → file → voice → text。
  ///
  /// 真机用例据此断言转发/合并后的顺序（旧→新，冻结合同 §4.3）。
  static List<core.Message> standardSet({
    required String authorId,
    required String textMarker,
    String? peerId,
    DateTime? baseTime,
  }) {
    final base = baseTime ?? DateTime.fromMillisecondsSinceEpoch(_nonce);
    String idOf(String kind) => 'w3k$kind${_nonce++}';
    return [
      text(
        id: idOf('t1'),
        text: '$textMarker-1',
        authorId: authorId,
        createdAt: base,
        peerId: peerId,
      ),
      image(
        id: idOf('i1'),
        authorId: authorId,
        createdAt: base.add(const Duration(milliseconds: 1)),
        remoteUri: 'https://fixture.invalid/w3k-image-$idOf.png',
        peerId: peerId,
      ),
      file(
        id: idOf('f1'),
        authorId: authorId,
        createdAt: base.add(const Duration(milliseconds: 2)),
        remoteUri: 'https://fixture.invalid/w3k-file-$idOf.pdf',
        name: 'w3k-fixture.pdf',
        peerId: peerId,
      ),
      voice(
        id: idOf('v1'),
        authorId: authorId,
        createdAt: base.add(const Duration(milliseconds: 3)),
        remoteUri: 'https://fixture.invalid/w3k-voice-$idOf.aac',
        peerId: peerId,
      ),
      text(
        id: idOf('t2'),
        text: '$textMarker-2',
        authorId: authorId,
        createdAt: base.add(const Duration(milliseconds: 4)),
        peerId: peerId,
      ),
    ];
  }
}

/// Message → MessageModel（w2-g handoff 字段对照表的 fixtures 侧实现）。
///
/// 供 bundle 构建与落库路径复用；E2EE 字段恒空（合成消息为明文快照）。
MessageModel chatMultiMessageModel(
  core.Message message, {
  required String chatType,
  required String fromUid,
  required String toUid,
  required String conversationUk3,
  int status = 11,
  int isAuthor = 1,
}) {
  final Map<String, dynamic> payload = switch (message) {
    core.TextMessage() => {'msg_type': MessageType.text, 'text': message.text},
    core.ImageMessage() => {
      'msg_type': MessageType.image,
      'uri': message.metadata?['uri'],
      'width': message.width,
      'height': message.height,
      'size': message.size,
    },
    core.FileMessage() => {
      'msg_type': MessageType.file,
      'uri': message.metadata?['uri'],
      'filename': message.name,
      'size': message.size,
    },
    core.AudioMessage() => {
      'msg_type': MessageType.audio,
      'uri': message.metadata?['uri'],
      'duration_ms': message.duration.inMilliseconds,
    },
    _ => {'msg_type': MessageType.text, 'text': '[w3k-fixture]'},
  };
  return MessageModel(
    message.id,
    autoId: 0,
    type: chatType,
    status: status,
    fromId: fromUid,
    toId: toUid,
    payload: payload,
    isAuthor: isAuthor,
    conversationUk3: conversationUk3,
    msgType: payload['msg_type'] as String?,
    createdAt: message.createdAt?.millisecondsSinceEpoch ?? 0,
  );
}

/// Message → HistoryBundleSourceMessage（w2-g handoff 字段对照表）。
HistoryBundleSourceMessage chatMultiBundleSource(
  core.Message message, {
  required String chatType,
  required String fromUid,
  required String toUid,
  String? senderName,
}) {
  final model = chatMultiMessageModel(
    message,
    chatType: chatType,
    fromUid: fromUid,
    toUid: toUid,
    conversationUk3: '',
  );
  return HistoryBundleSourceMessage(
    msgType: model.msgType,
    sourceMessageId: model.id,
    sourceChatType: model.type ?? chatType,
    sourceFromUid: model.fromId,
    sourceToUid: model.toId,
    sentAtMs: model.createdAt,
    status: domain.MessageStatus.sent,
    senderName: senderName,
    payload: model.payload is Map<String, dynamic>
        ? model.payload as Map<String, dynamic>
        : const <String, dynamic>{},
  );
}

/// 导出条目构造（W1-C ChatExportEntry 契约的 fixtures 侧便捷入口）。
ChatExportEntry chatMultiExportEntry({
  required core.Message message,
  required String senderName,
}) {
  final String body = switch (message) {
    core.TextMessage() => message.text,
    core.FileMessage() => message.name,
    _ => '[${message.metadata?['msg_type'] ?? 'message'}]',
  };
  return ChatExportEntry(
    msgType: message.metadata?['msg_type']?.toString() ?? MessageType.text,
    senderName: senderName,
    createdAt: message.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    status: domain.MessageStatus.sent,
    text: body,
  );
}

/// 记录型系统分享网关 fake（W1-C `ChatShareGateway` 契约）。
///
/// W3-K 导出用例用注入 adapter 替代平台 share_plus：
/// - [calls] 记录全部调用（shareText/shareFiles 各计入一项）；
/// - [outcome] 决定 fake 返回结果（默认 canceled —— 模拟用户在系统面板取消）；
/// - 真机「E2EE 取消=零副作用」断言调用 [assertNoCalls]。
class RecordingChatShareGateway implements ChatShareGateway {
  RecordingChatShareGateway({this.outcome = const ChatShareOutcome.canceled()});

  /// fake 的固定返回值。
  final ChatShareOutcome outcome;

  /// 调用记录（文本分享与文件分享合并计数；元素形如 `text:12` 或
  /// `files:/a/b`，便于断言诊断）。
  final List<String> calls = <String>[];

  int get callCount => calls.length;

  void assertNoCalls({String reason = 'gateway fake 不应有任何调用'}) {
    assert(calls.isEmpty, '$reason: $calls');
    if (calls.isNotEmpty) {
      throw StateError('$reason: $calls');
    }
  }

  void clear() => calls.clear();

  @override
  Future<ChatShareOutcome> shareText(String text, {String? subject}) async {
    calls.add(
      'text:${text.length}${subject == null ? '' : ' subject=$subject'}',
    );
    return outcome;
  }

  @override
  Future<ChatShareOutcome> shareFiles(ChatShareFilesRequest request) async {
    calls.add('files:${request.filePaths.join(',')}');
    return outcome;
  }
}

/// 勾选框 Key（w2-e 约定：`multi_select_check_<messageId>`）。
Key chatMultiCheckboxKey(String messageId) =>
    ValueKey('multi_select_check_$messageId');

/// action bar 稳定 Key 集中声明（w2-e 约定；测试与生产同源真值）。
abstract final class ChatMultiKeys {
  static const Key cancel = ValueKey('multi_select_cancel');
  static const Key count = ValueKey('multi_select_count');
  static const Key clear = ValueKey('multi_select_clear');
  static const Key forwardEach = ValueKey('multi_select_forward_each');
  static const Key forwardBundle = ValueKey('multi_select_forward_bundle');
  static const Key export = ValueKey('multi_select_export');
}
