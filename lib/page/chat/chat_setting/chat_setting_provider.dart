import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

/// 聊天设置逻辑控制器
class ChatSettingLogic {
  /// 清空会话聊天记录
  ///
  /// 使用 ConversationRepo.clearMessages() 方法，该方法：
  /// - 在事务中完成所有操作，保证原子性
  /// - 自动清理重试队列
  /// - 删除消息并更新会话表
  /// - 返回更新后的会话模型
  Future<int> cleanMessageByPeerId(String type, String peerId) async {
    final repo = ConversationRepo();
    ConversationModel? model = await repo.findByPeerId(type, peerId);
    if (model == null) {
      return 0;
    }

    // 使用事务清空消息并更新会话，返回更新后的会话模型
    final updatedModel = await repo.clearMessages(model);
    if (updatedModel == null) {
      return model.id;
    }

    // 触发 UI 更新事件，传递更新后的完整会话对象
    AppEventBus.fire(
      ChatExtendEvent(
        type: 'clean_msg',
        payload: {'uk3': updatedModel.uk3, 'conversation': updatedModel},
      ),
    );

    return model.id;
  }
}

/// 聊天设置 Provider - 使用 Provider 而不是 StateNotifierProvider
final chatSettingProvider = Provider<ChatSettingLogic>((ref) {
  return ChatSettingLogic();
});
