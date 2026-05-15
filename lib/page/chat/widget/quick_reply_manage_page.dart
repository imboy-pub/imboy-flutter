/// 快捷回复管理页（S2-b）
///
/// 让用户对 [QuickReplyService] 持久化的短语做 CRUD。
/// - 列表项滑动左划删除 + 点击编辑
/// - 底部 FAB 新增
/// - 未登录态下 FAB 隐藏
library;

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/quick_reply_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 适配器：将项目的 [StorageService] 桥接到 domain 层 [QuickReplyStore]。
/// 刻意保留在 UI 层文件里，保持 `quick_reply_service.dart` 纯粹可测。
class _StorageServiceQuickReplyStore implements QuickReplyStore {
  const _StorageServiceQuickReplyStore();

  @override
  Future<String?> getString(String key) async {
    final v = StorageService.to.getString(key);
    return v.isEmpty ? null : v;
  }

  @override
  Future<void> setString(String key, String value) async {
    await StorageService.to.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await StorageService.to.remove(key);
  }
}

class QuickReplyManagePage extends StatefulWidget {
  /// [defaults] 必传：首次使用时的内置默认列表（通常是 chat_input 同样的 i18n
  /// 短语）。在 UI 构造时由调用方传入而非本页内部组装，避免本页直接
  /// 耦合 chat_input 的默认列表字段。
  final List<String> defaults;

  const QuickReplyManagePage({super.key, required this.defaults});

  @override
  State<QuickReplyManagePage> createState() => _QuickReplyManagePageState();
}

class _QuickReplyManagePageState extends State<QuickReplyManagePage> {
  late final QuickReplyService _service;
  List<String> _replies = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = QuickReplyService(
      const _StorageServiceQuickReplyStore(),
      defaults: widget.defaults,
    );
    _refresh();
  }

  String get _uid => UserRepoLocal.to.currentUid;

  Future<void> _refresh() async {
    if (_uid.isEmpty) {
      setState(() {
        _replies = widget.defaults;
        _loading = false;
      });
      return;
    }
    final list = await _service.load(_uid);
    if (!mounted) return;
    setState(() {
      _replies = list;
      _loading = false;
    });
  }

  Future<void> _handleAdd() async {
    if (_replies.length >= QuickReplyService.maxEntries) {
      EasyLoading.showToast(
        t.chat.quickReplyMaxReached(
          max: QuickReplyService.maxEntries.toString(),
        ),
      );
      return;
    }
    final text = await _promptText(title: t.common.quickReplyAddTitle);
    if (text == null || text.trim().isEmpty) return;
    if (_replies.contains(text.trim())) {
      EasyLoading.showToast(t.chat.quickReplyDuplicate);
      return;
    }
    await _service.add(_uid, text);
    await _refresh();
  }

  Future<void> _handleEdit(int index) async {
    final original = _replies[index];
    final text = await _promptText(
      title: t.common.quickReplyEditTitle,
      initial: original,
    );
    if (text == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == original) return;
    if (_replies.any((r) => r == trimmed && r != original)) {
      EasyLoading.showToast(t.chat.quickReplyDuplicate);
      return;
    }
    await _service.updateAt(_uid, index, trimmed);
    await _refresh();
  }

  Future<void> _handleDelete(int index) async {
    await _service.removeAt(_uid, index);
    await _refresh();
  }

  /// S2-c: 拖拽排序回调，透传 Flutter ReorderableListView 的原始参数。
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    await _service.reorder(_uid, oldIndex, newIndex);
    await _refresh();
  }

  /// 弹 Material 对话框，接收用户输入文本，取消时返回 null。
  Future<String?> _promptText({
    required String title,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: QuickReplyService.maxTextLength,
          decoration: InputDecoration(hintText: t.chat.quickReplyHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t.chat.quickReplyManage)),
      floatingActionButton: _uid.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _handleAdd,
              tooltip: t.common.buttonAdd,
              child: const Icon(Icons.add),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _replies.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.chat.quickReplyEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _replies.length,
              onReorder: _handleReorder,
              // 关键：关闭默认长按拖拽，避免和 Dismissible 的滑动手势冲突；
              // 拖拽通过显式的 ReorderableDragStartListener handle 触发。
              buildDefaultDragHandles: false,
              itemBuilder: (context, index) {
                final text = _replies[index];
                final itemKey = ValueKey('quickReply-$index-$text');
                return Dismissible(
                  key: itemKey,
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.getIosRed(Theme.of(context).brightness),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) => _handleDelete(index),
                  child: ListTile(
                    title: Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: t.common.edit,
                          onPressed: () => _handleEdit(index),
                        ),
                        // S2-c: 拖拽手柄，仅在此图标上长按/拖动才触发 reorder
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _handleEdit(index),
                  ),
                );
              },
            ),
    );
  }
}
