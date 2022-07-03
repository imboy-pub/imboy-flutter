import 'package:get/get.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:sqflite/sqflite.dart';

class ConversationLogic extends GetxController {
  // 会话列表
  RxList<ConversationModel> conversations = RxList<ConversationModel>([]);

  // 网络状态描述
  RxString connectDesc = "".obs;

  // 会话提醒数量映射
  final RxMap<String, int> conversationRemind = RxMap<String, int>({});

  // 设置会话提醒
  setConversationRemind(String typeId, int val) {
    val = val > 0 ? val : 0;
    conversationRemind[typeId] = val;
    (ConversationRepo()).updateByTypeId(typeId, {
      ConversationRepo.unreadNum: val,
      ConversationRepo.isShow: 1,
    });
    update([conversationRemind]);
  }

  // 更新会话
  replace(ConversationModel cobj) {
    // 第一次会话的时候 i 为 -1
    final i = conversations
        .indexWhere((ConversationModel item) => (item).typeId == cobj.typeId);
    if (i > -1) {
      int i2 = i > 0 ? i : 0;
      conversations[i2] = cobj;
    } else {
      conversations.add(cobj);
    }
    update([conversations]);
  }

  // 步增会话提醒
  increaseConversationRemind(String key, int val) {
    if (!conversationRemind.containsKey(key) ||
        conversationRemind[key] == null ||
        conversationRemind[key]! < 0) {
      conversationRemind[key] = 0;
    }
    conversationRemind[key] = conversationRemind[key]!.toInt() + val;
    setConversationRemind(key, conversationRemind[key]!);
  }

  // 步减会话提醒
  decreaseConversationRemind(String key, int val) {
    if (conversationRemind.containsKey(key)) {
      val = conversationRemind[key]! - val;
    }
    setConversationRemind(key, val);
  }

  // 聊天消息提醒计数器
  int get chatMsgRemindCounter {
    int c = 0;
    conversationRemind.forEach((key, value) {
      c += value;
    });
    return c;
  }

  @override
  Future<void> onReady() async {
    // TODO: implement onReady
    super.onReady();
  }

  Future<void> getConversationsList() async {
    conversations.value = await (ConversationRepo()).all();
  }

  /// 移除会话
  Future<bool> removeConversation(int conversationId) async {
    Database db = await Sqlite.instance.database;
    return await db.transaction((txn) async {
      await txn.execute(
        "DELETE FROM ${MessageRepo.tablename} WHERE ${MessageRepo.conversationId}=?",
        [conversationId],
      );
      await txn.execute(
        "DELETE FROM ${ConversationRepo.tablename} WHERE id=?",
        [conversationId],
      );
      return true;
    });
  }

  /// 不显示（在会话列表）
  hideConversation(int conversationId) async {
    Database db = await Sqlite.instance.database;
    db.update(
      ConversationRepo.tablename,
      {ConversationRepo.isShow: 0},
      where: "id=?",
      whereArgs: [conversationId],
    );
  }

  /// 标记为未读 / 已读
  markAs(int conversationId, int num) async {
    Database db = await Sqlite.instance.database;
    db.update(
      ConversationRepo.tablename,
      {ConversationRepo.unreadNum: num},
      where: "id=?",
      whereArgs: [conversationId],
    );
  }

  /// 按消息ID来更新会话最后一消息的状态
  Future<List<ConversationModel>> updateLastMsgStatus(
      String msgId, int status) async {
    Database db = await Sqlite.instance.database;
    String where = "last_msg_id=?";
    List<String> whereArgs = [msgId];
    db.update(
      ConversationRepo.tablename,
      {ConversationRepo.lastMsgStatus: status},
      where: where,
      whereArgs: whereArgs,
    );

    return await (ConversationRepo()).search(
      where,
      whereArgs,
    );
  }

  Future<int> createConversationId(
      String typeId, String avatar, String title, String type) async {
    ConversationRepo repo = ConversationRepo();
    ConversationModel? obj = await repo.findByTypeId(typeId);
    if (obj != null) {
      return obj.id;
    }

    return await (ConversationRepo()).insert(ConversationModel.fromJson({
      'type_id': typeId,
      'avatar': avatar,
      'title': title,
      'subtitle': '',
      // 单位毫秒，13位时间戳  1561021145560
      'lasttime': DateTime.now().millisecond,
      'last_msg_id': 0,
      'last_msg_status': 1,
      'unread_num': 0,
      'type': type,
      'msgtype': '',
      'is_show': 0,
    }));
  }
  /**
   * 是否当前会话的最后一条消息
   */
  // Future<bool> isLastMsg(String msgId) async {}
}
