import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:imboy/config/enum.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:jiffy/jiffy.dart';

import '../confirm_new_friend/confirm_new_friend_view.dart';
import 'add_friend_view.dart';
import 'new_friend_logic.dart';

// ignore: must_be_immutable
class NewFriendPage extends StatelessWidget {
  final NewFriendLogic logic = Get.put(NewFriendLogic());

  NewFriendPage({super.key});

  /// 加载好友申请数据
  void initData() async {
    logic.items = [].obs;
    logic.items.value = await logic.listNewFriend(UserRepoLocal.to.currentUid);
    logic.update([logic.items]);
  }

  /// 构建搜索区域
  Widget _buildSearchArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
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
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: searchBar(
          context,
          hintText: 'hint_login_account'.tr,
          queryTips: 'hint_login_account'.tr,
          searchLabel: 'hint_login_account'.tr,
          doSearch: ((query) async {
            return logic.userSearch(kwd: query);
          }),
          doBuildResults: (results) => logic.doBuildUserSearchResults(Get.context!, results),
          onTapForItem: (value) {
            debugPrint("> on search value ${value.toString()}");
          },
        ),
      ),
    );
  }

  /// 构建好友申请项
  Widget _buildFriendRequestItem(BuildContext context, NewFriendModel model, int index) {
    bool fromSelf = model.from == UserRepoLocal.to.currentUid;
    
    // 检查申请是否过期
    if (model.status == NewFriendStatus.waiting_for_validation.index) {
      Jiffy dt = Jiffy.parseFromMillisecondsSinceEpoch(model.createdAt);
      int diff = Jiffy.now().diff(dt, unit: Unit.day) as int;
      if (diff > 7) {
        model.status = NewFriendStatus.expired.index;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Slidable(
        groupTag: '1',
        closeOnScroll: true,
        endActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const StretchMotion(),
          children: [
            SlidableAction(
              key: ValueKey("delete_$index"),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              onPressed: (_) async {
                await logic.delete(model.from, model.to);
              },
              icon: Icons.delete_outline,
              label: 'button_delete'.tr,
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
                  id: UserRepoLocal.to.currentUid == model.to ? model.from : model.to,
                  scene: model.source,
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
                  Avatar(
                    imgUri: model.avatar!,
                    width: 56,
                    height: 56,
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // 用户信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 用户名和状态指示
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.nickname,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (fromSelf) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 12,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '已发送',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // 验证消息
                        Text(
                          model.msg,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 操作按钮区域
                  _buildActionButton(context, model, fromSelf),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton(BuildContext context, NewFriendModel model, bool fromSelf) {
    if (fromSelf && model.status == NewFriendStatus.waiting_for_validation.index) {
      // 发送方等待验证状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'awaiting_verification'.tr,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else if (model.status == NewFriendStatus.waiting_for_validation.index) {
      // 接收方待处理状态
      return SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: () {
            Get.to(
              () => ConfirmNewFriendPage(
                to: model.to,
                from: model.from,
                msg: model.msg,
                nickname: model.nickname,
                payload: model.payload,
              ),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            'accept'.tr,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (model.status == NewFriendStatus.added.index) {
      // 已添加状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'added'.tr,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (model.status == NewFriendStatus.expired.index) {
      // 已过期状态
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 4),
            Text(
              'expired'.tr,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'no_new_friends'.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '暂时没有新的好友申请',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'new_friend'.tr,
        backgroundColor: Theme.of(context).colorScheme.surface,
        rightDMActions: [
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Get.to(
                    () => AddFriendPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true,
                  );
                },
                child: Icon(
                  Icons.person_add_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: Column(
          children: [
            // 搜索区域
            _buildSearchArea(context),
            
            // 好友申请列表
            Expanded(
              child: Obx(() {
                if (logic.items.isEmpty) {
                  return _buildEmptyState(context);
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  itemCount: logic.items.length,
                  itemBuilder: (BuildContext context, int index) {
                    NewFriendModel model = logic.items[index];
                    return _buildFriendRequestItem(context, model, index);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}