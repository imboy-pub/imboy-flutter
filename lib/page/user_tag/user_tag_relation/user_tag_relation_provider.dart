import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imboy/store/api/user_tag_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_tag_relation_provider.g.dart';

List<String> normalizeTagNames(Iterable<dynamic> tags) {
  final normalized = <String>[];
  final seen = <String>{};
  for (final rawTag in tags) {
    final tag = rawTag.toString().trim();
    if (tag.isEmpty || !seen.add(tag)) {
      continue;
    }
    normalized.add(tag);
  }
  return normalized;
}

Map<String, int> buildTagIdByNameMap(List<dynamic> items) {
  final tagIdByName = <String, int>{};
  for (final item in items.whereType<Map>()) {
    final name = item['name']?.toString().trim() ?? '';
    final rawTagId = item['tag_id'] ?? item['id'];
    final tagId = rawTagId is int
        ? rawTagId
        : int.tryParse(rawTagId?.toString() ?? '');
    if (name.isEmpty || tagId == null || tagId <= 0) {
      continue;
    }
    tagIdByName[name] = tagId;
  }
  return tagIdByName;
}

Map<String, int> buildTagUsageCountMap(List<dynamic> items) {
  final usageCount = <String, int>{};
  for (final item in items.whereType<Map>()) {
    final name = item['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      continue;
    }
    final rawCount = item['usage_count'];
    final count = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? 1;
    usageCount[name] = (usageCount[name] ?? 0) + count;
  }
  return usageCount;
}

List<String> buildTagNameList(List<dynamic> items) {
  return normalizeTagNames(
    items.whereType<Map>().map((item) => item['name']?.toString() ?? ''),
  );
}

class TagSyncPlan {
  final List<String> originalTags;
  final List<String> finalTags;
  final List<String> toAdd;
  final List<String> toRemove;

  const TagSyncPlan({
    required this.originalTags,
    required this.finalTags,
    required this.toAdd,
    required this.toRemove,
  });

  bool get hasChanges => toAdd.isNotEmpty || toRemove.isNotEmpty;
}

TagSyncPlan buildTagSyncPlan({
  required Iterable<dynamic> originalTags,
  required Iterable<dynamic> nextTags,
}) {
  final original = normalizeTagNames(originalTags);
  final next = normalizeTagNames(nextTags);
  final originalSet = original.toSet();
  final nextSet = next.toSet();

  return TagSyncPlan(
    originalTags: original,
    finalTags: next,
    toAdd: next.where((tag) => !originalSet.contains(tag)).toList(),
    toRemove: original.where((tag) => !nextSet.contains(tag)).toList(),
  );
}

/// UserTagRelation 模块的状态
class UserTagRelationState {
  final List<String> tagItems;
  final List<String> recentTagItems;
  final Map<String, int> tagUsageCount;
  final Map<String, int> tagIdByName;
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
    this.tagIdByName = const {},
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
    Map<String, int>? tagIdByName,
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
      tagIdByName: tagIdByName ?? this.tagIdByName,
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
  final UserTagApi _userTagApi;
  final ContactRepo _contactRepo;
  final UserCollectRepo _userCollectRepo;

  UserTagRelationNotifier({
    UserTagApi? userTagApi,
    ContactRepo? contactRepo,
    UserCollectRepo? userCollectRepo,
  }) : _userTagApi = userTagApi ?? UserTagApi(),
       _contactRepo = contactRepo ?? ContactRepo(),
       _userCollectRepo = userCollectRepo ?? UserCollectRepo();

  @override
  UserTagRelationState build() {
    return const UserTagRelationState();
  }

  /// 添加标签关联
  Future<bool> add(String scene, String objectId, List<dynamic> tag) async {
    final normalizedTags = normalizeTagNames(tag);
    bool res = await _userTagApi.relationAdd(
      scene: scene,
      objectId: objectId,
      tag: normalizedTags,
    );
    if (res) {
      await _updateLocalTags(
        scene: scene,
        objectId: objectId,
        tags: normalizedTags,
      );
    }
    return res;
  }

  Future<void> _updateLocalTags({
    required String scene,
    required String objectId,
    required List<String> tags,
  }) async {
    final joinedTags = tags.join(',');
    if (scene == 'friend') {
      await _contactRepo.update({
        ContactRepo.peerId: objectId,
        ContactRepo.tag: joinedTags,
      });
      return;
    }
    if (scene == 'collect') {
      await _userCollectRepo.update(objectId, {
        UserCollectRepo.kindId: objectId,
        UserCollectRepo.tag: joinedTags,
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTagPageItems({
    required String scene,
    int size = 200,
    String kwd = '',
  }) async {
    final resp = await _userTagApi.page(scene: scene, size: size, kwd: kwd);
    final rawItems = resp?['list'];
    if (rawItems is! List) {
      return const [];
    }
    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _loadTagStatistics(
    String scene, {
    List<String> ensureTags = const [],
  }) async {
    try {
      final items = <Map<String, dynamic>>[
        ...await _fetchTagPageItems(scene: scene),
      ];
      final requiredTags = normalizeTagNames(ensureTags);
      var tagIdByName = buildTagIdByNameMap(items);
      for (final tagName in requiredTags) {
        if (tagIdByName.containsKey(tagName)) {
          continue;
        }
        final searchedItems = await _fetchTagPageItems(
          scene: scene,
          size: 20,
          kwd: tagName,
        );
        for (final item in searchedItems) {
          final name = item['name']?.toString().trim() ?? '';
          if (name == tagName) {
            items.add(item);
          }
        }
        tagIdByName = buildTagIdByNameMap(items);
      }

      final tagList = buildTagNameList(items);
      final usageCount = buildTagUsageCountMap(items);
      tagList.sort((a, b) {
        final countA = usageCount[a] ?? 0;
        final countB = usageCount[b] ?? 0;
        return countB.compareTo(countA);
      });

      final statistics = <String, dynamic>{
        'tags': tagList,
        'usage_count': usageCount,
        'tag_id_by_name': tagIdByName,
        'total_tags': tagList.length,
        'most_used': tagList.isNotEmpty ? tagList.first : '',
      };
      updateTagStatistics(statistics);
      return statistics;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('getTagStatistics error: ${e.runtimeType}');
      const emptyStatistics = <String, dynamic>{
        'tags': <String>[],
        'usage_count': <String, int>{},
        'tag_id_by_name': <String, int>{},
        'total_tags': 0,
        'most_used': '',
      };
      updateTagStatistics(emptyStatistics);
      return emptyStatistics;
    }
  }

  /// 获取最近的标签项
  Future<List<String>> getRecentTagItems(
    String scene, {
    List<String> ensureTags = const [],
  }) async {
    final statistics = await _loadTagStatistics(scene, ensureTags: ensureTags);
    return List<String>.from(statistics['tags'] ?? const <String>[]);
  }

  /// 获取标签使用频率统计
  /// 返回 Map<标签名, 使用次数>
  Future<Map<String, int>> getTagUsageCount(
    String scene, {
    List<String> ensureTags = const [],
  }) async {
    final statistics = await _loadTagStatistics(scene, ensureTags: ensureTags);
    return Map<String, int>.from(statistics['usage_count'] ?? const {});
  }

  /// 获取标签统计信息
  /// 返回包含标签列表和使用频率的完整信息
  Future<Map<String, dynamic>> getTagStatistics(
    String scene, {
    List<String> ensureTags = const [],
  }) async {
    return _loadTagStatistics(scene, ensureTags: ensureTags);
  }

  Future<bool> syncFinalState({
    required String scene,
    required String objectId,
    required List<String> originalTags,
    required List<String> nextTags,
    Map<String, int> tagIdByName = const {},
  }) async {
    final plan = buildTagSyncPlan(
      originalTags: originalTags,
      nextTags: nextTags,
    );
    if (!plan.hasChanges) {
      state = state.copyWith(tagItems: plan.finalTags, hasChanges: false);
      return true;
    }

    final resolvedTagIdByName = Map<String, int>.from(tagIdByName);
    if (plan.toRemove.isNotEmpty) {
      final missingTagIds = plan.toRemove
          .where((tagName) => !resolvedTagIdByName.containsKey(tagName))
          .toList();
      if (missingTagIds.isNotEmpty) {
        final statistics = await _loadTagStatistics(
          scene,
          ensureTags: missingTagIds,
        );
        resolvedTagIdByName.addAll(
          Map<String, int>.from(statistics['tag_id_by_name'] ?? const {}),
        );
      }
      final unresolved = plan.toRemove
          .where((tagName) => !resolvedTagIdByName.containsKey(tagName))
          .toList();
      if (unresolved.isNotEmpty) {
        if (kDebugMode) debugPrint('syncFinalState missing tag ids: $unresolved');
        return false;
      }
    }

    for (final tagName in plan.toRemove) {
      final tagId = resolvedTagIdByName[tagName];
      if (tagId == null || tagId <= 0) {
        if (kDebugMode) debugPrint('syncFinalState invalid tag id for $tagName');
        return false;
      }
      final removed = await _userTagApi.removeRelation(
        tagId: tagId,
        objectId: objectId,
        scene: scene,
      );
      if (!removed) {
        return false;
      }
    }

    if (plan.toAdd.isNotEmpty) {
      final added = await _userTagApi.relationAdd(
        scene: scene,
        objectId: objectId,
        tag: plan.toAdd,
      );
      if (!added) {
        return false;
      }
    }

    await _updateLocalTags(
      scene: scene,
      objectId: objectId,
      tags: plan.finalTags,
    );
    state = state.copyWith(
      tagItems: plan.finalTags,
      tagIdByName: resolvedTagIdByName,
      hasChanges: false,
    );
    return true;
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
        final success = await syncFinalState(
          scene: scene,
          objectId: objectId,
          originalTags: currentTags,
          nextTags: updatedTags.toList(),
          tagIdByName: state.tagIdByName,
        );
        if (!success) {
          allSuccess = false;
        }
      }

      return allSuccess;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('batchUpdateTags error: ${e.runtimeType}');
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
      tagIdByName: Map<String, int>.from(statistics['tag_id_by_name'] ?? {}),
    );
  }

  /// 检查是否有变更
  bool checkChanges(List<String> originalTags) {
    final hasChanges = buildTagSyncPlan(
      originalTags: originalTags,
      nextTags: state.tagItems,
    ).hasChanges;
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
