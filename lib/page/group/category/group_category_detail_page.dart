import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/service/group_category_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/page/group/widgets/group_dialogs.dart';

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

  /// 弹出重命名 Dialog（Cupertino 风格）
  Future<void> _renameCategory() async {
    final controller = TextEditingController(text: _categoryName);
    final t = context.t;
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.groupCategory.renameCategory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.small),
            CupertinoTextField(
              controller: controller,
              autofocus: true,
              placeholder: t.groupCategory.categoryName,
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
      final newName = controller.text.trim();
      if (newName == _categoryName) return;

      final success = await GroupCategoryService.to.renameCategory(
        categoryId: widget.categoryId,
        name: newName,
      );

      if (!mounted) return;

      if (success) {
        setState(() => _categoryName = newName);
        AppLoading.showSuccess(t.groupCategory.categoryRenamed);
      } else {
        AppLoading.showError(t.groupCategory.renameFailed);
      }
    }
  }

  /// 弹出删除确认 Dialog（Cupertino 风格）
  Future<void> _deleteCategory() async {
    final t = context.t;
    final confirmed = await GroupDialogs.confirm(
      context,
      title: t.groupCategory.deleteCategory,
      content: t.groupCategory.deleteCategoryConfirm,
      destructive: true,
    );

    if (confirmed) {
      final success = await GroupCategoryService.to.deleteCategory(
        widget.categoryId,
      );

      if (!mounted) return;

      if (success) {
        AppLoading.showSuccess(t.groupCategory.categoryDeleted);
        Navigator.pop(context, true); // 告知父页面需要刷新
      } else {
        AppLoading.showError(t.groupCategory.deleteFailed);
      }
    }
  }

  /// 显示更多操作菜单（Cupertino ActionSheet）
  void _showMoreMenu() {
    final t = context.t;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _renameCategory();
            },
            child: Text(t.groupCategory.renameCategory),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCategory();
            },
            child: Text(t.groupCategory.deleteCategory),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.buttonCancel),
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
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showMoreMenu,
            child: const Icon(CupertinoIcons.ellipsis, size: 22),
          ),
        ],
      ),
      body: _buildBody(t),
    );
  }

  Widget _buildBody(Translations t) {
    return ListView(
      children: [
        AppSpacing.verticalXLarge,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderRadiusMedium,
            ),
            child: Padding(
              padding: AppSpacing.allRegular,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.iosGray,
                  ),
                  AppSpacing.horizontalMedium,
                  Expanded(
                    child: Text(
                      t.groupCategory.categoryDetailTip,
                      style: const TextStyle(
                        color: AppColors.iosGray,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppSpacing.verticalXLarge,
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
