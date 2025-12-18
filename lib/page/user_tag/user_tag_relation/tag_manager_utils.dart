import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 标签管理工具类
/// 提供标签相关的实用功能和UI组件
class TagManagerUtils {
  /// 常用标签模板
  static const List<String> commonTagTemplates = [
    '重要', '紧急', '工作', '生活', '学习',
    '娱乐', '旅行', '美食', '健康', '家庭',
    '朋友', '项目', '想法', '灵感', '备忘',
  ];

  /// 标签颜色映射
  static const Map<String, Color> tagColors = {
    '重要': Colors.red,
    '紧急': Colors.orange,
    '工作': Colors.blue,
    '生活': Colors.green,
    '学习': Colors.purple,
    '娱乐': Colors.pink,
    '旅行': Colors.teal,
    '美食': Colors.amber,
    '健康': Colors.lightGreen,
    '家庭': Colors.brown,
    '朋友': Colors.cyan,
    '项目': Colors.indigo,
    '想法': Colors.lime,
    '灵感': Colors.yellow,
    '备忘': Colors.grey,
  };

  /// 验证标签名称
  /// 返回错误信息，null表示验证通过
  static String? validateTagName(String tagName) {
    if (tagName.isEmpty) {
      return '标签名称不能为空';
    }
    if (tagName.length > 14) {
      return '标签名称不能超过14个字符';
    }
    if (tagName.contains(',')) {
      return '标签名称不能包含逗号';
    }
    if (tagName.trim() != tagName) {
      return '标签名称不能包含前后空格';
    }
    // 检查特殊字符
    final RegExp specialChars = RegExp(r'[<>:"/\\|?*]');
    if (specialChars.hasMatch(tagName)) {
      return '标签名称不能包含特殊字符';
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
    return tagColors[tagName] ?? defaultColor ?? AppColors.primaryGreen;
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: bgColor.withValues(alpha: 0.3),
              width: 1,
            ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withValues(alpha: 0.2)
                        : bgColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
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
                Icon(
                  Icons.check,
                  size: 14,
                  color: textColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签输入建议列表
  static Widget buildTagSuggestions({
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
        color: Get.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Get.theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                '建议标签',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Get.theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filteredSuggestions
                .map((tag) => buildTagChip(
                      tag: tag,
                      isSelected: false,
                      onTap: () => onTagSelected(tag),
                      usageCount: usageCount[tag],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 构建常用标签模板
  static Widget buildCommonTagTemplates({
    required Function(String) onTagSelected,
    List<String> excludeTags = const [],
  }) {
    final availableTemplates = commonTagTemplates
        .where((tag) => !excludeTags.contains(tag))
        .toList();

    if (availableTemplates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_outline,
                size: 16,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                '常用标签',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Get.theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTemplates
                .map((tag) => buildTagChip(
                      tag: tag,
                      isSelected: false,
                      onTap: () => onTagSelected(tag),
                      showUsageCount: false,
                    ))
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
    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
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
                  color: Get.theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 标题
            Text(
              '标签管理',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Get.theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            
            // 当前标签
            if (currentTags.isNotEmpty) ...[
              Text(
                '当前标签 (${currentTags.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Get.theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: currentTags
                    .map((tag) => buildTagChip(
                          tag: tag,
                          isSelected: true,
                          onTap: () {
                            final newTags = List<String>.from(currentTags)
                              ..remove(tag);
                            onTagsChanged(newTags);
                          },
                          usageCount: usageCount[tag],
                        ))
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
                      suggestions: allTags,
                      selectedTags: currentTags,
                      onTagSelected: (tag) {
                        final newTags = List<String>.from(currentTags)..add(tag);
                        onTagsChanged(newTags);
                      },
                      usageCount: usageCount,
                      maxSuggestions: 20,
                    ),
                    const SizedBox(height: 16),
                    buildCommonTagTemplates(
                      onTagSelected: (tag) {
                        if (!currentTags.contains(tag)) {
                          final newTags = List<String>.from(currentTags)..add(tag);
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
      isScrollControlled: true,
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