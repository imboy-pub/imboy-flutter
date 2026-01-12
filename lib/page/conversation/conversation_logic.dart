import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/contact_model.dart' show ContactModel;
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite/sqflite.dart';

class ConversationLogic extends GetxController {
  // 会话映射表 - 更高性能的查找和更新
  final RxMap<String, ConversationModel> conversationMap = <String, ConversationModel>{}.obs;

  // 会话列表 getter（已排序）
  List<ConversationModel> get conversations => conversationMap.values.toList()
    ..sort((a, b) => b.lastTime.compareTo(a.lastTime));

  final RxString connectDesc = "".obs;
  final RxMap<String, int> conversationRemind = <String, int>{}.obs;
  final Map<String, Timer> _debounceTimers = {};

  late final GroupListLogic _groupListLogic;

  /// 公共 getter 用于访问 groupListLogic
  GroupListLogic get groupListLogic => _groupListLogic;

  @override
  void onInit() {
    super.onInit();
    _groupListLogic = Get.find<GroupListLogic>();
  }

  @override
  void onClose() {
    _debounceTimers.forEach((_, timer) => timer.cancel());
    _debounceTimers.clear();
    super.onClose();
  }

  Rx<int> get chatMsgRemindCounter => conversationRemind.values.fold(0, (sum, val) => sum + val).obs;

  // 读取会话的“已读水位”（使用消息表 auto_id）
  int _getLastReadAutoId(ConversationModel conversation) {
    try {
      final v = conversation.payload?['last_read_auto_id'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // 设置会话“已读水位”（仅推进，不回退）
  Future<void> _setLastReadAutoId(ConversationModel conversation, int autoId) async {
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
    if (conversationMap.containsKey(uk3)) {
      conversationMap[uk3] = conversationMap[uk3]!.copyWith(payload: newPayload);
    } else {
      // 不在 Map 中时，尽量更新传入对象的 payload
      conversation.payload = newPayload;
    }
  }

  Future<void> setConversationRemind(ConversationModel conversation, int val) async {
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

        conversationRemind[uk3] = val;

        if (conversationMap.containsKey(uk3)) {
          conversationMap[uk3] = conversationMap[uk3]!.copyWith(unreadNum: val);
        }
      } catch (e, s) {
        iPrint('setConversationRemind error: $e ; $s');
      } finally {
        _debounceTimers.remove(uk3);
      }
    });
  }

  Future<void> increaseConversationRemind(ConversationModel conversation, int val) async {
    if (conversation.uk3.isEmpty) return;
    final current = conversationRemind[conversation.uk3] ?? 0;
    await setConversationRemind(conversation, current + val);
  }

  Future<void> decreaseConversationRemind(ConversationModel conversation, int val) async {
    if (conversation.uk3.isEmpty) return;
    final current = conversationRemind[conversation.uk3] ?? 0;
    await setConversationRemind(conversation, (current - val).clamp(0, 999999));
  }

  Future<void> replace(ConversationModel obj) async {
    if (obj.uk3.isEmpty) return;
    conversationMap[obj.uk3] = obj;
  }

  Future<String> computeTitle(ConversationModel obj) async {

    String computedTitle = '';

    if (obj.type == 'C2G') {
      // 群组会话：如果设置了群名称，就应该取群名称；否则取 _groupListLogic.computeTitle 的结果
      final group = await (GroupRepo()).findById(obj.peerId);
      if (group != null && group.title.trim().isNotEmpty) {
        computedTitle = group.title;
      } else {
        computedTitle = await _groupListLogic.computeTitle(obj.peerId);
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

  Future<List<ConversationModel>> conversationsList({
    String type = '',
    bool recalculateRemind = true,
  }) async {
    try {
      List<ConversationModel> li = await (ConversationRepo()).list(type: type);
      await Future.wait(li.map((obj) async {
        // obj.title = '';
        if (obj.title.isEmpty) {
          obj.title = await computeTitle(obj);
        }
      }));

      await _cleanupExpiredBurnLastMessages(li);
      
      if (recalculateRemind) {
        await recalculateAllReminds(li);
      }
      
      conversationMap.assignAll({for (var c in li) c.uk3: c});
      return li;
    } catch (e, s) {
      iPrint('conversationsList error: $e; $s');
      return [];
    }
  }

  Future<void> _cleanupExpiredBurnLastMessages(List<ConversationModel> conversations) async {
    try {
      if (conversations.isEmpty) return;
      final chatLogic = Get.find<ChatLogic>();
      final repo = ConversationRepo();

      for (int i = 0; i < conversations.length; i++) {
        final cm = conversations[i];
        if (cm.lastMsgId.isEmpty) continue;

        final tb = MessageRepo.getTableName(cm.type);
        if (tb.isEmpty) continue;
        final mRepo = MessageRepo(tableName: tb);
        final MessageModel? lastMsg = await mRepo.find(cm.lastMsgId);
        if (lastMsg == null) continue;

        if (!chatLogic.isBurnExpiredPayload(lastMsg.payload)) continue;

        await chatLogic.expireBurnMessage(cm, cm.lastMsgId);
        final updated = await repo.findById(cm.id);
        if (updated != null) {
          conversations[i] = updated;
        }
      }
    } catch (_) {}
  }

  // Future<void> sortConversationsList() async {
  //   // 排序通过 getter 实现，不再修改 Map 内部结构
  // }

  Future<bool> removeConversation(ConversationModel cm) async {
    if (cm.uk3.isEmpty) return false;
    try {
      Database? db = await SqliteService.to.db;
      if (db == null) return false;

      return await db.transaction((txn) async {
        String tb = MessageRepo.getTableName(cm.type);

        // 先查询该会话的所有消息ID，用于清理重试队列
        final List<Map<String, dynamic>> messages = await txn.query(
          tb,
          columns: ['id'],
          where: '${MessageRepo.conversationUk3}=?',
          whereArgs: [cm.uk3],
        );

        // 清理重试队列中属于该会话的消息
        if (messages.isNotEmpty && Get.isRegistered<MessageRetry>()) {
          for (final msg in messages) {
            final msgId = msg['id'] as String?;
            if (msgId != null && msgId.isNotEmpty) {
              MessageRetry.to.removeFromRetryQueue(msgId);
            }
          }
          iPrint('已从重试队列清理 ${messages.length} 条消息: conversationUk3=${cm.uk3}');
        }

        // 删除数据库中的消息和会话记录
        await txn.execute("DELETE FROM $tb WHERE ${MessageRepo.conversationUk3}=?", [cm.uk3]);
        await txn.execute("DELETE FROM ${ConversationRepo.tableName} WHERE id=?", [cm.id]);

        conversationMap.remove(cm.uk3);
        conversationRemind.remove(cm.uk3);
        return true;
      });
    } catch (e, s) {
      iPrint('removeConversation error: $e; $s');
      return false;
    }
  }

  Future<void> hideConversation(int cid) async {
    try {
      await ConversationRepo().updateById(cid, {ConversationRepo.isShow: 0});
      final uk3 = conversationMap.entries
          .firstWhere(
            (e) => e.value.id == cid,
        orElse: () => MapEntry('', ConversationModel.empty()),
      )
          .key;
      if (uk3.isNotEmpty) {
        conversationMap.remove(uk3);
      }
    } catch (e, s) {
      iPrint('hideConversation error: $e, $s');
    }
  }

  Future<List<ConversationModel>> updateLastMsg(String msgId, Map<String, dynamic> data) async {
    if (msgId.isEmpty) return [];
    try {
      if (data.containsKey(ConversationRepo.payload) && data[ConversationRepo.payload] is Map) {
        data[ConversationRepo.payload] = jsonEncode(data[ConversationRepo.payload]);
      }

      Database? db = await SqliteService.to.db;
      if (db == null) return [];

      String where = "${ConversationRepo.userId}=? and ${ConversationRepo.lastMsgId}=?";
      List<String> whereArgs = [UserRepoLocal.to.currentUid, msgId];

      await db.update(ConversationRepo.tableName, data, where: where, whereArgs: whereArgs);
      return await (ConversationRepo()).search(where, whereArgs);
    } catch (e, s) {
      iPrint('updateLastMsg error: $e; $s');
      return [];
    }
  }

  Future<void> updateConversationByMsgId(String msgId, Map<String, dynamic> data) async {
    if (msgId.isEmpty) return;
    try {
      List<ConversationModel> items = await updateLastMsg(msgId, data);
      for (var item in items) {
        await replace(item);
        AppEventBus.fireData(item);
        iPrint('updateConversationByMsgId: 更新会话 ${item.uk3} 的 lastMsgStatus 为 ${item.lastMsgStatus}');
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
      await repo.insert(ConversationModel.fromJson({
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
      }));
      m = await repo.findByPeerId(type, peerId);
      if (m != null && m.uk3.isNotEmpty) {
        conversationMap[m.uk3] = m;
      }
    }
    return m!;
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
        where: "${MessageRepo.conversationUk3} = ? and ${MessageRepo.isAuthor} = ? and ${MessageRepo.autoId} > ?",
        whereArgs: [cm.uk3, 0, lastRead],
      );
      if (count != null) {
        await setConversationRemind(cm, count);
      }
    } catch (e, s) {
      iPrint('recalculateConversationRemind error: $e; $s');
    }
  }

  // 依据一组消息ID推进“已读水位”至这些消息中的最大 auto_id，然后重算未读数
  Future<void> advanceReadWatermarkByMsgIds(ConversationModel cm, List<String> msgIds) async {
    if (cm.uk3.isEmpty || msgIds.isEmpty) return;
    try {
      String tb = MessageRepo.getTableName(cm.type);
      final placeholders = List.filled(msgIds.length, '?').join(',');
      final where = "${MessageRepo.conversationUk3} = ? and ${MessageRepo.isAuthor} = ? and ${MessageRepo.id} IN ($placeholders)";
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

  // 将水位推进到当前会话“来自对方”的最新消息（用于“标为已读”）
  Future<void> advanceWatermarkToLatest(ConversationModel cm) async {
    if (cm.uk3.isEmpty) return;
    try {
      String tb = MessageRepo.getTableName(cm.type);
      final int? maxAutoId = await SqliteService.to.pluck<int>(
        'MAX(${MessageRepo.autoId})',
        tb,
        where: "${MessageRepo.conversationUk3} = ? and ${MessageRepo.isAuthor} = ?",
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
}
