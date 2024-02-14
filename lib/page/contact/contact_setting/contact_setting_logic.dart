import 'package:get/get.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';

class ContactSettingLogic extends GetxController {
  /// 将联系人"$remark"删除，同时删除与该联系人的聊天记录
  Future<bool> deleteContact(String uid) async {
    bool res = await (ContactProvider()).deleteContact(uid);
    if (res) {
      await MessageRepo(tableName: MessageRepo.c2cTable).deleteByUid(uid);
      await ConversationRepo().delete(uid);
      await NewFriendRepo().deleteByUid(uid);
      await ContactRepo().deleteByUid(uid);
    }
    return res;
  }
}
