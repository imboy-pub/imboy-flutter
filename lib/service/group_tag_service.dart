import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/store/api/group_tag_api.dart';

/// 群标签服务
///
/// 负责协调 API 和本地存储，处理群标签业务逻辑
class GroupTagService {
  static final GroupTagService to = GroupTagService._privateConstructor();
  GroupTagService._privateConstructor();

  final GroupTagApi _api = GroupTagApi();

  // ==================== 标签管理 ====================

  /// 获取群的所有标签
  Future<List<Map<String, dynamic>>> getGroupTags(String groupId) async {
    try {
      return await _api.getGroupTags(groupId);
    } catch (e) {
      iPrint('GroupTagService: 获取群标签失败 - $e');
      return [];
    }
  }

  /// 添加群标签
  Future<bool> addTag({
    required String groupId,
    required String name,
    String? color,
  }) async {
    try {
      final success = await _api.addTag(
        groupId: groupId,
        name: name,
        color: color,
      );
      if (success) {
        iPrint('GroupTagService: 添加标签成功 - $name');
        AppEventBus.fire(TagAddedEvent(groupId: groupId, tagName: name));
      }
      return success;
    } catch (e) {
      iPrint('GroupTagService: 添加标签失败 - $e');
      return false;
    }
  }

  /// 删除群标签
  Future<bool> removeTag({
    required String groupId,
    required String tagName,
  }) async {
    try {
      final success = await _api.removeTag(groupId: groupId, tagName: tagName);
      if (success) {
        iPrint('GroupTagService: 删除标签成功 - $tagName');
        AppEventBus.fire(TagRemovedEvent(groupId: groupId, tagName: tagName));
      }
      return success;
    } catch (e) {
      iPrint('GroupTagService: 删除标签失败 - $e');
      return false;
    }
  }

  // ==================== 搜索 ====================

  /// 按标签搜索群
  Future<List<Map<String, dynamic>>> searchByTag(
    String tagName, {
    int limit = 20,
  }) async {
    try {
      return await _api.searchByTag(tagName, limit: limit);
    } catch (e) {
      iPrint('GroupTagService: 按标签搜索群失败 - $e');
      return [];
    }
  }

  /// 获取热门标签
  Future<List<Map<String, dynamic>>> getHotTags({int limit = 20}) async {
    try {
      return await _api.getHotTags(limit: limit);
    } catch (e) {
      iPrint('GroupTagService: 获取热门标签失败 - $e');
      return [];
    }
  }
}

/// 标签添加事件
class TagAddedEvent extends AppEvent {
  final String groupId;
  final String tagName;
  const TagAddedEvent({required this.groupId, required this.tagName});

  @override
  List<Object?> get props => [groupId, tagName];
}

/// 标签删除事件
class TagRemovedEvent extends AppEvent {
  final String groupId;
  final String tagName;
  const TagRemovedEvent({required this.groupId, required this.tagName});

  @override
  List<Object?> get props => [groupId, tagName];
}
