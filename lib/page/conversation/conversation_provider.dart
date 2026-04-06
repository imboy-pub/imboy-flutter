import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/events/common_events.dart'
    show ConversationAuthoritySyncEvent;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/model/contact_model.dart' show ContactModel;
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite/sqflite.dart';

part 'conversation_provider.g.dart';

// Riverpod State for Conversation Logic
class ConversationState {
  final bool isLoading;
  final Map<String, ConversationModel> conversationMap;
  final String connectDesc;
  final Map<String, int> conversationRemind;

  const ConversationState({
    this.isLoading = true,
    this.conversationMap = const {},
    this.connectDesc = '',
    this.conversationRemind = const {},
  });

  ConversationState copyWith({
    bool? isLoading,
    Map<String, ConversationModel>? conversationMap,
    String? connectDesc,
    Map<String, int>? conversationRemind,
  }) {
    return ConversationState(
      isLoading: isLoading ?? this.isLoading,
      conversationMap: conversationMap ?? this.conversationMap,
      connectDesc: connectDesc ?? this.connectDesc,
      conversationRemind: conversationRemind ?? this.conversationRemind,
    );
  }

  // Get sorted conversations list
  List<ConversationModel> get conversations {
    final list = conversationMap.values.toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.lastTime.compareTo(a.lastTime);
    });
    return list;
  }

  // Get total remind counter
  int get chatMsgRemindCounter {
    return conversationRemind.values.fold(0, (sum, val) => sum + val);
  }
}

// Riverpod Notifier for Conversation Logic
@riverpod
class ConversationNotifier extends _$ConversationNotifier {
  final Map<String, Timer> _debounceTimers = {};
  final ConversationApi _conversationApi;

  ConversationNotifier({ConversationApi? conversationApi})
    : _conversationApi = conversationApi ?? ConversationApi();

  @override
  ConversationState build() {
    // 添加 dispose 回调，清理资源
    ref.onDispose(() {
      // 取消所有活跃的定时器
      for (var timer in _debounceTimers.values) {
        timer.cancel();
      }
      _debounceTimers.clear();
    });

    return const ConversationState();
  }

  // Set loading state
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  // Set connection description
  void setConnectDesc(String desc) {
    state = state.copyWith(connectDesc: desc);
  }

  // Replace single conversation
  void replaceConversation(ConversationModel obj) {
    if (obj.uk3.isEmpty) return;
    // 检查 provider 是否仍然有效，避免在销毁后访问 state
    if (!ref.mounted) {
      iPrint('⚠️ [replaceConversation] ConversationNotifier 已释放，跳过更新');
      return;
    }
    final newMap = Map<String, ConversationModel>.from(state.conversationMap);
    newMap[obj.uk3] = obj;
    state = state.copyWith(conversationMap: newMap);
  }

  // Remove conversation from map
  void removeConversationFromMap(String uk3) {
    final newMap = Map<String, ConversationModel>.from(state.conversationMap);
    newMap.remove(uk3);
    state = state.copyWith(conversationMap: newMap);
  }

  // Set conversation remind
  void setConversationRemindLocal(String uk3, int val) {
    if (uk3.isEmpty) return;
    final newRemindMap = Map<String, int>.from(state.conversationRemind);
    newRemindMap[uk3] = val;
    state = state.copyWith(conversationRemind: newRemindMap);
  }

  // Apply a full conversation snapshot from backend/local persistence.
  // This keeps in-memory list/remind state aligned with one authoritative model.
  void applyConversationSnapshot(ConversationModel conversation) {
    if (conversation.uk3.isEmpty) return;
    replaceConversation(conversation);
    setConversationRemindLocal(
      conversation.uk3,
      conversation.unreadNum > 0 ? conversation.unreadNum : 0,
    );
  }

  // Remove conversation remind
  void removeConversationRemind(String uk3) {
    final newRemindMap = Map<String, int>.from(state.conversationRemind);
    newRemindMap.remove(uk3);
    state = state.copyWith(conversationRemind: newRemindMap);
  }

  // 读取会话的"已读水位"（使用消息表 auto_id）
  int _getLastReadAutoId(ConversationModel conversation) {
    try {
      final v = conversation.payload?['last_read_auto_id'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    } catch (e) {
      debugPrint('[ConversationProvider] conversation update failed: $e');
      return 0;
    }
  }

  // 设置会话"已读水位"（仅推进，不回退）
  Future<void> _setLastReadAutoId(
    ConversationModel conversation,
    int autoId,
  ) async {
    if (conversation.uk3.isEmpty) return;
    final current = _getLastReadAutoId(conversation);
    if (autoId <= current) return;

    final newPayload = <String, dynamic>{
      ...?conversation.payload,
      'last_read_auto_id': autoId,
    };
    await (ConversationRepo()).updateById(conversation.id, {
      ConversationRepo.payload: newPayload,
    });

    // 同步更新内存对象
    final uk3 = conversation.uk3;
    if (state.conversationMap.containsKey(uk3)) {
      final newMap = Map<String, ConversationModel>.from(state.conversationMap);
      newMap[uk3] = newMap[uk3]!.copyWith(payload: newPayload);
      state = state.copyWith(conversationMap: newMap);
    } else {
      // 不在 Map 中时，尽量更新传入对象的 payload
      conversation.payload = newPayload;
    }
  }

  Future<void> setConversationRemind(
    ConversationModel conversation,
    int val,
  ) async {
    final String uk3 = conversation.uk3;
    if (uk3.isEmpty) return;

    val = val > 0 ? val : 0;
    _debounceTimers[uk3]?.cancel();

    _debounceTimers[uk3] = Timer(const Duration(milliseconds: 500), () async {
      try {
        await (ConversationRepo()).updateById(conversation.id, {
          ConversationRepo.unreadNum: val,
          ConversationRepo.isShow: 1,
        });

        setConversationRemindLocal(uk3, val);

        if (state.conversationMap.containsKey(uk3)) {
          final newMap = Map<String, ConversationModel>.from(
            state.conversationMap,
          );
          newMap[uk3] = newMap[uk3]!.copyWith(unreadNum: val);
          state = state.copyWith(conversationMap: newMap);
        }
      } catch (e, s) {
        iPrint('setConversationRemind error: $e ; $s');
      } finally {
        _debounceTimers.remove(uk3);
      }
    });
  }

  Future<void> increaseConversationRemind(
    ConversationModel conversation,
    int val,
  ) async {
    if (conversation.uk3.isEmpty) return;
    final current = state.conversationRemind[conversation.uk3] ?? 0;
    await setConversationRemind(conversation, current + val);
  }

  Future<void> decreaseConversationRemind(
    ConversationModel conversation,
    int val,
  ) async {
    if (conversation.uk3.isEmpty) return;
    final current = state.conversationRemind[conversation.uk3] ?? 0;
    await setConversationRemind(conversation, (current - val).clamp(0, 999999));
  }

  Future<void> replace(ConversationModel obj) async {
    if (obj.uk3.isEmpty) return;
    replaceConversation(obj);
  }

  // Get group title - temporary implementation until GroupListLogic is migrated
  Future<String> _getGroupTitle(String peerId) async {
    try {
      final group = await (GroupRepo()).findById(peerId);
      if (group != null && group.title.trim().isNotEmpty) {
        return group.title;
      }
    } catch (e) {
      iPrint('_getGroupTitle error: $e');
    }
    return peerId;
  }

  Future<String> computeTitle(ConversationModel obj) async {
    String computedTitle = '';

    if (obj.type == 'C2G') {
      // 群组会话：如果设置了群名称，就应该取群名称；否则取 _groupListLogic.computeTitle 的结果
      final group = await (GroupRepo()).findById(obj.peerId);
      if (group != null && group.title.trim().isNotEmpty) {
        computedTitle = group.title;
      } else {
        computedTitle = await _getGroupTitle(obj.peerId);
      }
    } else if (obj.type == 'C2C') {
      // 个人会话：获取联系人标题
      computedTitle = await _getContactTitle(obj.peerId);
    }
    iPrint("${obj.peerId} computedTitle $computedTitle");
    // 将计算结果持久化到数据库
    if (computedTitle.isNotEmpty) {
      await (ConversationRepo()).updateById(obj.id, {
        ConversationRepo.title: computedTitle,
      });
      obj.title = computedTitle; // 更新内存中的对象
    }
    return computedTitle;
  }

  // Check if burn message is expired - temporary implementation
  bool isBurnExpiredPayload(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    final burnAfter = payload['burn_after'];
    if (burnAfter == null || burnAfter == 0) return false;
    final createdAt = payload['created_at'];
    if (createdAt == null) return false;
    try {
      final createdTime = createdAt is int
          ? createdAt
          : int.tryParse(createdAt.toString()) ?? 0;
      final currentTime = DateTimeHelper.millisecond();
      return (currentTime - createdTime) > burnAfter;
    } catch (e) {
      return false;
    }
  }

  // Expire burn message - temporary implementation
  Future<void> expireBurnMessage(ConversationModel cm, String msgId) async {
    // This is a simplified version - full implementation would be in ChatLogic
    try {
      final repo = ConversationRepo();
      await repo.updateById(cm.id, {});
    } catch (e) {
      iPrint('expireBurnMessage error: $e');
    }
  }

  String _normalizeAuthoritativeType(String rawType) {
    switch (rawType.trim().toLowerCase()) {
      case 'c2c':
        return 'C2C';
      case 'c2g':
        return 'C2G';
      default:
        return '';
    }
  }

  int _parseAuthoritativeServerTs(dynamic rawTs) {
    final ts = parseModelInt(rawTs);
    if (ts > 0) return ts;
    return parseModelDateTime(
      rawTs,
      defaultValue: DateTime.fromMillisecondsSinceEpoch(0),
    ).millisecondsSinceEpoch;
  }

  String _resolveAuthoritativeMsgType(Map<String, dynamic> lastMsg) {
    final payload =
        parseModelJsonMap(lastMsg['payload']) ?? <String, dynamic>{};
    final msgType = parseModelString(
      lastMsg['msg_type'] ?? payload['msg_type'] ?? lastMsg['type'],
    );
    if (msgType.isNotEmpty) return msgType;
    final text = parseModelString(lastMsg['text'] ?? payload['text']);
    return text.isNotEmpty ? 'text' : '';
  }

  String _resolveAuthoritativeSubtitle(
    Map<String, dynamic> lastMsg,
    String msgType,
  ) {
    final payload =
        parseModelJsonMap(lastMsg['payload']) ?? <String, dynamic>{};
    final text = parseModelString(lastMsg['text'] ?? payload['text']);
    if (text.isNotEmpty) return text;
    if (msgType == MessageType.text || msgType == MessageType.quote) {
      return parseModelString(lastMsg['content'] ?? payload['content']);
    }
    return '';
  }

  String _resolveAuthoritativeAvatar(Map<String, dynamic> lastMsg) {
    final payload =
        parseModelJsonMap(lastMsg['payload']) ?? <String, dynamic>{};
    return parseModelString(
      lastMsg['avatar'] ??
          lastMsg['from_avatar'] ??
          payload['avatar'] ??
          payload['from_avatar'],
    );
  }

  Map<String, dynamic> _mergeAuthoritativePayload({
    required Map<String, dynamic>? existingPayload,
    required int serverTs,
    required bool isPinned,
    required Map<String, dynamic> lastMsg,
  }) {
    final merged = <String, dynamic>{...?existingPayload};
    final authoritative =
        parseModelJsonMap(merged['authoritative']) ?? <String, dynamic>{};

    authoritative['server_ts'] = serverTs;
    authoritative['is_pinned'] = isPinned;
    authoritative['last_msg'] = lastMsg;

    merged['authoritative'] = authoritative;
    return merged;
  }

  String _authoritativeKey(String type, String peerId) => '$type::$peerId';

  Future<int> _hideMissingAuthoritativeConversations(
    ConversationRepo repo,
    Set<String> authoritativeKeys,
  ) async {
    final visible = await repo.list();
    int hidden = 0;

    for (final conversation in visible) {
      if (conversation.type != 'C2C' && conversation.type != 'C2G') {
        continue;
      }
      final key = _authoritativeKey(conversation.type, conversation.peerId);
      if (authoritativeKeys.contains(key)) {
        continue;
      }
      await repo.updateById(conversation.id, {ConversationRepo.isShow: 0});
      hidden++;
    }

    return hidden;
  }

  Future<void> _persistPinnedState(
    ConversationModel conversation,
    bool pinned,
  ) async {
    final repo = ConversationRepo();
    final payload = _mergeAuthoritativePayload(
      existingPayload: conversation.payload,
      serverTs: DateTimeHelper.millisecond(),
      isPinned: pinned,
      lastMsg:
          parseModelJsonMap(
            parseModelJsonMap(
              conversation.payload?['authoritative'],
            )?['last_msg'],
          ) ??
          <String, dynamic>{},
    );

    await repo.updateById(conversation.id, {
      ConversationRepo.isShow: 1,
      ConversationRepo.payload: payload,
    });

    final updated = await repo.findById(conversation.id);
    if (updated != null) {
      applyConversationSnapshot(updated);
    } else {
      applyConversationSnapshot(
        conversation.copyWith(payload: payload, isShow: 1),
      );
    }
  }

  Future<void> syncAuthoritativeConversations({
    String trigger = 'manual',
  }) async {
    const source = 'server_authoritative_pull';
    int fetchedCount = 0;
    int synced = 0;
    try {
      final entries = await _conversationApi.listMine();
      fetchedCount = entries.length;
      final repo = ConversationRepo();
      final authoritativeKeys = <String>{};

      for (final entry in entries) {
        final peerId = parseModelString(entry['conversation_id']);
        final type = _normalizeAuthoritativeType(
          parseModelString(entry['conversation_type']),
        );
        if (peerId.isEmpty || type.isEmpty) {
          continue;
        }
        authoritativeKeys.add(_authoritativeKey(type, peerId));

        final serverTs = _parseAuthoritativeServerTs(entry['server_ts']);
        final lastMsgId = parseModelString(entry['last_msg_id']);
        final lastMsg =
            parseModelJsonMap(entry['last_msg']) ?? <String, dynamic>{};
        final isPinned = parseModelBool(entry['is_pinned']);
        final msgType = _resolveAuthoritativeMsgType(lastMsg);
        final subtitle = _resolveAuthoritativeSubtitle(lastMsg, msgType);
        final avatar = _resolveAuthoritativeAvatar(lastMsg);

        final existing = await repo.findByPeerId(type, peerId);
        if (existing == null) {
          final created = ConversationModel(
            id: 0,
            peerId: peerId,
            avatar: avatar,
            title: '',
            subtitle: subtitle,
            type: type,
            msgType: msgType,
            lastTime: serverTs,
            lastMsgId: lastMsgId,
            unreadNum: 0,
            isShow: 1,
            payload: _mergeAuthoritativePayload(
              existingPayload: null,
              serverTs: serverTs,
              isPinned: isPinned,
              lastMsg: lastMsg,
            ),
          );
          await repo.insert(created);
          synced++;
          continue;
        }

        final shouldAdvance = serverTs > 0 && serverTs >= existing.lastTime;
        final data = <String, dynamic>{
          ConversationRepo.isShow: 1,
          ConversationRepo.payload: _mergeAuthoritativePayload(
            existingPayload: existing.payload,
            serverTs: serverTs,
            isPinned: isPinned,
            lastMsg: lastMsg,
          ),
        };

        if (shouldAdvance) {
          data[ConversationRepo.lastTime] = serverTs;
          if (lastMsgId.isNotEmpty) {
            data[ConversationRepo.lastMsgId] = lastMsgId;
          }
          if (msgType.isNotEmpty) {
            data[ConversationRepo.msgType] = msgType;
          }
          data[ConversationRepo.subtitle] = subtitle;
          if (existing.avatar.isEmpty && avatar.isNotEmpty) {
            data[ConversationRepo.avatar] = avatar;
          }
        }

        await repo.updateById(existing.id, data);
        synced++;
      }

      synced += await _hideMissingAuthoritativeConversations(
        repo,
        authoritativeKeys,
      );

      iPrint(
        'ConversationNotifier: authoritative sync finished, items=$synced',
      );
      AppEventBus.fireTracked(
        ConversationAuthoritySyncEvent(
          trigger: trigger,
          source: source,
          fetchedCount: fetchedCount,
          syncedCount: synced,
          success: true,
        ),
      );
    } catch (e, s) {
      iPrint('ConversationNotifier: authoritative sync failed: $e; $s');
      AppEventBus.fireTracked(
        ConversationAuthoritySyncEvent(
          trigger: trigger,
          source: source,
          fetchedCount: fetchedCount,
          syncedCount: synced,
          success: false,
        ),
      );
    }
  }

  Future<bool> setConversationPinned(
    ConversationModel conversation,
    bool pinned,
  ) async {
    if (conversation.peerId.isEmpty || conversation.type.isEmpty) {
      return false;
    }

    final ok = pinned
        ? await _conversationApi.pin(
            conversationId: conversation.peerId,
            type: conversation.type,
          )
        : await _conversationApi.unpin(
            conversationId: conversation.peerId,
            type: conversation.type,
          );
    if (!ok) {
      return false;
    }

    await _persistPinnedState(conversation, pinned);
    return true;
  }

  Future<bool> deleteConversationRemote(ConversationModel conversation) async {
    if (conversation.peerId.isEmpty || conversation.type.isEmpty) {
      return false;
    }

    final ok = await _conversationApi.deleteConversation(
      conversationId: conversation.peerId,
      type: conversation.type,
    );
    if (!ok) {
      return false;
    }

    await ConversationRepo().updateById(conversation.id, {
      ConversationRepo.isShow: 0,
    });
    removeConversationFromMap(conversation.uk3);
    removeConversationRemind(conversation.uk3);
    return true;
  }

  Future<bool> restoreConversationRemote({
    required String peerId,
    required String type,
  }) async {
    if (peerId.isEmpty || type.isEmpty) {
      return false;
    }

    final ok = await _conversationApi.restoreConversation(
      conversationId: peerId,
      type: type,
    );
    if (!ok) {
      return false;
    }

    await syncAuthoritativeConversationList(trigger: 'conversation_restore');
    return true;
  }

  Future<List<Map<String, dynamic>>> authoritativePinnedList() {
    return _conversationApi.pinnedList();
  }

  Future<List<ConversationModel>> conversationsList({
    String type = '',
    bool recalculateRemind = true,
    bool syncAuthoritative = false,
    String syncTrigger = 'manual',
  }) async {
    try {
      if (syncAuthoritative) {
        await syncAuthoritativeConversations(trigger: syncTrigger);
      }
      List<ConversationModel> li = await (ConversationRepo()).list(type: type);
      await Future.wait(
        li.map((obj) async {
          // obj.title = '';
          if (obj.title.isEmpty) {
            obj.title = await computeTitle(obj);
          }
        }),
      );

      await _cleanupExpiredBurnLastMessages(li);

      if (recalculateRemind) {
        await recalculateAllReminds(li);
      }

      final newMap = {for (var c in li) c.uk3: c};
      if (!ref.mounted) {
        return li;
      }
      state = state.copyWith(conversationMap: newMap, isLoading: false);
      return li;
    } catch (e, s) {
      iPrint('conversationsList error: $e; $s');
      return [];
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> syncAuthoritativeConversationList({
    String trigger = 'manual',
  }) async {
    await conversationsList(syncAuthoritative: true, syncTrigger: trigger);
  }

  Future<void> refreshConversationListLocal({
    bool recalculateRemind = true,
  }) async {
    await conversationsList(recalculateRemind: recalculateRemind);
  }

  Future<void> _cleanupExpiredBurnLastMessages(
    List<ConversationModel> conversations,
  ) async {
    try {
      if (conversations.isEmpty) return;
      final repo = ConversationRepo();

      for (int i = 0; i < conversations.length; i++) {
        final cm = conversations[i];
        if (cm.lastMsgId.isEmpty) continue;

        final tb = MessageRepo.getTableName(cm.type);
        if (tb.isEmpty) continue;
        final mRepo = MessageRepo(tableName: tb);
        final MessageModel? lastMsg = await mRepo.find(cm.lastMsgId);
        if (lastMsg == null) continue;

        if (!isBurnExpiredPayload(lastMsg.payload)) continue;

        await expireBurnMessage(cm, cm.lastMsgId);
        final updated = await repo.findById(cm.id);
        if (updated != null) {
          conversations[i] = updated;
        }
      }
    } catch (e) {
      debugPrint('[ConversationProvider] conversation update failed: $e');
    }
  }

  /// 删除会话及其所有消息
  ///
  /// 使用 ConversationRepo.deleteConversation() 方法，该方法：
  /// - 在事务中完成所有操作，保证原子性
  /// - 自动清理重试队列
  /// - 删除消息和会话记录
  Future<bool> removeConversation(ConversationModel cm) async {
    if (cm.uk3.isEmpty) return false;
    try {
      // 使用事务删除会话及其消息
      await ConversationRepo().deleteConversation(cm);

      // 清理内存中的会话数据
      removeConversationFromMap(cm.uk3);
      removeConversationRemind(cm.uk3);
      return true;
    } catch (e, s) {
      iPrint('removeConversation error: $e; $s');
      return false;
    }
  }

  Future<void> hideConversation(int cid) async {
    try {
      await ConversationRepo().updateById(cid, {ConversationRepo.isShow: 0});
      final uk3 = state.conversationMap.entries
          .firstWhere(
            (e) => e.value.id == cid,
            orElse: () => MapEntry('', ConversationModel.empty()),
          )
          .key;
      if (uk3.isNotEmpty) {
        removeConversationFromMap(uk3);
      }
    } catch (e, s) {
      iPrint('hideConversation error: $e, $s');
    }
  }

  Future<List<ConversationModel>> updateLastMsg(
    String msgId,
    Map<String, dynamic> data,
  ) async {
    if (msgId.isEmpty) return [];
    try {
      if (data.containsKey(ConversationRepo.payload) &&
          data[ConversationRepo.payload] is Map) {
        data[ConversationRepo.payload] = jsonEncode(
          data[ConversationRepo.payload],
        );
      }

      Database? db = await SqliteService.to.db;
      if (db == null) return [];

      String where =
          "${ConversationRepo.userId}=? and ${ConversationRepo.lastMsgId}=?";
      List<String> whereArgs = [UserRepoLocal.to.currentUid, msgId];

      await db.update(
        ConversationRepo.tableName,
        data,
        where: where,
        whereArgs: whereArgs,
      );
      return await (ConversationRepo()).search(where, whereArgs);
    } catch (e, s) {
      iPrint('updateLastMsg error: $e; $s');
      return [];
    }
  }

  Future<void> updateConversationByMsgId(
    String msgId,
    Map<String, dynamic> data,
  ) async {
    if (msgId.isEmpty) return;
    try {
      List<ConversationModel> items = await updateLastMsg(msgId, data);
      for (var item in items) {
        await replace(item);
        AppEventBus.fireData(item);
        iPrint(
          'updateConversationByMsgId: 更新会话 ${item.uk3} 的 lastMsgStatus 为 ${item.lastMsgStatus}',
        );
      }
    } catch (e, s) {
      iPrint('updateConversationByMsgId error: $e; $s');
    }
  }

  Future<ConversationModel> createConversation({
    required String type,
    required String peerId,
    required String avatar,
    required String title,
    int lastTime = 0,
    String subtitle = '',
  }) async {
    ConversationRepo repo = ConversationRepo();
    ConversationModel? m = await repo.findByPeerId(type, peerId);
    if (m == null) {
      await repo.insert(
        ConversationModel.fromJson({
          ConversationRepo.peerId: peerId,
          ConversationRepo.avatar: avatar,
          ConversationRepo.title: title,
          ConversationRepo.subtitle: subtitle,
          ConversationRepo.lastTime: lastTime,
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastMsgStatus: 1,
          ConversationRepo.unreadNum: 0,
          ConversationRepo.type: type,
          ConversationRepo.msgType: '',
          ConversationRepo.isShow: 1,
          ConversationRepo.payload: {},
        }),
      );
      m = await repo.findByPeerId(type, peerId);
      if (m != null && m.uk3.isNotEmpty) {
        // 检查 provider 是否仍然有效，避免在销毁后访问 state
        if (ref.mounted) {
          final newMap = Map<String, ConversationModel>.from(
            state.conversationMap,
          );
          newMap[m.uk3] = m;
          state = state.copyWith(conversationMap: newMap);
        }
      }
    }
    // 确保返回非空值
    if (m == null) {
      throw StateError('Failed to create conversation for peerId: $peerId');
    }
    return m;
  }

  Future<void> recalculateAllReminds(List<ConversationModel> list) async {
    await Future.wait(list.map((cm) => recalculateConversationRemind(cm)));
  }

  Future<void> recalculateConversationRemind(ConversationModel cm) async {
    if (cm.uk3.isEmpty) return;
    try {
      String tb = MessageRepo.getTableName(cm.type);
      final lastRead = _getLastReadAutoId(cm);
      int? count = await SqliteService.to.count(
        tb,
        where:
            "${MessageRepo.conversationUk3} = ? and ${MessageRepo.isAuthor} = ? and ${MessageRepo.autoId} > ?",
        whereArgs: [cm.uk3, 0, lastRead],
      );
      if (count != null) {
        await setConversationRemind(cm, count);
      }
    } catch (e, s) {
      iPrint('recalculateConversationRemind error: $e; $s');
    }
  }

  // 依据一组消息ID推进"已读水位"至这些消息中的最大 auto_id，然后重算未读数
  Future<void> advanceReadWatermarkByMsgIds(
    ConversationModel cm,
    List<String> msgIds,
  ) async {
    if (cm.uk3.isEmpty || msgIds.isEmpty) return;
    try {
      String tb = MessageRepo.getTableName(cm.type);
      final placeholders = List.filled(msgIds.length, '?').join(',');
      final where =
          "${MessageRepo.conversationUk3} = ? and ${MessageRepo.isAuthor} = ? and ${MessageRepo.id} IN ($placeholders)";
      final whereArgs = [cm.uk3, 0, ...msgIds];

      final int? maxAutoId = await SqliteService.to.pluck<int>(
        'MAX(${MessageRepo.autoId})',
        tb,
        where: where,
        whereArgs: whereArgs,
      );
      if (maxAutoId != null) {
        await _setLastReadAutoId(cm, maxAutoId);
        await recalculateConversationRemind(cm);
      }
    } catch (e, s) {
      iPrint('advanceReadWatermarkByMsgIds error: $e; $s');
    }
  }

  // 将水位推进到当前会话"来自对方"的最新消息（用于"标为已读"）
  Future<void> advanceWatermarkToLatest(ConversationModel cm) async {
    if (cm.uk3.isEmpty) return;
    try {
      String tb = MessageRepo.getTableName(cm.type);
      final int? maxAutoId = await SqliteService.to.pluck<int>(
        'MAX(${MessageRepo.autoId})',
        tb,
        where:
            "${MessageRepo.conversationUk3} = ? and ${MessageRepo.isAuthor} = ?",
        whereArgs: [cm.uk3, 0],
      );
      if (maxAutoId != null) {
        await _setLastReadAutoId(cm, maxAutoId);
        await recalculateConversationRemind(cm);
      }
    } catch (e, s) {
      iPrint('advanceWatermarkToLatest error: $e; $s');
    }
  }

  /// 获取联系人标题(用于C2C会话)
  Future<String> _getContactTitle(String peerId) async {
    if (peerId.trim().isEmpty) {
      return '';
    }

    try {
      ContactModel? c = await ContactRepo().findByUid(peerId, autoFetch: true);
      if (c != null) {
        return c.title;
      }
    } catch (e, s) {
      iPrint('_getContactTitle error for $peerId: $e; $s');
    }

    // 如果没有找到联系人信息，返回peerId
    return peerId;
  }

  // Compute avatar for group - temporary implementation
  Future<String> computeGroupAvatar(String groupId) async {
    try {
      final group = await (GroupRepo()).findById(groupId);
      if (group != null && group.avatar.isNotEmpty) {
        return group.avatar;
      }
    } catch (e) {
      iPrint('computeGroupAvatar error: $e');
    }
    return '';
  }
}
