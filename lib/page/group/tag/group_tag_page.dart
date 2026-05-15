import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/service/group_tag_service.dart';
import 'package:imboy/i18n/strings.g.dart';

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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.groupTag.addTag),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: t.groupTag.tagName),
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTag,
            tooltip: t.groupTag.addTag,
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
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Color(
            int.tryParse(tag['color'] as String? ?? '0xFF2196F3') ?? 0xFF2196F3,
          ),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(tag['name'] as String? ?? ''),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(t.groupTag.removeTitle),
              content: Text(t.groupTag.removeConfirm),
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

          if (confirm == true) {
            final tagName =
                tag['name']?.toString() ?? tag['tag_name']?.toString() ?? '';
            if (tagName.isEmpty) {
              return;
            }
            final success = await _service.removeTag(
              groupId: widget.groupId,
              tagName: tagName,
            );
            if (success && mounted) {
              _loadTags();
            }
          }
        },
      ),
    );
  }
}
