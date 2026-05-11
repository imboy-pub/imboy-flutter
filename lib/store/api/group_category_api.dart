import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 群分组 API 客户端
///
/// 负责与后端 API 通信，处理群分组相关的网络请求
class GroupCategoryApi extends HttpClient {
  List<Map<String, dynamic>> _normalizeCategories(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final name = (map['name'] ?? map['category_name'])?.toString();
      if (name != null) {
        map['name'] = name;
      }
      return map;
    }).toList();
  }

  /// 获取用户的群分组列表
  Future<List<Map<String, dynamic>>> getCategories() async {
    final resp = await get(API.groupCategoryList);
    debugPrint("GroupCategoryApi_getCategories resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    return _normalizeCategories(resp.payload['categories']);
  }

  /// 创建群分组
  Future<Map<String, dynamic>?> createCategory({
    required String name,
    int? sortOrder,
  }) async {
    final data = <String, dynamic>{'category_name': name};
    if (sortOrder != null) data['sort_order'] = sortOrder;

    final resp = await post(API.groupCategoryCreate, data: data);
    debugPrint("GroupCategoryApi_createCategory resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload as Map<String, dynamic>?;
  }

  /// 重命名群分组
  Future<bool> renameCategory({
    required int categoryId,
    required String name,
  }) async {
    final resp = await post(
      API.groupCategoryRename,
      data: {'id': categoryId, 'category_name': name},
    );
    debugPrint("GroupCategoryApi_renameCategory resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 删除群分组
  Future<bool> deleteCategory(int categoryId) async {
    final resp = await post(API.groupCategoryDelete, data: {'id': categoryId});
    debugPrint("GroupCategoryApi_deleteCategory resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 将群移入分组
  Future<bool> moveGroupToCategory({
    required String groupId,
    required int categoryId,
  }) async {
    final resp = await post(
      API.groupCategoryMoveGroup,
      data: {'gid': groupId, 'category_id': categoryId},
    );
    debugPrint("GroupCategoryApi_moveGroupToCategory resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 分组排序
  Future<bool> sortCategories(List<int> categoryIds) async {
    final sortOrders = categoryIds.asMap().entries.map((entry) {
      return {'id': entry.value, 'sort_order': entry.key + 1};
    }).toList();

    final resp = await post(
      API.groupCategorySort,
      data: {'sort_orders': sortOrders},
    );
    debugPrint("GroupCategoryApi_sortCategories resp: ok=${resp.ok}");
    return resp.ok;
  }
}
