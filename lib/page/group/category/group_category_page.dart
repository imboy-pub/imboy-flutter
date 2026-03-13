import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/service/group_category_service.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 群分组页面
class GroupCategoryPage extends ConsumerStatefulWidget {
  const GroupCategoryPage({super.key});

  @override
  ConsumerState<GroupCategoryPage> createState() => _GroupCategoryPageState();
}

class _GroupCategoryPageState extends ConsumerState<GroupCategoryPage> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await GroupCategoryService.to.getCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
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
          decoration: InputDecoration(
            hintText: t.groupCategory.categoryName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final success = await GroupCategoryService.to.createCategory(
        name: controller.text,
      );
      if (success != null && mounted) {
        _loadCategories();
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return NoDataView(
        text: t.groupCategory.noCategory,
        onTop: _loadCategories,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryItem(category);
        },
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: Text(category['name'] ?? ''),
      subtitle: Text('${category['group_count'] ?? 0} 个群聊'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // TODO: 跳转到分组详情
      },
    );
  }
}
