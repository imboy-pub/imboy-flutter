import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/service/group_tag_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群标签页面
class GroupTagPage extends ConsumerStatefulWidget {
  final String groupId;
  final GroupTagService? service;

  const GroupTagPage({super.key, required this.groupId, this.service});

  @override
  ConsumerState<GroupTagPage> createState() => _GroupTagPageState();
}

class _GroupTagPageState extends ConsumerState<GroupTagPage> {
  List<Map<String, dynamic>> _tags = [];
  bool _isLoading = true;

  GroupTagService get _service => widget.service ?? GroupTagService.to;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    final tags = await _service.getGroupTags(widget.groupId);
    if (mounted) {
      setState(() {
        _tags = tags;
        _isLoading = false;
      });
    }
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.groupTag.addTag),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.small),
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: t.groupTag.tagName,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final success = await _service.addTag(
        groupId: widget.groupId,
        name: controller.text,
      );
      if (success && mounted) {
        _loadTags();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupTag.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _addTag,
            child: const Icon(CupertinoIcons.add, size: 22),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tags.isEmpty) {
      return NoDataView(text: t.groupTag.noTag, onTop: _loadTags);
    }

    return RefreshIndicator(
      onRefresh: _loadTags,
      child: ListView.builder(
        itemCount: _tags.length,
        itemBuilder: (context, index) {
          final tag = _tags[index];
          return _buildTagItem(tag);
        },
      ),
    );
  }

  Widget _buildTagItem(Map<String, dynamic> tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.getIosSeparator(
              Theme.of(context).brightness,
            ).withValues(alpha: 0.3),
            width: 0.33,
          ),
        ),
      ),
      child: CupertinoListTile(
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            // 标签颜色来自服务端数据，动态解析
            color: _parseTagColor(tag['color'] as String?),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          tag['name'] as String? ?? '',
          style: context.textStyle(FontSizeType.body),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            final confirm = await GroupDialogs.confirm(
              context,
              title: t.groupTag.removeTitle,
              content: t.groupTag.removeConfirm,
              confirmText: t.common.confirm,
              destructive: true,
            );
            if (confirm) {
              final tagName =
                  tag['name']?.toString() ?? tag['tag_name']?.toString() ?? '';
              if (tagName.isEmpty) return;
              final success = await _service.removeTag(
                groupId: widget.groupId,
                tagName: tagName,
              );
              if (success && mounted) {
                _loadTags();
              }
            }
          },
          child: Icon(
            CupertinoIcons.delete,
            size: 20,
            color: AppColors.getIosRed(Theme.of(context).brightness),
          ),
        ),
      ),
    );
  }

  /// 解析标签颜色（服务端返回），兜底用 iosBlue。
  Color _parseTagColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.iosBlue;
    final parsed = int.tryParse(hex);
    return parsed != null ? Color(parsed) : AppColors.iosBlue;
  }
}
