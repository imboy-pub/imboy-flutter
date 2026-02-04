import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'people_info_more_provider.dart';
import 'people_info_same_group_page.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 用户更多信息页面
class PeopleInfoMorePage extends ConsumerStatefulWidget {
  final String id; // 用户ID

  const PeopleInfoMorePage({super.key, required this.id});

  @override
  ConsumerState<PeopleInfoMorePage> createState() => _PeopleInfoMorePageState();
}

class _PeopleInfoMorePageState extends ConsumerState<PeopleInfoMorePage> {
  @override
  void initState() {
    super.initState();
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(peopleInfoMoreProvider.notifier).initData(widget.id);
    });
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
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusRegular,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
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

                const SizedBox(height: 16),

                // 内容
                Text(
                  content,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusRegular,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.borderRadiusRegular,
          onTap: state.groupCount > 0
              ? () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => PeopleInfoSameGroupPage(
                        groupList: state.sameGroupList,
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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

                const SizedBox(width: 16),

                // 文字内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.mutualGroupsWithHer,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.groupCount > 0
                            ? t.numUnit(param: '${state.groupCount}')
                            : t.noCommonGroups,
                        style: TextStyle(
                          fontSize: 14,
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
                      horizontal: 12,
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
    return Container(
      margin: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.noMoreInfo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.noDetailedInfo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              height: 1.4,
            ),
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
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.socialProfile,
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(peopleInfoMoreProvider);

          // 检查是否有任何信息可显示
          bool hasSignature = strNoEmpty(state.sign);
          bool hasSource = state.source.isNotEmpty;
          bool hasAnyInfo = hasSignature || hasSource || state.groupCount > 0;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 共同群组卡片
                _buildMutualGroupsCard(context, state),

                // 个人签名卡片
                if (hasSignature)
                  _buildInfoCard(
                    context: context,
                    title: t.signature,
                    content: state.sign,
                    icon: Icons.format_quote_outlined,
                    maxLines: 8,
                  ),

                // 来源信息卡片
                if (hasSource)
                  _buildInfoCard(
                    context: context,
                    title: t.source,
                    content: '${state.sourcePrefix} ${state.source}',
                    icon: Icons.source_outlined,
                    maxLines: 3,
                  ),

                // 空状态提示
                if (!hasAnyInfo) _buildEmptyState(context),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
