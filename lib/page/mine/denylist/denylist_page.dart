import 'package:azlistview/azlistview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'denylist_provider.dart';

/// 黑名单页面
class DenylistPage extends ConsumerStatefulWidget {
  const DenylistPage({super.key});

  @override
  ConsumerState<DenylistPage> createState() => _DenylistPageState();
}

class _DenylistPageState extends ConsumerState<DenylistPage> {
  @override
  void initState() {
    super.initState();
    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(denylistProvider.notifier).loadData(page: 1, size: 1000);
    });
  }

  /// 构建黑名单用户卡片
  Widget _buildDenylistCard(BuildContext context, DenylistModel model) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusRegular,
      child: CellPressable(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute<dynamic>(
              builder: (context) => PeopleInfoPage(
                id: model.deniedUid.toString(),
                scene: 'denylist',
              ),
            ),
          ).then((_) {
            ref.read(denylistProvider.notifier).loadData(page: 1, size: 1000);
          });
        },
        onLongPress: () async {
          // 长按移出黑名单（备选入口）
          final confirmed = await showCupertinoDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text(t.confirmRemove),
              content: Text(t.confirmRemoveFromDenylist),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(t.buttonCancel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(t.buttonRemove),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            EasyLoading.show(status: t.loading);
            final res = await ref
                .read(denylistProvider.notifier)
                .removeDenylist(model.deniedUid.toString());
            EasyLoading.dismiss();
            if (res) {
              EasyLoading.showSuccess(t.removedFromDenylist);
            } else {
              EasyLoading.showError(t.tipFailed);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: AppRadius.borderRadiusRegular,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 头像
                ClipRRect(
                  borderRadius: AppRadius.borderRadiusMedium,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Avatar(imgUri: model.avatar),
                  ),
                ),
                const SizedBox(width: 16),

                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 用户名
                      Text(
                        model.nickname.isEmpty ? model.account : model.nickname,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // 黑名单状态标签
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: AppRadius.borderRadiusSmall,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 12,
                                  color: AppColors.getIosRed(
                                    Theme.of(context).brightness,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  t.blocked,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.getIosRed(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 箭头图标
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建警告提示卡片
  Widget _buildWarningCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.getIosRed(
          Theme.of(context).brightness,
        ).withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: AppColors.getIosRed(
            Theme.of(context).brightness,
          ).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.getIosRed(Theme.of(context).brightness),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.denylistNoteTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.denylistNoteDesc,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final denylistState = ref.watch(denylistProvider);

    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      appBar: GlassAppBar(automaticallyImplyLeading: true, title: t.denylist),
      body: Column(
        children: [
          // 警告提示卡片
          _buildWarningCard(context),

          // 黑名单列表
          Expanded(
            child: denylistState.items.isEmpty
                ? NoDataView(
                    text: t.denylistEmpty,
                    description: t.denylistEmptyDesc,
                    icon: Icons.block_outlined,
                    iconBgSize: 120,
                    iconSize: 60,
                  )
                : AzListView(
                    data: denylistState.items,
                    itemCount: denylistState.items.length,
                    itemBuilder: (BuildContext context, int index) {
                      DenylistModel model = denylistState.items[index];
                      // macOS 平台禁用 Dismissible，避免渲染冲突
                      if (defaultTargetPlatform == TargetPlatform.macOS) {
                        return _buildDenylistCard(context, model);
                      }
                      // 其他平台保留 Dismissible 滑动功能
                      return Dismissible(
                        key: ValueKey<String>('deny_${model.deniedUid}'),
                        direction: DismissDirection.endToStart,
                        background: const SizedBox.shrink(),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: AppColors.getIosRed(
                            Theme.of(context).brightness,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                t.buttonRemove,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          EasyLoading.show(status: t.loading);
                          bool res = await ref
                              .read(denylistProvider.notifier)
                              .removeDenylist(model.deniedUid.toString());
                          EasyLoading.dismiss();
                          if (res) {
                            EasyLoading.showSuccess(t.removedFromDenylist);
                            return true; // 允许滑动删除
                          } else {
                            EasyLoading.showError(t.tipFailed);
                            return false; // 阻止删除
                          }
                        },
                        onDismissed: (direction) {
                          // 列表已通过 confirmDismiss 中的 removeDenylist 更新
                        },
                        child: _buildDenylistCard(context, model),
                      );
                    },
                    physics: const AlwaysScrollableScrollPhysics(),
                    susItemBuilder: (BuildContext context, int index) {
                      DenylistModel model = denylistState.items[index];
                      if ('↑' == model.getSuspensionTag()) {
                        return Container();
                      }
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: AppRadius.borderRadiusSmall,
                              ),
                              child: Center(
                                child: Text(
                                  model.getSuspensionTag(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Container(
                                height: 0.5,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    indexBarData: denylistState.items.isNotEmpty
                        ? ['↑', ...denylistState.currIndexBarData]
                        : [],
                    indexBarOptions: IndexBarOptions(
                      needRebuild: true,
                      ignoreDragCancel: true,
                      downTextStyle: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      downItemDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      indexHintWidth: 64,
                      indexHintHeight: 64,
                      indexHintDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: AppRadius.borderRadiusXLarge,
                        // DESIGN.md §5.2 例外：Tooltip 类浮窗用极淡投影
                        // 推荐值 0 2 8 rgba(0,0,0,0.08)，原 alpha 0.2 偏强已下调
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indexHintAlignment: Alignment.centerRight,
                      indexHintChildAlignment: Alignment.center,
                      indexHintOffset: const Offset(-20, 0),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
