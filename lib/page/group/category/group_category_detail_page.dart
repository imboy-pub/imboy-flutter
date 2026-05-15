import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/service/group_category_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 群分组详情页面
class GroupCategoryDetailPage extends StatefulWidget {
  const GroupCategoryDetailPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  final int categoryId;
  final String categoryName;

  @override
  State<GroupCategoryDetailPage> createState() =>
      _GroupCategoryDetailPageState();
}

class _GroupCategoryDetailPageState extends State<GroupCategoryDetailPage> {
  late String _categoryName;

  @override
  void initState() {
    super.initState();
    _categoryName = widget.categoryName;
  }

  /// 弹出重命名 Dialog
  Future<void> _renameCategory() async {
    final controller = TextEditingController(text: _categoryName);
    final t = context.t;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.groupCategory.renameCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t.groupCategory.categoryName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final newName = controller.text.trim();
      if (newName == _categoryName) return;

      final success = await GroupCategoryService.to.renameCategory(
        categoryId: widget.categoryId,
        name: newName,
      );

      if (!mounted) return;

      if (success) {
        setState(() => _categoryName = newName);
        EasyLoading.showSuccess(t.groupCategory.categoryRenamed);
      } else {
        EasyLoading.showError(t.groupCategory.renameFailed);
      }
    }
  }

  /// 弹出删除确认 Dialog
  Future<void> _deleteCategory() async {
    final t = context.t;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.groupCategory.deleteCategory),
        content: Text(t.groupCategory.deleteCategoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.getIosRed(
                Theme.of(context).brightness,
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (result == true) {
      final success = await GroupCategoryService.to.deleteCategory(
        widget.categoryId,
      );

      if (!mounted) return;

      if (success) {
        EasyLoading.showSuccess(t.groupCategory.categoryDeleted);
        Navigator.pop(context, true); // 告知父页面需要刷新
      } else {
        EasyLoading.showError(t.groupCategory.deleteFailed);
      }
    }
  }

  /// 显示更多操作菜单
  void _showMoreMenu() {
    final t = context.t;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.groupCategory.renameCategory),
              onTap: () {
                Navigator.pop(context);
                _renameCategory();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: AppColors.getIosRed(Theme.of(context).brightness),
              ),
              title: Text(
                t.groupCategory.deleteCategory,
                style: TextStyle(
                  color: AppColors.getIosRed(Theme.of(context).brightness),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteCategory();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: _categoryName,
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: _showMoreMenu,
            tooltip: t.common.moreInfo,
          ),
        ],
      ),
      body: _buildBody(t),
    );
  }

  Widget _buildBody(Translations t) {
    return ListView(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMedium,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.groupCategory.categoryDetailTip,
                      style: const TextStyle(color: Colors.grey, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMedium,
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(t.groupCategory.renameCategory),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _renameCategory,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppColors.getIosRed(Theme.of(context).brightness),
                  ),
                  title: Text(
                    t.groupCategory.deleteCategory,
                    style: TextStyle(
                      color: AppColors.getIosRed(Theme.of(context).brightness),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _deleteCategory,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
