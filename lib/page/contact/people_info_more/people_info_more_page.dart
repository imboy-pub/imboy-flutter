import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'people_info_more_provider.dart';
import 'people_info_same_group_page.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 用户更多信息页面
class PeopleInfoMorePage extends ConsumerStatefulWidget {
  final String id; // 用户ID

  const PeopleInfoMorePage({super.key, required this.id});

  @override
  ConsumerState<PeopleInfoMorePage> createState() => _PeopleInfoMorePageState();
}

class _PeopleInfoMorePageState extends ConsumerState<PeopleInfoMorePage> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// 加载数据；请求失败时提示用户并展示可重试的错误态，避免静默失败。
  Future<void> _loadData() async {
    if (mounted) setState(() => _hasError = false);
    try {
      await ref.read(peopleInfoMoreProvider.notifier).initData(widget.id);
    } on Exception catch (e) {
      iPrint('PeopleInfoMorePage._loadData failed: $e');
      if (!mounted) return;
      setState(() => _hasError = true);
      AppLoading.showError(t.common.loadError);
    }
  }

  /// 构建信息卡片
  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    int maxLines = 8,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        // DESIGN.md §5.2 + §8.3：Cell 卡片靠边框区分，不用投影
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusRegular,
        child: CellPressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: AppRadius.borderRadiusMedium,
                      ),
                      child: Icon(
                        icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    AppSpacing.horizontalRegular,
                    Expanded(
                      child: Text(
                        title,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                  ],
                ),

                AppSpacing.verticalRegular,

                // 内容
                Text(
                  content,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: context
                      .textStyle(
                        FontSizeType.subheadline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      )
                      .copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建共同群组卡片
  Widget _buildMutualGroupsCard(
    BuildContext context,
    PeopleInfoMoreState state,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        // DESIGN.md §5.2 + §8.3：Cell 卡片靠边框区分，不用投影
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusRegular,
        child: CellPressable(
          onTap: state.groupCount > 0
              ? () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (_) => PeopleInfoSameGroupPage(
                        groupList: state.sameGroupList,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: Row(
              children: [
                // 图标容器
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: state.groupCount > 0
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                    borderRadius: AppRadius.borderRadiusRegular,
                  ),
                  child: Icon(
                    Icons.groups_outlined,
                    color: state.groupCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),

                AppSpacing.horizontalRegular,

                // 文字内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.group.mutualGroupsWithHer,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.verticalTiny,
                      Text(
                        state.groupCount > 0
                            ? t.main.numUnit(param: '${state.groupCount}')
                            : t.common.noCommonGroups,
                        style: context.textStyle(
                          FontSizeType.normal,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // 右侧箭头或数字徽章
                if (state.groupCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusLarge,
                    ),
                    child: Text(
                      '${state.groupCount}',
                      style: context.textStyle(
                        FontSizeType.normal,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  AppSpacing.horizontalSmall,
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ] else ...[
                  Icon(
                    Icons.remove_circle_outline,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(BuildContext context) {
    return NoDataView(
      text: t.common.noMoreInfo,
      description: t.common.noDetailedInfo,
      icon: Icons.info_outline,
      iconBgSize: 80,
      iconSize: 40,
    );
  }

  /// 构建请求失败错误态，提供重试入口（替代此前的静默失败）
  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxLarge),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          AppSpacing.verticalRegular,
          Text(
            t.common.loadError,
            style: context.textStyle(
              FontSizeType.medium,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalRegular,
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.large,
              vertical: AppSpacing.small,
            ),
            color: Theme.of(context).colorScheme.primary,
            borderRadius: AppRadius.borderRadiusRegular,
            onPressed: _loadData,
            child: Text(t.common.buttonRetry),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.chat.socialProfile,
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(peopleInfoMoreProvider);

          // 请求失败：展示错误态 + 重试入口，不再静默无提示
          if (_hasError) {
            return SingleChildScrollView(child: _buildErrorState(context));
          }

          // 检查是否有任何信息可显示
          bool hasSignature = strNoEmpty(state.sign);
          bool hasSource = state.source.isNotEmpty;
          bool hasAnyInfo = hasSignature || hasSource || state.groupCount > 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                AppSpacing.verticalSmall,

                // 共同群组卡片
                _buildMutualGroupsCard(context, state),

                // 个人签名卡片
                if (hasSignature)
                  _buildInfoCard(
                    context: context,
                    title: t.account.signature,
                    content: state.sign,
                    icon: Icons.format_quote_outlined,
                    maxLines: 8,
                  ),

                // 来源信息卡片
                if (hasSource)
                  _buildInfoCard(
                    context: context,
                    title: t.main.source,
                    content: '${state.sourcePrefix} ${state.source}',
                    icon: Icons.source_outlined,
                    maxLines: 3,
                  ),

                // 空状态提示
                if (!hasAnyInfo) _buildEmptyState(context),

                AppSpacing.verticalXXLarge,
              ],
            ),
          );
        },
      ),
    );
  }
}
