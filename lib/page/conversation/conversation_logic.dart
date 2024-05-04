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
  // 会话列表
  RxList<ConversationModel> conversations = RxList<ConversationModel>([]);

  // 网络状态描述
  RxString connectDesc = "".obs;

  // 会话提醒数量映射
  final RxMap<String, RxInt> conversationRemind = RxMap<String, RxInt>({});

  // 设置会话提醒
  setConversationRemind(ConversationModel conversation, int val) {
    val = val > 0 ? val : 0;
    (ConversationRepo()).updateById(conversation.id, {
      ConversationRepo.unreadNum: val,
      ConversationRepo.isShow: 1,
    });
    if (conversationRemind.containsKey(conversation.uk3)) {
      conversationRemind[conversation.uk3]!.value = val;
    } else {
      conversationRemind[conversation.uk3] = val.obs;
    }
    refresh();
  }

  /// 更新会话
  replace(ConversationModel obj) async {
    iPrint("ConversationRepo_Logic_replace ${obj.toJson().toString()}");
    // 第一次会话的时候 i 为 -1
    final i = conversations.indexWhere((ConversationModel m) => m.uk3 == obj.uk3);
    if (i > -1) {
      final i2 = i > 0 ? i : 0;
      conversations[i2] = obj;
    } else {
      conversations.add(obj);
    }
    // 重新计算会话消息提醒数量
    // recalculateConversationRemind(obj.id);
  }

  /// 步增会话提醒
  increaseConversationRemind(ConversationModel conversation, int val) async {
    if (!conversationRemind.containsKey(conversation.uk3) ||
        conversationRemind[conversation.uk3] == null ||
        conversationRemind[conversation.uk3]! < 0) {
      conversationRemind[conversation.uk3] = 0.obs;
    }
    RxInt val1 = (conversationRemind[conversation.uk3]?.value ?? 0 + val).obs;
    conversationRemind[conversation.uk3] = val1;
    iPrint(
        "setConversationRemind_increaseConversationRemind conversation.uk3 ${conversation.uk3}, val $val ${DateTime.now()}");
    await setConversationRemind(conversation, val1.value);
  }

  // 步减会话提醒
  decreaseConversationRemind(ConversationModel conversation, int val) async {
    iPrint(
        "setConversationRemind_decreaseConversationRemind uk3 ${conversation.uk3}, val $val ${DateTime.now()}");
    if (conversationRemind.value.containsKey(conversation.uk3)) {
      val = conversationRemind[conversation.uk3]!.value - val;
    }
    await setConversationRemind(conversation, val);
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
  Future<List<ConversationModel>> conversationsList({String type = '', bool recalculateRemind = true}) async {
    List<ConversationModel> li = await (ConversationRepo()).list(type: type);
    for (ConversationModel obj in li) {
      if (obj.type == 'C2G' && obj.avatar.isEmpty) {
        obj.computeAvatar = await Get.find<GroupListLogic>().computeAvatar(obj.peerId);
        iPrint("ConversationModel obj.title ${ obj.title}, ${obj.computeTitle}; obj.computeAvatar ${obj.computeAvatar.toString()}");
      }
      if (obj.type == 'C2G' && obj.title.isEmpty) {
        obj.computeTitle = await Get.find<GroupListLogic>().computeTitle(
          obj.peerId,
        );
      }
      // 重新计算会话消息提醒数量
      if (recalculateRemind) {
        recalculateConversationRemind(obj);
      }
    }
    conversations.value = li;
    return li;
  }

  /// 会话列表按最近会话时间倒序排序
  Future<void> sortConversationsList() async {
    conversations.sort(((a, b) => b.lastTime.compareTo(a.lastTime)));
  }

  /// 移除会话
  Future<bool> removeConversation(ConversationModel cm) async {
    Database db = await SqliteService.to.db;
    String tb = MessageRepo.getTableName(cm.type);
    return await db.transaction((txn) async {
      await txn.execute(
        "DELETE FROM $tb WHERE ${MessageRepo.conversationUk3}=?",
        [cm.uk3],
      );
      await txn.execute(
        "DELETE FROM ${ConversationRepo.tableName} WHERE id=?",
        [cm.id],
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
      repo.insert(ConversationModel.fromJson({
        ConversationRepo.peerId: peerId,
        ConversationRepo.avatar: avatar,
        ConversationRepo.title: title,
        ConversationRepo.subtitle: subtitle,
        // 单位毫秒，13位时间戳  1561021145560
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
    }
    return m!;
  }

  // 重新计算会话消息提醒数量
  recalculateConversationRemind(ConversationModel cm) async {
    String tb = MessageRepo.getTableName(cm.type);
    // idx_conversation_status_author
    int? count = await SqliteService.to.count(
      tb,
      where:
          "${MessageRepo.conversationUk3} = ? and ${MessageRepo.status} = ? and ${MessageRepo.isAuthor} = ?",
      whereArgs: [
        cm.uk3,
        IMBoyMessageStatus.delivered,
        0,
      ],
    );
    // String sql = Sqlite.instance
    if (count != null) {
      setConversationRemind(cm, count);
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
