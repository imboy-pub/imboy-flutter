import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 企业附件筛选控件族。
///
/// 视觉口径：全部控件同款「填充式圆角 10」容器（fill/radius 对齐全局
/// InputDecorationTheme，下拉从裸 DropdownButton 升级为
/// DropdownButtonFormField，消除三种控件风格混排）；高度 ≥44 满足触达
/// 合同；激活的筛选以 primary 描边 + primary 前景表达，状态可见。
class WorkspaceAttachmentFilters extends ConsumerStatefulWidget {
  const WorkspaceAttachmentFilters({
    super.key,
    required this.workspaceId,
    required this.onChanged,
  });
  final EntityId workspaceId;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  ConsumerState<WorkspaceAttachmentFilters> createState() => _FilterState();
}

class _FilterState extends ConsumerState<WorkspaceAttachmentFilters> {
  final _choices = <String, Map<EntityId, String>>{};
  final _selection = <String, EntityId>{};
  final _person = TextEditingController();
  Timer? _debounce;
  DateTimeRange? _dates;
  Object? _error;
  bool _loading = true;
  late final _owner = UserRepoLocal.to.currentUid;
  @override
  void initState() {
    super.initState();
    unawaited(_loadChoices());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _person.dispose();
    super.dispose();
  }

  Future<void> _loadChoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(workspaceApiProvider);
      final groups = await api.memberGroups(widget.workspaceId);
      final channels = await api.channels(widget.workspaceId);
      if (!mounted || _owner != UserRepoLocal.to.currentUid) return;
      setState(() {
        _choices['group_id'] = {
          for (final group in groups)
            entityIdOf(group.groupId): group.displayTitle,
        };
        _choices['channel_id'] = {
          for (final channel in channels) entityIdOf(channel.id): channel.name,
        };
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _emit() {
    widget.onChanged({
      ..._selection,
      'user_keyword': _person.text.trim(),
      if (_dates != null) 'from_ms': _dates!.start.millisecondsSinceEpoch,
      if (_dates != null)
        'until_ms': DateTime(
          _dates!.end.year,
          _dates!.end.month,
          _dates!.end.day + 1,
        ).millisecondsSinceEpoch,
    });
  }

  bool get _hasActive =>
      _selection.isNotEmpty || _dates != null || _person.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.t.attachmentManager;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.regular),
        child: Center(child: CupertinoActivityIndicator(radius: 10)),
      );
    }
    if (_error != null) {
      return TextButton(onPressed: _loadChoices, child: Text(t.moreFailed));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _dropdown('group_id', t.allGroups, t.selectGroupTitle),
            ),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: _dropdown(
                'channel_id',
                t.allChannels,
                t.selectChannelTitle,
              ),
            ),
          ],
        ),
        AppSpacing.verticalSmall,
        TextField(
          controller: _person,
          decoration: _fieldDecoration(
            context,
            active: _person.text.isNotEmpty,
            hintText: t.personSearch,
            prefixIcon: Icon(
              CupertinoIcons.search,
              size: 16,
              color: AppColors.iosGray,
            ),
            suffixIcon: _person.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.t.common.clear,
                    onPressed: () {
                      _person.clear();
                      setState(() {});
                      _emit();
                    },
                    icon: Icon(
                      CupertinoIcons.clear_thick_circled,
                      size: 18,
                      color: AppColors.iosGray3,
                    ),
                    // 18px 字形不够触达：约束到 40x40 命中区。
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
          ),
          onChanged: (_) {
            setState(() {});
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), _emit);
          },
        ),
        AppSpacing.verticalSmall,
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dateButton(context),
            if (_hasActive) _clearButton(context),
          ],
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    bool active = false,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      hintStyle: context.textStyle(
        FontSizeType.normal,
        color: AppColors.iosGray,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.medium,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: active
            ? BorderSide(
                color: AppColors.getIosBlue(Theme.of(context).brightness),
              )
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide(
          color: AppColors.getIosBlue(Theme.of(context).brightness),
        ),
      ),
      // 与全局主题同源（component_theme_manager getInputDecorationTheme），
      // 显式声明保证下拉/输入/按钮三族容器填色一致。
      fillColor: isDark
          ? AppColors.darkSurfaceGroupedTertiary
          : AppColors.lightBorder.withValues(alpha: 0.5),
      filled: true,
    );
  }

  /// 群组/频道选择器：字段外壳沿用控件族容器（InputDecorator），点开后
  /// 用底部弹层选择（iOS 惯例）替代 Material 下拉覆盖层——覆盖层与字段
  /// 错位、无选中勾选态、长列表滚动差，弹层一并解决。
  Widget _dropdown(String key, String label, String sheetTitle) {
    final selected = _selection[key];
    final selectedLabel = selected == null ? null : _choices[key]?[selected];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: AppRadius.input,
      onTap: () => _openPicker(context, key, label, sheetTitle),
      child: InputDecorator(
        decoration: _fieldDecoration(
          context,
          active: selected != null,
          suffixIcon: Icon(
            CupertinoIcons.chevron_down,
            size: 16,
            color: AppColors.iosGray,
          ),
        ),
        // 未选中回显灰色 hint 文案、选中回显常规前景——用显式 child 而非
        // InputDecoration.hintText：裸 InputDecorator 的 hint 显示机制在
        // 真 Mac 渲染下不稳定（测试环境可见、真机空白）。
        child: Text(
          selectedLabel ?? label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(
            FontSizeType.normal,
            color: selectedLabel == null
                ? AppColors.iosGray
                : (isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }

  /// 底部弹层选择：「全部」回传 ''（清除），具体项回传其 id；滑落/点外
  /// 回传 null = 不变更。
  Future<void> _openPicker(
    BuildContext context,
    String key,
    String allLabel,
    String title,
  ) async {
    final choices = _choices[key]!;
    final selected = _selection[key];
    final picked = await showModalBottomSheet<EntityId>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示条。
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(top: AppSpacing.small),
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).brightness == Brightness.dark
                      ? AppColors.iosGray3Dark
                      : AppColors.iosGray4,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.medium,
                ),
                child: Text(
                  title,
                  style: sheetContext.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: AppSpacing.small),
                  children: [
                    _pickerOption(
                      sheetContext,
                      label: allLabel,
                      selected: selected == null,
                      onPick: () => Navigator.pop(sheetContext, ''),
                    ),
                    for (final choice in choices.entries)
                      _pickerOption(
                        sheetContext,
                        label: choice.value,
                        selected: choice.key == selected,
                        onPick: () => Navigator.pop(sheetContext, choice.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (picked.isEmpty) {
        _selection.remove(key);
      } else {
        _selection[key] = picked;
      }
      if (key == 'group_id') _selection.remove('channel_id');
      if (key == 'channel_id') _selection.remove('group_id');
    });
    _emit();
  }

  /// 弹层选项行：≥48pt 触达、名称 + 当前项 primary 勾选。
  Widget _pickerOption(
    BuildContext sheetContext, {
    required String label,
    required bool selected,
    required VoidCallback onPick,
  }) {
    final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
    return InkWell(
      onTap: onPick,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.medium,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: sheetContext.textStyle(
                  FontSizeType.normal,
                  fontWeight: selected ? FontWeight.w600 : null,
                  color: selected
                      ? AppColors.getIosBlue(Theme.of(sheetContext).brightness)
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                ),
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.check_mark,
                size: 18,
                color: AppColors.getIosBlue(Theme.of(sheetContext).brightness),
              ),
          ],
        ),
      ),
    );
  }

  /// 时间范围：与下拉同款填充容器（激活态 primary 着色 + 已选区间回显）。
  Widget _dateButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _dates != null;
    final label = _dates == null
        ? context.t.attachmentManager.dateRange
        : '${DateFormat('MM/dd').format(_dates!.start)}–${DateFormat('MM/dd').format(_dates!.end)}';
    return TextButton.icon(
      onPressed: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          initialDateRange: _dates,
        );
        if (range == null || !mounted) return;
        setState(() => _dates = range);
        _emit();
      },
      icon: Icon(
        CupertinoIcons.calendar,
        size: 16,
        color: active
            ? AppColors.getIosBlue(Theme.of(context).brightness)
            : AppColors.iosGray,
      ),
      label: Text(label),
      style: TextButton.styleFrom(
        backgroundColor: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightBorder.withValues(alpha: 0.5),
        foregroundColor: active
            ? AppColors.getIosBlue(Theme.of(context).brightness)
            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.medium,
        ),
        minimumSize: const Size(0, 46),
        textStyle: context.textStyle(FontSizeType.normal),
      ),
    );
  }

  /// 清除筛选：与控件族同高的中性胶囊（图标先行，行为可预期）。
  Widget _clearButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _selection.clear();
          _dates = null;
          _person.clear();
        });
        _emit();
      },
      icon: Icon(CupertinoIcons.xmark, size: 14, color: AppColors.iosGray),
      label: Text(context.t.attachmentManager.clearFiltersAction),
      style: TextButton.styleFrom(
        backgroundColor: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightBorder.withValues(alpha: 0.5),
        foregroundColor: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.medium,
        ),
        minimumSize: const Size(0, 46),
        textStyle: context.textStyle(FontSizeType.normal),
      ),
    );
  }
}
