import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/people_model.dart';

import 'recently_registered_user_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentlyRegisteredUserApi.notifier).initData();
    });
  }

  /// 构建用户卡片
  Widget _buildUserCard(BuildContext context, PeopleModel model) {
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
          onTap: () {
            context.push(
              '/people_info/${model.id}',
              extra: {'scene': 'recently_user'},
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 头像
                Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.borderRadiusMedium,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.borderRadiusMedium,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Avatar(imgUri: model.avatar),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 用户信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 用户名和注册时间
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.nickname.isEmpty
                                  ? model.account
                                  : model.nickname,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (model.createdAt > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: AppRadius.borderRadiusMedium,
                              ),
                              child: Text(
                                DateTimeHelper.lastTimeFmt(
                                  model.createdAt,
                                  pattern: 'MM-dd',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 地区信息
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              model.region.isEmpty
                                  ? t.unknownRegion
                                  : model.region,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recentlyRegisteredUserApi);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.newlyRegisteredPeople,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SlidableAutoCloseBehavior(
        child: Column(
          children: [
            // 顶部说明卡片
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusMedium,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.newRegisteredUsersTip,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 用户列表
            Expanded(
              child: state.peopleList.isEmpty
                  ? NoDataView(
                      text: t.noNewFriendRequests,
                      description: t.noNewRegisteredUsers,
                      icon: Icons.people_outline,
                      iconBgSize: 120,
                      iconSize: 60,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: state.peopleList.length,
                      itemBuilder: (BuildContext context, int index) {
                        PeopleModel model = state.peopleList[index];
                        return _buildUserCard(context, model);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
