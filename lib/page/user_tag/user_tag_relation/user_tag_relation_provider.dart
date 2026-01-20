import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imboy/store/api/user_tag_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_tag_relation_provider.g.dart';

/// UserTagRelation 模块的状态
class UserTagRelationState {
  final List<String> tagItems;
  final List<String> recentTagItems;
  final Map<String, int> tagUsageCount;
  final Map<String, dynamic> tagStatistics;
  final bool useAdvancedMode;
  final String searchQuery;
  final List<String> filteredTags;
  final bool isEditMode;
  final bool hasChanges;
  final bool isLoading;
  final Timer? inputTimer;
  final String lastInputTag;

  const UserTagRelationState({
    this.tagItems = const [],
    this.recentTagItems = const [],
    this.tagUsageCount = const {},
    this.tagStatistics = const {},
    this.useAdvancedMode = true,
    this.searchQuery = '',
    this.filteredTags = const [],
    this.isEditMode = false,
    this.hasChanges = false,
    this.isLoading = false,
    this.inputTimer,
    this.lastInputTag = '',
  });

  UserTagRelationState copyWith({
    List<String>? tagItems,
    List<String>? recentTagItems,
    Map<String, int>? tagUsageCount,
    Map<String, dynamic>? tagStatistics,
    bool? useAdvancedMode,
    String? searchQuery,
    List<String>? filteredTags,
    bool? isEditMode,
    bool? hasChanges,
    bool? isLoading,
    Timer? inputTimer,
    String? lastInputTag,
  }) {
    return UserTagRelationState(
      tagItems: tagItems ?? this.tagItems,
      recentTagItems: recentTagItems ?? this.recentTagItems,
      tagUsageCount: tagUsageCount ?? this.tagUsageCount,
      tagStatistics: tagStatistics ?? this.tagStatistics,
      useAdvancedMode: useAdvancedMode ?? this.useAdvancedMode,
      searchQuery: searchQuery ?? this.searchQuery,
      filteredTags: filteredTags ?? this.filteredTags,
      isEditMode: isEditMode ?? this.isEditMode,
      hasChanges: hasChanges ?? this.hasChanges,
      isLoading: isLoading ?? this.isLoading,
      inputTimer: inputTimer ?? this.inputTimer,
      lastInputTag: lastInputTag ?? this.lastInputTag,
    );
  }
}

@riverpod
class UserTagRelationNotifier extends _$UserTagRelationNotifier {
  @override
  UserTagRelationState build() {
    return const UserTagRelationState();
  }

  /// 添加标签关联
  Future<bool> add(String scene, String objectId, List<dynamic> tag) async {
    bool res = await UserTagApi().relationAdd(
      scene: scene,
      objectId: objectId,
      tag: tag,
    );
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
    }
    return res;
  }

  /// 获取最近的标签项
  Future<List<String>> getRecentTagItems(String scene) async {
    Map<String, dynamic>? resp = await UserTagApi().page(
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
      Map<String, dynamic>? resp = await UserTagApi().page(
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
            currentTags = tagStr
                .split(',')
                .where((t) => t.trim().isNotEmpty)
                .toList();
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

  /// 设置标签项
  void setTagItems(List<String> items) {
    state = state.copyWith(tagItems: items);
  }

  /// 设置最近标签项
  void setRecentTagItems(List<String> items) {
    state = state.copyWith(recentTagItems: items);
  }

  /// 更新标签统计信息
  void updateTagStatistics(Map<String, dynamic> statistics) {
    state = state.copyWith(
      tagStatistics: statistics,
      recentTagItems: List<String>.from(statistics['tags'] ?? []),
      tagUsageCount: Map<String, int>.from(statistics['usage_count'] ?? {}),
    );
  }

  /// 检查是否有变更
  bool checkChanges(List<String> originalTags) {
    final currentTags = Set.from(state.tagItems);
    final originalTagsSet = Set.from(originalTags);
    bool hasChanges =
        !currentTags.containsAll(originalTagsSet) ||
        !originalTagsSet.containsAll(currentTags);
    state = state.copyWith(hasChanges: hasChanges);
    return hasChanges;
  }

  /// 过滤标签
  void filterTags(String query) {
    state = state.copyWith(searchQuery: query);
    if (query.isEmpty) {
      state = state.copyWith(filteredTags: List.from(state.recentTagItems));
    } else {
      state = state.copyWith(
        filteredTags: state.recentTagItems
            .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
            .toList(),
      );
    }
  }

  /// 获取常用标签（使用频率前N个）
  List<String> getPopularTags({int limit = 10}) {
    final tags = state.recentTagItems.toList();
    tags.sort((a, b) {
      final countA = state.tagUsageCount[a] ?? 0;
      final countB = state.tagUsageCount[b] ?? 0;
      return countB.compareTo(countA);
    });
    return tags.take(limit).toList();
  }

  /// 获取最近使用的标签（排除已选择的）
  List<String> getRecentUnselectedTags({int limit = 15}) {
    return state.recentTagItems
        .where((tag) => !state.tagItems.contains(tag))
        .take(limit)
        .toList();
  }

  /// 清理资源
  void dispose() {
    state.inputTimer?.cancel();
  }
}
