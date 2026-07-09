import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

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

  /// 搜索关键字（本地即时过滤，无需进 provider）
  String _keyword = '';

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
    _keyword = '';
    ref.read(groupListProvider.notifier).setAttr(attr);
    await initData(onRefresh: true);
  }

  /// 本地即时过滤（按标题 / computeTitle 匹配关键字）。
  List<GroupModel> _filteredList(List<GroupModel> source) {
    final kw = _keyword.trim().toLowerCase();
    if (kw.isEmpty) return source;
    return source.where((m) {
      final title = m.title.isEmpty ? m.computeTitle : m.title;
      return title.toLowerCase().contains(kw);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupListProvider);
    final brightness = Theme.of(context).brightness;
    final filtered = _filteredList(state.groupList);

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
        // iOS 原生下拉刷新（与右上角刷新按钮互补）
        CupertinoSliverRefreshControl(
          onRefresh: () => initData(onRefresh: true),
        ),
        // 搜索框（即时过滤，修复原先 onSubmitted 空实现）
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
              suffixMode: OverlayVisibilityMode.always,
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
        ),

        // 分类分段控件（iOS 原生 SlidingSegmentedControl，替代 ChoiceChip）
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
            ).copyWith(bottom: AppSpacing.medium),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: state.attr,
                thumbColor: AppColors.getIosBlue(brightness),
                padding: const EdgeInsets.all(3),
                children: {
                  for (final attr in const ['all', 'join', 'manager', 'owner'])
                    attr: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        _attrLabel(attr),
                        style: context.textStyle(
                          FontSizeType.footnote,
                          fontWeight: state.attr == attr
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: state.attr == attr
                              ? AppColors.onPrimary
                              : AppColors.iosGray,
                        ),
                      ),
                    ),
                },
                onValueChanged: (v) {
                  if (v != null) _switchAttr(v);
                },
              ),
            ),
          ),
        ),

        // 列表区域
        if (state.isLoading)
          const SliverFillRemaining(child: ShimmerList())
        else if (state.groupList.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(context))
        else if (filtered.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(
              context,
              text: t.common.searchNoResults,
              showCta: false,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(top: AppSpacing.small, bottom: 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final model = filtered[index];
                final displayTitle = model.title.isEmpty
                    ? model.computeTitle
                    : model.title;
                return Column(
                  children: [
                    ImBoyListTile(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push(
                          '/chat/${model.groupId}',
                          extra: {
                            'title': model.title,
                            'avatar': model.avatar,
                            'type': 'C2G',
                            'options': {'memberCount': model.memberCount},
                          },
                        );
                      },
                      onLongPress: () {
                        HapticFeedback.heavyImpact();
                        _showItemActions(context, model);
                      },
                      leading: SmartGroupAvatar(
                        avatar: model.avatar,
                        groupId: model.groupId.toString(),
                        size: 48,
                        avatarLoader: (gid) => ref
                            .read(groupListServiceProvider)
                            .computeAvatar(gid),
                      ),
                      title: Text(displayTitle),
                      subtitle: Text(
                        '${model.memberCount} ${t.group.groupMembers}',
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.iosGray3,
                      ),
                    ),
                    if (index < filtered.length - 1)
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
              }, childCount: filtered.length),
            ),
          ),
      ],
    );
  }

  /// 空状态引导卡片。
  /// 无群时展示「发起群聊」CTA；搜索无结果时展示纯文案。
  Widget _buildEmptyState(
    BuildContext context, {
    String? text,
    bool showCta = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iosBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.person_2_square_stack,
                size: 40,
                color: AppColors.iosBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text ?? t.common.noData,
              style: context.textStyle(
                FontSizeType.medium,
                fontWeight: FontWeight.w500,
                color: secondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (showCta) ...[
              const SizedBox(height: 8),
              Text(
                t.common.createGroupF2fTips,
                style: context.textStyle(
                  FontSizeType.small,
                  color: secondaryColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xLarge,
                ),
                onPressed: () => context.push('/group/launch_chat'),
                child: Text(
                  t.chat.initiateChat,
                  style: context.textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 列表项长按菜单（群聊信息 / 进入聊天）
  void _showItemActions(BuildContext context, GroupModel model) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(
                '/group/detail/${model.groupId}',
                extra: {
                  'title': model.title,
                  'memberCount': model.memberCount,
                  'options': {'memberCount': model.memberCount},
                },
              );
            },
            // TODO(i18n): 补充 t.chat.groupInfo key 后替换字面量
            child: const Text('群聊信息'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(
                '/chat/${model.groupId}',
                extra: {
                  'title': model.title,
                  'avatar': model.avatar,
                  'type': 'C2G',
                  'options': {'memberCount': model.memberCount},
                },
              );
            },
            child: Text(t.chat.chatMessage),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
  }

  GroupListNotifier get notifier => ref.read(groupListProvider.notifier);
}
