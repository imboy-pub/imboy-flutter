import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';

/// 群组选择服务类 - 处理业务逻辑
class GroupSelectService {
  /// 加载群组会话列表
  Future<List<ConversationModel>> loadGroupConversations() async {
    final allConversations = await ConversationRepo().list(
      limit: 1000,
      offset: 0,
    );
    return allConversations
        .where((conversation) => conversation.type == 'C2G')
        .toList();
  }

  /// 计算群组头像 - 委托给 GroupListService
  Future<List<String>> computeAvatar(String gid) async {
    final service = GroupListService();
    return await service.computeAvatar(gid);
  }
}
