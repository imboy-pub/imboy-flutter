import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_relation_page.dart'
    show TagRelationPage;
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Temporary compatibility page for the social graph module shell.
/// New upper-layer imports should prefer `package:imboy/modules/social_graph/public.dart`.

import 'user_collect_detail_page.dart';
import 'user_collect_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// UserCollect 页面
///
/// 从 GetX 迁移到 Riverpod
/// 使用 ConsumerWidget + ConsumerStatefulWidget 管理状态
class UserCollectPage extends ConsumerStatefulWidget {
  final bool isSelect;
  final Map<String, String> peer;

  const UserCollectPage({
    super.key,
    this.peer = const {},
    this.isSelect = false,
  });

  @override
  ConsumerState<UserCollectPage> createState() => _UserCollectPageState();
}

class _UserCollectPageState extends ConsumerState<UserCollectPage> {
  final ScrollController controller = ScrollController();

  bool _loadError = false;
  bool _isInitialized = false;

  StreamSubscription<dynamic>? _localeSubscription;

  /// 最近一次次要点击（右键/触控板次要点击）的位置
  Offset? _lastSecondaryTapPosition;

  /// 置顶集合（前端内存置顶）
  final Set<String> _pinnedIds = {};
  static const String _kPinnedPrefsKey = 'user_collect_pinned_ids';

  /// 多选模式与已选集合
  bool _multiSelect = false;
  final Set<String> _selectedIds = {};

  /// 搜索防抖
  Timer? _searchTimer;

  /// 搜索输入控制器
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _setupScrollListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
      _loadPinnedIds();
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    controller.dispose();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// 初始化数据
  Future<void> _initData() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _loadError = false;

    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);

    // 使用 page = 1 重置状态
    String? kind = widget.isSelect ? currentState.recentUse : currentState.kind;

    try {
      final list = await notifier.page(
        page: 1,
        size: currentState.size,
        kind: kind,
      );

      debugPrint('_initData loaded ${list.length} items');

      if (mounted) {
        // 更新状态
        notifier.updateState(
          currentState.copyWith(
            items: list,
            page: list.isNotEmpty ? 2 : 1,
            hasMore: list.length >= currentState.size,
          ),
        );
      }

      // 加载标签数据
      final tagItems = await notifier.tagItems(context);
      if (mounted) {
        final updatedState = ref.read(userCollectProvider);
        notifier.updateState(updatedState.copyWith(tagItems: tagItems));
      }
    } catch (e, s) {
      debugPrint('user_collect_page_initData error: $e, $s');
      if (mounted) {
        setState(() {
          _loadError = true;
        });
      }
    }
  }

  /// 设置滚动监听
  void _setupScrollListener() {
    controller.addListener(() async {
      if (!controller.hasClients) return;

      final currentState = ref.read(userCollectProvider);

      // 如果已经在加载中或没有更多，直接忽略触发
      if (currentState.isLoading || !currentState.hasMore) return;

      double pixels = controller.position.pixels;
      double maxScrollExtent = controller.position.maxScrollExtent;

      // 滑动到底部，执行加载更多操作
      if (pixels >= maxScrollExtent - 100) {
        try {
          final notifier = ref.read(userCollectProvider.notifier);

          final list = await notifier.page(
            page: currentState.page,
            size: currentState.size,
            kind: currentState.kind,
          );

          if (list.isNotEmpty && mounted) {
            // 去重添加
            final existingIds = currentState.items.map((e) => e.kindId).toSet();
            final filtered = list
                .where((e) => !existingIds.contains(e.kindId))
                .toList();

            if (filtered.isNotEmpty) {
              final updatedItems = [...currentState.items, ...filtered];
              notifier.updateState(
                currentState.copyWith(
                  items: updatedItems,
                  page: currentState.page + 1,
                  hasMore: list.length >= currentState.size,
                ),
              );
            } else {
              // 没有新数据，更新 hasMore
              notifier.updateState(currentState.copyWith(hasMore: false));
            }
          } else {
            // 没有获取到更多数据
            notifier.updateState(currentState.copyWith(hasMore: false));
          }
        } on Exception catch (e) {
          if (kDebugMode) debugPrint('Load more error: ${e.runtimeType}');
        }
      }
    });
  }

  /// 持久化：加载置顶集合
  Future<void> _loadPinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list =
          prefs.getStringList(_kPinnedPrefsKey) ?? <String>[];
      if (!mounted) return;
      setState(() {
        _pinnedIds
          ..clear()
          ..addAll(list);
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Load pinned ids error: ${e.runtimeType}');
    }
  }

  /// 持久化：保存置顶集合
  Future<void> _savePinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPinnedPrefsKey, _pinnedIds.toList());
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Save pinned ids error: ${e.runtimeType}');
    }
  }

  /// 构建标签列表组件
  Widget buildItemTag(String tagStr, BuildContext context) {
    List<Widget> items = [];
    List<String> tagList = tagStr
        .split(',')
        .where((o) => o.trim().isNotEmpty)
        .toList();

    for (String tag in tagList) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 6),
          child: GestureDetector(
            onTap: () {
              _searchByTag(context, tag, tag);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha10,
                borderRadius: AppRadius.borderRadiusMedium,
                border: Border.all(color: AppColors.primaryAlpha30, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    tag,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Wrap(spacing: 4, runSpacing: 4, children: items);
  }

  /// 置顶/取消置顶
  void _togglePin(UserCollectModel obj) {
    setState(() {
      if (_pinnedIds.contains(obj.kindId.toString())) {
        _pinnedIds.remove(obj.kindId.toString());
      } else {
        _pinnedIds.add(obj.kindId.toString());
      }
    });
    _savePinnedIds();
  }

  /// 进入多选模式并选择首个项（长按进入）
  void _enterMultiSelect(UserCollectModel obj) {
    setState(() {
      _multiSelect = true;
      _selectedIds
        ..clear()
        ..add(obj.kindId.toString());
    });
  }

  /// 退出多选模式并清空选择
  void _exitMultiSelect() {
    setState(() {
      _multiSelect = false;
      _selectedIds.clear();
    });
  }

  /// 切换选择某一项
  void _toggleSelect(UserCollectModel obj) {
    setState(() {
      if (_selectedIds.contains(obj.kindId.toString())) {
        _selectedIds.remove(obj.kindId.toString());
        if (_selectedIds.isEmpty) {
          _multiSelect = false;
        }
      } else {
        _selectedIds.add(obj.kindId.toString());
      }
    });
  }

  /// 全选当前已加载的项
  void _selectAllCurrent() {
    final currentState = ref.read(userCollectProvider);
    setState(() {
      for (final o in currentState.items) {
        _selectedIds.add(o.kindId.toString());
      }
      _multiSelect = true;
    });
  }

  /// 取消全选
  void _clearSelect() {
    setState(() {
      _selectedIds.clear();
      _multiSelect = false;
    });
  }

  /// 批量删除
  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();

    final currentState = ref.read(userCollectProvider);
    final notifier = ref.read(userCollectProvider.notifier);

    // 检查是否有正在删除的项
    final hasRemoving = ids.any((id) => currentState.removingIds.contains(id));
    if (hasRemoving) {
      EasyLoading.showInfo(t.main.deletingInProgressPleaseWait);
      return;
    }

    try {
      EasyLoading.show(status: t.common.loading);
      int successCount = 0;
      int failCount = 0;

      // 逐个删除，失败不阻断
      final updatedItems = <UserCollectModel>[];
      for (int i = currentState.items.length - 1; i >= 0; i--) {
        final obj = currentState.items[i];
        if (ids.contains(obj.kindId)) {
          try {
            final ok = await notifier.remove(obj as UserCollectModel);
            if (ok) {
              successCount++;
            } else {
              updatedItems.add(obj);
              failCount++;
            }
          } catch (_) {
            updatedItems.add(obj as UserCollectModel);
            failCount++;
          }
        } else {
          updatedItems.add(obj as UserCollectModel);
        }
      }

      EasyLoading.dismiss();
      if (failCount == 0) {
        EasyLoading.showSuccess(t.common.deleteSuccess);
      } else if (successCount > 0) {
        EasyLoading.showInfo(
          t.common.partialDeleteSuccess(
            success: '$successCount',
            fail: '$failCount',
          ),
        );
      } else {
        EasyLoading.showError(t.common.saveFailed);
      }

      // 更新状态
      notifier.updateState(currentState.copyWith(items: updatedItems));
      _exitMultiSelect();
    } on Exception {
      EasyLoading.dismiss();
      EasyLoading.showError(t.common.tipFailed);
    }
  }

  /// 批量加标签
  Future<void> _batchTag() async {
    if (_selectedIds.isEmpty) return;
    final TextEditingController tc = TextEditingController();

    final currentState = ref.read(userCollectProvider);
    final notifier = ref.read(userCollectProvider.notifier);

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.editTag),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: tc,
            placeholder: t.contact.favoriteGroupTagsEtc,
            minLines: 1,
            maxLines: 3,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final input = tc.text.trim();
              if (input.isEmpty) {
                EasyLoading.showInfo(t.contact.pleaseEnterTags);
                return;
              }
              Navigator.pop(context);

              try {
                EasyLoading.show(status: t.common.loading);
                final Set<String> ids = {..._selectedIds};
                final updatedItems = <UserCollectModel>[];

                for (final obj in currentState.items) {
                  if (!ids.contains(obj.kindId)) {
                    updatedItems.add(obj as UserCollectModel);
                    continue;
                  }

                  String newTag = obj.tag.isEmpty == true
                      ? input
                      : '${obj.tag},$input';
                  // 清理重复标签
                  final parts = newTag
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toSet()
                      .toList();

                  // 创建新的对象而不是使用 copyWith
                  updatedItems.add(
                    UserCollectModel(
                      userId: obj.userId as int,
                      kind: obj.kind as int,
                      kindId: obj.kindId as int,
                      source: obj.source as String,
                      remark: obj.remark as String,
                      tag: parts.join(','),
                      updatedAt: obj.updatedAt as int,
                      createdAt: obj.createdAt as int,
                      info: obj.info as Map<String, dynamic>,
                    ),
                  );
                }

                notifier.updateState(
                  currentState.copyWith(items: updatedItems),
                );

                EasyLoading.dismiss();
                EasyLoading.showSuccess(t.common.tipSuccess);
                _exitMultiSelect();
              } on Exception {
                EasyLoading.dismiss();
                EasyLoading.showError(t.common.tipFailed);
              }
            },
            isDefaultAction: true,
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
  }

  /// 构建加载失败的错误面板
  Widget _buildLoadErrorPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.common.loadError,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () {
              _isInitialized = false;
              _initData();
            },
            child: Text(t.common.buttonRetry),
          ),
        ],
      ),
    );
  }

  /// 构建收藏项组件
  Widget _buildCollectItem(
    BuildContext context,
    UserCollectModel obj,
    int index,
  ) {
    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);

    final bool isPinned = _pinnedIds.contains(obj.kindId.toString());
    final bool isSelected = _selectedIds.contains(obj.kindId.toString());

    final card = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.borderRadiusMedium,
        child: GestureDetector(
          onLongPress: () {
            _enterMultiSelect(obj);
          },
          onTap: () async {
            try {
              // 多选模式下，点击切换选择状态
              if (_multiSelect) {
                _toggleSelect(obj);
                return;
              }

              // 非多选模式下的点击处理
              if (widget.isSelect) {
                // 转发消息模式
                _sendToDialog(obj);
              } else {
                // 进入收藏详情页面
                if (kDebugMode) debugPrint('Navigating to detail page');
                Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (context) =>
                        UserCollectDetailPage(obj: obj, pageIndex: index),
                  ),
                );
              }
            } on Exception catch (e) {
              if (kDebugMode) debugPrint('Tap error: ${e.runtimeType}');
            }
          },
          onSecondaryTapDown: (details) {
            _lastSecondaryTapPosition = details.globalPosition;
          },
          onSecondaryTap: () {
            try {
              if (_lastSecondaryTapPosition != null) {
                _showContextMenu(_lastSecondaryTapPosition!, obj, index);
              }
            } on Exception catch (e) {
              if (kDebugMode) {
                debugPrint('showContextMenu error: ${e.runtimeType}');
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // 主体内容
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 置顶标识
                    if (isPinned) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.chat.pinned,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // 消息内容
                    notifier.buildItemBody(context, obj, 'page'),
                    const SizedBox(height: 12),
                    // 来源和时间
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            obj.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: AppRadius.borderRadiusSmall,
                          ),
                          child: Text(
                            currentState.kind == currentState.recentUse &&
                                    obj.updatedAt > 0
                                ? DateTimeHelper.lastTimeFmt(obj.updatedAt)
                                : DateTimeHelper.lastTimeFmt(obj.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 标签
                    if (obj.tag.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      buildItemTag(obj.tag, context),
                    ],
                  ],
                ),

                // 右上角选择框（仅多选模式显示）
                if (_multiSelect)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) {
                          _toggleSelect(obj);
                        },
                        activeColor: AppColors.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Slidable(
        key: ValueKey('${obj.kindId}_$index'),
        groupTag: 'collect_items',
        closeOnScroll: true,
        // 左侧：置顶/取消置顶
        startActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) {
                _togglePin(obj);
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: isPinned
                  ? Icons.vertical_align_bottom
                  : Icons.vertical_align_top,
              label: isPinned ? t.chat.unpin : t.chat.pin,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ],
        ),
        // 右侧：标签、删除
        endActionPane: ActionPane(
          extentRatio: 0.5,
          motion: const DrawerMotion(),
          children: [
            // 标签编辑按钮
            SlidableAction(
              backgroundColor: AppColors.info,
              onPressed: (_) async {
                try {
                  final result = await Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (context) => TagRelationPage(
                        peerId: obj.kindId.toString(),
                        peerTag: obj.tag,
                        scene: 'collect',
                        title: t.common.editTag,
                      ),
                    ),
                  );
                  if (result != null && result is String && mounted) {
                    // 创建新的对象而不是使用 copyWith
                    final updatedItems = currentState.items.map((item) {
                      if (item.kindId == obj.kindId) {
                        return UserCollectModel(
                          userId: item.userId as int,
                          kind: item.kind as int,
                          kindId: item.kindId as int,
                          source: item.source as String,
                          remark: item.remark as String,
                          tag: result.toString(),
                          updatedAt: item.updatedAt as int,
                          createdAt: item.createdAt as int,
                          info: item.info as Map<String, dynamic>,
                        );
                      }
                      return item;
                    }).toList();
                    notifier.updateState(
                      currentState.copyWith(items: updatedItems),
                    );
                  }
                } on Exception catch (e) {
                  if (kDebugMode) {
                    debugPrint('Edit tag error: ${e.runtimeType}');
                  }
                }
              },
              icon: Icons.local_offer_outlined,
              foregroundColor: Colors.white,
              label: t.contact.tags,
            ),
            // 删除按钮
            SlidableAction(
              backgroundColor: AppColors.lightError,
              onPressed: (_) {
                _showDeleteBottomSheet(context, obj, index);
              },
              icon: Icons.delete_outline,
              foregroundColor: Colors.white,
              label: t.common.buttonDelete,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
          ],
        ),
        child: card,
      ),
    );
  }

  /// 发送到对话框
  Future<void> _sendToDialog(UserCollectModel model) async {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.chat.sendTo),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Avatar(imgUri: widget.peer['avatar'] ?? ''),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        widget.peer['title'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                model.info['payload']?['text'] as String? ??
                    t.common.messageContent,
                style: TextStyle(
                  color: CupertinoColors.label.resolveFrom(context),
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop(model);
            },
            child: Text(t.common.buttonSend),
          ),
        ],
      ),
    );
  }

  /// 显示删除确认底部弹窗
  void _showDeleteBottomSheet(
    BuildContext context,
    UserCollectModel obj,
    int index,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final currentState = ref.read(userCollectProvider);
        final notifier = ref.read(userCollectProvider.notifier);
        final isRemoving = currentState.removingIds.contains(
          obj.kindId.toString(),
        );

        return Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示器
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: AppRadius.borderRadiusTiny,
                ),
              ),
              const SizedBox(height: 24),
              // 删除图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.lightError.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderRadiusXLarge,
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 32,
                  color: AppColors.lightError,
                ),
              ),
              const SizedBox(height: 16),
              // 标题
              Text(
                t.common.sureDeleteData,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // 描述
              Text(
                t.common.deleteCollectConfirmDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              // 按钮区域
              Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadiusMedium,
                          ),
                        ),
                        child: Text(
                          t.common.buttonCancel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 确认删除按钮
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.lightError,
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                      child: TextButton(
                        onPressed: isRemoving
                            ? null
                            : () async {
                                try {
                                  bool res = await notifier.remove(obj);
                                  debugPrint(
                                    "user_collect_remove $res; i $index",
                                  );
                                  if (res) {
                                    final updatedItems = [
                                      ...currentState.items,
                                    ];
                                    updatedItems.removeAt(index);
                                    notifier.updateState(
                                      currentState.copyWith(
                                        items: updatedItems,
                                      ),
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      EasyLoading.showSuccess(
                                        t.common.tipSuccess,
                                      );
                                    }
                                  } else {
                                    EasyLoading.showError(t.common.tipFailed);
                                  }
                                } on Exception catch (e) {
                                  if (kDebugMode) {
                                    debugPrint(
                                      'Delete error: ${e.runtimeType}',
                                    );
                                  }
                                  EasyLoading.showError(t.common.tipFailed);
                                }
                              },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadiusMedium,
                          ),
                        ),
                        child: isRemoving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                t.common.buttonDelete,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              // 底部安全区域
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// 显示右键菜单
  void _showContextMenu(
    Offset globalPosition,
    UserCollectModel obj,
    int index,
  ) async {
    try {
      final result = showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          globalPosition.dx,
          globalPosition.dy,
          globalPosition.dx,
          globalPosition.dy,
        ),
        items: [
          PopupMenuItem(value: 'uncollect', child: Text(t.common.buttonDelete)),
          PopupMenuItem(
            value: 'pin_toggle',
            child: Text(
              _pinnedIds.contains(obj.kindId.toString())
                  ? t.chat.unpin
                  : t.chat.pin,
            ),
          ),
        ],
      );

      // 由于 showMenu 是异步的，需要等待结果
      result.then((selection) {
        if (selection == 'uncollect') {
          _confirmRemove(obj, index);
        } else if (selection == 'pin_toggle') {
          _togglePin(obj);
        }
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('context menu error: ${e.runtimeType}');
    }
  }

  /// 确认删除
  void _confirmRemove(UserCollectModel obj, int index) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.sureDeleteData),
        content: Text(t.common.deleteCollectConfirmDesc),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);

              try {
                final notifier = ref.read(userCollectProvider.notifier);
                final currentState = ref.read(userCollectProvider);

                bool res = await notifier.remove(obj);
                if (res && mounted) {
                  final updatedItems = [...currentState.items];
                  updatedItems.removeWhere((e) => e.kindId == obj.kindId);
                  notifier.updateState(
                    currentState.copyWith(items: updatedItems),
                  );
                  EasyLoading.showSuccess(t.common.tipSuccess);
                } else {
                  EasyLoading.showError(t.common.tipFailed);
                }
              } on Exception catch (e) {
                if (kDebugMode) {
                  debugPrint('confirmRemove error: ${e.runtimeType}');
                }
                EasyLoading.showError(t.common.tipFailed);
              }
            },
            child: Text(t.common.buttonDelete),
          ),
        ],
      ),
    );
  }

  /// 刷新数据（下拉刷新）
  Future<void> _onRefresh() async {
    try {
      // 检查网络状态
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        String msg = t.common.tipConnectDesc;
        EasyLoading.showInfo(' $msg        ');
        return;
      }

      final notifier = ref.read(userCollectProvider.notifier);
      final currentState = ref.read(userCollectProvider);

      var list = await notifier.page(
        page: 1,
        size: currentState.size * 200,
        kwd: currentState.kwd,
        onRefresh: true,
      );
      if (mounted) {
        notifier.updateState(currentState.copyWith(items: list, page: 2));
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('Refresh error: ${e.runtimeType}');
    }
  }

  /// 搜索
  Future<void> _search(String query) async {
    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);

    final list = await notifier.page(
      page: 1,
      size: currentState.size,
      kind: currentState.kind,
      kwd: query,
    );

    if (mounted) {
      notifier.updateState(
        currentState.copyWith(items: list, page: list.isNotEmpty ? 2 : 1),
      );
    }
  }

  /// 重置搜索
  Future<void> _resetSearch() async {
    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);

    final list = await notifier.page(
      page: 1,
      size: currentState.size,
      kind: currentState.kind,
      onRefresh: true,
    );

    if (mounted) {
      notifier.updateState(
        currentState.copyWith(items: list, page: 2, kwd: ''),
      );
      _searchController.clear();
    }
  }

  /// 按标签搜索
  Future<void> _searchByTag(
    BuildContext context,
    String tag,
    String kindTips,
  ) async {
    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);

    final list = await notifier.page(
      page: 1,
      size: currentState.size,
      tag: tag,
    );

    if (mounted) {
      notifier.updateState(
        currentState.copyWith(items: list, page: list.isNotEmpty ? 2 : 1),
      );
    }
  }

  /// 按分类搜索
  Future<void> _searchByKind(
    BuildContext context,
    String kind,
    String kindTips,
  ) async {
    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);

    final list = await notifier.page(
      page: 1,
      size: currentState.size,
      kind: kind,
    );

    if (mounted) {
      notifier.updateState(
        currentState.copyWith(
          items: list,
          kind: kind,
          page: list.isNotEmpty ? 2 : 1,
        ),
      );
    }
  }

  /// 构建顶部多选工具条
  Widget _buildMultiSelectBar(BuildContext context) {
    if (!_multiSelect) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Row(
        children: [
          Text(
            '${t.main.selected}: ${_selectedIds.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: t.common.selectAll,
            onPressed: _selectAllCurrent,
            icon: Icon(
              Icons.select_all,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            tooltip: t.contact.tags,
            onPressed: _batchTag,
            icon: const Icon(Icons.local_offer_outlined, color: Colors.orange),
          ),
          IconButton(
            tooltip: t.common.buttonDelete,
            onPressed: _batchDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
          IconButton(
            tooltip: t.common.buttonCancel,
            onPressed: _clearSelect,
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类筛选列表
  Widget _buildKindList(BuildContext context) {
    final currentState = ref.read(userCollectProvider);

    // 被收藏的资源种类映射
    Map<String, String> kindMap = {
      currentState.recentUse: t.main.recentlyUsed,
      '1': t.main.text,
      '2': t.chat.image,
      '7': t.common.personalCard,
      '4': t.chat.video,
      '5': t.chat.file,
      '6': t.common.locationMessage,
      '3': t.chat.voice,
      'all': t.common.all,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionPanelList(
          elevation: 0,
          dividerColor: Colors.transparent,
          materialGapSize: 0,
          expandedHeaderPadding: EdgeInsets.zero,
          expansionCallback: (panelIndex, isExpanded) {
            final notifier = ref.read(userCollectProvider.notifier);
            final currentState = ref.read(userCollectProvider);
            notifier.updateState(
              currentState.copyWith(kindActive: !currentState.kindActive),
            );
          },
          children: <ExpansionPanel>[
            ExpansionPanel(
              backgroundColor: Colors.transparent,
              headerBuilder: (context, isExpanded) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAlpha10,
                          borderRadius: AppRadius.borderRadiusSmall,
                        ),
                        child: Icon(
                          Icons.tune,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t.main.type,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 分类按钮区域
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 8,
                      children: kindMap.entries.map((entry) {
                        final isSelected = currentState.kind == entry.key;
                        return Material(
                          color: Colors.transparent,
                          child: GestureDetector(
                            onTap: () {
                              _searchByKind(context, entry.key, entry.value);
                              // 收起面板
                              final notifier = ref.read(
                                userCollectProvider.notifier,
                              );
                              final updatedState = ref.read(
                                userCollectProvider,
                              );
                              notifier.updateState(
                                updatedState.copyWith(kindActive: false),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: AppRadius.borderRadiusLarge,
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.2),
                                        width: 0.5,
                                      ),
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // 标签区域
                  if (currentState.tagItems.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8,
                        left: 16,
                        bottom: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderRadiusSmall,
                            ),
                            child: Icon(
                              Icons.sell_outlined,
                              size: 16,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.contact.tags,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 6,
                        runSpacing: 6,
                        children: currentState.tagItems,
                      ),
                    ),
                  ],
                ],
              ),
              isExpanded: currentState.kindActive,
              canTapOnHeader: true,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentState = ref.watch(userCollectProvider);

    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        leading: widget.isSelect
            ? GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: const Icon(Icons.close),
              )
            : null,
        titleWidget: Text(
          widget.isSelect ? t.main.favorites : t.main.myFavorites,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loadError) _buildLoadErrorPanel(context),

              // 搜索栏
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: searchBar(
                  context,
                  leading: GestureDetector(
                    onTap: () async {
                      final q = _searchController.text.trim();
                      if (q.isNotEmpty) {
                        await _search(q);
                      } else {
                        await _resetSearch();
                      }
                    },
                    child: Icon(
                      Icons.search,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  controller: _searchController,
                  searchLabel: t.common.search,
                  hintText: t.common.search,
                  queryTips: t.contact.favoriteGroupTagsEtc,
                  onChanged: (query) {
                    // 防抖搜索
                    if (_searchTimer != null) {
                      _searchTimer!.cancel();
                    }
                    _searchTimer = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        final q = query.trim();
                        if (q.isNotEmpty) {
                          await _search(q);
                        } else {
                          await _resetSearch();
                        }
                      },
                    );
                  },
                  doSearch: (query) async {
                    final q = query.toString().trim();
                    if (q.isNotEmpty) {
                      await _search(q);
                    } else {
                      await _resetSearch();
                    }
                    return <dynamic>[];
                  },
                ),
              ),

              // 分类列表
              _buildKindList(context),

              // 多选工具条
              _buildMultiSelectBar(context),

              // 收藏列表
              Expanded(
                child: SlidableAutoCloseBehavior(
                  child: currentState.items.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: AppRadius.borderRadiusXLarge,
                                ),
                                child: Icon(
                                  Icons.bookmark_border,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.common.noData,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                t.common.noFavoritesYet,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: controller,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: currentState.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            final obj = currentState.items[index];
                            return _buildCollectItem(
                              context,
                              obj as UserCollectModel,
                              index,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
