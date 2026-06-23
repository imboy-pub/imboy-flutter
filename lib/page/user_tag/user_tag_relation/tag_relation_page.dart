import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_input.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 增强版标签编辑页面
/// 提供更好的用户体验和功能
class TagRelationPage extends ConsumerStatefulWidget {
  final String peerId;
  final String peerTag;
  final String scene;
  final String? title;

  const TagRelationPage({
    super.key,
    required this.peerId,
    required this.peerTag,
    required this.scene,
    this.title,
  });

  @override
  ConsumerState<TagRelationPage> createState() => _TagRelationPageState();
}

class _TagRelationPageState extends ConsumerState<TagRelationPage> {
  List<String> _originalTags = [];
  List<String> _currentTags = [];
  List<String> _suggestedTags = [];
  Map<String, int> _tagUsageCount = {};
  Map<String, int> _tagIdByName = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  /// 初始化数据
  Future<void> _initData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 解析当前标签
      _originalTags = normalizeTagNames(widget.peerTag.split(','));
      _currentTags = List.from(_originalTags);

      // 获取标签统计信息
      final statistics = await ref
          .read(userTagRelationProvider.notifier)
          .getTagStatistics(widget.scene, ensureTags: _originalTags);
      _suggestedTags = List<String>.from(
        (statistics['tags'] ?? const <dynamic>[]) as Iterable<dynamic>,
      );
      _tagUsageCount = Map<String, int>.from(
        (statistics['usage_count'] ?? const <dynamic, dynamic>{})
            as Map<dynamic, dynamic>,
      );
      _tagIdByName = Map<String, int>.from(
        (statistics['tag_id_by_name'] ?? const <dynamic, dynamic>{})
            as Map<dynamic, dynamic>,
      );

      // 确保当前标签包含在建议列表中
      for (String tag in _currentTags) {
        if (!_suggestedTags.contains(tag)) {
          _suggestedTags.add(tag);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('_initData error: ${e.runtimeType}');
      setState(() {
        _isLoading = false;
      });
      EasyLoading.showError(t.common.loadingTagDataFailed);
    }
  }

  /// 标签变更回调
  void _onTagsChanged(List<String> newTags) {
    setState(() {
      _currentTags = newTags;
    });
  }

  /// 检查是否有变更
  bool _hasChanges() {
    final currentSet = Set<dynamic>.from(_currentTags);
    final originalSet = Set<dynamic>.from(_originalTags);
    return !currentSet.containsAll(originalSet) ||
        !originalSet.containsAll(currentSet);
  }

  /// 保存标签
  Future<void> _saveTags() async {
    if (_isSaving) return;

    try {
      setState(() {
        _isSaving = true;
      });

      EasyLoading.show(status: t.common.loading);

      final success = await ref
          .read(userTagRelationProvider.notifier)
          .syncFinalState(
            scene: widget.scene,
            objectId: widget.peerId,
            originalTags: _originalTags,
            nextTags: _currentTags,
            tagIdByName: _tagIdByName,
          );

      EasyLoading.dismiss();

      if (success) {
        EasyLoading.showSuccess(t.common.saveSuccess);
        // 触觉反馈
        HapticFeedback.lightImpact();
        if (mounted) {
          Navigator.of(context).pop(normalizeTagNames(_currentTags).join(','));
        }
      } else {
        EasyLoading.showError(t.common.saveFailed);
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('_saveTags error: ${e.runtimeType}');
      EasyLoading.dismiss();
      EasyLoading.showError(t.common.saveFailed);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// 重置标签
  void _resetTags() {
    setState(() {
      _currentTags = List.from(_originalTags);
    });
    HapticFeedback.lightImpact();
  }

  /// 清空所有标签
  void _clearAllTags() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.tagClearAll),
        content: Text(t.common.tagClearAllConfirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _currentTags.clear();
              });
              HapticFeedback.lightImpact();
            },
            child: Text(t.common.buttonOk),
          ),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: FontSizeType.medium.size,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: FontSizeType.small.size,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// 构建快捷操作按钮
  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: onPressed != null
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: onPressed != null
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(44, 44),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Text(widget.title ?? t.common.editTags),
        backgroundColor: isDark
            ? Theme.of(context).colorScheme.surface
            : AppColors.lightSurface,
        rightDMActions: [
          if (_hasChanges())
            TextButton(
              onPressed: _isSaving ? null : _saveTags,
              child: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : Text(
                      t.common.buttonSave,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 统计信息卡片
                _buildStatisticsCard(isDark),

                // 快捷操作栏
                _buildQuickActions(isDark),

                const SizedBox(height: 16),

                // 标签编辑区域
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : AppColors.lightSurface,
                      borderRadius: AppRadius.borderRadiusMedium,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.transparent
                              : AppColors.darkBackground.withValues(
                                  alpha: 0.04,
                                ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TagInput(
                      initialTags: _currentTags,
                      suggestedTags: _suggestedTags,
                      tagUsageCount: _tagUsageCount,
                      onTagsChanged: _onTagsChanged,
                      hintText: t.contact.inputNewTag,
                      maxTagLength: 14,
                      maxTags: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 底部保存按钮
                if (_hasChanges())
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).colorScheme.surface
                          : AppColors.lightSurface,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveTags,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderRadiusMedium,
                        ),
                      ),
                      child: _isSaving
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.onPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(t.common.loading),
                              ],
                            )
                          : Text(
                              t.common.saveTag(
                                count: _currentTags.length.toString(),
                              ),
                              style: TextStyle(
                                fontSize: FontSizeType.medium.size,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard(bool isDark) {
    final totalTags = _suggestedTags.length;
    final selectedCount = _currentTags.length;
    final mostUsedTag = _tagUsageCount.isNotEmpty
        ? _tagUsageCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.lightSurface,
        gradient: isDark
            ? null
            : const LinearGradient(
                colors: [AppColors.successBackground, AppColors.lightSurface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: AppRadius.borderRadiusMedium,
        border: isDark
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.15),
                width: 0.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.transparent
                : AppColors.darkBackground.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: AppColors.onPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                t.chat.tagStatistics,
                style: TextStyle(
                  fontSize: FontSizeType.medium.size,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  t.main.selectedCount(count: selectedCount),
                  '$selectedCount',
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  t.main.availableCount,
                  '$totalTags',
                  Icons.label_outline,
                ),
              ),
              if (mostUsedTag.isNotEmpty)
                Expanded(
                  child: _buildStatItem(
                    t.main.mostUsed,
                    mostUsedTag,
                    Icons.star_outline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建快捷操作栏
  Widget _buildQuickActions(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.transparent
                : AppColors.darkBackground.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            t.common.quickActions,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          _buildQuickActionButton(
            t.common.reset,
            Icons.refresh,
            _hasChanges() ? _resetTags : null,
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            t.common.clear,
            Icons.clear_all,
            _currentTags.isNotEmpty ? _clearAllTags : null,
          ),
        ],
      ),
    );
  }
}
