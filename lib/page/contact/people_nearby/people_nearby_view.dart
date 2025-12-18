import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/store/model/people_model.dart';

import 'people_nearby_logic.dart';

// ignore: must_be_immutable
class PeopleNearbyPage extends StatelessWidget {
  PeopleNearbyPage({super.key});

  ValueAdapter adapter = ValueAdapter(0.0, animated: true);
  bool changedAdapter = true;

  /// 旋转指南针动画
  void rotateCompass() {
    adapter.value = changedAdapter ? 1.0 : 0.0;
    changedAdapter = !changedAdapter;
  }

  /// 构建搜索区域 - Telegram风格
  Widget _buildSearchArea(BuildContext context, PeopleNearbyLogic logic) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // 指南针按钮 - 简洁设计，去掉外层框框
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(64),
              onTap: () {
                rotateCompass();
                logic.peopleNearby();
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child:
                    Icon(
                          Icons.explore,
                          color: Theme.of(context).colorScheme.primary,
                          size: 100,
                        )
                        .animate(adapter: adapter)
                        .rotate(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutCubic,
                        )
                        .scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.1, 1.1),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        ),
              ),
            ),
          ),

          // 标题 - 居中显示
          Text(
            'find_nearby_people'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),

          const SizedBox(height: 8),

          // 描述文字 - 居中显示
          Text(
            'nearby_people_tips'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建可见性控制卡片 - 弱化设计
  Widget _buildVisibilityCard(BuildContext context) {
    final logic = Get.find<PeopleNearbyLogic>();
    final state = Get.find<PeopleNearbyLogic>().state;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (state.peopleNearbyVisible.isFalse) {
            _showVisibilityDialog(context, logic);
          } else {
            logic.makeMyselfUnVisible();
            EasyLoading.showSuccess('已隐藏您的位置'.tr);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // 图标容器 - 缩小尺寸
              Obx(
                () => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: state.peopleNearbyVisible.isFalse
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.15)
                        : Theme.of(
                            context,
                          ).colorScheme.errorContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    state.peopleNearbyVisible.isFalse
                        ? Icons.location_on_outlined
                        : Icons.location_off_outlined,
                    color: state.peopleNearbyVisible.isFalse
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.7)
                        : Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 文字内容 - 缩小字体
              Expanded(
                child: Obx(
                  () => Text(
                    state.peopleNearbyVisible.isFalse
                        ? 'make_yourself_visible'.tr
                        : 'make_yourself_invisible'.tr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),

              // 状态指示器 - 缩小尺寸
              Obx(
                () => Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: state.peopleNearbyVisible.isFalse
                        ? Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.5)
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${state.peopleList.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建附近的人列表 - 突出显示
  Widget _buildPeopleList(BuildContext context) {
    final state = Get.find<PeopleNearbyLogic>().state;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 列表标题 - 更突出的设计
            _buildVisibilityCard(context),
            // 人员列表
            Expanded(
              child: Obx(() {
                if (state.peopleList.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: state.peopleList.length,
                  itemBuilder: (BuildContext context, int index) {
                    PeopleModel model = state.peopleList[index];
                    return _buildPersonItem(
                      context,
                      model,
                      index == state.peopleList.length - 1,
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建单个人员项 - 突出显示用户信息
  Widget _buildPersonItem(
    BuildContext context,
    PeopleModel model,
    bool isLast,
  ) {
    String distance = '';
    if (model.distanceUnit == 'm' && model.distance > 1000) {
      distance = "${(model.distance / 1000).toStringAsFixed(1)} km";
    } else {
      distance = '${model.distance.toStringAsFixed(0)} ${model.distanceUnit}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Get.to(
              () => PeopleInfoPage(id: model.id, scene: 'people_nearby'),
              transition: Transition.rightToLeft,
              popGesture: true,
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 8,
              bottom: 8,
            ),
            child: Row(
              children: [
                // 头像 - 增大尺寸
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Avatar(imgUri: model.avatar, width: 56, height: 56),
                ),

                const SizedBox(width: 18),

                // 用户信息 - 突出显示
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.nickname,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 箭头 - 弱化显示
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 18,
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
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle),
            child: Icon(
              Icons.location_searching,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无附近的人',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方的搜索按钮查找附近的人',
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

  /// 显示可见性确认对话框
  void _showVisibilityDialog(BuildContext context, PeopleNearbyLogic logic) {
    final colorScheme = Theme.of(context).colorScheme;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),

              const SizedBox(height: 20),

              // 标题
              Text(
                'display_profile'.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              // 内容
              Text(
                'nearby_people_explain'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.close(),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'button_cancel'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        logic.makeMyselfVisible();
                        Get.close();
                        EasyLoading.showSuccess('已显示您的位置'.tr);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'button_confirm'.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(PeopleNearbyLogic());

    Future.delayed(const Duration(milliseconds: 200), () {
      rotateCompass();
    });

    return Scaffold(
      appBar: NavAppBar(title: 'people_nearby'.tr),
      body: SlidableAutoCloseBehavior(
        child: Column(
          children: [
            // 搜索区域
            _buildSearchArea(context, logic),

            // 附近的人列表
            _buildPeopleList(context),
          ],
        ),
      ),
    );
  }
}
