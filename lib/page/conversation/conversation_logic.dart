import 'dart:convert';

import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite/sqflite.dart';

class ConversationLogic extends GetxController {
  // 会话列表
  RxList<ConversationModel> conversations = RxList<ConversationModel>([]);

  // 网络状态描述
  RxString connectDesc = "".obs;

  // 会话提醒数量映射
  final RxMap<int, RxInt> conversationRemind = RxMap<int, RxInt>({});

  // 设置会话提醒
  setConversationRemind(int cid, int val) {
    val = val > 0 ? val : 0;
    (ConversationRepo()).updateById(cid, {
      ConversationRepo.unreadNum: val,
      ConversationRepo.isShow: 1,
    });
    if (conversationRemind.containsKey(cid)) {
      conversationRemind[cid]!.value = val;
    } else {
      conversationRemind[cid] = val.obs;
    }
    refresh();
  }

  /// 更新会话
  replace(ConversationModel obj) async {
    iPrint("ConversationRepo_Logic_replace ${obj.toJson().toString()}");
    // 第一次会话的时候 i 为 -1
    final i = conversations.indexWhere((ConversationModel m) => m.id == obj.id);
    if (i > -1) {
      int i2 = i > 0 ? i : 0;
      conversations[i2] = obj;
    } else {
      conversations.add(obj);
    }
    // 重新计算会话消息提醒数量
    recalculateConversationRemind(obj.id);
  }

  /// 步增会话提醒
  increaseConversationRemind(int cid, int val) async {
    if (!conversationRemind.containsKey(cid) ||
        conversationRemind[cid] == null ||
        conversationRemind[cid]! < 0) {
      conversationRemind[cid] = 0.obs;
    }
    RxInt val1 = (conversationRemind[cid]?.value ?? 0 + val).obs;
    conversationRemind[cid] = val1;
    iPrint(
        "setConversationRemind_increaseConversationRemind cid $cid, val $val ${DateTime.now()}");
    await setConversationRemind(cid, val1.value);
  }

  // 步减会话提醒
  decreaseConversationRemind(int cid, int val) async {
    iPrint(
        "setConversationRemind_decreaseConversationRemind cid $cid, val $val ${DateTime.now()}");
    if (conversationRemind.value.containsKey(cid)) {
      iPrint(
          "decreaseConversationRemind cid $cid, val2 ${conversationRemind[cid]!.value}");
      val = conversationRemind[cid]!.value - val;
    }
    await setConversationRemind(cid, val);
  }

  // 聊天消息提醒计数器
  Rx<int> get chatMsgRemindCounter {
    // debugPrint("> on count chatMsgRemindCounter");
    int c = 0;
    conversationRemind.value.forEach((key, val) {
      c += val.value;
    });
    return c.obs;
  }

  @override
  Future<void> onReady() async {
    // TODO: implement onReady
    super.onReady();
  }

  /// 获取会话类别
  Future<void> conversationsList() async {
    conversations.value = await (ConversationRepo()).list();
  }

  /// 会话列表按最近会话时间倒序排序
  Future<void> sortConversationsList() async {
    conversations.sort(((a, b) => b.lastTime.compareTo(a.lastTime)));
  }

  /// 移除会话
  Future<bool> removeConversation(int conversationId) async {
    Database db = await SqliteService.to.db;
    ConversationModel? cm = await ConversationRepo().findById(conversationId);
    String tableName =
        cm?.type == 'C2G' ? MessageRepo.c2gTable : MessageRepo.c2cTable;
    return await db.transaction((txn) async {
      await txn.execute(
        "DELETE FROM $tableName WHERE ${MessageRepo.conversationId}=?",
        [conversationId],
      );
      await txn.execute(
        "DELETE FROM ${ConversationRepo.tableName} WHERE id=?",
        [conversationId],
      );
      return true;
    });
  }

  /// 不显示（在会话列表）
  Future<void> hideConversation(int cid) async {
    await ConversationRepo().updateById(cid, {ConversationRepo.isShow: 0});
  }

  /// 按消息ID来更新会话最后一消息的状态
  Future<List<ConversationModel>> updateLastMsg(
    String msgId,
    Map<String, dynamic> data,
  ) async {
    iPrint("updateLastMsg $msgId, ${data.toString()}");
    if (data.containsKey(ConversationRepo.payload) &&
        data[ConversationRepo.payload] is Map<String, dynamic>) {
      data[ConversationRepo.payload] =
          jsonEncode(data[ConversationRepo.payload]);
    }
    Database db = await SqliteService.to.db;
    String where =
        "${ConversationRepo.userId}=? and ${ConversationRepo.lastMsgId}=?";
    List<String> whereArgs = [
      UserRepoLocal.to.currentUid,
      msgId,
    ];
    await db.update(
      ConversationRepo.tableName,
      data,
      where: where,
      whereArgs: whereArgs,
    );

    return await (ConversationRepo()).search(
      where,
      whereArgs,
    );
  }

  Future<int> createConversationId(
    String peerId,
    String avatar,
    String title,
    String type,
  ) async {
    String where =
        '${ConversationRepo.type} = ? and ${ConversationRepo.userId} = ? and ${ConversationRepo.peerId} = ?';
    List<Object?> whereArgs = [type, UserRepoLocal.to.currentUid, peerId];

    int? id = await SqliteService.to.pluck(
      'id',
      ConversationRepo.tableName,
      where: where,
      whereArgs: whereArgs,
    );
    iPrint("> on pageMessages createConversationId id $id");
    if (id != null && id > 0) {
      return id;
    }

    return await (ConversationRepo()).insert(ConversationModel.fromJson({
      ConversationRepo.peerId: peerId,
      ConversationRepo.avatar: avatar,
      ConversationRepo.title: title,
      ConversationRepo.subtitle: '',
      // 单位毫秒，13位时间戳  1561021145560
      ConversationRepo.lastTime: 0,
      ConversationRepo.lastMsgId: '',
      ConversationRepo.lastMsgStatus: 1,
      ConversationRepo.unreadNum: 0,
      ConversationRepo.type: type,
      ConversationRepo.msgType: '',
      ConversationRepo.isShow: 0,
      ConversationRepo.payload: {},
    }));
  }

  // 重新计算会话消息提醒数量
  recalculateConversationRemind(int cid) async {
    ConversationModel? cm = await ConversationRepo().findById(cid);
    if (cm == null) {
      return;
    }
    String tb = cm.type == 'C2G' ? MessageRepo.c2gTable : MessageRepo.c2cTable;
    int? count = await SqliteService.to.count(
      tb,
      where: "${MessageRepo.conversationId} = ? and ${MessageRepo.status} = ?",
      whereArgs: [cid, IMBoyMessageStatus.delivered],
    );
    iPrint("recalculateConversationRemind $tb $count, $cid");
    // String sql = Sqlite.instance
    if (count != null) {
      setConversationRemind(cid, count);
    }
  }

  /**
   * 是否当前会话的最后一条消息
   */
  // Future<bool> isLastMsg(String msgId) async {}

  /// 更新会话状态
  updateConversationByMsgId(String msgId, Map<String, dynamic> data) async {
    List<ConversationModel> items = await updateLastMsg(msgId, data);
    if (items.isNotEmpty) {
      for (var item in items) {
        // 更新会话
        replace(item);
        eventBus.fire(item);
      }
    }
  }
}
