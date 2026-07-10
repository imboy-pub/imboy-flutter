import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'denylist_provider.dart';

/// 黑名单页面 - 像素级对齐 iOS 设置风
class DenylistPage extends ConsumerStatefulWidget {
  const DenylistPage({super.key});

  @override
  ConsumerState<DenylistPage> createState() => _DenylistPageState();
}

class _DenylistPageState extends ConsumerState<DenylistPage> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      await ref.read(denylistProvider.notifier).loadData(page: 1, size: 1000);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final denylistState = ref.watch(denylistProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.contact.denylist,
      useLargeTitle: false,
      slivers: [
        // 警告 Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.none,
            ),
            child: _buildWarningCard(context),
          ),
        ),

        // 列表 Section：加载 / 错误(可重试) / 空 / 数据 四态收敛为三态组件
        SliverFillRemaining(
          child: AsyncStateView(
            isLoading: denylistState.isLoading && denylistState.items.isEmpty,
            error: _error,
            isEmpty: denylistState.items.isEmpty,
            onRetry: _load,
            emptyText: t.contact.denylistEmpty,
            emptyIcon: CupertinoIcons.slash_circle,
            child: AzListView(
              data: denylistState.items,
              itemCount: denylistState.items.length,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
                vertical: AppSpacing.medium,
              ),
              itemBuilder: (context, index) {
                final model = denylistState.items[index];
                return _buildDenylistItem(context, model, brightness);
              },
              susItemBuilder: (context, index) {
                final model = denylistState.items[index];
                if (model.getSuspensionTag() == '↑') {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 6, left: 8),
                  child: Text(
                    model.getSuspensionTag(),
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: AppColors.iosGray,
                    ),
                  ),
                );
              },
              indexBarData: ['↑', ...denylistState.currIndexBarData],
              indexBarOptions: IndexBarOptions(
                needRebuild: true,
                downItemDecoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                indexHintDecoration: BoxDecoration(
                  color: AppColors.getSurfaceColor(brightness),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lightTextPrimary.withValues(alpha: 0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: AppColors.getIosRed(brightness).withValues(alpha: 0.05),
        borderRadius: AppRadius.borderRadiusCell,
        border: Border.all(
          color: AppColors.getIosRed(brightness).withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: AppColors.getIosRed(brightness),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.common.denylistNoteTitle,
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.verticalTiny,
                Text(
                  t.common.denylistNoteDesc,
                  style: context
                      .textStyle(
                        FontSizeType.footnote,
                        color: AppColors.iosGray,
                      )
                      .copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenylistItem(
    BuildContext context,
    DenylistModel model,
    Brightness brightness,
  ) {
    final item = ImBoySettingsTile(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute<void>(
            builder: (context) => PeopleInfoPage(
              id: model.deniedUid.toString(),
              scene: 'denylist',
            ),
          ),
        ).then((_) {
          ref.read(denylistProvider.notifier).loadData(page: 1, size: 1000);
        });
      },
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Avatar(imgUri: model.avatar),
      ),
      title: Text(
        model.nickname.isEmpty ? model.account : model.nickname,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Icon(
            CupertinoIcons.slash_circle,
            size: 10,
            color: AppColors.getIosRed(brightness),
          ),
          AppSpacing.horizontalTiny,
          Text(
            t.contact.blocked,
            style: context.textStyle(
              FontSizeType.caption2,
              color: AppColors.getIosRed(brightness),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey('deny_${model.deniedUid}'),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
        color: AppColors.getIosRed(brightness),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(CupertinoIcons.minus_circle, color: AppColors.onPrimary),
            AppSpacing.horizontalSmall,
            Text(
              t.common.buttonRemove,
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (dir) async {
        AppLoading.show(status: t.common.loading);
        bool res = await ref
            .read(denylistProvider.notifier)
            .removeDenylist(model.deniedUid.toString());
        AppLoading.dismiss();
        if (res) {
          AppLoading.showSuccess(t.common.removedFromDenylist);
        } else {
          AppLoading.showError(t.common.tipFailed);
        }
        return res;
      },
      child: item,
    );
  }
}
