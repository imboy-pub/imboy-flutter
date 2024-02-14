import 'dart:convert';

import 'package:get/get.dart';
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
  final RxMap<String, RxInt> conversationRemind = RxMap<String, RxInt>({});

  // 设置会话提醒
  setConversationRemind(String peerId, int val) {
    val = val > 0 ? val : 0;
    (ConversationRepo()).updateByPeerId(peerId, {
      ConversationRepo.unreadNum: val,
      ConversationRepo.isShow: 1,
    });
    if (conversationRemind.containsKey(peerId)) {
      conversationRemind[peerId]!.value = val;
    } else {
      conversationRemind[peerId] = val.obs;
    }
  }

  /// 更新会话
  replace(ConversationModel obj) async {
    // 第一次会话的时候 i 为 -1
    final i = conversations
        .indexWhere((ConversationModel item) => (item).peerId == obj.peerId);
    if (i > -1) {
      int i2 = i > 0 ? i : 0;
      conversations[i2] = obj;
    } else {
      conversations.add(obj);
    }
    // 重新计算会话消息提醒数量
    recalculateConversationRemind(obj.peerId);
    update([conversations]);
  }

  /// 步增会话提醒
  increaseConversationRemind(String key, int val) {
    if (!conversationRemind.containsKey(key) ||
        conversationRemind[key] == null ||
        conversationRemind[key]! < 0) {
      conversationRemind[key] = 0.obs;
    }
    RxInt val1 = (conversationRemind[key]?.value ?? 0 + val).obs;
    conversationRemind[key] = val1;
    setConversationRemind(key, val1.value);
  }

  // 步减会话提醒
  decreaseConversationRemind(String key, int val) {
    if (conversationRemind.value.containsKey(key)) {
      val = conversationRemind[key]!.value - val;
    }
    setConversationRemind(key, val);
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
  Future<void> hideConversation(String peerId) async {
    await ConversationRepo()
        .updateByPeerId(peerId, {ConversationRepo.isShow: 0});
  }

  /// 按消息ID来更新会话最后一消息的状态
  Future<List<ConversationModel>> updateLastMsg(
      String msgId, Map<String, dynamic> data) async {
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
    ConversationRepo repo = ConversationRepo();
    ConversationModel? obj = await repo.findByPeerId(peerId);
    if (obj != null) {
      return obj.id;
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
  recalculateConversationRemind(String peerId) async {
    ConversationModel? cm = await ConversationRepo().findByPeerId(peerId);
    String tb = cm?.type == 'C2G' ? MessageRepo.c2gTable : MessageRepo.c2cTable;
    int? count = await SqliteService.to.count(
      tb,
      where:
          "${MessageRepo.status} = ? and ${MessageRepo.from} = ? and ${MessageRepo.from} <> ?",
      whereArgs: [MessageStatus.delivered, peerId, UserRepoLocal.to.currentUid],
    );
    // debugPrint("recalculateConversationRemind $count, $peerId");
    // String sql = Sqlite.instance
    if (count != null) {
      setConversationRemind(peerId, count);
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
