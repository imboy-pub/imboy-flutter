/// 合并转发发送编排（chat_history_bundle_v1 / Central Wiring）。
///
/// 把 W2-G 的 [HistoryBundleBuilder]/[bindBundleAttachmentTasks] 与既有
/// 单条转发出网机制（MessageRepo.insert(outbound:true) → 立即经
/// `ChatNetworkService.sendWsMsg` 主动派发；未及出网的 sending 行仍由
/// MessageRetry 扫描 / 会话页补发兜底）接到多选 action bar 的
/// `onForwardBundle` typed callback（计划 §12 第 2/3 步）。发送语义与
/// send_to_provider 单条转发同构：
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
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
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
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_sanitizer.dart';
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
  if (!AppFeatureRegistry.isRolloutFlagEnabled(
    FeatureKeys.chatHistoryBundleV1,
  )) {
    return false;
  }
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
  if (!AppFeatureRegistry.isRolloutFlagEnabled(FeatureKeys.chatExportShareV1)) {
    return false;
  }
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
/// 转发副本出网派发口（方案 B 变体，chat-multi-20261111 产品缺陷修复）。
///
/// 缺陷：管线落库（status=10）后只 fire `MessageSendRequestedEvent`——
/// 该事件全仓无消费者，副本只能靠重进会话页 / 重启 / 重连的补发通道
/// 偶然出网，UI 却报成功。修复：落库后立即经
/// [BundleForwardDispatcher.defaultForwardDispatch]（即
/// `ChatNetworkService.sendWsMsg`）主动派发，加密判定 / 策略门 /
/// deep-seal 闸 / 上传认领 / 重试闭环全部复用现行链路，零旁路。
typedef ForwardCopyDispatch = Future<bool> Function(MessageModel model);

class BundleForwardDispatcher {
  BundleForwardDispatcher({
    BundleAttachmentForwarder? attachmentForwarder,
    Future<MessageModel?> Function(String messageId, String chatType)?
    messageFetcher,
    Future<void> Function(MessageModel model, String chatType)? messageInserter,
    String Function()? forwarderUidResolver,
    Future<bool> Function(String chatType, String peerId)?
    targetEncryptedResolver,
    ForwardCopyDispatch? wsDispatcher,
    HistoryBundleBuildResult Function(
      String targetUk3,
      List<HistoryBundleSourceMessage> sources, {
      String? title,
    })?
    bundleBuilder,
  }) : _attachmentForwarder =
           attachmentForwarder ?? const DefaultBundleAttachmentForwarder(),
       _messageFetcher = messageFetcher ?? _defaultMessageFetcher,
       _messageInserter = messageInserter ?? _defaultMessageInserter,
       _forwarderUidResolver = forwarderUidResolver ?? _defaultForwarderUid,
       _targetEncryptedResolver =
           targetEncryptedResolver ?? _defaultTargetEncrypted,
       _wsDispatcher = wsDispatcher ?? defaultForwardDispatch,
       _bundleBuilder = bundleBuilder ?? HistoryBundleBuilder.buildForTarget;

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

  static Future<bool> _defaultTargetEncrypted(String chatType, String peerId) {
    return SendToNotifier.targetPayloadWillBeEncrypted(
      chatType: chatType,
      peerId: peerId,
    );
  }

  /// 副本出网派发默认实现：走 `ChatNetworkService.sendWsMsg` —— 与聊天页
  /// 加载补发 status=10 行（`_pageMessages`）同一条现行链路。bundle 的
  /// msg_type 由 sendWsMsg / encryptPayload 的 bundle 感知分支处理
  /// （A4FIX F3 终检 / 群级 E2EE 强制门原样生效）。
  ///
  /// 生产默认路径（W5 G4-6）：构造未注入 [ForwardCopyDispatch] 时，全部
  /// 副本都经它派发；故不加 @visibleForTesting（那会禁止生产引用）。
  /// 测试经构造注入替身 dispatcher，不依赖本入口。
  static Future<bool> defaultForwardDispatch(MessageModel model) =>
      const ChatNetworkService().sendWsMsg(model);

  final BundleAttachmentForwarder _attachmentForwarder;
  final Future<MessageModel?> Function(String messageId, String chatType)
  _messageFetcher;
  final Future<void> Function(MessageModel model, String chatType)
  _messageInserter;
  final String Function() _forwarderUidResolver;
  final Future<bool> Function(String chatType, String peerId)
  _targetEncryptedResolver;
  final ForwardCopyDispatch _wsDispatcher;
  final HistoryBundleBuildResult Function(
    String targetUk3,
    List<HistoryBundleSourceMessage> sources, {
    String? title,
  })
  _bundleBuilder;

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
              // F1（A4FIX 复审）：失败文案与单条转发同一映射口径
              // （SendToNotifier.forwardFailureToast）——策略性永久拒绝
              // （rejected_plaintext_target → e2eeErrForwardPlaintextTarget，
              // 既有键复用、无新 i18n）与瞬时基础设施失败（→ sendFailed）
              // 可辨识，避免用户对恒拒目标盲目重试。
              final code = report.failures.isEmpty
                  ? ''
                  : report.failures.first.errorCode;
              AppLoading.showError(SendToNotifier.forwardFailureToast(code));
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

    // 0. 空目标防御（W5 G4-2）：`targets.first` 对空列表抛 StateError
    //    （Error 不被 on Exception 捕获 → 未处理异步错误 + 模态卡死）。
    //    与 validateBatch 空目标同语义的稳定码 invalidTarget（目标标识
    //    缺失），以报告形态返回，不抛出。
    if (targets.isEmpty) {
      failures.add(
        const BundleForwardTargetFailure(
          '',
          HistoryBundleBuildErrorCode.invalidTarget,
        ),
      );
      return BundleForwardReport(successCount: 0, failures: failures);
    }

    // 1. 源消息快照输入：payload 一律取 DB 原行；UI metadata 只提供
    //    E2EE 失败占位标记（mapper 产物，DB 行不含）。
    final e2eeFailedIds = <String>{
      for (final m in sourceMessages)
        if (m.metadata?['_e2ee_failed'] == true) m.id,
    };
    List<HistoryBundleSourceMessage> sources;
    try {
      sources = <HistoryBundleSourceMessage>[];
      for (final m in sourceMessages) {
        final model = await _messageFetcher(m.id, chatType);
        if (model == null) {
          // 源行已不存在（会话被清等）：整体放弃，不做部分 bundle
          // （W5 G4-7：专用稳定码 sourceMissing，与目标标识缺失分离）。
          failures.add(
            const BundleForwardTargetFailure(
              '',
              HistoryBundleBuildErrorCode.sourceMissing,
            ),
          );
          return BundleForwardReport(successCount: 0, failures: failures);
        }
        final payload = model.payloadMap;
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
            // W5 G4-1（冻结合同 §4.4）：burn_read_at 有 int/String 两种
            // 落库形态，复用 ChatBurnService 既有宽松解析（禁自造第三套）；
            // 仅按 int 解析会让字符串形态落 0，绕过 rejectedBurnAfterRead
            // 焚毁闸。
            burnReadAtMs: ChatBurnService.burnReadAtMsFromPayload(payload),
          ),
        );
      }
    } on Object catch (e) {
      // W5 G4-3（阶段 1）：DB 异常不得穿透本方法（否则未处理异步错误 +
      // 模态卡死）；归一到 F4 sendFailed 同口径稳定码，日志只记类型
      // （Finding 014）。整体放弃，无半转发状态。
      iPrint(
        '⚠️ [BundleForwardDispatcher] 源行快照失败(整体放弃): '
        'errType=${e.runtimeType}',
      );
      failures.add(
        const BundleForwardTargetFailure(
          '',
          HistoryBundleBuildErrorCode.sendFailed,
        ),
      );
      return BundleForwardReport(successCount: 0, failures: failures);
    }

    // 2. 准入预检（目标无关，一次失败全部放弃；无半转发状态）。
    final firstUk3 = targets.first.uk3;
    try {
      final probe = _bundleBuilder(firstUk3, sources, title: title);
      if (probe is HistoryBundleBuildFailureResult) {
        failures.add(
          BundleForwardTargetFailure(firstUk3, probe.failure.errorCode),
        );
        return BundleForwardReport(successCount: 0, failures: failures);
      }
    } on Object catch (e) {
      // W5 G4-3（阶段 2）：probe 构建异常同口径归一（F4 sendFailed），
      // 只记类型不输出异常对象（Finding 014）。
      iPrint(
        '⚠️ [BundleForwardDispatcher] 准入预检异常(整体放弃): '
        'errType=${e.runtimeType}',
      );
      failures.add(
        BundleForwardTargetFailure(
          firstUk3,
          HistoryBundleBuildErrorCode.sendFailed,
        ),
      );
      return BundleForwardReport(successCount: 0, failures: failures);
    }

    // 3. 每目标构建 + 附件重封装 + 落库出网（目标间串行，§4.3 v1）。
    var successCount = 0;
    for (final target in targets) {
      try {
        await _sendToTarget(target, sources, title: title);
        successCount++;
      } on BundleForwardException catch (e) {
        failures.add(BundleForwardTargetFailure(target.uk3, e.code));
      } on Exception catch (_) {
        // F4（A4FIX 复审）：附件下载/上传等基础设施失败（含 resolver 的
        // policy_not_initialized）归一专用稳定码——不再误标 payloadTooLarge
        // （尺寸语义有专属判定），也不向日志泄漏异常对象（Finding 014）。
        // 不落库、无半转发状态。
        failures.add(
          BundleForwardTargetFailure(
            target.uk3,
            HistoryBundleBuildErrorCode.sendFailed,
          ),
        );
      }
    }
    return BundleForwardReport(successCount: successCount, failures: failures);
  }

  Future<void> _sendToTarget(
    ConversationModel target,
    List<HistoryBundleSourceMessage> sources, {
    String? title,
  }) async {
    // F2（A4FIX 复审）：scope/resolver/落库一律按**目标**会话类型归一
    // （与单条转发 send_to_provider 的 conversation.type 同口径）。
    // 源 chatType 只决定源消息 DB 行 fetch 表（sendToTargets 内）；SendToPage
    // 目标可为跨类型（源 C2C → 目标 C2G），把源类型灌进这里会同时污染
    // 上传 scope、加密判定（resolver）与插表。
    final targetChatType = MessageFlowType.normalize(target.type);
    final result = _bundleBuilder(target.uk3, sources, title: title);
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
      type: targetChatType,
    );
    // 明文目标闸（A4 审计 CRITICAL）：与单条转发 AttachmentForward.decide →
    // ForwardRejected 同语义 —— 带 content key 的源附件只允许进入加密目标；
    // 否则新 descriptor（content key）会以明文随 bundle 出网。判定与单条
    // 转发共用同一真值（SendToNotifier.targetPayloadWillBeEncrypted），
    // 且传**目标** chatType（F2）。
    var sealedSourceSeen = false;
    for (final task in success.attachmentTasks) {
      if (AttachmentSealPolicy.carriesContentKey(task.sourcePayload)) {
        sealedSourceSeen = true;
      }
    }
    if (sealedSourceSeen) {
      final encrypted = await _targetEncryptedResolver(
        targetChatType,
        target.peerId,
      );
      if (!encrypted) {
        throw BundleForwardException(
          HistoryBundleBuildErrorCode.rejectedPlaintextTarget,
        );
      }
    }
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
      // 写回净化（A4 审计 HIGH）：adapter 产物基于源 payload 拷贝，禁止
      // 字段不得随写回进入 bundle JSON（合同 §4.5）。唯一豁免 = 本次
      // 重封装新产生的目标绑定 attachment_descriptor（仅加密目标可达此
      // 路径，整包随后进密文，接收侧开封依赖它；§4.5 禁止的是源密钥）。
      bundle = bundle.withEntryPayload(
        task.entryIndex,
        sanitizeAttachmentWriteback(payload),
      );
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
      type: targetChatType,
      status: 10, // 发送中；MessageRetry 扫描出网（与单条转发同机制）
      fromId: uid,
      toId: target.peerId,
      payload: bundle.toJson(),
      createdAt: DateTimeHelper.millisecond(),
      isAuthor: 1,
      conversationUk3: target.uk3,
      msgType: HistoryBundleContract.msgType,
    );
    await _messageInserter(model, targetChatType);
    // 方案 B 变体：落库后立即主动派发（原 MessageSendRequestedEvent 全仓
    // 无消费者，副本只能靠重进会话页/重启的补发通道偶然出网）。派发结果
    // 不改判转发成败（E2EE-062 口径：策略/加密失败行保持 sending 留库，
    // 由补发通道在策略恢复后补发；瞬时 WS 失败已由 sendWithRetry 入重试
    // 闭环），只记类型不输出异常对象（Finding 014）。
    try {
      await _wsDispatcher(model);
    } on Object catch (e) {
      iPrint(
        '⚠️ [BundleForwardDispatcher] 副本派发提交失败(不影响落库): '
        'msgId=${model.id}, errType=${e.runtimeType}',
      );
    }
    // 回环可见性：与单条转发同款（见 send_to_provider.sendMsg）——目标
    // 会话正打开时，经入站消息同一 ingestion 事件（fireData 'Message'）
    // 让副本立即进入内存列表；未打开会话由 ChatPage 按 conversation_uk3
    // 过滤，为 no-op。
    try {
      AppEventBus.fireData(await model.toTypeMessage(), 'Message');
    } on Object catch (e) {
      iPrint(
        '⚠️ [BundleForwardDispatcher] 副本 UI 事件失败(不影响落库): '
        'msgId=${model.id}, errType=${e.runtimeType}',
      );
    }
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

/// 附件写回产物净化：BundleSanitizer 全键清理 + 目标绑定新 descriptor
/// 豁免回填（顶层与 images[] 两处；其余任何嵌套层仍被清理）。
///
/// 只读契约（W5 G2 并行）：sanitizer 输出一律视为只读（G2 侧嵌套层为
/// Map.unmodifiable），本函数对清理产物**重建新 map/list 再整体替换**，
/// 禁止原地改写任何嵌套结构；顶层 descriptor 回填也走重建式（双保险，
/// 两个 sanitizer 版本下均正确）。
Map<String, dynamic> sanitizeAttachmentWriteback(Map<String, dynamic> payload) {
  final sanitized = BundleSanitizer.sanitize(payload).cleaned;
  // 顶层重建式回填：不在 sanitized 顶层原位插 key（双保险）。
  final out = Map<String, dynamic>.of(sanitized);
  final desc = payload[AttachmentSealPolicy.descriptorPayloadKey];
  if (desc != null) {
    out[AttachmentSealPolicy.descriptorPayloadKey] = desc;
  }
  final images = payload[AttachmentSealPolicy.imagesPayloadKey];
  if (images is List) {
    // W5 G4-5：非 Map 元素不得原引用透传（未净化 + 与输入共享可变引用），
    // 一律取 cleaned images 里的净化后版本；仅 Map 元素做 descriptor
    // 豁免回填。整体重建新 list，不原地改写 sanitized 的嵌套结构。
    final sanitizedImages = sanitized[AttachmentSealPolicy.imagesPayloadKey];
    final cleanedElements = sanitizedImages is List ? sanitizedImages : null;
    final rebuiltImages = <Object?>[
      for (var i = 0; i < images.length; i++)
        if (images[i] is Map)
          _sanitizeImageWriteback(Map<String, dynamic>.from(images[i] as Map))
        else if (cleanedElements != null && i < cleanedElements.length)
          cleanedElements[i],
      // cleaned 缺对应下标（异常形态）时丢弃：宁缺毋透传原引用。
    ];
    out[AttachmentSealPolicy.imagesPayloadKey] = rebuiltImages;
  }
  return out;
}

Map<String, dynamic> _sanitizeImageWriteback(Map<String, dynamic> image) {
  final sanitized = BundleSanitizer.sanitize(image).cleaned;
  // 顶层重建式回填（同上：不在 sanitize 产物原位插 key）。
  final out = Map<String, dynamic>.of(sanitized);
  final desc = image[AttachmentSealPolicy.descriptorPayloadKey];
  if (desc != null) {
    out[AttachmentSealPolicy.descriptorPayloadKey] = desc;
  }
  return out;
}

/// 发送编排的稳定错误异常（错误码 = [HistoryBundleBuildErrorCode]）。
class BundleForwardException implements Exception {
  const BundleForwardException(this.code);

  final String code;
}
