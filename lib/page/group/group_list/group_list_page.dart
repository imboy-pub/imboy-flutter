import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'group_list_provider.dart';
import 'group_list_service.dart';

/// 群组列表服务 Provider
final groupListServiceProvider = Provider<GroupListService>(
  (ref) => GroupListService(),
);

/// 群聊列表页面 - 像素级对齐 iOS 17 Premium 风格
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
    _localeSubscription = LocaleSettings.getLocaleStream().listen(
      (_) => mounted ? setState(() {}) : null,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => initData());
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

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
      for (var m in list) {
        if (m.title.isEmpty) {
          m.computeTitle = await service.computeTitle(m.groupId.toString());
        }
      }
      notifier.setGroupList(list);
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
      default:
        return t.groupList.attrJoin;
    }
  }

  Future<void> _switchAttr(String attr) async {
    if (ref.read(groupListProvider).attr == attr) return;
    ref.read(groupListProvider.notifier).setAttr(attr);
    await initData(onRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupListProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title:
          '${t.chat.groupChat}${state.groupList.isNotEmpty ? " (${state.groupList.length})" : ""}',
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            notifier.setLoading(true);
            await AppInitializer.triggerGroupMembershipSelfHeal(
              force: true,
              source: 'group_list_refresh',
            );
            await initData(onRefresh: true);
          },
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ],
      slivers: [
        // 搜索框
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.medium,
            ),
            child: CupertinoSearchTextField(
              placeholder: t.common.search,
              onSubmitted: (v) {
                // 这里通常会打开一个搜索结果页或局部过滤
              },
            ),
          ),
        ),

        // 分类 Chip 栏
        SliverToBoxAdapter(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['all', 'join', 'manager', 'owner'].map((attr) {
                final selected = state.attr == attr;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.small),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(
                      _attrLabel(attr),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected ? AppColors.onPrimary : null,
                      ),
                    ),
                    selectedColor: AppColors.getIosBlue(brightness),
                    onSelected: (_) => _switchAttr(attr),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // 列表区域
        if (state.isLoading)
          const SliverFillRemaining(child: ShimmerList())
        else if (state.groupList.isEmpty)
          SliverFillRemaining(child: NoDataView(text: t.common.noData))
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.small, bottom: 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final model = state.groupList[index];
                return Column(
                  children: [
                    ImBoyListTile(
                      onTap: () => context.push(
                        '/chat/${model.groupId}',
                        extra: {
                          'title': model.title,
                          'avatar': model.avatar,
                          'type': 'C2G',
                          'options': {'memberCount': model.memberCount},
                        },
                      ),
                      leading: SmartGroupAvatar(
                        avatar: model.avatar,
                        groupId: model.groupId.toString(),
                        size: 48,
                        avatarLoader: (gid) => ref
                            .read(groupListServiceProvider)
                            .computeAvatar(gid),
                      ),
                      title: Text(
                        model.title.isEmpty ? model.computeTitle : model.title,
                      ),
                      subtitle: Text(
                        '${model.memberCount} ${t.group.groupMembers}',
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.iosGray3,
                      ),
                    ),
                    if (index < state.groupList.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 76),
                        child: Divider(
                          height: 0.33,
                          color: AppColors.getIosSeparator(
                            brightness,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                );
              }, childCount: state.groupList.length),
            ),
          ),
      ],
    );
  }

  GroupListNotifier get notifier => ref.read(groupListProvider.notifier);
}
