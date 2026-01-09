import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'package:imboy/page/user_tag/user_tag_relation/tag_relation_view.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_collect_detail_view.dart';
import 'user_collect_logic.dart';

class UserCollectPage extends StatefulWidget {
  final bool isSelect;
  final Map<String, String> peer;

  const UserCollectPage({
    super.key,
    this.peer = const {},
    this.isSelect = false,
  });

  @override
  State<UserCollectPage> createState() => _UserCollectPageState();
}

class _UserCollectPageState extends State<UserCollectPage> {
  final logic = Get.put(UserCollectLogic());
  late final state = logic.state;
  final ScrollController controller = ScrollController();

  bool _loadError = false;

  bool _isInitialized = false;

  /// 最近一次次要点击（右键/触控板次要点击）的位置，用于 onSecondaryTap 展示上下文菜单
  Offset? _lastSecondaryTapPosition;

  // 置顶集合（前端内存置顶，后续可接入后端持久化）
  final Set<String> _pinnedIds = {};
  static const String _kPinnedPrefsKey = 'user_collect_pinned_ids';

  // 多选模式与已选集合
  bool _multiSelect = false;
  final Set<String> _selectedIds = {};

  // 搜索防抖
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
      _loadPinnedIds();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  /// 初始化数据
  /// 加载首屏数据、标签数据
  Future<void> _initData() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 重置加载错误状态
    _loadError = false;

    state.page = 1;
    String? kind = widget.isSelect ? state.recentUse : state.kind;

    try {
      // 标记为加载中，避免重复触发
      state.isLoading.value = true;

      var list = await logic.page(
        page: state.page,
        size: state.size,
        kind: kind,
      );
      
      debugPrint('_initData loaded ${list.length} items');
      
      // 使用 WidgetsBinding.instance.addPostFrameCallback 确保在下一帧更新状态
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // 确保数据更新到状态中
          state.items.assignAll(list);
          if (list.isNotEmpty) {
            state.page += 1;
          }

          // 更新 hasMore：如果返回数量小于 size，则没有更多
          state.hasMore.value = list.length >= state.size;

          // 成功加载，清除错误状态
          _loadError = false;
        }
      });

      // 加载标签数据
      state.tagItems.value = await logic.tagItems();

    } catch (e, s) {
      debugPrint('user_collect_view_initData error: $e, $s');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadError = true;
        });
      }
    } finally {
      // 无论成功或失败都清理加载标志
      state.isLoading.value = false;
    }
  }

  /// 设置滚动监听
  /// 滑动触底加载更多
  void _setupScrollListener() {
    controller.addListener(() async {
      if (!controller.hasClients) return;

      // 如果已经在加载中或没有更多，直接忽略触发
      if (state.isLoading.value || !state.hasMore.value) return;

      double pixels = controller.position.pixels;
      double maxScrollExtent = controller.position.maxScrollExtent;

      // 滑动到底部，执行加载更多操作
      if (pixels >= maxScrollExtent - 100) {
        try {
          // 标记加载中，避免并发
          state.isLoading.value = true;

          var list = await logic.page(
            page: state.page,
            size: state.size,
            kind: state.kind,
          );

          if (list.isNotEmpty) {
            if (!mounted) return;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              // 去重添加：以 kindId 为唯一标识
              final existingIds = state.items.map((e) => (e as dynamic).kindId).toSet();
              final filtered = list.where((e) => !existingIds.contains((e as dynamic).kindId)).toList();

              if (filtered.isNotEmpty) {
                state.items.addAll(filtered);
                // 仅当成功添加新数据时才递增页码
                state.page = state.page + 1;
              }

              // 更新 hasMore：若返回数量小于 page size 说明无更多
              state.hasMore.value = list.length >= state.size;
            });
          } else {
            // 没有获取到更多数据
            state.hasMore.value = false;
          }
        } catch (e) {
          debugPrint('Load more error: $e');
        } finally {
          state.isLoading.value = false;
        }
      }
    });
  }

  /// 持久化：加载置顶集合
  Future<void> _loadPinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList(_kPinnedPrefsKey) ?? <String>[];
      if (!mounted) return;
      setState(() {
        _pinnedIds
          ..clear()
          ..addAll(list);
      });
    } catch (e) {
      debugPrint('Load pinned ids error: $e');
    }
  }

  /// 持久化：保存置顶集合
  Future<void> _savePinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPinnedPrefsKey, _pinnedIds.toList());
    } catch (e) {
      debugPrint('Save pinned ids error: $e');
    }
  }

  /// 构建标签列表组件
  /// 支持点击标签直接筛选
  Widget buildItemTag(String tagStr, BuildContext context) {
    List<Widget> items = [];
    List<String> tagList = tagStr.split(',').where((o) => o.trim().isNotEmpty).toList();

    for (String tag in tagList) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 6),
          child: GestureDetector(
            onTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                logic.searchByTag(tag, tag, () {
                  if (mounted) {
                    setState(() {
                      state.kindActive.value = !state.kindActive.value;
                    });
                  }
                });
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGreenAlpha10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGreenAlpha30,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_offer,
                    size: 12,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tag,
                    style: TextStyle(
                      color: AppColors.primaryGreen,
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
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: items,
    );
  }

  /// 发送到对话框
  /// 选择转发对象后，确认发送收藏内容
  Future<void> sendToDialog(UserCollectModel model) async {
    Get.defaultDialog(
      title: 'sendTo'.tr,
      backgroundColor: Theme.of(context).colorScheme.surface,
      radius: 6,
      cancel: TextButton(
        onPressed: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.back();
          });
        },
        child: Text(
          'buttonCancel'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      confirm: TextButton(
        onPressed: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.back();
            Navigator.of(context).pop(model);
          });
        },
        child: Text(
          'buttonSend'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primaryGreen,
          ),
        ),
      ),
      content: SizedBox(
        height: 200,
        child: Column(
          children: [
            Row(
              children: [
                Avatar(imgUri: widget.peer['avatar'] ?? '', onTap: () {}),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      widget.peer['title'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: Center(
                child: Text(
                  model.info['payload']?['text'] ?? 'messageContent'.tr,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 置顶/取消置顶
  /// 前端内存实现，不影响数据结构
  void _togglePin(UserCollectModel obj) {
    setState(() {
      if (_pinnedIds.contains(obj.kindId)) {
        _pinnedIds.remove(obj.kindId);
      } else {
        _pinnedIds.add(obj.kindId);
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
        ..add(obj.kindId);
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
      if (_selectedIds.contains(obj.kindId)) {
        _selectedIds.remove(obj.kindId);
        if (_selectedIds.isEmpty) {
          _multiSelect = false;
        }
      } else {
        _selectedIds.add(obj.kindId);
      }
    });
  }

  /// 全选当前已加载的项
  void _selectAllCurrent() {
    setState(() {
      for (final o in state.items) {
        _selectedIds.add(o.kindId);
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
    
    // 检查是否有正在删除的项
    final hasRemoving = ids.any((id) => logic.removingIds.contains(id));
    if (hasRemoving) {
      EasyLoading.showInfo('正在删除中，请稍候...');
      return;
    }
    
    try {
      EasyLoading.show(status: 'loading'.tr);
      int successCount = 0;
      int failCount = 0;
      
      // 逐个删除，失败不阻断
      for (int i = state.items.length - 1; i >= 0; i--) {
        final obj = state.items[i];
        if (ids.contains(obj.kindId)) {
          try {
            final ok = await logic.remove(obj);
            if (ok) {
              state.items.removeAt(i);
              successCount++;
            } else {
              failCount++;
            }
          } catch (_) {
            failCount++;
          }
        }
      }
      
      EasyLoading.dismiss();
      if (failCount == 0) {
        EasyLoading.showSuccess('删除成功');
      } else if (successCount > 0) {
        EasyLoading.showInfo('部分删除成功：$successCount 成功，$failCount 失败');
      } else {
        EasyLoading.showError('删除失败');
      }
      _exitMultiSelect();
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('tipFailed'.tr);
    }
  }

  /// 批量加标签：输入一个或多个标签，附加到每个选中项
  Future<void> _batchTag() async {
    if (_selectedIds.isEmpty) return;
    final TextEditingController tc = TextEditingController();
    Get.defaultDialog(
      title: 'editTag'.tr,
      backgroundColor: Theme.of(context).colorScheme.surface,
      radius: 6,
      content: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: tc,
          decoration: InputDecoration(
            hintText: 'favoriteGroupTagsEtc'.tr,
            border: const OutlineInputBorder(),
          ),
          minLines: 1,
          maxLines: 3,
        ),
      ),
      confirm: TextButton(
        onPressed: () async {
          final input = tc.text.trim();
          if (input.isEmpty) {
            EasyLoading.showInfo('请输入标签');
            return;
          }
          Get.back();
          try {
            EasyLoading.show(status: 'loading'.tr);
            final Set<String> ids = {..._selectedIds};
            for (final obj in state.items) {
              if (!ids.contains(obj.kindId)) continue;
              String newTag = obj.tag.isEmpty ? input : '${obj.tag},$input';
              // 清理重复标签
              final parts = newTag.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
              obj.tag = parts.join(',');
              try {
                logic.updateItem(obj);
              } catch (_) {}
            }
            EasyLoading.dismiss();
            EasyLoading.showSuccess('tipSuccess'.tr);
            setState(() {});
            _exitMultiSelect();
          } catch (e) {
            EasyLoading.dismiss();
            EasyLoading.showError('tipFailed'.tr);
          }
        },
        child: Text(
          'buttonConfirm'.tr,
          style: TextStyle(color: AppColors.primaryGreen),
        ),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: Text(
          'buttonCancel'.tr,
        ),
      ),
    );
  }

  /// 生成分组key：今天/昨天/更早
  String _groupKeyFor(UserCollectModel obj) {
    final int ts = (state.kind == state.recentUse && obj.updatedAt > 0) ? obj.updatedAt : obj.createdAt;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond());
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(thatDay).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return 'earlier';
  }

  /// 分组标题文本
  String _groupTitle(String key) {
    if (key == 'today') return 'today'.tr;
    if (key == 'yesterday') return 'yesterday'.tr;
    return 'earlier'.tr;
  }

  /// 构建分组后的列表条目（含置顶优先、时间倒序）
  List<_ListEntry> _buildGroupedEntries() {
    final List<UserCollectModel> list = List<UserCollectModel>.from(state.items);

    // 时间字段：最近使用用 updatedAt，否则 createdAt；倒序
    int ts(UserCollectModel o) => (state.kind == state.recentUse && o.updatedAt > 0) ? o.updatedAt : o.createdAt;

    // 置顶优先
    list.sort((a, b) {
      final pa = _pinnedIds.contains(a.kindId);
      final pb = _pinnedIds.contains(b.kindId);
      if (pa != pb) return pa ? -1 : 1;
      return ts(b).compareTo(ts(a));
    });

    final Map<String, List<UserCollectModel>> groups = {
      'today': [],
      'yesterday': [],
      'earlier': [],
    };
    for (final o in list) {
      groups[_groupKeyFor(o)]!.add(o);
    }

    final entries = <_ListEntry>[];
    for (final key in ['today', 'yesterday', 'earlier']) {
      final g = groups[key]!;
      if (g.isEmpty) continue;
      entries.add(_ListEntry.header(_groupTitle(key)));
      entries.addAll(g.map((e) => _ListEntry.item(e)));
    }
    return entries;
  }

  /// 构建列表分组头部组件
  Widget _buildGroupHeader(BuildContext context, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
        ),
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
              'loadError'.tr,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _initData();
              });
            },
            child: Text('buttonRetry'.tr),
          ),
        ],
      ),
    );
  }

  /// 构建收藏项组件 - 支持长按进入多选、左置顶右删除/标签
  Widget _buildCollectItem(
      BuildContext context,
      UserCollectModel obj,
      int index,
      ) {
    final bool isPinned = _pinnedIds.contains(obj.kindId);
    final bool isSelected = _selectedIds.contains(obj.kindId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: isDark 
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                width: 0.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onLongPress: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _enterMultiSelect(obj);
            });
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
                await sendToDialog(obj);
              } else {
                // 进入收藏详情页面
                debugPrint('Navigating to detail page for ${obj.kindId}');
                Get.to(
                  () => UserCollectDetailPage(obj: obj, pageIndex: index),
                  transition: Transition.rightToLeft,
                  popGesture: true,
                );
              }
            } catch (e) {
              debugPrint('Tap error: $e');
            }
          },
          // macOS 右键 / 触控板 次要点击：显示上下文菜单（取消收藏/置顶）
          onSecondaryTapDown: (details) {
            // 先记录位置，由 onSecondaryTap 统一触发菜单，避免在设备更新阶段调用菜单导致断言
            _lastSecondaryTapPosition = details.globalPosition;
          },
          onSecondaryTap: () {
            try {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_lastSecondaryTapPosition != null) {
                  _showContextMenu(_lastSecondaryTapPosition!, obj, index);
                }
              });
            } catch (e) {
              debugPrint('showContextMenu error: $e');
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
                          Icon(Icons.push_pin, size: 14, color: AppColors.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            'pinned'.tr,
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // 消息内容
                    logic.buildItemBody(obj, 'page'),
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
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.kind == state.recentUse && obj.updatedAt > 0
                                ? DateTimeHelper.lastTimeFmt(obj.updatedAt)
                                : DateTimeHelper.lastTimeFmt(obj.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _toggleSelect(obj);
                          });
                        },
                        activeColor: AppColors.primaryGreen,
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _togglePin(obj);
                });
              },
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              icon: isPinned ? Icons.vertical_align_bottom : Icons.vertical_align_top,
              label: isPinned ? 'unpin'.tr : 'pin'.tr,
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
              onPressed: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    final result = await Get.to(
                          () => TagRelationPage(
                        peerId: obj.kindId,
                        peerTag: obj.tag,
                        scene: 'collect',
                        title: 'editTag'.tr,
                      ),
                      transition: Transition.rightToLeft,
                      popGesture: true,
                    );
                    if (result != null && result is String && mounted) {
                      obj.tag = result.toString();
                      logic.updateItem(obj);
                      setState(() {});
                    }
                  } catch (e) {
                    debugPrint('Edit tag error: $e');
                  }
                });
              },
              icon: Icons.local_offer_outlined,
              foregroundColor: Colors.white,
              label: 'tags'.tr,
            ),
            // 删除按钮
            SlidableAction(
              backgroundColor: AppColors.lightError,
              onPressed: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showDeleteBottomSheet(context, obj, index);
                });
              },
              icon: Icons.delete_outline,
              foregroundColor: Colors.white,
              label: 'buttonDelete'.tr,
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

  /// 显示删除确认底部弹窗
  void _showDeleteBottomSheet(
      BuildContext context,
      UserCollectModel obj,
      int index,
      ) {
    Get.bottomSheet(
      Container(
        width: Get.width,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部指示器
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // 删除图标
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.lightError.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
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
              'sureDeleteData'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            // 描述
            Text(
              'deleteCollectConfirmDesc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Get.closeAllBottomSheets();
                        });
                      },
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'buttonCancel'.tr,
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Obx(() {
                      final isRemoving = logic.removingIds.contains(obj.kindId);
                      return TextButton(
                        onPressed: isRemoving ? null : () async {
                          try {
                            bool res = await logic.remove(obj);
                            debugPrint("user_collect_remove $res; i $index");
                            if (res && mounted) {
                              state.items.removeAt(index);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Get.closeAllBottomSheets();
                              });
                              EasyLoading.showSuccess('tipSuccess'.tr);
                            } else {
                              EasyLoading.showError('tipFailed'.tr);
                            }
                          } catch (e) {
                            debugPrint('Delete error: $e');
                            EasyLoading.showError('tipFailed'.tr);
                          }
                        },
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isRemoving 
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'buttonDelete'.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      );
                    }),
                  ),
                ),
              ],
            ),
            // 底部安全区域
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      isScrollControlled: true,
    );
  }

  /// 在指定全局位置显示右键菜单（macOS / 右键）
  /// 参数：globalPosition - 点击位置（全局坐标）
  ///       obj - 当前收藏项
  ///       index - 当前项索引
  void _showContextMenu(Offset globalPosition, UserCollectModel obj, int index) async {
    try {
      final selection = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          globalPosition.dx,
          globalPosition.dy,
          globalPosition.dx,
          globalPosition.dy,
        ),
        items: [
          PopupMenuItem(
            value: 'uncollect',
            child: Text('buttonDelete'.tr),
          ),
          PopupMenuItem(
            value: 'pin_toggle',
            child: Text(_pinnedIds.contains(obj.kindId) ? 'unpin'.tr : 'pin'.tr),
          ),
        ],
      );

      if (selection == 'uncollect') {
        _confirmRemove(obj, index);
      } else if (selection == 'pin_toggle') {
        // 切换置顶状态
        _togglePin(obj);
      }
    } catch (e) {
      debugPrint('context menu error: $e');
    }
  }

  /// 右键/菜单确认删除操作（复用现有删除逻辑）
  void _confirmRemove(UserCollectModel obj, int index) {
    Get.defaultDialog(
      title: 'sureDeleteData'.tr,
      middleText: 'deleteCollectConfirmDesc'.tr,
      textConfirm: 'buttonDelete'.tr,
      textCancel: 'buttonCancel'.tr,
      confirmTextColor: Colors.white,
      onConfirm: () async {
        // 关闭对话框
        Get.back();

        try {
          bool res = await logic.remove(obj);
          if (res && mounted) {
            // 从列表中移除
            state.items.removeWhere((e) => (e as dynamic).kindId == obj.kindId);
            EasyLoading.showSuccess('tipSuccess'.tr);
          } else {
            EasyLoading.showError('tipFailed'.tr);
          }
        } catch (e) {
          debugPrint('confirmRemove error: $e');
          EasyLoading.showError('tipFailed'.tr);
        }
      },
    );
  }

  /// 构建分类筛选列表
  Widget _buildKindList(BuildContext context) {
    // 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
    Map<String, String> kindMap = {
      state.recentUse: 'recentlyUsed'.tr,
      '1': 'text'.tr,
      '2': 'image'.tr,
      '7': 'personalCard'.tr,
      '4': 'video'.tr,
      '5': 'file'.tr,
      '6': 'locationMessage'.tr,
      '3': 'voice'.tr,
      'all': 'all'.tr,
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDark 
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: 0.5,
              )
            : null,
        boxShadow: isDark ? [] : [
           BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateSB) {
          return Obx(
                () => ExpansionPanelList(
              elevation: 0,
              dividerColor: Colors.transparent,
              materialGapSize: 0,
              expansionCallback: (panelIndex, isExpanded) {
                setStateSB(() {
                  state.kindActive.value = !state.kindActive.value;
                });
              },
              children: <ExpansionPanel>[
                ExpansionPanel(
                  backgroundColor: Colors.transparent,
                  headerBuilder: (context, isExpanded) {
                    if (isExpanded) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreenAlpha10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.tune,
                                size: 18,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'type'.tr,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return _buildQuickFilterRow(context);
                    }
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
                            final isSelected = state.kind == entry.key;
                            return Material(
                              color: Colors.transparent,
                              child: GestureDetector(
                                onTap: () {
                                  setStateSB(() {
                                    state.kindActive.value = false;
                                  });
                                  logic.searchByKind(entry.key, entry.value, () {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(20),
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.onSurface,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // 标签区域
                      if (state.tagItems.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 16, bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.sell_outlined,
                                  size: 16,
                                  color: AppColors.info,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'tags'.tr,
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
                            children: state.tagItems.value,
                          ),
                        ),
                      ],
                    ],
                  ),
                  isExpanded: state.kindActive.value,
                  canTapOnHeader: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建快速筛选行（折叠状态下显示）
  Widget _buildQuickFilterRow(BuildContext context) {
    // 被收藏的资源种类映射
    Map<String, String> kindMap = {
      state.recentUse: 'recentlyUsed'.tr,
      '1': 'text'.tr,
      '2': 'image'.tr,
      '7': 'personalCard'.tr,
      '4': 'video'.tr,
      '5': 'file'.tr,
      '6': 'locationMessage'.tr,
      '3': 'voice'.tr,
      'all': 'all'.tr,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreenAlpha10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.filter_list,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: kindMap.entries.take(6).map((entry) {
                  final isSelected = state.kind == entry.key;
                  return _buildQuickFilterItem(
                    context, 
                    entry.value, 
                    isSelected,
                    () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        logic.searchByKind(entry.key, entry.value, () {});
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建快速筛选项
  Widget _buildQuickFilterItem(
      BuildContext context,
      String text,
      bool isSelected,
      VoidCallback onTap,
      ) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primaryGreen
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primaryGreen
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 刷新数据（下拉刷新）
  Future<void> _onRefresh() async {
    try {
      // 检查网络状态
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        String msg = 'tipConnectDesc'.tr;
        EasyLoading.showInfo(' $msg        ');
        return;
      }

      state.page = 1;
      var list = await logic.page(
        page: state.page,
        size: state.size * 200,
        kwd: state.kwd.value,
        onRefresh: true,
      );
      if (mounted) {
        state.items.assignAll(list);
        state.page += 1;
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  /// 重置搜索：清空关键词并恢复列表
  Future<void> _resetSearch() async {
    try {
      state.kwd.value = '';
      state.page = 1;
      final list = await logic.page(
        page: state.page,
        size: state.size,
        kind: state.kind,
        onRefresh: true,
      );
      if (mounted) {
        state.items.assignAll(list);
        state.page += 1;
      }
    } catch (e) {
      debugPrint('Reset search error: $e');
    }
  }

  /// 构建顶部多选工具条
  Widget _buildMultiSelectBar(BuildContext context) {
    if (!_multiSelect) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isDark 
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: 0.5,
              )
            : null,
        boxShadow: isDark ? [] : [
           BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${'selected'.tr}: ${_selectedIds.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'selectAll'.tr,
            onPressed: _selectAllCurrent,
            icon: Icon(Icons.select_all, color: Theme.of(context).colorScheme.onSurface),
          ),
          IconButton(
            tooltip: 'tags'.tr,
            onPressed: _batchTag,
            icon: const Icon(Icons.local_offer_outlined, color: Colors.orange),
          ),
          IconButton(
            tooltip: 'buttonDelete'.tr,
            onPressed: _batchDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
          IconButton(
            tooltip: 'buttonCancel'.tr,
            onPressed: _clearSelect,
            icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        leading: widget.isSelect
            ? GestureDetector(
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop();
            });
          },
          child: const Icon(Icons.close),
        )
            : null,
        title: widget.isSelect ? 'favorites'.tr : 'myFavorites'.tr,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SizedBox(
          width: Get.width,
          height: Get.height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loadError) _buildLoadErrorPanel(context),
              // 搜索栏
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Obx(
                      () => searchBar(
                    context,
                    leading: state.searchLeading?.value ??
                        GestureDetector(
                          onTap: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) async {
                              final q = state.kwd.value.trim();
                              if (q.isNotEmpty) {
                                await logic.doSearch(q);
                              } else {
                                await _resetSearch();
                              }
                            });
                          },
                          child: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                    trailing: state.searchTrailing?.value,
                    controller: state.searchController,
                    searchLabel: 'search'.tr,
                    hintText: 'search'.tr,
                    queryTips: 'favoriteGroupTagsEtc'.tr,
                    onChanged: (query) {
                      // 实时更新搜索关键词
                      state.kwd.value = query;

                      // 防抖搜索：延迟500ms执行搜索，避免频繁搜索
                      if (_searchTimer != null) {
                        _searchTimer!.cancel();
                      }
                      _searchTimer = Timer(const Duration(milliseconds: 500), () async {
                        final q = query.trim();
                        if (q.isNotEmpty) {
                          await logic.doSearch(q);
                        } else {
                          await _resetSearch();
                        }
                      });
                    },
                    doSearch: (query) async {
                      final q = query.toString().trim();
                      if (q.isNotEmpty) {
                        await logic.doSearch(q);
                      } else {
                        await _resetSearch();
                      }
                      return <dynamic>[];
                    },
                  ),
                ),
              ),

              // 分类列表
              _buildKindList(context),

              // 多选工具条
              _buildMultiSelectBar(context),

              // 收藏列表（分组 + 置顶优先）
              Expanded(
                child: SlidableAutoCloseBehavior(
                  child: Obx(
                        () {
                      if (state.items.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: Icon(
                                  Icons.bookmark_border,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'noData'.tr,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '暂无收藏内容，快去收藏一些有趣的消息吧',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      final entries = _buildGroupedEntries();
                      // 支持列表尾部加载指示
                      final showFooter = state.hasMore.value && entries.isNotEmpty;
                      final itemCount = entries.length + (showFooter ? 1 : 0);

                      return ListView.builder(
                        controller: controller,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: itemCount,
                        itemBuilder: (BuildContext context, int index) {
                          // 底部加载指示
                          if (showFooter && index == entries.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Obx(() {
                                  if (state.isLoading.value) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppColors.primaryGreen,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '加载中...',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Text(
                                      '上拉加载更多',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                      ),
                                    );
                                  }
                                }),
                              ),
                            );
                          }

                          final entry = entries[index];
                          if (entry.isHeader) {
                            return _buildGroupHeader(context, entry.header!);
                          } else {
                            final obj = entry.item!;
                            // 注意：用于打开详情时传入的 index，这里用 state.items 的索引更准确
                            final realIndex = state.items.indexWhere((e) => e.kindId == obj.kindId);
                            return _buildCollectItem(context, obj, realIndex < 0 ? index : realIndex);
                          }
                        },
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

/// 列表条目类型：分组头或数据项
class _ListEntry {
  final String? header;
  final UserCollectModel? item;

  _ListEntry._(this.header, this.item);

  /// 构建分组头条目
  factory _ListEntry.header(String title) => _ListEntry._(title, null);

  /// 构建数据条目
  factory _ListEntry.item(UserCollectModel model) => _ListEntry._(null, model);

  /// 是否为分组头
  bool get isHeader => header != null;
}
