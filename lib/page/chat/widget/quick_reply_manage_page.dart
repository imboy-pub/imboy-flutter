/// 快捷回复管理页（S2-b）
///
/// 让用户对 [QuickReplyService] 持久化的短语做 CRUD。
/// - 列表项滑动左划删除 + 点击编辑
/// - 底部 FAB 新增
/// - 未登录态下 FAB 隐藏
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/chat_input_types.dart';
import 'package:imboy/service/quick_reply_service.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

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
      const StorageServiceQuickReplyStore(),
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
      AppLoading.showToast(
        t.chat.quickReplyMaxReached(
          max: QuickReplyService.maxEntries.toString(),
        ),
      );
      return;
    }
    final text = await _promptText(title: t.common.quickReplyAddTitle);
    if (text == null || text.trim().isEmpty) return;
    if (_replies.contains(text.trim())) {
      AppLoading.showToast(t.chat.quickReplyDuplicate);
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
      AppLoading.showToast(t.chat.quickReplyDuplicate);
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
  ///
  /// controller 须由对话框自身 State 持有（见 [_PromptDialog]）：在本
  /// 方法作用域手动 dispose 会早于退出动画，动画帧重建 TextField 时
  /// 触发 "used after being disposed"。
  Future<String?> _promptText({required String title, String initial = ''}) {
    return showCupertinoDialog<String>(
      context: context,
      builder: (_) => _PromptDialog(title: title, initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(t.chat.quickReplyManage),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _replies.isEmpty
          ? Center(
              child: Padding(
                padding: AppSpacing.allXLarge,
                child: Text(
                  t.chat.quickReplyEmpty,
                  textAlign: TextAlign.center,
                  style: context.textStyle(
                    FontSizeType.body,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            )
          : Stack(
              children: [
                ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _replies.length,
                  onReorderItem: _handleReorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final text = _replies[index];
                    final itemKey = ValueKey('quickReply-$index-$text');
                    return Dismissible(
                      key: itemKey,
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.getIosRed(
                          Theme.of(context).brightness,
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(
                          CupertinoIcons.delete,
                          color: AppColors.onPrimary,
                        ),
                      ),
                      onDismissed: (_) => _handleDelete(index),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleEdit(index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _handleEdit(index),
                                child: const Icon(
                                  CupertinoIcons.pencil,
                                  size: 20,
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.line_horizontal_3,
                                    size: 20,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // FAB positioned manually
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _uid.isEmpty
                      ? const SizedBox.shrink()
                      : CupertinoButton(
                          onPressed: _handleAdd,
                          color: CupertinoColors.activeBlue,
                          child: const Icon(
                            CupertinoIcons.add,
                            color: CupertinoColors.white,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// [_promptText] 的输入对话框。
///
/// controller 生命周期绑定本 widget，dispose 在对话框真正移出树后
/// （退出动画结束）触发，而非随 showDialog 调用方作用域提前释放。
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.title, this.initial = ''});

  final String title;
  final String initial;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: CupertinoTextField(
        enableSuggestions: false,
        autocorrect: false,
        controller: _controller,
        autofocus: true,
        maxLength: QuickReplyService.maxTextLength,
        placeholder: t.chat.quickReplyHint,
      ),
      actions: [
        CupertinoButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.buttonCancel),
        ),
        CupertinoButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(t.common.buttonConfirm),
        ),
      ],
    );
  }
}
