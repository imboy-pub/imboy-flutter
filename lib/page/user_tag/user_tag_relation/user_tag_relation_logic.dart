import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';

import 'user_tag_relation_state.dart';

class UserTagRelationLogic extends GetxController {
  final UserTagRelationState state = UserTagRelationState();

  RxBool valueChanged = false.obs;

  void valueOnChange(bool isChange) {
    // 必须使用 .value 修饰具体的值
    valueChanged.value = isChange;
    update([valueChanged]);
  }

  Future<bool> add(String scene, String objectId, List<dynamic> tag) async {
    bool res = await UserTagProvider().relationAdd(
      scene: scene,
      objectId: objectId,
      tag: tag,
    );
    // debugPrint("tag_add_logic/add $objectId, tag ${tag.toString()} ;");
    if (res) {
      if (scene == 'friend') {
        await ContactRepo().update({
          ContactRepo.peerId: objectId,
          ContactRepo.tag: tag.join(','),
        });
      } else if (scene == 'collect') {
        await UserCollectRepo().update(objectId, {
          UserCollectRepo.kindId: objectId,
          UserCollectRepo.tag: tag.join(','),
        });
      }
      // res = res2 > 0 ? true : false;
    }
    return res;
  }

  Future<List<String>> getRecentTagItems(String scene) async {
    Map<String, dynamic>? resp = await UserTagProvider().page(
      scene: scene,
      size: 100,
    );
    List<dynamic> items = resp?['list'] ?? [];

    List<String> res = [];
    for (var item in items) {
      String tag = "${item['name'] ?? ''}";
      // 去除重复和空白字符串
      if (tag.isNotEmpty && !res.contains(tag)) {
        res.add(tag);
      }
    }
    return res;
  }

  /// 获取标签使用频率统计
  /// 返回 Map<标签名, 使用次数>
  Future<Map<String, int>> getTagUsageCount(String scene) async {
    try {
      Map<String, dynamic>? resp = await UserTagProvider().page(
        scene: scene,
        size: 200, // 获取更多数据用于统计
      );
      List<dynamic> items = resp?['list'] ?? [];

      Map<String, int> usageCount = {};
      for (var item in items) {
        String tag = "${item['name'] ?? ''}";
        if (tag.isNotEmpty) {
          // 这里可以根据实际API返回的数据结构调整
          // 假设API返回包含使用次数的字段，如果没有则默认为1
          int count = item['usage_count'] ?? 1;
          usageCount[tag] = (usageCount[tag] ?? 0) + count;
        }
      }
      return usageCount;
    } catch (e) {
      debugPrint('getTagUsageCount error: $e');
      return {};
    }
  }

  /// 获取标签统计信息
  /// 返回包含标签列表和使用频率的完整信息
  Future<Map<String, dynamic>> getTagStatistics(String scene) async {
    try {
      final tagList = await getRecentTagItems(scene);
      final usageCount = await getTagUsageCount(scene);
      
      // 按使用频率排序标签
      tagList.sort((a, b) {
        final countA = usageCount[a] ?? 0;
        final countB = usageCount[b] ?? 0;
        return countB.compareTo(countA);
      });

      return {
        'tags': tagList,
        'usage_count': usageCount,
        'total_tags': tagList.length,
        'most_used': tagList.isNotEmpty ? tagList.first : '',
      };
    } catch (e) {
      debugPrint('getTagStatistics error: $e');
      return {
        'tags': <String>[],
        'usage_count': <String, int>{},
        'total_tags': 0,
        'most_used': '',
      };
    }
  }

  /// 批量更新标签
  /// 支持批量添加、删除、重命名标签
  Future<bool> batchUpdateTags({
    required String scene,
    required List<String> objectIds,
    required List<String> tagsToAdd,
    List<String> tagsToRemove = const [],
    Map<String, String> tagsToRename = const {},
  }) async {
    try {
      bool allSuccess = true;
      
      for (String objectId in objectIds) {
        // 获取当前标签
        List<String> currentTags = [];
        if (scene == 'collect') {
          // 从数据库获取当前标签
          final collectData = await UserCollectRepo().findByKindId(objectId);
          if (collectData != null) {
            String tagStr = collectData.tag;
            currentTags = tagStr.split(',').where((t) => t.trim().isNotEmpty).toList();
          }
        }
        
        // 处理标签操作
        Set<String> updatedTags = Set.from(currentTags);
        
        // 删除标签
        for (String tagToRemove in tagsToRemove) {
          updatedTags.remove(tagToRemove);
        }
        
        // 重命名标签
        tagsToRename.forEach((oldTag, newTag) {
          if (updatedTags.contains(oldTag)) {
            updatedTags.remove(oldTag);
            updatedTags.add(newTag);
          }
        });
        
        // 添加新标签
        updatedTags.addAll(tagsToAdd);
        
        // 更新标签
        final success = await add(scene, objectId, updatedTags.toList());
        if (!success) {
          allSuccess = false;
        }
      }
      
      return allSuccess;
    } catch (e) {
      debugPrint('batchUpdateTags error: $e');
      return false;
    }
  }
}
