import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_relation_page.dart'
    show TagRelationPage;
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_collect_detail_page.dart';
import 'user_collect_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

/// UserCollect 页面 - 像素级对齐 iOS 17 Premium 风格
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
  final Set<String> _pinnedIds = {};
  static const String _kPinnedPrefsKey = 'user_collect_pinned_ids';
  bool _multiSelect = false;
  final Set<String> _selectedIds = {};
  Timer? _searchTimer;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) setState(() {});
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

  Future<void> _initData() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _loadError = false;
    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);
    String? kind = widget.isSelect ? currentState.recentUse : currentState.kind;

    try {
      final list = await notifier.page(
        page: 1,
        size: currentState.size,
        kind: kind,
      );
      if (mounted) {
        notifier.updateState(
          currentState.copyWith(
            items: list,
            page: list.isNotEmpty ? 2 : 1,
            hasMore: list.length >= currentState.size,
          ),
        );
      }
      if (!mounted) return;
      final tagItems = await notifier.tagItems(context);
      if (mounted) {
        final updatedState = ref.read(userCollectProvider);
        notifier.updateState(updatedState.copyWith(tagItems: tagItems));
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = true);
    }
  }

  void _setupScrollListener() {
    controller.addListener(() async {
      if (!controller.hasClients) return;
      final currentState = ref.read(userCollectProvider);
      if (currentState.isLoading || !currentState.hasMore) return;
      if (controller.position.pixels >=
          controller.position.maxScrollExtent - 100) {
        try {
          final notifier = ref.read(userCollectProvider.notifier);
          final list = await notifier.page(
            page: currentState.page,
            size: currentState.size,
            kind: currentState.kind,
          );
          if (list.isNotEmpty && mounted) {
            final existingIds = currentState.items.map((e) => e.kindId).toSet();
            final filtered = list
                .where((e) => !existingIds.contains(e.kindId))
                .toList();
            if (filtered.isNotEmpty) {
              notifier.updateState(
                currentState.copyWith(
                  items: [...currentState.items, ...filtered],
                  page: currentState.page + 1,
                  hasMore: list.length >= currentState.size,
                ),
              );
            } else {
              notifier.updateState(currentState.copyWith(hasMore: false));
            }
          } else {
            notifier.updateState(currentState.copyWith(hasMore: false));
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _loadPinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPinnedPrefsKey) ?? <String>[];
      if (mounted) {
        setState(
          () => _pinnedIds
            ..clear()
            ..addAll(list),
        );
      }
    } catch (_) {}
  }

  Future<void> _savePinnedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPinnedPrefsKey, _pinnedIds.toList());
    } catch (_) {}
  }

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
            onTap: () => _searchByTag(context, tag, tag),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getIosBlue(
                  Theme.of(context).brightness,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.getIosBlue(
                    Theme.of(context).brightness,
                  ).withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_offer,
                    size: 10,
                    color: AppColors.getIosBlue(Theme.of(context).brightness),
                  ),
                  AppSpacing.horizontalTiny,
                  Text(
                    tag,
                    style: context.textStyle(
                      FontSizeType.caption2,
                      color: AppColors.getIosBlue(Theme.of(context).brightness),
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

  void _togglePin(UserCollectModel obj) {
    setState(() {
      final id = obj.kindId.toString();
      if (_pinnedIds.contains(id)) {
        _pinnedIds.remove(id);
      } else {
        _pinnedIds.add(id);
      }
    });
    _savePinnedIds();
  }

  void _enterMultiSelect(UserCollectModel obj) {
    setState(() {
      _multiSelect = true;
      _selectedIds
        ..clear()
        ..add(obj.kindId.toString());
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelect = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(UserCollectModel obj) {
    setState(() {
      final id = obj.kindId.toString();
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _multiSelect = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllCurrent() {
    final currentState = ref.read(userCollectProvider);
    setState(() {
      for (final o in currentState.items) {
        _selectedIds.add(o.kindId.toString());
      }
      _multiSelect = true;
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final currentState = ref.read(userCollectProvider);
    final notifier = ref.read(userCollectProvider.notifier);
    if (ids.any((id) => currentState.removingIds.contains(id))) {
      EasyLoading.showInfo(t.main.deletingInProgressPleaseWait);
      return;
    }
    try {
      EasyLoading.show(status: t.common.loading);
      int successCount = 0;
      int failCount = 0;
      final updatedItems = <UserCollectModel>[];
      for (int i = currentState.items.length - 1; i >= 0; i--) {
        final obj = currentState.items[i];
        if (ids.contains(obj.kindId.toString())) {
          try {
            if (await notifier.remove(obj)) {
              successCount++;
            } else {
              updatedItems.add(obj);
              failCount++;
            }
          } catch (_) {
            updatedItems.add(obj);
            failCount++;
          }
        } else {
          updatedItems.add(obj);
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
      notifier.updateState(
        currentState.copyWith(items: updatedItems.reversed.toList()),
      );
      _exitMultiSelect();
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError(t.common.tipFailed);
    }
  }

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
            isDefaultAction: true,
            onPressed: () async {
              final input = tc.text.trim();
              if (input.isEmpty) {
                EasyLoading.showInfo(t.contact.pleaseEnterTags);
                return;
              }
              Navigator.pop(context);
              try {
                EasyLoading.show(status: t.common.loading);
                final updatedItems = <UserCollectModel>[];
                for (final obj in currentState.items) {
                  if (!_selectedIds.contains(obj.kindId.toString())) {
                    updatedItems.add(obj);
                    continue;
                  }
                  String newTag = obj.tag.isEmpty ? input : '${obj.tag},$input';
                  final parts = newTag
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toSet()
                      .toList();
                  updatedItems.add(
                    UserCollectModel(
                      userId: obj.userId,
                      kind: obj.kind,
                      kindId: obj.kindId,
                      source: obj.source,
                      remark: obj.remark,
                      tag: parts.join(','),
                      updatedAt: obj.updatedAt,
                      createdAt: obj.createdAt,
                      info: obj.info,
                    ),
                  );
                }
                notifier.updateState(
                  currentState.copyWith(items: updatedItems),
                );
                EasyLoading.dismiss();
                EasyLoading.showSuccess(t.common.tipSuccess);
                _exitMultiSelect();
              } catch (_) {
                EasyLoading.dismiss();
                EasyLoading.showError(t.common.tipFailed);
              }
            },
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadErrorPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.allMedium,
      color: AppColors.getIosRed(
        Theme.of(context).brightness,
      ).withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.iosRed),
          AppSpacing.horizontalSmall,
          Expanded(child: Text(t.common.loadError)),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Text(t.common.buttonRetry),
            onPressed: () {
              _isInitialized = false;
              _initData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollectItem(
    BuildContext context,
    UserCollectModel obj,
    int index,
  ) {
    final notifier = ref.read(userCollectProvider.notifier);
    final currentState = ref.read(userCollectProvider);
    final bool isPinned = _pinnedIds.contains(obj.kindId.toString());
    final bool isSelected = _selectedIds.contains(obj.kindId.toString());
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final card = Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusCell,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusCell,
          onLongPress: () => _enterMultiSelect(obj),
          onTap: () async {
            if (_multiSelect) {
              _toggleSelect(obj);
              return;
            }
            if (widget.isSelect) {
              _sendToDialog(obj);
            } else {
              Navigator.push(
                context,
                CupertinoPageRoute<void>(
                  builder: (context) =>
                      UserCollectDetailPage(obj: obj, pageIndex: index),
                ),
              );
            }
          },
          child: Padding(
            padding: AppSpacing.allRegular,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPinned) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.pin_fill,
                        size: 12,
                        color: AppColors.getIosBlue(brightness),
                      ),
                      AppSpacing.horizontalTiny,
                      Text(
                        t.chat.pinned,
                        style: context.textStyle(
                          FontSizeType.caption2,
                          color: AppColors.getIosBlue(brightness),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalSmall,
                ],
                notifier.buildItemBody(context, obj, 'page'),
                AppSpacing.verticalMedium,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        obj.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.small,
                          color: AppColors.iosGray,
                        ),
                      ),
                    ),
                    Text(
                      currentState.kind == currentState.recentUse &&
                              obj.updatedAt > 0
                          ? DateTimeHelper.lastTimeFmt(obj.updatedAt)
                          : DateTimeHelper.lastTimeFmt(obj.createdAt),
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
                if (obj.tag.isNotEmpty) ...[
                  AppSpacing.verticalSmall,
                  buildItemTag(obj.tag, context),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Slidable(
        key: ValueKey('${obj.kindId}_$index'),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => _togglePin(obj),
              backgroundColor: AppColors.getIosBlue(brightness),
              foregroundColor: AppColors.onPrimary,
              icon: isPinned
                  ? CupertinoIcons.pin_slash_fill
                  : CupertinoIcons.pin_fill,
              label: isPinned ? t.chat.unpin : t.chat.pin,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.45,
          children: [
            SlidableAction(
              backgroundColor: AppColors.iosGray,
              onPressed: (_) async {
                final result = await Navigator.push(
                  context,
                  CupertinoPageRoute<String?>(
                    builder: (context) => TagRelationPage(
                      peerId: obj.kindId.toString(),
                      peerTag: obj.tag,
                      scene: 'collect',
                      title: t.common.editTag,
                    ),
                  ),
                );
                if (result != null && mounted) {
                  final updatedItems = currentState.items.map((item) {
                    if (item.kindId == obj.kindId) {
                      return UserCollectModel(
                        userId: item.userId,
                        kind: item.kind,
                        kindId: item.kindId,
                        source: item.source,
                        remark: item.remark,
                        tag: result.toString(),
                        updatedAt: item.updatedAt,
                        createdAt: item.createdAt,
                        info: item.info,
                      );
                    }
                    return item;
                  }).toList();
                  notifier.updateState(
                    currentState.copyWith(items: updatedItems),
                  );
                }
              },
              icon: CupertinoIcons.tag_fill,
              label: t.contact.tags,
            ),
            SlidableAction(
              backgroundColor: AppColors.getIosRed(brightness),
              onPressed: (_) => _confirmRemove(obj, index),
              icon: CupertinoIcons.delete_solid,
              label: t.common.buttonDelete,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_multiSelect)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CupertinoCheckbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelect(obj),
                  activeColor: AppColors.getIosBlue(brightness),
                ),
              ),
            Expanded(child: card),
          ],
        ),
      ),
    );
  }

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
                  Avatar(
                    imgUri: widget.peer['avatar'] ?? '',
                    width: 44,
                    height: 44,
                  ),
                  AppSpacing.horizontalMedium,
                  Expanded(
                    child: Text(
                      widget.peer['title'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              AppSpacing.verticalMedium,
              Text(
                model.info['payload']?['text'] as String? ??
                    t.common.messageContent,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.textStyle(FontSizeType.normal),
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
              final notifier = ref.read(userCollectProvider.notifier);
              final currentState = ref.read(userCollectProvider);
              if (await notifier.remove(obj)) {
                final updatedItems = [...currentState.items]
                  ..removeWhere((e) => e.kindId == obj.kindId);
                notifier.updateState(
                  currentState.copyWith(items: updatedItems),
                );
                EasyLoading.showSuccess(t.common.tipSuccess);
              } else {
                EasyLoading.showError(t.common.tipFailed);
              }
            },
            child: Text(t.common.buttonDelete),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final currentState = ref.watch(userCollectProvider);
    final t = context.t;

    return IosPageTemplate(
      title: widget.isSelect ? t.main.favorites : t.main.myFavorites,
      useLargeTitle: !widget.isSelect,
      actions: widget.isSelect
          ? [
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.xmark, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]
          : null,
      slivers: [
        if (_loadError)
          SliverToBoxAdapter(child: _buildLoadErrorPanel(context)),

        // 搜索栏
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchController,
              placeholder: t.common.search,
              onSubmitted: _search,
              onSuffixTap: _resetSearch,
              onChanged: (v) {
                _searchTimer?.cancel();
                _searchTimer = Timer(
                  const Duration(milliseconds: 500),
                  () => _search(v),
                );
              },
            ),
          ),
        ),

        // 分类筛选
        SliverToBoxAdapter(child: _buildKindList(context)),

        // 多选工具
        if (_multiSelect)
          SliverToBoxAdapter(child: _buildMultiSelectBar(context)),

        // 列表
        SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          sliver: currentState.items.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCollectItem(
                      context,
                      currentState.items[index],
                      index,
                    ),
                    childCount: currentState.items.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.bookmark,
            size: 60,
            color: AppColors.iosGray.withValues(alpha: 0.3),
          ),
          AppSpacing.verticalRegular,
          Text(
            t.common.noFavoritesYet,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.iosGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectBar(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${t.main.selected}: ${_selectedIds.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _selectAllCurrent,
            child: const Icon(CupertinoIcons.square_list, size: 20),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _batchTag,
            child: const Icon(CupertinoIcons.tag, size: 20),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _batchDelete,
            child: Icon(
              CupertinoIcons.delete,
              color: AppColors.getIosRed(brightness),
              size: 20,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: _exitMultiSelect,
            child: const Icon(CupertinoIcons.xmark_circle, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildKindList(BuildContext context) {
    final currentState = ref.read(userCollectProvider);
    final brightness = Theme.of(context).brightness;
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

    return ImBoySettingsSection(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Row(
              children: [
                Icon(
                  CupertinoIcons.slider_horizontal_3,
                  size: 18,
                  color: AppColors.getIosBlue(brightness),
                ),
                AppSpacing.horizontalMedium,
                Text(
                  t.main.type,
                  style: context.textStyle(
                    FontSizeType.medium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kindMap.entries.map((e) {
                    final isSelected = currentState.kind == e.key;
                    return ChoiceChip(
                      label: Text(
                        e.value,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: isSelected ? AppColors.onPrimary : null,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (v) {
                        if (v) _searchByKind(context, e.key, e.value);
                      },
                      selectedColor: AppColors.getIosBlue(brightness),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (currentState.tagItems.isNotEmpty) ...[
                const Divider(indent: 16, endIndent: 16, height: 1),
                Padding(
                  padding: AppSpacing.allRegular,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: currentState.tagItems,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
