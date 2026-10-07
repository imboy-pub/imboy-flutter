import 'package:imboy/store/repository/offline_message_payload.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart' as func_helper;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/model/message_columns.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/store/repository/message_repo_types.dart';

/// 离线批量写入：消息/会话事务提交、重投快照恢复与提交后通知。
class OfflineMessageWriter {
  final SqliteService db;
  final ProviderContainer Function() getContainer;
  final String? Function() activeConversation;
  final String Function(String) resolveTable;
  final Future<void> Function(InsertedOfflineMessage) indexMessage;

  const OfflineMessageWriter({
    required this.db,
    required this.getContainer,
    required this.activeConversation,
    required this.resolveTable,
    required this.indexMessage,
  });

  /// 批量插入离线消息
  Future<List<String>?> write(
    List<Map<String, dynamic>> messages, {
    Future<void> Function(Map<String, dynamic>)? onS2CMessage,
    bool trustedArchive = false,
  }) async {
    if (messages.isEmpty) return null;

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
        // 优化类型处理，确保类型标准化
        String type = (msgData['type'] ?? 'C2C').toString().toUpperCase();
        // 处理可能的类型别名
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
        for (final msgData in normalMessages) {
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
            '${MessageColumns.from}, ${MessageColumns.to}, ${MessageColumns.type}, '
            '${MessageColumns.msgType} '
            'FROM $tableName WHERE id = ?',
            [msgId],
          );
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
            final snapshot = await _existingOfflineConversation(
              txn,
              existing.single,
            );
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
          final createdAt = _parseCreatedAt(msgData['created_at']);
          final topicId =
              int.tryParse((msgData['topic_id'] ?? 0).toString()) ?? 0;

          // 确定消息方向（是否为作者）
          String currentUid = UserRepoLocal.to.currentUid;
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

          // A2-b：服务端在信封顶层注入的发送方设备 ID（认证态，客户端不可伪造）。
          // PFv3 接收侧 context binding 第 6 项要用；离线行读取时才解密
          // （decrypt-on-read），此刻不存 = v3 消息永久不可读。
          // 缺失时**不写空串**：让 context binding 如实失配（fail-closed），
          // 运维据 context_mismatch_sender_did 可区分「旧行」与「真篡改」。
          // 仅 C2C：C2G 当前走 Megolm v2（非 PFv3），msg_c2g 表无该列。
          final senderDid = msgData[MessageColumns.senderDid]?.toString() ?? '';
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
        conversations.addAll(await _persistOfflineConversations(inserted, txn));
      });

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
      // 不再吞成 null（A-24）。
      //
      // 返回 null 与"这批本来就没有需要 ACK 的消息"在调用方看来完全一样
      // （`if (msgIds != null && msgIds.isNotEmpty)`），于是整批写入失败
      // 被读成"没什么要确认的"：不 ACK、不报错、拉取继续、游标照常推进。
      // 持久性失败（A-21 的 msg_c2c.sender_did 缺列就是实例）因此变成
      // 每次拉取都失败、每次都只留一行 print 的静默循环。
      //
      // 向上抛之后由 message_offline.dart 的拉取外层 catch 接住 —— 那里
      // 有失败计数、_markPullFailure()、指标上报和用户可见提示，
      // 是这条链上唯一有处理能力的一层。异常不会逃逸成未捕获崩溃。
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

  static int _parseCreatedAt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    final s = raw.toString();
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    try {
      return DateTimeHelper.rfc3339ToMillisecond(s);
    } on Object {
      return 0;
    }
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
    Transaction txn,
  ) async {
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
          peerId: parseModelInt(agg.peerId),
          avatar: avatar,
          title: title,
          subtitle: preview.subtitle,
          type: agg.type,
          msgType: preview.msgType,
          lastMsgId: parseModelInt(latest.id),
          lastTime: latest.createdAt,
          lastMsgStatus: latest.status, // 传递消息状态
          unreadNum: agg.unreadDelta, // 使用计算出的未读数
          mentionUnread: agg.mentionDelta, // C7-β
          payload: {},
          isShow: 1,
        );
        conv.id = await conversationRepo.insert(conv, txn: txn);
        func_helper.iPrint('创建新会话: type=${conv.type}, 未读数: ${agg.unreadDelta}');
      } else {
        // 更新现有会话，总是更新最后消息信息
        int newUnreadNum = existing.unreadNum + agg.unreadDelta;
        int newMentionUnread =
            existing.mentionUnread + agg.mentionDelta; // C7-β
        await conversationRepo.updateById(existing.id, {
          ConversationRepo.avatar: avatar.isNotEmpty ? avatar : existing.avatar,
          ConversationRepo.title: title.isNotEmpty ? title : existing.title,
          ConversationRepo.subtitle: preview.subtitle,
          ConversationRepo.msgType: preview.msgType,
          ConversationRepo.lastMsgId: parseModelInt(latest.id),
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
          '新增未读数: ${agg.unreadDelta}, 总未读数: $newUnreadNum',
        );
      }

      conversations.add(conv);
    }
    return conversations;
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

  /// WebSocket API v2.0: 根据消息 status 和 payload 生成会话预览
  ///
  /// 方案 D: 检查 status 字段（30=peer_revoked, 31=my_revoked）
  static ({String msgType, String subtitle}) _derivePreview(
    String msgType,
    int? status,
    Map<String, dynamic> payload,
  ) {
    // 【重构】使用 MessageTypeNormalizer 做类型合法性校验
    final effectiveMsgType = MessageTypeNormalizer.normalize(
      msgType: msgType,
      payload: payload,
    );

    if (kDebugMode) {
      func_helper.iPrint(
        '🔍 [DEBUG _derivePreview] 输入: msgType="$msgType", effective=$effectiveMsgType',
      );
    }

    // 方案 D: 检查 status 字段（撤回状态 30-39）
    if (IMBoyMessageStatus.isRevokedStatus(status)) {
      // status = 30 (peer_revoked) 或 31 (my_revoked)
      // 保留原始 msg_type，让会话列表知道原始内容类型
      if (status == IMBoyMessageStatus.peerRevoked) {
        return (
          msgType: msgType,
          subtitle: '[${t.common.otherRevokedMessage}]',
        );
      } else {
        return (msgType: msgType, subtitle: '[${t.common.youRevokedMessage}]');
      }
    }

    // 【简化】使用 effectiveMsgType 判断内容类型
    String subtitle;
    switch (effectiveMsgType) {
      case 'text':
        subtitle = (payload['text'] ?? '').toString();
        break;
      case 'quote':
        subtitle = (payload['quote_text'] ?? '').toString();
        break;
      case 'location':
        subtitle = (payload['title'] ?? '[位置]').toString();
        break;
      case 'image':
        subtitle = '[图片]';
        break;
      case 'imageMulti':
        subtitle = '[多图]';
        break;
      case 'voice':
        subtitle = '[语音]';
        break;
      case 'video':
        subtitle = '[视频]';
        break;
      case 'file':
        final filename = payload['filename']?.toString() ?? '';
        final name = payload['name']?.toString() ?? '';
        subtitle = filename.isNotEmpty
            ? filename
            : (name.isNotEmpty ? name : '[文件]');
        break;
      case 'webrtcAudio':
      case 'webrtcVideo':
        subtitle = '[通话]';
        break;
      case 'visitCard':
        subtitle = '[名片]';
        break;
      case 'system':
        subtitle = '[系统消息]';
        break;
      default:
        // 未知类型，尝试从 text 字段获取
        subtitle = (payload['text'] ?? '[消息]').toString();
        break;
    }

    if (kDebugMode) {
      func_helper.iPrint(
        '🔍 [DEBUG _derivePreview] 返回: msgType=$effectiveMsgType',
      );
    }
    return (msgType: effectiveMsgType, subtitle: subtitle);
  }
}
