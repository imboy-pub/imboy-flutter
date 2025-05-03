import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
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

  Future<List<ConversationModel>> conversationsList({
    String type = '',
    bool recalculateRemind = true,
  }) async {
    try {
      List<ConversationModel> li = await (ConversationRepo()).list(type: type);
      await Future.wait(li.map((obj) async {
        if (obj.type == 'C2G') {
          final futures = <Future>[];
          if (obj.avatar.isEmpty) {
            futures.add(_groupListLogic.computeAvatar(obj.peerId).then((v) => obj.computeAvatar = v));
          }
          if (obj.title.isEmpty) {
            futures.add(_groupListLogic.computeTitle(obj.peerId).then((v) => obj.computeTitle = v));
          }
          await Future.wait(futures);
        }
        if (recalculateRemind) {
          await recalculateAllReminds(li);
        }
      }));
      conversationMap.assignAll({for (var c in li) c.uk3: c});
      return li;
    } catch (e, s) {
      iPrint('conversationsList error: $e; $s');
      return [];
    }
  }

  Future<void> sortConversationsList() async {
    // 排序通过 getter 实现，不再修改 Map 内部结构
  }

  Future<bool> removeConversation(ConversationModel cm) async {
    if (cm.uk3.isEmpty) return false;
    try {
      Database? db = await SqliteService.to.db;
      if (db == null) return false;

      return await db.transaction((txn) async {
        String tb = MessageRepo.getTableName(cm.type);
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
        eventBus.fire(item);
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
      if (m != null) {
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
      int? count = await SqliteService.to.count(
        tb,
        where: "${MessageRepo.conversationUk3} = ? and ${MessageRepo.status} = ? and ${MessageRepo.isAuthor} = ?",
        whereArgs: [cm.uk3, IMBoyMessageStatus.delivered, 0],
      );
      if (count != null) {
        await setConversationRemind(cm, count);
      }
    } catch (e, s) {
      iPrint('recalculateConversationRemind error: $e; $s');
    }
  }
}
