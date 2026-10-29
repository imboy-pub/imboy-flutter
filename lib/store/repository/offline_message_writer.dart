import 'package:imboy/store/repository/offline_message_payload.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart' as func_helper;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/message_preview_text.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/model/message_columns.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/store/repository/message_repo_types.dart';

part 'offline_message_preview.dart';

/// 离线批量写入：消息/会话事务提交、重投快照恢复与提交后通知。
class OfflineMessageWriter {
  final SqliteService db;
  final ProviderContainer Function() getContainer;
  final String? Function() activeConversation;
  final String Function(String) resolveTable;
  final Future<void> Function(InsertedOfflineMessage) indexMessage;

  final Future<void> Function(
    String msgId, {
    int? convSeq,
    int? acceptedAt,
    Transaction? txn,
  })
  backfillServerOrderFacts;

  const OfflineMessageWriter({
    required this.db,
    required this.getContainer,
    required this.activeConversation,
    required this.resolveTable,
    required this.indexMessage,
    required this.backfillServerOrderFacts,
  });

  /// 批量插入离线消息
  Future<List<String>?> write(
    List<Map<String, dynamic>> messages, {
    Future<void> Function(Map<String, dynamic>)? onS2CMessage,
    bool trustedArchive = false,
  }) async {
    if (messages.isEmpty) return null;
    final session = trustedArchive ? authSessionReader.current : null;
    final endpoint = trustedArchive ? Env().apiBaseUrl : null;
    void requireCurrent() {
      if (session != null &&
          (!authSessionReader.isCurrent(session) ||
              Env().apiBaseUrl != endpoint)) {
        throw StateError('Archive session changed');
      }
    }

    requireCurrent();

    final List<String> ackMsgIds = [];
    final Set<String> ackIdSet = <String>{};
    void addAckId(String id) {
      if (id.isEmpty) return;
      if (ackIdSet.add(id)) {
        ackMsgIds.add(id);
      }
    }

    final List<InsertedOfflineMessage> inserted = [];
    final conversations = <ConversationModel>[];
    try {
      // 先收集 S2C 消息，在事务外处理
      final List<Map<String, dynamic>> s2cMessages = [];
      final List<Map<String, dynamic>> normalMessages = [];

      for (final msgData in messages) {
        final rawMsgId = msgData['msg_id'] ?? msgData['id'];
        final msgId = rawMsgId?.toString() ?? '';
        String type = (msgData['type'] ?? 'C2C').toString().toUpperCase();
        switch (type) {
          case 'C2C_SERVER_ACK':
            type = 'C2C';
            break;
          case 'C2G_SERVER_ACK':
            type = 'C2G';
            break;
          case 'S2C_SERVER_ACK':
            type = 'S2C';
            break;
        }

        if (msgId.isEmpty) {
          func_helper.iPrint('离线消息缺少id，跳过');
          continue;
        }

        // S2C 消息是系统消息，不应该插入数据库
        if (type == 'S2C') {
          s2cMessages.add(msgData);
          continue;
        }

        normalMessages.add(msgData);
      }

      // 处理普通消息（插入数据库）
      await db.transaction((txn) async {
        requireCurrent();
        for (final msgData in normalMessages) {
          requireCurrent();
          final rawMsgId = msgData['msg_id'] ?? msgData['id'];
          final msgId = rawMsgId?.toString() ?? '';
          String type = (msgData['type'] ?? 'C2C').toString().toUpperCase();

          final tableName = resolveTable(type);
          if (tableName.isEmpty) {
            func_helper.iPrint("离线消息type不支持，跳过: $type");
            continue;
          }

          // 检查消息是否已存在
          final List<Map<String, Object?>> existing = await txn.rawQuery(
            'SELECT ${MessageColumns.payload}, ${MessageColumns.e2ee}, '
            'CAST(${MessageColumns.from} AS TEXT) AS ${MessageColumns.from}, '
            'CAST(${MessageColumns.to} AS TEXT) AS ${MessageColumns.to}, ${MessageColumns.type}, '
            '${MessageColumns.msgType} '
            'FROM $tableName WHERE id = ?',
            [msgId],
          );
          requireCurrent();
          if (existing.isNotEmpty) {
            final upgraded =
                trustedArchive &&
                await _upgradeFailedMegolmArchive(
                  txn,
                  tableName,
                  msgId,
                  existing.single,
                  msgData,
                );
            // R07-phase2 去重分支：已有 msg_id 收到带权威序号/接受时间的
            // 可信 offline/archive/ACK 数据时，调 backfillServerOrderFacts
            // 补齐缺失的 conv_seq/accepted_at（COALESCE 仅写 NULL 列，
            // 幂等），不能因去重直接 continue 丢掉权威字段。
            // SERVER_ACK 复用本分支：只补权威列，绝不覆盖原始 created_at。
            final facts = parseServerOrderFacts(msgData);
            requireCurrent();
            if (facts.convSeq != null || facts.acceptedAt != null) {
              try {
                await backfillServerOrderFacts(
                  msgId,
                  convSeq: facts.convSeq,
                  acceptedAt: facts.acceptedAt,
                  txn: txn,
                );
              } on Object catch (e) {
                if (trustedArchive) rethrow;
                // 补齐失败不阻断批量写入主流程（权威字段可在后续批次
                // 再次补齐）；与 upgraded 失败同样只记录。
                func_helper.iPrint(
                  'backfillServerOrderFacts 失败: $msgId, '
                  '${e.runtimeType}: $e',
                );
              }
            }
            final snapshot = await _existingOfflineConversation(
              txn,
              existing.single,
            );
            requireCurrent();
            if (snapshot != null) conversations.add(snapshot);
            addAckId(msgId);
            func_helper.iPrint(
              upgraded ? "历史密文已修复失败占位: $msgId" : "离线消息已存在，跳过: $msgId",
            );
            continue;
          }

          final decoded = OfflineMessagePayload.decode(
            msgData,
            trustedArchive: trustedArchive,
          );
          final payload = decoded.payload;
          final rawPayloadCipher = decoded.rawCipher;
          final e2ee = decoded.encryption;

          // WebSocket API v2.0: msg_type/action/e2ee 在顶层，不在 payload 内
          // 获取顶层字段
          var msgType = (msgData['msg_type'] ?? '').toString();

          if (kDebugMode) {
            func_helper.iPrint(
              '🔍 [DEBUG 离线消息] 原始数据: msgId=$msgId, msgData[\'msg_type\']="${msgData['msg_type']}", payload keys=${payload.keys.toList()}',
            );
          }

          // 【重构】使用 MessageTypeNormalizer 做类型合法性校验
          msgType = MessageTypeNormalizer.normalize(
            msgType: msgType,
            payload: payload,
          );

          if (kDebugMode) {
            func_helper.iPrint('🔍 [DEBUG 离线消息] 归一化后: msgType="$msgType"');
          }
          final action = (msgData['action'] ?? '').toString();

          final fromId = (msgData['from'] ?? '').toString();
          final toId = (msgData['to'] ?? '').toString();
          final createdAt = parseCreatedAt(msgData['created_at']);
          final topicId =
              int.tryParse((msgData['topic_id'] ?? 0).toString()) ?? 0;

          // 确定消息方向（是否为作者）
          String currentUid = session?.uid ?? UserRepoLocal.to.currentUid;
          bool isAuthor = fromId == currentUid;

          // 构建会话UK3
          String peerId = '';
          if (type == 'C2G') {
            peerId = toId;
            if (peerId.isEmpty) {
              peerId = (payload['group_id'] ?? payload['groupId'] ?? '')
                  .toString();
            }
          } else if (type == 'S2C') {
            peerId = fromId;
          } else {
            peerId = isAuthor ? toId : fromId;
          }

          if (peerId.isEmpty) {
            func_helper.iPrint("离线消息缺少peerId，跳过: $msgId, type: $type");
            continue;
          }

          String conversationUk3 = ConversationUk3Generator.generateSmart(
            type: type,
            currentUserId: currentUid,
            peerId: peerId,
          );

          Map<String, dynamic> insertData = {
            MessageColumns.id: msgId,
            MessageColumns.type: type,
            MessageColumns.from: fromId,
            MessageColumns.to: toId,
            MessageColumns.payload: rawPayloadCipher ?? json.encode(payload),
            MessageColumns.createdAt: createdAt,
            MessageColumns.isAuthor: isAuthor ? 1 : 0,
            MessageColumns.topicId: topicId,
            MessageColumns.conversationUk3: conversationUk3,
            MessageColumns.status: IMBoyMessageStatus.delivered,
            // v2.0 新增字段 - 从消息顶层获取（不在 payload 内）
            // 所有消息类型都应包含这三个字段
            MessageColumns.msgType: msgType,
            MessageColumns.action: action, // ✅ 修复：所有类型都写入 action
            MessageColumns.e2ee: e2ee != null ? json.encode(e2ee) : '',
          };

          // R07-phase2 权威顺序事实随插入一并落列（实时 / 离线 / 归档
          // 三路径共用本写入点）：conv_seq/accepted_at 仅在服务端提供时
          // 写入；本地待发无序号消息两列保持 NULL，确认（SERVER_ACK）
          // 后由去重分支的 backfillServerOrderFacts 按 conv_seq 收敛，
          // 绝不用收到时刻伪造。收敛规则：NULL→补权威值；已有值不覆盖；
          // created_at（原始发送时间）任何路径都不改写。
          final facts = parseServerOrderFacts(msgData);
          if (facts.convSeq != null) {
            insertData[MessageColumns.convSeq] = facts.convSeq;
          }
          if (facts.acceptedAt != null) {
            insertData[MessageColumns.acceptedAt] = facts.acceptedAt;
          }

          // A2-b：服务端在信封顶层注入的发送方设备 ID（认证态，客户端不可伪造）。
          // PFv3 接收侧 context binding 第 6 项要用；离线行读取时才解密
          // （decrypt-on-read），此刻不存 = v3 消息永久不可读。
          // 缺失时**不写空串**：让 context binding 如实失配（fail-closed），
          // 运维据 context_mismatch_sender_did 可区分「旧行」与「真篡改」。
          // C2G 无独立列，仅由认证顶层身份生成本地保留字段。
          final senderDid = msgData[MessageColumns.senderDid]?.toString() ?? '';
          if (e2ee is Map) {
            final localMetadata = Map<String, dynamic>.from(e2ee)
              ..remove(MessageModel.localSenderDidKey);
            if (type == 'C2G' && senderDid.isNotEmpty) {
              localMetadata[MessageModel.localSenderDidKey] = senderDid;
            }
            insertData[MessageColumns.e2ee] = jsonEncode(localMetadata);
          }
          if (type == 'C2C' && senderDid.isNotEmpty) {
            insertData[MessageColumns.senderDid] = senderDid;
          }

          await txn.insert(tableName, insertData);

          inserted.add(
            InsertedOfflineMessage(
              id: msgId,
              type: type,
              fromId: fromId,
              toId: toId,
              payload: rawPayloadCipher ?? payload,
              createdAt: createdAt,
              isAuthor: isAuthor ? 1 : 0,
              topicId: topicId,
              conversationUk3: conversationUk3,
              status: IMBoyMessageStatus.delivered,
              peerId: peerId,
              msgType: msgType, // WebSocket API v2.0: 从顶层字段读取
              e2ee: e2ee is Map ? Map<String, dynamic>.from(e2ee) : null,
              senderDid: senderDid.isNotEmpty ? senderDid : null,
            ),
          );

          addAckId(msgId);

          func_helper.iPrint(
            "离线消息插入成功: $msgId, type: $type, conversation: $conversationUk3",
          );
        }
        conversations.addAll(
          await _persistOfflineConversations(
            inserted,
            txn,
            historyImport: trustedArchive,
          ),
        );
        requireCurrent();
      });
      requireCurrent();

      if (inserted.isNotEmpty) {
        db.clearQueryCache(ConversationRepo.tableName);
        for (final type in inserted.map((msg) => msg.type).toSet()) {
          db.clearQueryCache(resolveTable(type));
        }
        // 批量写入 FTS 索引（异步，不阻塞离线消息处理）
        for (final msg in inserted) {
          unawaited(indexMessage(msg));
        }
      }
      if (conversations.isNotEmpty) {
        await _syncOfflineConversationsAndNotify(inserted, conversations);
      }
      // 处理 S2C 消息（在事务外）
      if (s2cMessages.isNotEmpty) {
        if (onS2CMessage == null) {
          throw StateError('offline S2C messages require a handler');
        }
        func_helper.iPrint("开始处理 ${s2cMessages.length} 条 S2C 消息");
        for (final msgData in s2cMessages) {
          await onS2CMessage(msgData);
          addAckId((msgData['msg_id'] ?? msgData['id']).toString());
        }
      }
    } on Object catch (e, s) {
      func_helper.iPrint('批量插入离线消息失败: ${e.runtimeType}');
      Error.throwWithStackTrace(e, s);
    }
    return ackMsgIds;
  }

  static Future<ConversationModel?> _existingOfflineConversation(
    Transaction txn,
    Map<String, Object?> row,
  ) async {
    // 从已持久化的信封确定会话，重投数据不能覆盖原消息的会话归属。
    final type = row[MessageColumns.type]?.toString() ?? '';
    final sender = row[MessageColumns.from]?.toString() ?? '';
    final recipient = row[MessageColumns.to]?.toString() ?? '';
    final peer = type == 'C2G' || sender == UserRepoLocal.to.currentUid
        ? recipient
        : sender;
    if (peer.isEmpty) return null;
    return ConversationRepo().findByPeerId(type, peer, txn: txn);
  }

  static Future<bool> _upgradeFailedMegolmArchive(
    Transaction txn,
    String tableName,
    String msgId,
    Map<String, Object?> existing,
    Map<String, dynamic> incoming,
  ) async {
    Map<String, dynamic>? decodeMap(dynamic raw) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is! String || raw.isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      } on FormatException {
        return null;
      }
    }

    final placeholder = decodeMap(existing[MessageColumns.payload]);
    final raw = placeholder?['_e2ee_raw'];
    final original = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final originalE2ee = decodeMap(original?['e2ee']);
    final incomingE2ee = decodeMap(incoming['e2ee']);
    if (placeholder?['_e2ee_failed'] != true ||
        original == null ||
        originalE2ee?['protocol'] != 'megolm' ||
        incomingE2ee?['protocol'] != 'megolm') {
      return false;
    }
    final originalMetadata = originalE2ee!;
    final incomingMetadata = incomingE2ee!;

    bool same(dynamic a, dynamic b) => a?.toString() == b?.toString();
    final immutableMatch =
        same(original['id'] ?? original['msg_id'], msgId) &&
        same(original['from'], incoming['from']) &&
        same(original['to'], incoming['to']) &&
        same(original['type'], incoming['type']) &&
        same(original['msg_type'], incoming['msg_type']) &&
        same(original['payload'], incoming['payload']) &&
        same(originalMetadata['gid'], incomingMetadata['gid']) &&
        same(originalMetadata['session_id'], incomingMetadata['session_id']);
    final rawSeq = incoming['conv_seq'];
    final convSeq = rawSeq is int
        ? rawSeq
        : int.tryParse(rawSeq?.toString() ?? '');
    if (!immutableMatch || convSeq == null || convSeq <= 0) return false;

    incomingMetadata.remove('_archive_conv_seq');
    incomingMetadata['_archive_conv_seq'] = convSeq;
    final updated = await txn.update(
      tableName,
      {
        MessageColumns.payload: incoming['payload'],
        MessageColumns.e2ee: jsonEncode(incomingMetadata),
      },
      where: '${MessageColumns.id} = ?',
      whereArgs: [msgId],
    );
    return updated == 1;
  }

  /// created_at（客户端原始发送时间，不改写）→ 毫秒。
  ///
  /// W8-A2：String 形态仅接受带显式 zone 的 ISO/RFC3339
  /// （[ApiTime.parseIsoZoned]），无 zone 串不猜设备本地时区、紧凑数字
  /// 形态不误入 ISO 分支——解析失败返回 0（"无 created_at"既有哨兵，
  /// 落库为 0 而非伪造时间），与实时接收侧 message.dart 同一口径。
  /// 纯函数，@visibleForTesting 公开供单测钉住口径。
  @visibleForTesting
  static int parseCreatedAt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    final s = raw.toString();
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    return ApiTime.parseIsoZoned(s)?.millisecondsSinceEpoch ?? 0;
  }

  /// R07-phase2：从服务端消息数据顶层提取权威顺序事实。
  ///
  /// - `conv_seq`：服务端会话内序号（history 归档行 / 带序号的投递信封），
  ///   仅接受正整数；无序号的旧消息返回 null（**绝不本地伪造序号**）。
  /// - `accepted_at`：首次服务端接受时刻，统一归一为毫秒（int 原样、
  ///   毫秒数字串经 [ApiTime.parseEpochMillis] 直取、带 zone 的 RFC3339
  ///   经 [ApiTime.parseIsoZoned] 严格归一）。无 zone 串不猜设备本地时区
  ///   （紧凑形态也不静默接受）——一律返回 null 落 accepted_at=NULL，
  ///   由下游按低可信降级处理，与 ApiTime 单位合同一致。
  ///
  /// 纯函数（公开供测试守护）；返回 null 表示无该事实，调用方不写列。
  static ({int? convSeq, int? acceptedAt}) parseServerOrderFacts(
    Map<String, dynamic> msgData,
  ) {
    int? convSeq;
    final rawSeq = msgData['conv_seq'];
    if (rawSeq is int && rawSeq > 0) {
      convSeq = rawSeq;
    } else if (rawSeq is num) {
      // W8-C2：非整数 double（如 1.5）不得截断成 1 静默接受——与
      // ApiTime._parseIntLike"可无损转 int 才收"口径一致，截断即拒。
      if (rawSeq == rawSeq.truncateToDouble()) {
        final asInt = rawSeq.toInt();
        if (asInt > 0) convSeq = asInt;
      }
    } else if (rawSeq != null) {
      final asInt = int.tryParse(rawSeq.toString());
      if (asInt != null && asInt > 0) convSeq = asInt;
    }
    int? acceptedAt;
    final rawAccepted = msgData['accepted_at'];
    if (rawAccepted != null) {
      // 毫秒 int / 整数字符串直取；带 zone 的 RFC3339（BE jsone timestamp
      // 输出形态）经 ApiTime.parseIsoZoned 严格归一为毫秒；无 zone 串不猜
      // 本地时区、紧凑形态不静默接受——返回 null 落 accepted_at=NULL，
      // 走低可信降级；无法解析同样返回 null 不落列。
      // W8-C3：accepted_at 毫秒 0（=1970-01-01T00:00:00Z）不是合理的
      // 服务端接受时刻，负值同理——与 conv_seq 的 >0 守卫对称，一律拒绝。
      if (rawAccepted is int) {
        if (rawAccepted > 0) acceptedAt = rawAccepted;
      } else if (rawAccepted is String &&
          RegExp(r'^\d+$').hasMatch(rawAccepted.trim())) {
        final parsed = int.tryParse(rawAccepted.trim());
        if (parsed != null && parsed > 0) acceptedAt = parsed;
      } else {
        acceptedAt = ApiTime.parseEpochMillis(rawAccepted);
        if (acceptedAt == null &&
            rawAccepted is String &&
            rawAccepted.isNotEmpty) {
          acceptedAt = ApiTime.parseIsoZoned(rawAccepted)
              ?.millisecondsSinceEpoch;
        }
      }
      // W8-C3/P2 终端兜底：无论经哪个来源得出（int/纯数字串直取、
      // parseEpochMillis、parseIsoZoned），<= 0 一律置 null——
      // parseEpochMillis 接受带符号串（'-5'）与可整转 double（0.0），
      // parseIsoZoned 可产出 1970 前负毫秒，均在此收口，与上方声明
      // 及 conv_seq 的 >0 守卫口径统一。
      if (acceptedAt != null && acceptedAt <= 0) acceptedAt = null;
    }
    return (convSeq: convSeq, acceptedAt: acceptedAt);
  }

  Future<void> _syncOfflineConversationsAndNotify(
    List<InsertedOfflineMessage> inserted,
    List<ConversationModel> conversations,
  ) async {
    // 后台入库没有页面监听；跨数据库等待时保留自动释放的会话状态。
    final container = getContainer();
    final subscription = container.listen(conversationProvider, (_, _) {});
    try {
      await _publishOfflineConversations(inserted, conversations);
    } finally {
      subscription.close();
    }
  }

  Future<List<ConversationModel>> _persistOfflineConversations(
    List<InsertedOfflineMessage> inserted,
    Transaction txn, {
    required bool historyImport,
  }) async {
    final conversations = <ConversationModel>[];
    final conversationRepo = ConversationRepo();
    final contactRepo = ContactRepo();
    final groupRepo = GroupRepo();

    // 获取当前会话 ID - 使用静态字段跟踪当前活动会话
    // 注意：如果没有打开的聊天页面，currentConversationUk3 将为空
    final String currentConversationUk3 = activeConversation() ?? '';

    final Map<String, OfflineConversationAgg> convAgg = {};
    final currentUid = UserRepoLocal.to.currentUid; // C7-β
    for (final msg in inserted) {
      final key = '${msg.type}::${msg.peerId}';
      final agg = convAgg.putIfAbsent(
        key,
        () => OfflineConversationAgg(
          type: msg.type,
          peerId: msg.peerId,
          currentUid: currentUid,
        ),
      );
      agg.observe(msg, currentConversationUk3);
    }

    for (final agg in convAgg.values) {
      final latest = agg.latest;
      if (latest == null) continue;

      String avatar = '';
      String title = '';
      try {
        if (agg.type == 'C2G') {
          final g = await groupRepo.findById(agg.peerId, txn: txn);
          avatar = g?.avatar ?? '';
          title = g?.title ?? '';
        } else {
          final ct = await contactRepo.findByUid(
            agg.peerId,
            autoFetch: false,
            txn: txn,
          );
          avatar = ct?.avatar ?? '';
          title = ct?.title ?? '';
        }
      } on Object catch (e, s) {
        AppLogger.error('[message_repo_sqlite] findByUid error', e, s);
      }

      final previewPayload = latest.payload is Map<String, dynamic>
          ? latest.payload as Map<String, dynamic>
          : <String, dynamic>{};

      // WebSocket API v2.0: 从顶层字段读取 msg_type 和 status
      if (kDebugMode) {
        func_helper.iPrint(
          '🔍 [DEBUG 会话同步] latest.msgType="${latest.msgType}", latest.status=${latest.status}, payload keys=${previewPayload.keys.toList()}',
        );
      }
      final preview = _derivePreview(
        latest.msgType,
        latest.status,
        previewPayload,
      );
      final existing = await conversationRepo.findByPeerId(
        agg.type,
        agg.peerId,
        txn: txn,
      );

      ConversationModel conv;
      if (existing == null) {
        // 创建新会话时确保设置所有必要字段
        conv = ConversationModel(
          id: 0,
          peerId: agg.peerId,
          avatar: avatar,
          title: title,
          subtitle: preview.subtitle,
          type: agg.type,
          msgType: preview.msgType,
          lastMsgId: latest.id,
          lastTime: latest.createdAt,
          lastMsgStatus: latest.status, // 传递消息状态
          unreadNum: agg.unreadDelta, // 使用计算出的未读数
          mentionUnread: agg.mentionDelta, // C7-β
          payload: {},
          isShow: 1,
        );
        conv.id = await conversationRepo.insert(conv, txn: txn);
        func_helper.iPrint('创建新会话: type=${conv.type}, 未读数: ${agg.unreadDelta}');
      } else if (latest.createdAt < existing.lastTime) {
        // R06：本批最新比会话头更旧——典型为历史回填（trustedArchive）晚于
        // 实时/更晚批次到达。投影不做时间比较外的猜测：更旧的批次不得把
        // 会话头拉回过去，直接保持现有头（与去重跳过路径同一保护语义）。
        // W8-B2（审查 P2）：实时批次（historyImport=false）乱序投递时消息
        // 行是**新落库的未读消息**——会话头可以不回退，但未读/mention
        // 必须照常累加，否则乱序到达的新消息永久丢失角标。归档批次维持
        // 现状（历史导入是补齐过去，不重复计未读）。
        var head = existing;
        if (!historyImport && (agg.unreadDelta > 0 || agg.mentionDelta > 0)) {
          await conversationRepo.incrementUnread(
            existing.id,
            txn: txn,
            unreadDelta: agg.unreadDelta,
            mentionDelta: agg.mentionDelta,
          );
          head =
              await conversationRepo.findById(existing.id, txn: txn) ??
              existing;
        }
        conversations.add(head);
        func_helper.iPrint(
          '历史批次早于会话头，保持会话头不变: type=${existing.type}, '
          'batchLatest=${latest.createdAt}, headLastTime=${existing.lastTime}'
          '${historyImport ? '' : '（实时乱序批次：未读照常累加）'}',
        );
        continue;
      } else {
        // R06：更新现有会话。投影只在「本批最新不旧于会话头」时推进
        //（上面分支已拦截更旧批次），不能用"本批最新"无条件覆盖
        // "整个会话最新"——历史导入与新投递共用这一时间比较，而非用
        // trustedArchive 标志混控投影。
        // 未读/mention 语义按批次来源区分：历史导入是补齐过去消息，
        // 不是新投递，不重复累加（R06）；新投递照旧累加。
        final unreadDelta = historyImport ? 0 : agg.unreadDelta;
        final mentionDelta = historyImport ? 0 : agg.mentionDelta;
        int newUnreadNum = existing.unreadNum + unreadDelta;
        int newMentionUnread = existing.mentionUnread + mentionDelta; // C7-β
        await conversationRepo.updateById(existing.id, {
          ConversationRepo.avatar: avatar.isNotEmpty ? avatar : existing.avatar,
          ConversationRepo.title: title.isNotEmpty ? title : existing.title,
          ConversationRepo.subtitle: preview.subtitle,
          ConversationRepo.msgType: preview.msgType,
          ConversationRepo.lastMsgId: latest.id,
          ConversationRepo.lastTime: latest.createdAt,
          ConversationRepo.lastMsgStatus: latest.status, // 传递消息状态
          ConversationRepo.unreadNum: newUnreadNum,
          ConversationRepo.mentionUnread: newMentionUnread, // C7-β
          ConversationRepo.isShow: 1,
        }, txn: txn);

        // 重新获取更新后的会话
        conv =
            (await conversationRepo.findById(existing.id, txn: txn)) ??
            existing;
        func_helper.iPrint(
          '更新会话: type=${conv.type}, '
          '新增未读数: $unreadDelta, 总未读数: $newUnreadNum',
        );
      }

      conversations.add(conv);
    }
    return conversations;
  }

  /// R06：已回退会话头的有界权威重算。
  ///
  /// 历史缺陷可能已把存量会话头写坏（last_msg_id/last_time 被"本批最新"
  /// 无条件覆盖回旧值）。本方法按会话现有消息集合重算头投影：
  /// 取该会话最新一条消息（`created_at DESC, auto_id DESC LIMIT 1`，
  /// 有界查询）重建 lastMsgId/lastTime/lastMsgStatus/msgType/subtitle。
  ///
  /// 边界（R06 卡明确）：不做 SQLite schema 迁移；不增加未读/mention；
  /// 不修改消息行；会话或消息为空时返回现状不伪造头。
  Future<ConversationModel?> recomputeConversationHead({
    required String type,
    required String peerId,
  }) async {
    final conversationRepo = ConversationRepo();
    final conv = await conversationRepo.findByPeerId(type, peerId);
    if (conv == null) return null;
    final tableName = resolveTable(type);
    if (tableName.isEmpty) return conv;

    final rows = await db.rawQuery(
      'SELECT ${MessageColumns.id}, ${MessageColumns.msgType}, '
      '${MessageColumns.status}, ${MessageColumns.payload}, '
      '${MessageColumns.createdAt} FROM $tableName '
      'WHERE ${MessageColumns.conversationUk3} = ? '
      'ORDER BY ${MessageColumns.createdAt} DESC, ${MessageColumns.autoId} DESC '
      'LIMIT 1',
      [conv.uk3],
    );
    if (rows.isEmpty) return conv;

    final row = rows.single;
    Map<String, dynamic> payload = const <String, dynamic>{};
    final rawPayload = row[MessageColumns.payload];
    if (rawPayload is String && rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        // 密文行（rawCipher 直存）：无明文 payload，预览退化为类型兜底。
      }
    }
    final status = row[MessageColumns.status];
    final preview = _derivePreview(
      row[MessageColumns.msgType]?.toString() ?? '',
      status is int ? status : null,
      payload,
    );
    final createdAt = row[MessageColumns.createdAt];
    await conversationRepo.updateById(conv.id, {
      ConversationRepo.lastMsgId: row[MessageColumns.id]?.toString() ?? '',
      ConversationRepo.lastTime: createdAt is int ? createdAt : conv.lastTime,
      ConversationRepo.lastMsgStatus: status is int
          ? status
          : conv.lastMsgStatus,
      ConversationRepo.msgType: preview.msgType,
      ConversationRepo.subtitle: preview.subtitle,
    });
    return await conversationRepo.findById(conv.id) ?? conv;
  }

  Future<void> _publishOfflineConversations(
    List<InsertedOfflineMessage> inserted,
    List<ConversationModel> conversations,
  ) async {
    final conversationNotifier = getContainer().read(
      conversationProvider.notifier,
    );
    for (final conv in conversations) {
      AppEventBus.fireData(conv);
      conversationNotifier.applyConversationSnapshot(conv);
    }
    final currentConversationUk3 = activeConversation() ?? '';

    if (currentConversationUk3.isNotEmpty) {
      for (final msg in inserted) {
        if (msg.conversationUk3 != currentConversationUk3) continue;
        try {
          AppEventBus.fireData(
            await msg.toMessageModel().toTypeMessage(),
            'Message',
          );
        } on Object catch (e, s) {
          AppLogger.error('[message_repo_sqlite] toMessageModel error', e, s);
        }
      }
    }
  }
}
