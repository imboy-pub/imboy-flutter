import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/people_model.dart';

import 'recently_registered_user_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 最近注册用户页面 - 像素级对齐 iOS 17 Premium 风格
class RecentlyRegisteredUserPage extends ConsumerStatefulWidget {
  const RecentlyRegisteredUserPage({super.key});

  @override
  ConsumerState<RecentlyRegisteredUserPage> createState() =>
      _RecentlyRegisteredUserPageState();
}

class _RecentlyRegisteredUserPageState
    extends ConsumerState<RecentlyRegisteredUserPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentlyRegisteredUserApi.notifier).initData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recentlyRegisteredUserApi);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.account.newlyRegisteredPeople,
      useLargeTitle: false,
      slivers: [
        // 说明卡片 Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.small,
            ),
            child: _buildTipsCard(context, brightness == Brightness.dark),
          ),
        ),

        // 用户列表 Section
        if (state.isLoading)
          const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (state.peopleList.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(context))
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final model = state.peopleList[index];
                return Column(
                  children: [
                    _buildUserItem(context, model, brightness),
                    if (index < state.peopleList.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 84),
                        child: Divider(
                          height: 0.33,
                          color: AppColors.getIosSeparator(
                            brightness,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                );
              }, childCount: state.peopleList.length),
            ),
          ),
      ],
    );
  }

  Widget _buildTipsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: AppColors.getIosBlue(
          Theme.of(context).brightness,
        ).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.info,
            color: AppColors.getIosBlue(Theme.of(context).brightness),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.common.newRegisteredUsersTip,
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                height: 1.4,
                fontSize: FontSizeType.footnote.size,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(
    BuildContext context,
    PeopleModel model,
    Brightness brightness,
  ) {
    return ImBoyListTile(
      onTap: () => context.push(
        '/people_info/${model.id}',
        extra: {'scene': 'recently_user'},
      ),
      leading: Avatar(imgUri: model.avatar, width: 56, height: 56),
      title: Text(model.nickname.isEmpty ? model.account : model.nickname),
      subtitle: Text(
        model.region.isEmpty ? t.common.unknownRegion : model.region,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.createdAt > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.small,
                vertical: AppSpacing.tiny,
              ),
              decoration: BoxDecoration(
                color: AppColors.getIosBlue(brightness).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                DateTimeHelper.lastTimeFmt(model.createdAt, pattern: 'MM-dd'),
                style: TextStyle(
                  fontSize: FontSizeType.caption2.size,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getIosBlue(brightness),
                ),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppColors.iosGray3,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return NoDataView(
      text: t.common.noNewFriendRequests,
      description: t.common.noNewRegisteredUsers,
      icon: CupertinoIcons.person_2,
    );
  }
}
