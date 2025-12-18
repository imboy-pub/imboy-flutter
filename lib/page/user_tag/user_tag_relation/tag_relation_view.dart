import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'tag_input.dart';
import 'user_tag_relation_logic.dart';

/// 增强版标签编辑页面
/// 提供更好的用户体验和功能
class TagRelationPage extends StatefulWidget {
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
  State<TagRelationPage> createState() => _TagRelationPageState();
}

class _TagRelationPageState extends State<TagRelationPage> {
  final logic = Get.put(UserTagRelationLogic());
  late final state = logic.state;

  List<String> _originalTags = [];
  List<String> _currentTags = [];
  List<String> _suggestedTags = [];
  Map<String, int> _tagUsageCount = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  /// 初始化数据
  Future<void> _initData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 解析当前标签
      _originalTags = widget.peerTag
          .split(',')
          .where((tag) => tag.trim().isNotEmpty)
          .toList();
      _currentTags = List.from(_originalTags);

      // 获取标签统计信息
      final statistics = await logic.getTagStatistics(widget.scene);
      _suggestedTags = List<String>.from(statistics['tags'] ?? []);
      _tagUsageCount = Map<String, int>.from(statistics['usage_count'] ?? {});

      // 确保当前标签包含在建议列表中
      for (String tag in _currentTags) {
        if (!_suggestedTags.contains(tag)) {
          _suggestedTags.add(tag);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('_initData error: $e');
      setState(() {
        _isLoading = false;
      });
      EasyLoading.showError('加载标签数据失败');
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
    final currentSet = Set.from(_currentTags);
    final originalSet = Set.from(_originalTags);
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

      EasyLoading.show(status: '保存中...');

      final success = await logic.add(
        widget.scene,
        widget.peerId,
        _currentTags,
      );

      EasyLoading.dismiss();

      if (success) {
        EasyLoading.showSuccess('保存成功');
        // 触觉反馈
        HapticFeedback.lightImpact();
        Get.back(result: _currentTags.join(','));
      } else {
        EasyLoading.showError('保存失败');
      }
    } catch (e) {
      debugPrint('_saveTags error: $e');
      EasyLoading.dismiss();
      EasyLoading.showError('保存失败');
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有标签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentTags.clear();
              });
              HapticFeedback.lightImpact();
            },
            child: Text(
              '确定',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard() {
    final totalTags = _suggestedTags.length;
    final selectedCount = _currentTags.length;
    final mostUsedTag = _tagUsageCount.isNotEmpty
        ? _tagUsageCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key
        : '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.1),
            AppColors.primaryGreen.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '标签统计',
                style: TextStyle(
                  fontSize: 16,
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
                child: _buildStatItem('已选择', '$selectedCount', Icons.check_circle),
              ),
              Expanded(
                child: _buildStatItem('可选择', '$totalTags', Icons.label_outline),
              ),
              if (mostUsedTag.isNotEmpty)
                Expanded(
                  child: _buildStatItem('最常用', mostUsedTag, Icons.star_outline),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primaryGreen,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  /// 构建快捷操作栏
  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '快捷操作',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          _buildQuickActionButton(
            '重置',
            Icons.refresh,
            _hasChanges() ? _resetTags : null,
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            '清空',
            Icons.clear_all,
            _currentTags.isNotEmpty ? _clearAllTags : null,
          ),
        ],
      ),
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
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.title ?? '编辑标签'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
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
                          AppColors.primaryGreen,
                        ),
                      ),
                    )
                  : Text(
                      '保存',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // 统计信息卡片
                _buildStatisticsCard(),

                // 快捷操作栏
                _buildQuickActions(),

                const SizedBox(height: 16),

                // 标签编辑区域
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: TagInput(
                      initialTags: _currentTags,
                      suggestedTags: _suggestedTags,
                      tagUsageCount: _tagUsageCount,
                      onTagsChanged: _onTagsChanged,
                      hintText: '输入新标签...',
                      maxTagLength: 14,
                      maxTags: 20,
                    ),
                  ),
                ),

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
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveTags,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('保存中...'),
                              ],
                            )
                          : Text(
                              '保存标签 (${_currentTags.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
    );
  }
}