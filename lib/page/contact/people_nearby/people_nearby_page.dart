import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/store/model/people_model.dart';

import 'people_nearby_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 附近的人页面 - 像素级对齐 iOS 17 Premium 风格
class PeopleNearbyPage extends ConsumerStatefulWidget {
  const PeopleNearbyPage({super.key});

  @override
  ConsumerState<PeopleNearbyPage> createState() => _PeopleNearbyPageState();
}

class _PeopleNearbyPageState extends ConsumerState<PeopleNearbyPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isRotating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(peopleNearbyProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _rotateCompass() {
    setState(() => _isRotating = !_isRotating);
    if (_isRotating) {
      _animationController.forward(from: 0);
    } else {
      _animationController.reverse(from: 1);
    }
  }

  /// 触发"附近的人"刷新：指南针旋转动画 + 重新拉取列表。
  /// 供右上角刷新按钮与中部大指南针图标共用（点击指南针即可加载/刷新下方数据）。
  void _refreshNearby() {
    _rotateCompass();
    ref.read(peopleNearbyProvider.notifier).peopleNearby();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(peopleNearbyProvider);
    final notifier = ref.read(peopleNearbyProvider.notifier);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return IosPageTemplate(
      title: t.discovery.peopleNearby,
      useLargeTitle: false,
      actions: const [],
      slivers: [
        // 搜索区域 Section - 增强视觉重感
        SliverToBoxAdapter(
          child: _buildSearchHeader(context, isDark, brightness),
        ),

        // 可见性开关 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.sectionPrivacySecurity.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(
                  state.peopleNearbyVisible
                      ? t.main.makeYourselfInvisible
                      : t.main.makeYourselfVisible,
                ),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: state.peopleNearbyVisible
                        ? AppColors.getIosRed(brightness)
                        : AppColors.getIosBlue(brightness),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    state.peopleNearbyVisible
                        ? CupertinoIcons.location_slash_fill
                        : CupertinoIcons.location_fill,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.peopleList.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.small,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.iosGray.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.peopleList.length}',
                          style: context.textStyle(
                            FontSizeType.small,
                            fontWeight: FontWeight.bold,
                            color: AppColors.iosGray,
                          ),
                        ),
                      ),
                    AppSpacing.horizontalSmall,
                    const CupertinoListTileChevron(),
                  ],
                ),
                onTap: () {
                  if (!state.peopleNearbyVisible) {
                    _showVisibilityDialog(context, notifier);
                  } else {
                    notifier.makeMyselfUnVisible();
                    EasyLoading.showSuccess(t.common.locationHidden);
                  }
                },
              ),
            ],
          ),
        ),

        // 列表 Section
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
                    _buildPersonItem(context, model, brightness),
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

  Widget _buildSearchHeader(
    BuildContext context,
    bool isDark,
    Brightness brightness,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.regular,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xLarge),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 点击大指南针即可刷新下方"附近的人"列表（旋转动画反馈）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _refreshNearby,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => Transform.rotate(
                  angle: _animationController.value * 6.28318,
                  child: const Icon(
                    CupertinoIcons.compass,
                    color: AppColors.primary,
                    size: 80,
                  ),
                ),
              ),
            ),
            AppSpacing.verticalRegular,
            Text(
              t.discovery.findNearbyPeople,
              style: context
                  .textStyle(FontSizeType.large, fontWeight: FontWeight.bold)
                  .copyWith(letterSpacing: -0.5),
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.nearbyPeopleTips,
              textAlign: TextAlign.center,
              style: context
                  .textStyle(FontSizeType.footnote, color: AppColors.iosGray)
                  .copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonItem(
    BuildContext context,
    PeopleModel model,
    Brightness brightness,
  ) {
    String distance = model.distanceUnit == 'm' && model.distance > 1000
        ? "${(model.distance / 1000).toStringAsFixed(1)} km"
        : '${model.distance.toStringAsFixed(0)} ${model.distanceUnit}';

    return ImBoyListTile(
      onTap: () => context.push(
        '/people_info/${model.id}',
        extra: {'scene': 'people_nearby'},
      ),
      leading: Avatar(imgUri: model.avatar, width: 56, height: 56),
      title: Text(model.nickname),
      subtitle: Row(
        children: [
          Icon(
            CupertinoIcons.location_fill,
            size: 12,
            color: AppColors.getIosBlue(brightness).withValues(alpha: 0.7),
          ),
          AppSpacing.horizontalTiny,
          Text(
            distance,
            style: context.textStyle(
              FontSizeType.small,
              fontWeight: FontWeight.w500,
              color: AppColors.getIosBlue(brightness).withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppColors.iosGray3,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    // 空状态指南针同样可点击 + 旋转动画：点它即重新搜索附近的人。
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _refreshNearby,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Transform.rotate(
                angle: _animationController.value * 6.28318,
                child: const Icon(
                  CupertinoIcons.compass,
                  color: AppColors.iosGray3,
                  size: 64,
                ),
              ),
            ),
            AppSpacing.verticalMedium,
            Text(
              t.common.noNearbyPeople,
              style: context.textStyle(
                FontSizeType.subheadline,
                fontWeight: FontWeight.w600,
                color: AppColors.iosGray,
              ),
            ),
            AppSpacing.verticalTiny,
            Text(
              t.common.clickSearchButtonToFind,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVisibilityDialog(
    BuildContext context,
    PeopleNearbyNotifier notifier,
  ) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.chat.displayProfile),
        content: Text(t.discovery.nearbyPeopleExplain),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              notifier.makeMyselfVisible();
              Navigator.pop(ctx);
              EasyLoading.showSuccess(t.common.locationVisible);
            },
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
  }
}
