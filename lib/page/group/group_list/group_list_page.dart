import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'group_list_provider.dart';
import 'group_list_service.dart';

/// 群组列表服务 Provider
final groupListServiceProvider = Provider<GroupListService>((ref) {
  return GroupListService();
});

class GroupListPage extends ConsumerStatefulWidget {
  const GroupListPage({super.key});

  @override
  ConsumerState<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends ConsumerState<GroupListPage> {
  StreamSubscription<dynamic>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initData();
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  /// 初始化数据
  Future<void> initData({bool onRefresh = false}) async {
    final notifier = ref.read(groupListProvider.notifier);
    final service = ref.read(groupListServiceProvider);
    final state = ref.read(groupListProvider);
    var currentAttr = state.attr;

    notifier.setLoading(true);
    try {
      List<GroupModel> list = await service.page(
        page: 1,
        size: state.size,
        onRefresh: onRefresh,
        attr: currentAttr,
      );
      if (list.isEmpty && currentAttr != 'all') {
        final fallback = await service.page(
          page: 1,
          size: state.size,
          onRefresh: true,
          attr: 'all',
        );
        if (fallback.isNotEmpty) {
          currentAttr = 'all';
          notifier.setAttr('all');
          list = fallback;
        }
      }
      List<GroupModel> list2 = [];
      for (GroupModel m in list) {
        if (strEmpty(m.title)) {
          m.computeTitle = await service.computeTitle(m.groupId.toString());
        }
        list2.add(m);
      }
      notifier.setGroupList(list2);
      notifier.setPage(2);
    } finally {
      notifier.setLoading(false);
    }
  }

  String _attrLabel(String attr) {
    switch (attr) {
      case 'all':
        return t.groupList.attrAll;
      case 'owner':
        return t.groupList.attrOwner;
      case 'manager':
        return t.groupList.attrManager;
      case 'join':
      default:
        return t.groupList.attrJoin;
    }
  }

  Future<void> _switchAttr(String attr) async {
    final state = ref.read(groupListProvider);
    if (state.attr == attr) {
      return;
    }
    ref.read(groupListProvider.notifier).setAttr(attr);
    await initData(onRefresh: true);
  }

  Future<void> _refreshWithSelfHeal() async {
    final notifier = ref.read(groupListProvider.notifier);
    notifier.setLoading(true);
    try {
      await AppInitializer.triggerGroupMembershipSelfHeal(
        force: true,
        source: 'group_list_refresh',
      );
      await initData(onRefresh: true);
    } finally {
      notifier.setLoading(false);
    }
  }

  /// 计算群组头像
  Future<List<String>> computeAvatar(String gid) async {
    final service = ref.read(groupListServiceProvider);
    return await service.computeAvatar(gid);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(groupListProvider);

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        titleWidget: Text("${t.groupChat}(${state.groupList.length})"),
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            onPressed: _refreshWithSelfHeal,
            icon: const Icon(Icons.refresh),
            tooltip: t.groupList.refresh,
            splashRadius: 20,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? colorScheme.shadow.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: searchBar(
                context,
                searchLabel: t.search,
                hintText: t.search,
                queryTips: t.groupSearchTips,
                doSearch: ((query) =>
                    GroupRepo().searchByAttr(attr: state.attr, kwd: query as String)),
                onTapForItem: (model) {
                  if (model is GroupModel) {
                    context.push(
                      '/chat',
                      extra: {
                        'peerId': model.groupId,
                        'peerTitle': model.title,
                        'peerAvatar': model.avatar,
                        'peerSign': '',
                        'type': 'C2G',
                        'options': {'memberCount': model.memberCount},
                      },
                    );
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['all', 'join', 'manager', 'owner'].map((attr) {
                      final selected = state.attr == attr;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(_attrLabel(attr)),
                        onSelected: (_) => _switchAttr(attr),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 群组列表
          Expanded(
            child: SlidableAutoCloseBehavior(
              child: state.isLoading
                  ? const ShimmerList()
                  : state.groupList.isEmpty
                  ? NoDataView(text: t.noData)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: state.groupList.length,
                      itemBuilder: (BuildContext context, int index) {
                        GroupModel model = state.groupList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colorScheme.surfaceContainerHighest
                                : Colors.white,
                            borderRadius: AppRadius.borderRadiusMedium,
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? colorScheme.shadow.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: SmartGroupAvatar(
                              avatar: model.avatar,
                              groupId: model.groupId.toString(),
                              avatarLoader: computeAvatar,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              strEmpty(model.title)
                                  ? model.computeTitle
                                  : model.title,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              context.push(
                                '/chat',
                                extra: {
                                  'peerId': model.groupId,
                                  'peerTitle': model.title,
                                  'peerAvatar': model.avatar,
                                  'peerSign': '',
                                  'type': 'C2G',
                                  'options': {'memberCount': model.memberCount},
                                },
                              );
                            },
                          ),
                        );
                      },
                      physics: const AlwaysScrollableScrollPhysics(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
