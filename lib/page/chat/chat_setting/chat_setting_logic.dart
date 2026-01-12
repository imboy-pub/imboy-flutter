import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import 'chat_setting_state.dart';

class ChatSettingLogic extends GetxController {
  final state = ChatSettingState();

  /// 清空会话聊天记录
  Future<int> cleanMessageByPeerId(String type, String peerId) async {
    ConversationModel? model =
        await ConversationRepo().findByPeerId(type, peerId);
    if (model == null) {
      return 0;
    }
    String tb = MessageRepo.getTableName(model.type);

    // 先查询该会话的所有消息ID，用于清理重试队列
    final repo = MessageRepo(tableName: tb);
    // 使用page方法获取所有消息，设置一个足够大的size
    final messages = await repo.page(
      conversationUk3: model.uk3,
      page: 1,
      size: 10000, // 获取大量消息以覆盖所有
    );

    // 清理重试队列中属于该会话的消息
    if (messages.isNotEmpty && Get.isRegistered<MessageRetry>()) {
      for (final msg in messages) {
        if (msg.id != null && msg.id!.isNotEmpty) {
          MessageRetry.to.removeFromRetryQueue(msg.id!);
        }
      }
      iPrint('已从重试队列清理 ${messages.length} 条消息: conversationUk3=${model.uk3}');
    }

    // 删除数据库中的消息
    await repo.deleteByConversationId(model.uk3);

    AppEventBus.fire(ChatExtendEvent(type: 'clean_msg', payload: {
      'uk3': model.uk3,
    }));
    return model.id;
  }
}
