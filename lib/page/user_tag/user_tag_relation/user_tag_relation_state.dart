import 'dart:async';

import 'package:get/get.dart';
import 'package:textfield_tags/textfield_tags.dart';

class UserTagRelationState {
  RxBool loaded = false.obs;

  TextfieldTagsController tagController = TextfieldTagsController();
  RxDouble distanceToField = Get.width.obs;

  // 当前朋友的标签
  RxList<String> tagItems = <String>[].obs;

  // 当前用户最近添加的标签
  RxList<String> recentTagItems = <String>[].obs;

  // 标签使用频率统计
  RxMap<String, int> tagUsageCount = <String, int>{}.obs;

  // 标签统计信息
  RxMap<String, dynamic> tagStatistics = <String, dynamic>{}.obs;

  // 是否使用高级模式（新的标签编辑界面）
  RxBool useAdvancedMode = true.obs;

  // 搜索相关
  RxString searchQuery = ''.obs;
  RxList<String> filteredTags = <String>[].obs;

  // 标签编辑模式
  RxBool isEditMode = false.obs;
  RxBool hasChanges = false.obs;

  Timer? inputTimer;
  String lastInputTag = '';

  /// 初始化状态
  void initState() {
    loaded.value = false;
    tagItems.clear();
    recentTagItems.clear();
    tagUsageCount.clear();
    tagStatistics.clear();
    searchQuery.value = '';
    filteredTags.clear();
    isEditMode.value = false;
    hasChanges.value = false;
  }

  /// 更新标签统计信息
  void updateTagStatistics(Map<String, dynamic> statistics) {
    tagStatistics.value = statistics;
    recentTagItems.value = List<String>.from(statistics['tags'] ?? []);
    tagUsageCount.value = Map<String, int>.from(statistics['usage_count'] ?? {});
  }

  /// 检查是否有变更
  void checkChanges(List<String> originalTags) {
    final currentTags = Set.from(tagItems);
    final originalTagsSet = Set.from(originalTags);
    hasChanges.value = !currentTags.containsAll(originalTagsSet) || 
                      !originalTagsSet.containsAll(currentTags);
  }

  /// 过滤标签
  void filterTags(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      filteredTags.value = List.from(recentTagItems);
    } else {
      filteredTags.value = recentTagItems
          .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  /// 获取常用标签（使用频率前N个）
  List<String> getPopularTags({int limit = 10}) {
    final tags = recentTagItems.toList();
    tags.sort((a, b) {
      final countA = tagUsageCount[a] ?? 0;
      final countB = tagUsageCount[b] ?? 0;
      return countB.compareTo(countA);
    });
    return tags.take(limit).toList();
  }

  /// 获取最近使用的标签（排除已选择的）
  List<String> getRecentUnselectedTags({int limit = 15}) {
    return recentTagItems
        .where((tag) => !tagItems.contains(tag))
        .take(limit)
        .toList();
  }

  /// 清理资源
  void dispose() {
    inputTimer?.cancel();
    inputTimer = null;
  }
}
