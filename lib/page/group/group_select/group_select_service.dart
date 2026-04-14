import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';

/// 群组选择服务类 - 处理业务逻辑
class GroupSelectService {
  /// 加载群组会话列表 / Load group conversations
  ///
  /// 直接在 SQL 层过滤 type=C2G，避免加载所有会话后再内存过滤
  /// Filter type=C2G in SQL to avoid loading all conversations into memory
  Future<List<ConversationModel>> loadGroupConversations() {
    return ConversationRepo().list(type: 'C2G');
  }

  /// 计算群组头像 - 委托给 GroupListService
  Future<List<String>> computeAvatar(String gid) async {
    final service = GroupListService();
    return await service.computeAvatar(gid);
  }
}
