import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/store/api/group_category_api.dart';

/// 群分组服务
///
/// 负责协调 API 和本地存储，处理群分组业务逻辑
class GroupCategoryService {
  static final GroupCategoryService to =
      GroupCategoryService._privateConstructor();
  GroupCategoryService._privateConstructor();

  final GroupCategoryApi _api = GroupCategoryApi();

  // ==================== 分组管理 ====================

  /// 获取用户的群分组列表
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      return await _api.getCategories();
    } catch (e) {
      iPrint('GroupCategoryService: 获取分组列表失败 - $e');
      return [];
    }
  }

  /// 创建群分组
  Future<Map<String, dynamic>?> createCategory({
    required String name,
    int? sortOrder,
  }) async {
    try {
      final result = await _api.createCategory(
        name: name,
        sortOrder: sortOrder,
      );
      if (result != null) {
        iPrint('GroupCategoryService: 创建分组成功 - $name');
        AppEventBus.fire(CategoryCreatedEvent(data: result));
      }
      return result;
    } catch (e) {
      iPrint('GroupCategoryService: 创建分组失败 - $e');
      return null;
    }
  }

  /// 重命名群分组
  Future<bool> renameCategory({
    required int categoryId,
    required String name,
  }) async {
    try {
      final success = await _api.renameCategory(
        categoryId: categoryId,
        name: name,
      );
      if (success) {
        iPrint('GroupCategoryService: 重命名分组成功 - $categoryId');
        AppEventBus.fire(CategoryUpdatedEvent(categoryId: categoryId));
      }
      return success;
    } catch (e) {
      iPrint('GroupCategoryService: 重命名分组失败 - $e');
      return false;
    }
  }

  /// 删除群分组
  Future<bool> deleteCategory(int categoryId) async {
    try {
      final success = await _api.deleteCategory(categoryId);
      if (success) {
        iPrint('GroupCategoryService: 删除分组成功 - $categoryId');
        AppEventBus.fire(CategoryDeletedEvent(categoryId: categoryId));
      }
      return success;
    } catch (e) {
      iPrint('GroupCategoryService: 删除分组失败 - $e');
      return false;
    }
  }

  // ==================== 群与分组关联 ====================

  /// 将群移入分组
  Future<bool> moveGroupToCategory({
    required String groupId,
    required int categoryId,
  }) async {
    try {
      final success = await _api.moveGroupToCategory(
        groupId: groupId,
        categoryId: categoryId,
      );
      if (success) {
        iPrint('GroupCategoryService: 移动群到分组 - $groupId -> $categoryId');
        AppEventBus.fire(
          GroupMovedEvent(groupId: groupId, categoryId: categoryId),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupCategoryService: 移动群到分组失败 - $e');
      return false;
    }
  }

  /// 分组排序
  Future<bool> sortCategories(List<int> categoryIds) async {
    try {
      final success = await _api.sortCategories(categoryIds);
      if (success) {
        iPrint('GroupCategoryService: 分组排序成功');
        AppEventBus.fire(CategorySortedEvent(categoryIds: categoryIds));
      }
      return success;
    } catch (e) {
      iPrint('GroupCategoryService: 分组排序失败 - $e');
      return false;
    }
  }
}

/// 分组创建事件
class CategoryCreatedEvent extends AppEvent {
  final Map<String, dynamic> data;
  const CategoryCreatedEvent({required this.data});

  @override
  List<Object?> get props => [data];
}

/// 分组更新事件
class CategoryUpdatedEvent extends AppEvent {
  final int categoryId;
  const CategoryUpdatedEvent({required this.categoryId});

  @override
  List<Object?> get props => [categoryId];
}

/// 分组删除事件
class CategoryDeletedEvent extends AppEvent {
  final int categoryId;
  const CategoryDeletedEvent({required this.categoryId});

  @override
  List<Object?> get props => [categoryId];
}

/// 群移动事件
class GroupMovedEvent extends AppEvent {
  final String groupId;
  final int categoryId;
  const GroupMovedEvent({required this.groupId, required this.categoryId});

  @override
  List<Object?> get props => [groupId, categoryId];
}

/// 分组排序事件
class CategorySortedEvent extends AppEvent {
  final List<int> categoryIds;
  const CategorySortedEvent({required this.categoryIds});

  @override
  List<Object?> get props => [categoryIds];
}
