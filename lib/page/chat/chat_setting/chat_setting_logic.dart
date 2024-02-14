import 'package:get/get.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import 'chat_setting_state.dart';

class ChatSettingLogic extends GetxController {
  final state = ChatSettingState();

  /// 清空会话聊天记录
  Future<bool> cleanMessageByPeerId(String peerId) async {
    ConversationModel? model = await ConversationRepo().findByPeerId(peerId);
    if (model == null) {
      return true;
    }
    String tb = model.type.toUpperCase() == 'C2G'
        ? MessageRepo.c2gTable
        : MessageRepo.c2cTable;
    await MessageRepo(tableName: tb).deleteByConversationId(model.id);
    return true;
  }
}
