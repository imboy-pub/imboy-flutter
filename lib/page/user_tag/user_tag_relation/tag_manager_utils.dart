import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 标签管理工具类
/// 提供标签相关的实用功能和UI组件
class TagManagerUtils {
  /// 常用标签模板 - 使用国际化键
  static List<String> getCommonTagTemplates() {
    return [
      t.tagImportant,
      t.tagUrgent,
      t.tagWork,
      t.tagLife,
      t.tagStudy,
      t.tagEntertainment,
      t.tagTravel,
      t.tagFood,
      t.tagHealth,
      t.tagFamily,
      t.tagFriends,
      t.tagProject,
      t.tagIdeas,
      t.tagInspiration,
      t.tagMemo,
    ];
  }

  /// 标签颜色映射 - 使用统一的颜色方案
  static const Map<String, Color> tagColors = {
    'important': Colors.red,
    'urgent': Colors.orange,
    'work': Colors.blue,
    'life': Colors.green,
    'study': Colors.purple,
    'entertainment': Colors.pink,
    'travel': Colors.teal,
    'food': Colors.amber,
    'health': Colors.lightGreen,
    'family': Colors.brown,
    'friends': Colors.cyan,
    'project': Colors.indigo,
    'ideas': Colors.lime,
    'inspiration': Colors.yellow,
    'memo': Colors.grey,
  };

  /// 获取标签颜色键（基于标签文本匹配）
  static String _getTagColorKey(String tagName) {
    // 根据标签文本映射到颜色键
    final tagMap = {
      t.tagImportant: 'important',
      t.tagUrgent: 'urgent',
      t.tagWork: 'work',
      t.tagLife: 'life',
      t.tagStudy: 'study',
      t.tagEntertainment: 'entertainment',
      t.tagTravel: 'travel',
      t.tagFood: 'food',
      t.tagHealth: 'health',
      t.tagFamily: 'family',
      t.tagFriends: 'friends',
      t.tagProject: 'project',
      t.tagIdeas: 'ideas',
      t.tagInspiration: 'inspiration',
      t.tagMemo: 'memo',
    };
    return tagMap[tagName] ?? 'default';
  }

  /// 验证标签名称
  /// 返回错误信息，null表示验证通过
  static String? validateTagName(String tagName) {
    if (tagName.isEmpty) {
      return t.tagNameRequired;
    }
    if (tagName.length > 14) {
      return t.tagNameTooLong;
    }
    if (tagName.contains(',')) {
      return t.tagNameNoComma;
    }
    if (tagName.trim() != tagName) {
      return t.tagNameNoLeadingTrailingSpaces;
    }
    // 检查特殊字符
    final RegExp specialChars = RegExp(r'[<>:"/\\|?*]');
    if (specialChars.hasMatch(tagName)) {
      return t.tagNameNoSpecialChars;
    }
    return null;
  }

  /// 清理标签列表
  /// 去重、去空、排序
  static List<String> cleanTagList(List<String> tags) {
    return tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// 合并标签列表
  /// 将多个标签列表合并并去重
  static List<String> mergeTags(List<List<String>> tagLists) {
    final Set<String> allTags = {};
    for (final tagList in tagLists) {
      allTags.addAll(cleanTagList(tagList));
    }
    return allTags.toList()..sort();
  }

  /// 获取标签颜色
  static Color getTagColor(String tagName, {Color? defaultColor}) {
    final colorKey = _getTagColorKey(tagName);
    return tagColors[colorKey] ?? defaultColor ?? AppColors.primary;
  }

  /// 构建标签芯片组件
  static Widget buildTagChip({
    required String tag,
    required bool isSelected,
    required VoidCallback onTap,
    int? usageCount,
    bool showUsageCount = true,
    Color? backgroundColor,
    Color? selectedColor,
    double? fontSize,
  }) {
    final bgColor = backgroundColor ?? getTagColor(tag);
    final textColor = isSelected ? Colors.white : bgColor;
    final chipBgColor = isSelected ? bgColor : bgColor.withValues(alpha: 0.1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.borderRadiusRegular,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipBgColor,
            borderRadius: AppRadius.borderRadiusRegular,
            border: Border.all(color: bgColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tag,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize ?? 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (showUsageCount && usageCount != null && usageCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : bgColor.withValues(alpha: 0.2),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Text(
                    '$usageCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check, size: 14, color: textColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签输入建议列表
  static Widget buildTagSuggestions({
    required BuildContext context,
    required List<String> suggestions,
    required List<String> selectedTags,
    required Function(String) onTagSelected,
    Map<String, int> usageCount = const {},
    int maxSuggestions = 10,
  }) {
    final filteredSuggestions = suggestions
        .where((tag) => !selectedTags.contains(tag))
        .take(maxSuggestions)
        .toList();

    if (filteredSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                t.suggestedTags,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filteredSuggestions
                .map(
                  (tag) => buildTagChip(
                    tag: tag,
                    isSelected: false,
                    onTap: () => onTagSelected(tag),
                    usageCount: usageCount[tag],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 构建常用标签模板
  static Widget buildCommonTagTemplates({
    required BuildContext context,
    required Function(String) onTagSelected,
    List<String> excludeTags = const [],
  }) {
    final availableTemplates = getCommonTagTemplates()
        .where((tag) => !excludeTags.contains(tag))
        .toList();

    if (availableTemplates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                t.commonTags,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTemplates
                .map(
                  (tag) => buildTagChip(
                    tag: tag,
                    isSelected: false,
                    onTap: () => onTagSelected(tag),
                    showUsageCount: false,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 显示标签管理底部弹窗
  static void showTagManagementBottomSheet({
    required BuildContext context,
    required List<String> currentTags,
    required List<String> allTags,
    required Function(List<String>) onTagsChanged,
    Map<String, int> usageCount = const {},
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              t.tagManagement,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // 当前标签
            if (currentTags.isNotEmpty) ...[
              Text(
                t.currentTags(param: currentTags.length.toString()),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: currentTags
                    .map(
                      (tag) => buildTagChip(
                        tag: tag,
                        isSelected: true,
                        onTap: () {
                          final newTags = List<String>.from(currentTags)
                            ..remove(tag);
                          onTagsChanged(newTags);
                        },
                        usageCount: usageCount[tag],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // 可选标签
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTagSuggestions(
                      context: context,
                      suggestions: allTags,
                      selectedTags: currentTags,
                      onTagSelected: (task) {
                        final newTags = List<String>.from(currentTags)
                          ..add(task);
                        onTagsChanged(newTags);
                      },
                      usageCount: usageCount,
                      maxSuggestions: 20,
                    ),
                    const SizedBox(height: 16),
                    buildCommonTagTemplates(
                      context: context,
                      onTagSelected: (task) {
                        if (!currentTags.contains(task)) {
                          final newTags = List<String>.from(currentTags)
                            ..add(task);
                          onTagsChanged(newTags);
                        }
                      },
                      excludeTags: currentTags,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 搜索标签
  static List<String> searchTags(
    List<String> tags,
    String query, {
    bool fuzzyMatch = true,
  }) {
    if (query.isEmpty) return tags;

    final lowerQuery = query.toLowerCase();

    return tags.where((tag) {
      final lowerTag = tag.toLowerCase();
      if (fuzzyMatch) {
        // 模糊匹配：包含查询字符串
        return lowerTag.contains(lowerQuery);
      } else {
        // 精确匹配：以查询字符串开头
        return lowerTag.startsWith(lowerQuery);
      }
    }).toList();
  }

  /// 按使用频率排序标签
  static List<String> sortTagsByUsage(
    List<String> tags,
    Map<String, int> usageCount, {
    bool descending = true,
  }) {
    final sortedTags = List<String>.from(tags);
    sortedTags.sort((a, b) {
      final countA = usageCount[a] ?? 0;
      final countB = usageCount[b] ?? 0;
      return descending ? countB.compareTo(countA) : countA.compareTo(countB);
    });
    return sortedTags;
  }

  /// 获取标签统计信息
  static Map<String, dynamic> getTagStatistics(
    List<String> tags,
    Map<String, int> usageCount,
  ) {
    if (tags.isEmpty) {
      return {
        'total_tags': 0,
        'total_usage': 0,
        'average_usage': 0.0,
        'most_used_tag': '',
        'least_used_tag': '',
      };
    }

    final totalUsage = usageCount.values.fold(0, (sum, count) => sum + count);
    final averageUsage = totalUsage / tags.length;

    final sortedByUsage = sortTagsByUsage(tags, usageCount);
    final mostUsedTag = sortedByUsage.isNotEmpty ? sortedByUsage.first : '';
    final leastUsedTag = sortedByUsage.isNotEmpty ? sortedByUsage.last : '';

    return {
      'total_tags': tags.length,
      'total_usage': totalUsage,
      'average_usage': averageUsage,
      'most_used_tag': mostUsedTag,
      'least_used_tag': leastUsedTag,
    };
  }
}
