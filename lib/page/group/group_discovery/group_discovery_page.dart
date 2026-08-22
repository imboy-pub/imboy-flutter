import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'group_discovery_provider.dart';

/// 搜索输入防抖时长
const _kSearchDebounce = Duration(milliseconds: 300);

/// 触底加载更多的提前量（px）
const _kLoadMoreThreshold = 200.0;

/// 群组发现页 —— 浏览/检索平台公开群（type=1）
///
/// 顶部搜索框（FTS，q 参数）+ 分类横向过滤条（全部/平台分类）+
/// 排序切换（热门/最新）+ 分页公开群卡片；点击卡片进入群详情
/// （由详情页承担预览与加入流程）。
class GroupDiscoveryPage extends ConsumerStatefulWidget {
  const GroupDiscoveryPage({super.key});

  @override
  ConsumerState<GroupDiscoveryPage> createState() => _GroupDiscoveryPageState();
}

class _GroupDiscoveryPageState extends ConsumerState<GroupDiscoveryPage> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupDiscoveryProvider.notifier).initData();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String keyword) {
    _debounce?.cancel();
    _debounce = Timer(_kSearchDebounce, () {
      ref.read(groupDiscoveryProvider.notifier).updateKeyword(keyword.trim());
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.maxScrollExtent - notification.metrics.pixels <
        _kLoadMoreThreshold) {
      ref.read(groupDiscoveryProvider.notifier).loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupDiscoveryProvider);
    final notifier = ref.read(groupDiscoveryProvider.notifier);
    final showStateView =
        state.isLoading || state.error != null || state.list.isEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: IosPageTemplate(
        title: t.groupDiscovery.title,
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: notifier.refresh),
          SliverToBoxAdapter(
            child: searchBar(
              context,
              hintText: t.groupDiscovery.searchHint,
              onChanged: _onSearchChanged,
            ),
          ),
          if (state.categories.isNotEmpty)
            SliverToBoxAdapter(child: _buildCategoryBar(state, notifier)),
          if (!state.keyword.trim().isNotEmpty)
            SliverToBoxAdapter(child: _buildSortBar(state, notifier)),
          if (showStateView)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AsyncStateView(
                isLoading: state.isLoading,
                error: state.error,
                isEmpty: state.list.isEmpty,
                onRetry: notifier.refresh,
                emptyText: state.keyword.trim().isEmpty
                    ? t.groupDiscovery.emptyTitle
                    : t.groupDiscovery.searchEmpty,
                emptyIcon: CupertinoIcons.person_3,
                child: const SizedBox.shrink(),
              ),
            )
          else ...[
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _GroupCard(
                  item: state.list[index],
                  brightness: Theme.of(context).brightness,
                ),
                childCount: state.list.length,
              ),
            ),
            SliverToBoxAdapter(
              child: state.isLoadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.regular),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  : const SizedBox(height: 40),
            ),
          ],
        ],
      ),
    );
  }

  /// 分类横向过滤条：全部 + 平台分类
  Widget _buildCategoryBar(
    GroupDiscoveryState state,
    GroupDiscoveryNotifier notifier,
  ) {
    final brightness = Theme.of(context).brightness;
    final all = [
      GroupDiscoveryCategory(id: 0, name: t.groupDiscovery.allCategories),
      ...state.categories,
    ];
    final selectedId = state.categoryId ?? 0;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
        itemCount: all.length,
        separatorBuilder: (_, _) => AppSpacing.horizontalSmall,
        itemBuilder: (context, index) {
          final cat = all[index];
          final selected = cat.id == selectedId;
          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () =>
                notifier.selectCategory(cat.id == 0 ? null : cat.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: AppSpacing.small,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.getIosBlue(brightness)
                    : (brightness == Brightness.dark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface),
                borderRadius: AppRadius.button,
                border: Border.all(
                  color: AppColors.getIosSeparator(
                    brightness,
                  ).withValues(alpha: 0.3),
                  width: 0.33,
                ),
              ),
              child: Text(
                cat.name,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: selected
                      ? AppColors.lightTextPrimary
                      : (brightness == Brightness.dark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 排序切换（搜索态隐藏——FTS 自带相关性排序）
  Widget _buildSortBar(
    GroupDiscoveryState state,
    GroupDiscoveryNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: CupertinoSlidingSegmentedControl<String>(
        groupValue: state.sort,
        children: {
          'popular': Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(t.groupDiscovery.sortPopular),
          ),
          'newest': Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(t.groupDiscovery.sortNewest),
          ),
        },
        onValueChanged: (sort) {
          if (sort != null) notifier.updateSort(sort);
        },
      ),
    );
  }
}

/// 公开群卡片：头像 + 群名 + 成员数 + 简介（2 行）
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.item, required this.brightness});

  final GroupDiscoveryItem item;
  final Brightness brightness;

  void _openDetail(BuildContext context) {
    context.push(
      '/group/detail/${item.id}',
      extra: {
        'title': item.title,
        'memberCount': item.memberCount,
        'options': {'memberCount': item.memberCount},
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.small,
        ),
        padding: AppSpacing.cardPadding,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.3),
            width: 0.33,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(imgUri: item.avatar, width: 56, height: 56),
            AppSpacing.horizontalMedium,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyle(
                            FontSizeType.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      AppSpacing.horizontalTiny,
                      Icon(
                        CupertinoIcons.person_3,
                        size: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        semanticLabel: t.group.groupMembers,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${item.memberCount}',
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalSmall,
                  Text(
                    item.introduction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.horizontalSmall,
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.getIosSeparator(brightness),
            ),
          ],
        ),
      ),
    );
  }
}
