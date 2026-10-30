import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:xid/xid.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/channel_decimal_id.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/service/e2ee/attachment_forward.dart';
import 'package:imboy/service/attachment_plain_forward.dart';
import 'package:imboy/service/e2ee/attachment_seal_policy.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';

import 'package:imboy/service/events/events.dart';

/// 发送给 页面状态
class SendToState {
  final List<ConversationModel> conversations;
  final List<ConversationModel> searchResults;
  final List<ConversationModel> selectedContacts;

  const SendToState({
    this.conversations = const [],
    this.searchResults = const [],
    this.selectedContacts = const [],
  });

  SendToState copyWith({
    List<ConversationModel>? conversations,
    List<ConversationModel>? searchResults,
    List<ConversationModel>? selectedContacts,
  }) {
    return SendToState(
      conversations: conversations ?? this.conversations,
      searchResults: searchResults ?? this.searchResults,
      selectedContacts: selectedContacts ?? this.selectedContacts,
    );
  }
}

/// 发送消息逻辑控制器
class SendToNotifier extends Notifier<SendToState> {
  @override
  SendToState build() => const SendToState();

  String _normalizeConversationType(String? type) {
    return MessageFlowType.normalize(type);
  }

  void clearSelection() => state = const SendToState();

  /// 最近聊天
  ///
  /// 群会话的 `title` 列在库里通常是空的 —— 真实群名是会话页 load 时
  /// `ConversationNotifier.computeTitle` 现算出来的（无名群还要回落成员昵称
  /// 拼接，那一跳只存内存态 `computeTitle`，刻意不落库）。本页直读 SQLite，
  /// 缺了这一跳就会把每个群都兜成「未命名」，用户搜真实群名也永远搜不出来。
  /// 只对缺名的补算，复用同一份口径，别在这里另写一套。
  Future<void> conversationsList() async {
    final conversations = await (ConversationRepo()).list(limit: 100);
    final notifier = ref.read(conversationProvider.notifier);
    for (final conversation in conversations) {
      if (conversation.resolvedTitle.isEmpty) {
        conversation.title = await notifier.computeTitle(conversation);
      }
    }
    state = state.copyWith(
      conversations: conversations,
      searchResults: List.from(conversations),
    );
  }

  /// 构造转发消息的 payload。
  ///
  /// 源消息 metadata 必须**先**展开、再被目标会话字段覆盖。反过来（原实现把
  /// `...metadata` 放在最后）会让源会话的 `peer_id` / `conversation_uk3`
  /// 盖掉目标值 —— 真机实测：从群里转发到单聊，发出的 payload 仍带
  /// `peer_id: <群 gid>` 与 `conversation_uk3: C2G_...`，消息归属错乱。
  @visibleForTesting
  static Map<String, dynamic> buildForwardPayload({
    required Map<String, dynamic>? sourceMetadata,
    required String text,
    required Object peerId,
    required String conversationUk3,
  }) {
    return <String, dynamic>{
      ...?sourceMetadata,
      'text': text,
      'peer_id': peerId is String ? decimalIdForWire(peerId) : peerId,
      'conversation_uk3': conversationUk3,
      // D01 冻结合同 R05F-2：burn_read_at 永不进发送 payload。转发源是
      // 本地 DB 的 metadata，可能带接收方已读时刻；不剥离则新接收方副本
      // 以旧已读时刻提前开烧。
    }..remove('burn_read_at');
  }

  /// 推导转发消息的顶层 msg_type。
  ///
  /// 顶层 msg_type 为空时服务端直接回 `action=invalid_message`，客户端
  /// `toTypeMessage` 也判为「msg_type 为空或无效」→ 消息显示「[无效消息类型]」
  /// 并进入无限重试（真机实测每 5~10s 重发一次，服务端每次都拒）。
  ///
  /// 历史别名（如 `channel_message`）在这里换成现役类型：转发不应把
  /// 已废弃、无渲染器的值继续传播到新会话。
  @visibleForTesting
  static String resolveForwardMsgType(Map<String, dynamic>? sourceMetadata) {
    final raw = parseModelString(sourceMetadata?['msg_type']);
    return raw.isEmpty ? 'text' : MessageTypeNormalizer.aliasOf(raw);
  }

  /// 目标会话的 payload 会不会被加密——与**真正决定出网加密的那一处**
  /// （`chat_network_service.encryptPayload`）同一组判据：
  /// 群级 Megolm 强制门（含 `EncryptionModeService.current.requiresEncryption`
  /// 硬闸前置，P0-B B4）+ `E2EEService.shouldEncryptOutgoingPayload`（二次
  /// 复核口径 `interactiveConfirm=false`：转发是批量动作，不触发 AI 首次
  /// 确认弹窗）。转发重封装的 seal 判定与消息出网加密判定因此完全一致。
  @visibleForTesting
  static Future<bool> targetPayloadWillBeEncrypted({
    required String chatType,
    required String peerId,
  }) async {
    final bool groupMegolm =
        chatType == 'C2G' &&
        EncryptionModeService.current.requiresEncryption &&
        await GroupSessionService.to.isGroupE2EE(peerId);
    if (groupMegolm) return true;
    return E2EEService.shouldEncryptOutgoingPayload(chatType, toId: peerId);
  }

  /// 加密附件转发失败 → 用户可见文案（既有 i18n 机制）。
  ///
  /// - 明文目标域拒绝 / 源不可解密 → 专用键（10 locale）；
  /// - 下载/上传等基础设施失败 → 既有通用 [Translatables.common.sendFailed]
  ///   （send_to_page 对 failCount 的汇总提示同源）。
  @visibleForTesting
  static String forwardFailureToast(String reason) {
    switch (reason) {
      case 'attachment_forward_plaintext_target':
        return t.common.e2eeErrForwardPlaintextTarget;
      case 'attachment_forward_undecryptable':
      case 'attachment_forward_open_failed':
        return t.common.e2eeErrForwardUndecryptable;
      default:
        return t.common.sendFailed;
    }
  }

  /// 把重封装产物覆盖进转发 payload 的附件字段（纯函数）。
  ///
  /// [ForwardedAttachment.objectKey] 覆盖 `uri`（接收侧 toTypeMessage 的
  /// 下载入口）；descriptor / file_hash256 / size 同步替换；thumb 按
  /// metadata['thumb'] 的既有形状回填——视频是 map（EntityImage json，
  /// 更新 `uri`+`file_hash256`），位置是 object_key 字符串（整体替换）。
  /// 上传侧 `handleVideoUpload`/`handleLocationSelection` 的写入形状是
  /// 这里的唯一真值源。
  @visibleForTesting
  static Map<String, dynamic> applyForwardedAttachment(
    Map<String, dynamic> base,
    ForwardedAttachment forwarded,
  ) {
    final out = Map<String, dynamic>.from(base)
      ..['uri'] = forwarded.objectKey
      ..[AttachmentSealPolicy.descriptorPayloadKey] = forwarded.descriptor
          .toMap()
      ..['file_hash256'] = forwarded.fileHash256
      ..['size'] = forwarded.plainSize;
    if (forwarded.thumbObjectKey != null) {
      final thumb = out['thumb'];
      if (thumb is Map) {
        out['thumb'] = Map<String, dynamic>.from(thumb)
          ..['uri'] = forwarded.thumbObjectKey
          ..['file_hash256'] = forwarded.thumbFileHash256;
      } else {
        // 位置消息：thumb 即 object_key 字符串。
        out['thumb'] = forwarded.thumbObjectKey;
      }
    }
    return out;
  }

  /// 多图转发：用逐图重封装结果整体改写 `images[]`（纯函数）。
  /// 元素形状由 [AttachmentForward.reSealImages] 保证（uri / file_hash256 /
  /// size / descriptor 已替换，明文项原样）。
  @visibleForTesting
  static Map<String, dynamic> applyForwardedImages(
    Map<String, dynamic> base,
    List<Map<String, dynamic>> images,
  ) => Map<String, dynamic>.from(base)
    ..[AttachmentSealPolicy.imagesPayloadKey] = images
    ..['total'] = images.length;

  /// 发送消息
  Future<bool> sendMsg(
    ConversationModel conversation,
    Message msg, {
    void Function(MessageModel)? onQueued,
    bool Function()? isCurrent,
  }) async {
    try {
      if (isCurrent != null && !isCurrent()) return false;
      // 获取并归一化会话类型，历史脏值统一按 C2C 处理
      final chatType = _normalizeConversationType(conversation.type);

      final forwarderUid = UserRepoLocal.to.currentUid;
      final sourceMetadata = msg.metadata;
      final sourceChatType = AttachmentForward.chatTypeFromConversationUk3(
        parseModelString(sourceMetadata?['conversation_uk3']),
      );
      // 只有带 content key 的源才触碰 E2EE 策略判定（PolicyGate 未就绪会
      // fail-closed 抛出）——纯文本/明文附件路径与旧行为零偏差。
      final decision = AttachmentSealPolicy.carriesContentKey(sourceMetadata)
          ? AttachmentForward.decide(
              sourceMetadata: sourceMetadata,
              targetPayloadWillBeEncrypted: await targetPayloadWillBeEncrypted(
                chatType: chatType,
                peerId: conversation.peerId.toString(),
              ),
              sourceMessageId: msg.id,
              sourceChatType: sourceChatType,
              sourceFromUid: msg.authorId,
              sourceToUid: parseModelString(sourceMetadata?['peer_id']),
            )
          : const ForwardNotSealed();

      // 加密附件：按目标会话重封装（本地解密 → 新 key/nonce/绑定 →
      // 重上传）。成功后新消息 id 即上传锚点（与发送侧同序：先上传拿
      // meta、再建消息）。失败（含明文目标域/源不可解密）抛
      // [AttachmentForwardException] —— 在落库**之前**，杜绝半转发状态。
      final String messageId = Xid().toString();
      // 目标会话上传 scope：加密重封装与明文重上传必须同源（scope 与绑定值
      // 一旦分歧就是隐性错配），故在分支外算一次。
      final scope = ChatAttachmentHandler.deriveUploadScope(
        conversationUk3: conversation.uk3,
        currentUid: forwarderUid,
        peerId: conversation.peerId.toString(),
        type: chatType,
      );
      final Map<String, dynamic> payload;
      switch (decision) {
        case ForwardNotSealed():
          final base = buildForwardPayload(
            sourceMetadata: sourceMetadata,
            text: msg is TextMessage ? msg.text : '',
            peerId: conversation.peerId,
            conversationUk3: conversation.uk3,
          );
          // 明文附件（无 content key）不重封装，但**必须重上传**：源 uri 是
          // 原会话 scope 下的 object_key，读取授权按 scope 判成员资格，原样
          // 复制等于投递一条「看得见、点开 403」的消息。
          payload = PlainAttachmentForward.needsReupload(sourceMetadata)
              ? await PlainAttachmentForward.reupload(
                  payload: base,
                  newMessageId: messageId,
                  targetScope: scope.scope,
                  targetConversationId: scope.scopeRef,
                )
              : base;
        case ForwardRejected(:final reason):
          throw AttachmentForwardException(reason);
        case ForwardReSeal():
          final base = buildForwardPayload(
            sourceMetadata: sourceMetadata,
            text: msg is TextMessage ? msg.text : '',
            peerId: conversation.peerId,
            conversationUk3: conversation.uk3,
          );
          final sourcePayload = Map<String, dynamic>.from(
            sourceMetadata ?? const {},
          );
          final sourceToUid = parseModelString(sourceMetadata?['peer_id']);
          // 多图：images[i] 各自重封装（同一新绑定）；单附件：顶层 descriptor。
          if (sourcePayload[AttachmentSealPolicy.imagesPayloadKey] is List) {
            payload = applyForwardedImages(
              base,
              await AttachmentForward.reSealImages(
                sourcePayload: sourcePayload,
                sourceMessageId: msg.id,
                sourceChatType: sourceChatType,
                sourceFromUid: msg.authorId,
                sourceToUid: sourceToUid,
                newMessageId: messageId,
                targetScope: scope.scope,
                targetConversationId: scope.scopeRef ?? '',
                forwarderUid: forwarderUid,
              ),
            );
          } else {
            payload = applyForwardedAttachment(
              base,
              await AttachmentForward.reSeal(
                sourcePayload: sourcePayload,
                sourceMessageId: msg.id,
                sourceChatType: sourceChatType,
                sourceFromUid: msg.authorId,
                sourceToUid: sourceToUid,
                newMessageId: messageId,
                targetScope: scope.scope,
                targetConversationId: scope.scopeRef ?? '',
                forwarderUid: forwarderUid,
              ),
            );
          }
      }
      final msgType = resolveForwardMsgType(sourceMetadata);

      // 创建 MessageModel（id 与重封装上传锚点同值；NotSealed 分支为全新 Xid）
      final msgModel = MessageModel(
        messageId,
        autoId: 0,
        type: chatType,
        status: 10, // 发送中
        fromId: UserRepoLocal.to.currentUid,
        toId: conversation.peerId,
        payload: payload,
        createdAt: DateTimeHelper.millisecond(),
        isAuthor: 1,
        conversationUk3: conversation.uk3,
        msgType: msgType,
      );

      // 添加消息到数据库
      final msgRepo = MessageRepo(
        tableName: MessageRepo.getTableName(chatType),
      );
      if (isCurrent != null && !isCurrent()) return false;
      await msgRepo.insert(msgModel);
      if (isCurrent != null && !isCurrent()) return false;
      onQueued?.call(msgModel);

      // 通过事件总线触发消息发送
      AppEventBus.fire(
        MessageSendRequestedEvent(
          message: msgModel,
          conversationUk3: conversation.uk3,
        ),
      );

      return true;
    } on AttachmentForwardException catch (e) {
      // 转发失败（明文目标域 / 源不可解密 / 下载上传失败）：落库前抛出，
      // 无半转发状态；重试 = 全新消息 id + 全新密钥重封装，幂等。
      // 日志按 Finding 014 口径只落稳定码，不输出异常对象。
      debugPrint('[send_to_provider] forward blocked, reason=${e.reason}');
      AppLoading.showError(forwardFailureToast(e.reason));
    } on PlainAttachmentForwardException catch (e) {
      // 明文附件重上传失败：同样在落库前失败。稳定码与加密路径同一组映射，
      // 用户看到的文案一致（下载/上传失败 → 通用发送失败）。
      debugPrint(
        '[send_to_provider] plain forward blocked, reason=${e.reason}',
      );
      AppLoading.showError(forwardFailureToast(e.reason));
    } on Exception catch (e) {
      debugPrint('[send_to_provider] block error: $e');
    }
    return false;
  }

  /// 转发给所有已选联系人，返回失败数量
  Future<int> sendToSelected(Message msg) async {
    final targets = state.selectedContacts;
    var failCount = 0;
    for (final contact in targets) {
      final ok = await sendMsg(contact, msg);
      if (!ok) failCount++;
    }
    return failCount;
  }

  /// 搜索
  void search(String query) {
    final results = query.isEmpty
        ? List<ConversationModel>.from(state.conversations)
        : state.conversations
              .where(
                (contact) =>
                    // 同 send_to_page：按 displayTitle 匹配。裸 title 对群会话
                    // 可能是空串，那样用户搜群名永远搜不出来。
                    contact.displayTitle.toLowerCase().contains(
                      query.toLowerCase(),
                    ),
              )
              .toList();
    state = state.copyWith(searchResults: results);
  }

  /// 切换联系人选择
  void toggleContactSelection(ConversationModel contact) {
    final selected = List<ConversationModel>.from(state.selectedContacts);
    final exists = selected.any((element) => element.id == contact.id);
    if (exists) {
      selected.removeWhere((element) => element.id == contact.id);
    } else {
      selected.add(contact);
    }
    state = state.copyWith(selectedContacts: selected);
  }
}

/// 发送消息 Provider
final sendToProvider = NotifierProvider<SendToNotifier, SendToState>(
  SendToNotifier.new,
);
