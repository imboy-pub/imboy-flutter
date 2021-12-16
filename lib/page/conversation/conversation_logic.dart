import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/helper/sqflite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';
import 'package:sqflite/sqflite.dart';

import 'conversation_state.dart';

class ConversationLogic extends GetxController {
  final state = ConversationState();
  final UserRepoSP current = Get.put(UserRepoSP.user);

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  getConversationsList() async {
    Map<String, ConversationModel> items =
        await (ConversationRepo()).findByCuid(current.currentUid);
    print(">>>>> on items.length: " + items.length.toString());
    return items;
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

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
      debugPrint(
          'on >>>>> removeConversation :' + conversationId.toString() + ';');
      return true;
    });
  }

  /**
   * 不显示（在会话列表）
   */
  hideConversation(int conversationId) async {
    Database db = await Sqlite.instance.database;
    db.update(
      ConversationRepo.tablename,
      {ConversationRepo.isShow: 0},
      where: "id=?",
      whereArgs: [conversationId],
    );
  }

  /**
   * 标记为未读 / 已读
   */
  markAs(int conversationId, int num) async {
    Database db = await Sqlite.instance.database;
    db.update(
      ConversationRepo.tablename,
      {ConversationRepo.unreadNum: num},
      where: "id=?",
      whereArgs: [conversationId],
    );
  }
}
