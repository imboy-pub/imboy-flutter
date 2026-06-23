import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 增强的标签输入组件
/// 提供更好的标签编辑体验，包括：
/// 1. 清晰的标签显示和删除
/// 2. 智能输入提示
/// 3. 标签使用频率显示
/// 4. 实时预览
class TagInput extends StatefulWidget {
  final List<String> initialTags;
  final List<String> suggestedTags;
  final Map<String, int> tagUsageCount;
  final void Function(List<String>) onTagsChanged;
  final String? hintText;
  final int maxTagLength;
  final int maxTags;

  const TagInput({
    super.key,
    required this.initialTags,
    required this.suggestedTags,
    required this.onTagsChanged,
    this.tagUsageCount = const {},
    this.hintText,
    this.maxTagLength = 14,
    this.maxTags = 20,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _currentTags = [];
  List<String> _filteredSuggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentTags = List.from(widget.initialTags);
    _filteredSuggestions = List.from(widget.suggestedTags);

    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 文本变化监听
  void _onTextChanged() {
    final text = _controller.text.trim();

    // 防抖处理
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filterSuggestions(text);
    });
  }

  /// 焦点变化监听
  void _onFocusChanged() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus;
    });
  }

  /// 过滤建议标签
  void _filterSuggestions(String query) {
    if (!mounted) return;

    setState(() {
      if (query.isEmpty) {
        // 按使用频率排序显示所有建议
        _filteredSuggestions = List.from(widget.suggestedTags)
          ..sort((a, b) {
            final countA = widget.tagUsageCount[a] ?? 0;
            final countB = widget.tagUsageCount[b] ?? 0;
            return countB.compareTo(countA);
          });
      } else {
        // 模糊搜索匹配
        _filteredSuggestions =
            widget.suggestedTags
                .where(
                  (tag) =>
                      tag.toLowerCase().contains(query.toLowerCase()) &&
                      !_currentTags.contains(tag),
                )
                .toList()
              ..sort((a, b) {
                final countA = widget.tagUsageCount[a] ?? 0;
                final countB = widget.tagUsageCount[b] ?? 0;
                return countB.compareTo(countA);
              });
      }
    });
  }

  /// 添加标签
  void _addTag(String tag) {
    if (tag.isEmpty || _currentTags.contains(tag)) return;
    if (tag.length > widget.maxTagLength) {
      _showError(
        t.contact.tagLengthExceeded(param: widget.maxTagLength.toString()),
      );
      return;
    }
    if (_currentTags.length >= widget.maxTags) {
      _showError(t.contact.maxTagsExceeded(param: widget.maxTags.toString()));
      return;
    }

    setState(() {
      _currentTags.add(tag);
      _controller.clear();
      _filterSuggestions('');
    });

    widget.onTagsChanged(_currentTags);

    // 触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 删除标签
  void _removeTag(String tag) {
    setState(() {
      _currentTags.remove(tag);
    });

    widget.onTagsChanged(_currentTags);
    _filterSuggestions(_controller.text.trim());

    // 触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 显示错误提示
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.iosRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 构建当前标签列表
  Widget _buildCurrentTags() {
    if (_currentTags.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, size: 16, color: AppColors.primary),
              AppSpacing.horizontalSmall,
              Text(
                t.contact.selectedTags(
                  param: _currentTags.length.toString(),
                  max: widget.maxTags.toString(),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          AppSpacing.verticalMedium,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentTags
                .map((tag) => _buildTagChip(tag, true))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 构建标签芯片
  Widget _buildTagChip(String tag, bool isSelected) {
    final usageCount = widget.tagUsageCount[tag] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: AppRadius.borderRadiusLarge,
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).colorScheme.outline,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusLarge,
          onTap: () {
            if (isSelected) {
              _removeTag(tag);
            } else {
              _addTag(tag);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (usageCount > 0) ...[
                  AppSpacing.horizontalTiny,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.onPrimary.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Text(
                      '$usageCount',
                      style: context.textStyle(
                        FontSizeType.tiny,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (isSelected) ...[
                  AppSpacing.horizontalTiny,
                  Icon(Icons.close, size: 16, color: AppColors.onPrimary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建输入框
  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: _focusNode.hasFocus
              ? AppColors.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: _focusNode.hasFocus ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText ?? t.contact.tagInputHint,
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding: AppSpacing.allRegular,
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: AppColors.primary,
                  onPressed: () => _addTag(_controller.text.trim()),
                )
              : null,
        ),
        onSubmitted: (value) => _addTag(value.trim()),
        textInputAction: TextInputAction.done,
      ),
    );
  }

  /// 构建建议标签列表
  Widget _buildSuggestions() {
    if (!_showSuggestions || _filteredSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppSpacing.allRegular,
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: AppColors.iosOrange,
                ),
                AppSpacing.horizontalSmall,
                Text(
                  t.contact.suggestedTags,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filteredSuggestions
                  .take(15) // 限制显示数量
                  .map((tag) => _buildTagChip(tag, false))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 当前标签显示
        if (_currentTags.isNotEmpty) ...[
          _buildCurrentTags(),
          AppSpacing.verticalRegular,
        ],

        // 输入框
        _buildInputField(),

        // 建议标签
        _buildSuggestions(),
      ],
    );
  }
}
