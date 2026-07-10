import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/service/group_category_service.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/category/group_category_detail_page.dart';

/// 群分组页面
class GroupCategoryPage extends ConsumerStatefulWidget {
  const GroupCategoryPage({super.key});

  @override
  ConsumerState<GroupCategoryPage> createState() => _GroupCategoryPageState();
}

class _GroupCategoryPageState extends ConsumerState<GroupCategoryPage> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await GroupCategoryService.to.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.groupCategory.createCategory),
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
      final success = await GroupCategoryService.to.createCategory(
        name: controller.text,
      );
      if (!mounted) return;
      if (success != null) {
        _loadCategories();
      } else {
        AppLoading.showError(t.common.tipFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupCategory.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createCategory,
            tooltip: t.groupCategory.createCategory,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return AsyncStateView(
      isLoading: _isLoading,
      error: _error,
      isEmpty: _categories.isEmpty,
      onRetry: _loadCategories,
      emptyText: t.groupCategory.noCategory,
      child: RefreshIndicator(
        onRefresh: _loadCategories,
        child: ListView.builder(
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return _buildCategoryItem(category);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(category['name'] as String? ?? ''),
      subtitle: Text(
        t.chat.groupCategoryGroupCount(
          count: category['group_count'] as Object? ?? 0,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute<dynamic>(
            builder: (_) => GroupCategoryDetailPage(
              categoryId: category['id'] as int,
              categoryName: category['name'] as String? ?? '',
            ),
          ),
        ).then((result) {
          if (result == true) _loadCategories();
        });
      },
    );
  }
}
