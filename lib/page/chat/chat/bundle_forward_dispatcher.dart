/// 合并转发发送编排（chat_history_bundle_v1 / Central Wiring）。
///
/// 把 W2-G 的 [HistoryBundleBuilder]/[bindBundleAttachmentTasks] 与既有
/// 单条转发出网机制（MessageRepo.insert(outbound:true) → MessageRetry
/// 扫描出网）接到多选 action bar 的 `onForwardBundle` typed callback
/// （计划 §12 第 2/3 步）。发送语义与 send_to_provider 单条转发同构：
/// - 每目标会话单独构建 bundle（§4.5），附件经
///   [BundleAttachmentForwarder] 适配器重传/重封装（E2EE 接
///   `AttachmentForward.reSeal/reSealImages`，明文接
///   `PlainAttachmentForward.reupload`），任一任务失败整条放弃（无半
///   转发状态，落库前失败）；
/// - 目标会话之间串行（§4.3 v1 口径）；成功目标不回滚不重发；
/// - 源消息 payload 一律从 DB 原行取（UI Message 只提供 id 与
///   `_e2ee_failed` 占位标记），禁止从 UI 对象搬运 payload。
library;

import 'package:flutter/cupertino.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart' as core;
import 'package:xid/xid.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/page/chat/send_to/send_to_page.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/service/events/message_events.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_admission.dart';
import 'package:imboy/modules/messaging/application/export/chat_export_entry.dart';
import 'package:imboy/modules/messaging/domain/selection/message_selectability.dart';
import 'package:imboy/modules/messaging/application/history_bundle/bundle_attachment_forwarder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_builder.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_source.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/modules/messaging/domain/message_status.dart';
import 'package:imboy/service/e2ee/attachment_forward.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/attachment_plain_forward.dart';

/// 客户端发送前安全边（合同 §3.1：jsone 字节口径残差，W3-L F-4）。
const int kBundleClientSafetyMarginBytes = 64 * 1024;

/// 客户端发送前 payload 软上限：256KiB 合同边界 − 64KiB 安全边 = 192KiB。
/// 服务端仍按 256KiB 权威校验；本边仅让客户端在边界抖动时先行失败。
int bundleSoftPayloadLimitBytes() =>
    HistoryBundleContract.maxPayloadBytes - kBundleClientSafetyMarginBytes;

/// 单目标失败记录（稳定错误码，不含 PII）。
class BundleForwardTargetFailure {
  const BundleForwardTargetFailure(this.targetUk3, this.errorCode);

  final String targetUk3;
  final String errorCode;
}

/// 一次合并转发的执行报告。
class BundleForwardReport {
  const BundleForwardReport({
    required this.successCount,
    required this.failures,
  });

  final int successCount;
  final List<BundleForwardTargetFailure> failures;

  bool get allSuccess => failures.isEmpty && successCount > 0;
}

/// 默认附件转发适配器：桥接既有 E2EE/明文重封装能力（零复制实现）。
class DefaultBundleAttachmentForwarder implements BundleAttachmentForwarder {
  const DefaultBundleAttachmentForwarder();

  @override
  Future<Map<String, dynamic>> forwardAttachment(
    BundleAttachmentForwardRequest request,
  ) async {
    final task = request.task;
    final sourcePayload = task.sourcePayload;
    // 明文附件：按目标 scope 重上传（plain 路径对 private scope 显式失败）。
    if (!AttachmentSealPolicy.carriesContentKey(sourcePayload)) {
      return PlainAttachmentForward.reupload(
        payload: sourcePayload,
        newMessageId: request.newMessageId,
        targetScope: request.targetScope,
        targetConversationId: request.targetConversationUk3,
      );
    }
    if (task.sourceMsgType == MessageType.imageMulti) {
      final images = await AttachmentForward.reSealImages(
        sourcePayload: sourcePayload,
        sourceMessageId: task.sourceMessageId,
        sourceChatType: task.sourceChatType,
        sourceFromUid: task.sourceFromUid,
        sourceToUid: task.sourceToUid,
        newMessageId: request.newMessageId,
        targetScope: request.targetScope,
        targetConversationId: request.targetConversationUk3,
        forwarderUid: request.forwarderUid,
      );
      return SendToNotifier.applyForwardedImages(sourcePayload, images);
    }
    final forwarded = await AttachmentForward.reSeal(
      sourcePayload: sourcePayload,
      sourceMessageId: task.sourceMessageId,
      sourceChatType: task.sourceChatType,
      sourceFromUid: task.sourceFromUid,
      sourceToUid: task.sourceToUid,
      newMessageId: request.newMessageId,
      targetScope: request.targetScope,
      targetConversationId: request.targetConversationUk3,
      forwarderUid: request.forwarderUid,
    );
    return SendToNotifier.applyForwardedAttachment(sourcePayload, forwarded);
  }
}

/// 多选 action bar「合并转发」按钮动作策略（计划 §12.5：按动作策略分别
/// enable/disable，而非统一 selectable）。flag 关闭恒 false；有选中项且
/// 全部可合并（类型桶 + 状态 + 焚毁 + E2EE 失败）且条数 ≤50 才为 true。
bool bundleActionAllowedFor(Iterable<MessageSelectionTraits> traits) {
  if (!AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatHistoryBundleV1))
    return false;
  var count = 0;
  for (final t in traits) {
    count++;
    if (count > HistoryBundleContract.maxEntries) return false;
    if (t.e2eeFailed || t.burnReadAt > 0) return false;
    switch (t.status) {
      case MessageStatus.sending:
      case MessageStatus.error:
      case MessageStatus.revoked:
        return false;
      case MessageStatus.sent:
      case MessageStatus.delivered:
      case MessageStatus.seen:
        break;
    }
    if (!HistoryBundleBuilder.isTypeBundleAdmissible(t.msgType)) return false;
  }
  return count > 0;
}

/// 多选 action bar「导出」按钮动作策略：flag 开启 + 全部选中项过 W1-C
/// 导出准入矩阵。
bool exportActionAllowedFor(Iterable<MessageSelectionTraits> traits) {
  if (!AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1))
    return false;
  var count = 0;
  for (final t in traits) {
    count++;
    final entry = ChatExportEntry(
      msgType: t.msgType ?? '',
      senderName: '',
      createdAt: DateTime.now(),
      status: t.status,
      e2eeFailedPlaceholder: t.e2eeFailed,
      burnAfterRead: t.burnReadAt > 0,
    );
    if (!evaluateChatExportAdmission(entry).allowed) return false;
  }
  return count > 0;
}

/// 合并转发发送编排器。
class BundleForwardDispatcher {
  BundleForwardDispatcher({
    BundleAttachmentForwarder? attachmentForwarder,
    Future<MessageModel?> Function(String messageId, String chatType)?
    messageFetcher,
    Future<void> Function(MessageModel model, String chatType)? messageInserter,
    String Function()? forwarderUidResolver,
  }) : _attachmentForwarder =
           attachmentForwarder ?? const DefaultBundleAttachmentForwarder(),
       _messageFetcher = messageFetcher ?? _defaultMessageFetcher,
       _messageInserter = messageInserter ?? _defaultMessageInserter,
       _forwarderUidResolver = forwarderUidResolver ?? _defaultForwarderUid;

  static Future<MessageModel?> _defaultMessageFetcher(
    String messageId,
    String chatType,
  ) =>
      MessageRepo(tableName: MessageRepo.getTableName(chatType))
          .find(messageId);

  static Future<void> _defaultMessageInserter(
    MessageModel model,
    String chatType,
  ) =>
      MessageRepo(tableName: MessageRepo.getTableName(chatType))
          .insert(model, outbound: true);

  static String _defaultForwarderUid() => UserRepoLocal.to.currentUid;

  final BundleAttachmentForwarder _attachmentForwarder;
  final Future<MessageModel?> Function(String messageId, String chatType)
  _messageFetcher;
  final Future<void> Function(MessageModel model, String chatType)
  _messageInserter;
  final String Function() _forwarderUidResolver;

  /// 多选 action bar「合并转发」入口（计划 §12 第 2 步）。
  ///
  /// flag 关闭：静默返回（按钮已按策略禁用，此处兜底 fail-closed）；
  /// 复用 SendToPage 目标选择 UI，经既有 `onConfirmedSend` 注入口执行
  /// 每目标构建+发送；全部成功 toast 后返回 true（页面 pop），任一失败
  /// toast 后返回 false（页面保留，用户可重开重试）。
  static Future<void> forwardAsHistoryBundle(
    BuildContext context, {
    required List<core.Message> messages,
    required String sourceChatType,
    String? title,
  }) async {
    if (messages.isEmpty) return;
    if (!AppFeatureRegistry.isRolloutFlagEnabled(
      FeatureKeys.chatHistoryBundleV1,
    )) {
      return;
    }
    await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xLarge),
        child: SendToPage(
          msg: messages.first,
          onConfirmedSend: (targets) async {
            final report = await BundleForwardDispatcher().sendToTargets(
              targets,
              messages,
              sourceChatType: sourceChatType,
              title: title,
            );
            if (report.allSuccess) {
              AppLoading.showToast(
                t.chat.forwardedToChats(count: targets.length),
              );
            } else {
              AppLoading.showError(t.common.sendFailed);
            }
            return report.allSuccess;
          },
        ),
      ),
    );
  }

  /// 对每个目标会话串行构建并发送 bundle（§4.3/§4.5）。
  Future<BundleForwardReport> sendToTargets(
    List<ConversationModel> targets,
    List<core.Message> sourceMessages, {
    required String sourceChatType,
    String? title,
  }) async {
    final failures = <BundleForwardTargetFailure>[];
    final chatType = MessageFlowType.normalize(sourceChatType);

    // 1. 源消息快照输入：payload 一律取 DB 原行；UI metadata 只提供
    //    E2EE 失败占位标记（mapper 产物，DB 行不含）。
    final e2eeFailedIds = <String>{
      for (final m in sourceMessages)
        if (m.metadata?['_e2ee_failed'] == true) m.id,
    };
    final sources = <HistoryBundleSourceMessage>[];
    for (final m in sourceMessages) {
      final model = await _messageFetcher(m.id, chatType);
      if (model == null) {
        // 源行已不存在（会话被清等）：整体放弃，不做部分 bundle。
        failures.add(
          BundleForwardTargetFailure(
            '',
            HistoryBundleBuildErrorCode.invalidTarget,
          ),
        );
        return BundleForwardReport(successCount: 0, failures: failures);
      }
      final payload = model.payloadMap;
      final burn = payload['burn_read_at'];
      sources.add(
        HistoryBundleSourceMessage(
          msgType: model.msgType,
          sourceMessageId: model.id,
          sourceChatType: model.type ?? chatType,
          sourceFromUid: model.fromId,
          sourceToUid: model.toId,
          sentAtMs: model.createdAt,
          status: _domainStatusFromCore(model.typesStatus),
          payload: payload,
          e2eeFailedPlaceholder: e2eeFailedIds.contains(model.id),
          burnReadAtMs: burn is int ? burn : 0,
        ),
      );
    }

    // 2. 准入预检（目标无关，一次失败全部放弃；无半转发状态）。
    final firstUk3 = targets.first.uk3;
    final probe = HistoryBundleBuilder.buildForTarget(
      firstUk3,
      sources,
      title: title,
    );
    if (probe is HistoryBundleBuildFailureResult) {
      failures.add(
        BundleForwardTargetFailure(firstUk3, probe.failure.errorCode),
      );
      return BundleForwardReport(successCount: 0, failures: failures);
    }

    // 3. 每目标构建 + 附件重封装 + 落库出网（目标间串行，§4.3 v1）。
    var successCount = 0;
    for (final target in targets) {
      try {
        await _sendToTarget(target, sources, chatType: chatType, title: title);
        successCount++;
      } on BundleForwardException catch (e) {
        failures.add(BundleForwardTargetFailure(target.uk3, e.code));
      } on Exception catch (_) {
        // 附件下载/上传等异常：稳定码归一（不落库、无半转发状态）。
        failures.add(
          BundleForwardTargetFailure(
            target.uk3,
            HistoryBundleBuildErrorCode.payloadTooLarge,
          ),
        );
      }
    }
    return BundleForwardReport(successCount: successCount, failures: failures);
  }

  Future<void> _sendToTarget(
    ConversationModel target,
    List<HistoryBundleSourceMessage> sources, {
    required String chatType,
    String? title,
  }) async {
    final result = HistoryBundleBuilder.buildForTarget(
      target.uk3,
      sources,
      title: title,
    );
    if (result is HistoryBundleBuildFailureResult) {
      throw BundleForwardException(result.failure.errorCode);
    }
    final success = (result as HistoryBundleBuildSuccessResult).success;
    var bundle = success.bundle;

    final uid = _forwarderUidResolver();
    final messageId = Xid().toString();
    final scope = ChatAttachmentHandler.deriveUploadScope(
      conversationUk3: target.uk3,
      currentUid: uid,
      peerId: target.peerId,
      type: chatType,
    );
    for (final task in success.attachmentTasks) {
      final request = bindBundleAttachmentTasks(
        tasks: [task],
        newMessageId: messageId,
        targetScope: scope.scope,
        // 重封装 targetConversationId 绑定与单条转发同一真值：
        // scope.scopeRef（c2c:'c2c:<min>:<max>' / group:gid），非 uk3。
        targetConversationUk3: scope.scopeRef ?? target.uk3,
        forwarderUid: uid,
      ).single;
      final payload = await _attachmentForwarder.forwardAttachment(request);
      bundle = bundle.withEntryPayload(task.entryIndex, payload);
    }

    // 尺寸复检（附件写回后）：先合同 256KiB 硬边界，再客户端 192KiB 软边
    // （W3-L F-4：jsone 字节口径残差，客户端先行失败）。
    final bytes = bundle.serializedByteLength;
    final hardError = validateBundlePayloadSize(bytes);
    if (hardError != null) {
      throw BundleForwardException(hardError);
    }
    if (bytes > bundleSoftPayloadLimitBytes()) {
      throw BundleForwardException(HistoryBundleBuildErrorCode.payloadTooLarge);
    }

    final model = MessageModel(
      messageId,
      autoId: 0,
      type: chatType,
      status: 10, // 发送中；MessageRetry 扫描出网（与单条转发同机制）
      fromId: uid,
      toId: target.peerId,
      payload: bundle.toJson(),
      createdAt: DateTimeHelper.millisecond(),
      isAuthor: 1,
      conversationUk3: target.uk3,
      msgType: HistoryBundleContract.msgType,
    );
    await _messageInserter(model, chatType);
    AppEventBus.fire(
      MessageSendRequestedEvent(message: model, conversationUk3: target.uk3),
    );
  }
}

/// flutter_chat_core 状态 → 域状态（与 messageSelectionTraitsOf 同口径：
/// null/sent → sent；core 无 revoked，DB 行在途态已在 typesStatus 归一）。
MessageStatus _domainStatusFromCore(core.MessageStatus? status) {
  return switch (status) {
    core.MessageStatus.error => MessageStatus.error,
    core.MessageStatus.sending => MessageStatus.sending,
    core.MessageStatus.delivered => MessageStatus.delivered,
    core.MessageStatus.seen => MessageStatus.seen,
    core.MessageStatus.sent || null => MessageStatus.sent,
  };
}

/// 发送编排的稳定错误异常（错误码 = [HistoryBundleBuildErrorCode]）。
class BundleForwardException implements Exception {
  const BundleForwardException(this.code);

  final String code;
}
