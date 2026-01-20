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
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
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
  StreamSubscription? _localeSubscription;

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
  Future<void> initData() async {
    final notifier = ref.read(groupListProvider.notifier);
    final service = ref.read(groupListServiceProvider);
    final state = ref.read(groupListProvider);

    notifier.setLoading(true);
    try {
      if (state.page == 1) {
        List<GroupModel> list = await service.page(
          page: state.page,
          size: state.size,
        );
        List<GroupModel> list2 = [];
        for (GroupModel m in list) {
          if (strEmpty(m.title)) {
            m.computeTitle = await service.computeTitle(m.groupId);
          }
          list2.add(m);
        }
        notifier.setGroupList(list2);
        notifier.incrementPage();
      }
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
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        titleWidget: Text("${t.groupChat}(${state.groupList.length})"),
        automaticallyImplyLeading: true,
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
                doSearch: ((query) => GroupRepo().search(kwd: query)),
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
                              groupId: model.groupId,
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
