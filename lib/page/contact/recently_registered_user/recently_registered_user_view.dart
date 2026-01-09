import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/store/model/people_model.dart';

import 'recently_registered_user_logic.dart';

class RecentlyRegisteredUserPage extends StatelessWidget {
  RecentlyRegisteredUserPage({super.key});

  final logic = Get.put(RecentlyRegisteredUserLogic());
  final state = Get.find<RecentlyRegisteredUserLogic>().state;

  void initData() async {
    state.page = 1;
    var list = await logic.page(
      page: state.page,
      size: state.size,
      kwd: state.kwd.value,
    );
    if (list.isNotEmpty) {
      state.peopleList.value = list;
      state.page += 1;
    }

    /*
    controller.addListener(() async {
      double pixels = controller.position.pixels;
      double maxScrollExtent = controller.position.maxScrollExtent;
      // debugPrint("RefreshIndicator_collect_ $pixels; $maxScrollExtent; ");
      // 滑动到底部，执行加载更多操作
      if (pixels == maxScrollExtent) {
        var list = await logic.page(
          page: state.page,
          size: state.size,
          kwd: state.kwd.value,
        );
        if (list.isNotEmpty) {
          state.items.addAll(list);
          state.page = state.page + 1;
        } else {
          EasyLoading.showToast('noMoreData'.tr);
        }
      }
    });
    */
  }

  /// 构建用户卡片
  Widget _buildUserCard(BuildContext context, PeopleModel model) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Get.to(
              () => PeopleInfoPage(
                id: model.id,
                scene: 'recently_user',
              ),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 头像
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                              model.nickname.isEmpty ? model.account : model.nickname,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              model.region.isEmpty ? '未知地区' : model.region,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.people_outline,
              size: 60,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无新注册用户',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '当前没有新注册的用户\n请稍后再来查看',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: 'newlyRegisteredPeople'.tr,
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
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
                      '这里显示最近注册的用户，你可以主动添加他们为好友',
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
              child: Obx(
                () => state.peopleList.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: state.peopleList.length,
                        itemBuilder: (BuildContext context, int index) {
                          PeopleModel model = state.peopleList[index];
                          return _buildUserCard(context, model);
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
