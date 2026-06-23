import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/quick_action_grid.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mine_page.g.dart';

class MineState {
  const MineState();
  MineState copyWith() => const MineState();
}

@riverpod
class MineNotifier extends _$MineNotifier {
  @override
  MineState build() => const MineState();
}

/// 我的页面 - 像素级对齐 iOS 17 高保真重构
class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  @override
  Widget build(BuildContext context) {
    final userRepo = ref.watch(userRepoProvider);
    final user = userRepo.currentUser;
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.main.titleMine,
      slivers: [
        // 顶部名片 - 采用 iOS 17 系统级质感
        SliverToBoxAdapter(
          child: _buildSystemHeader(context, user, brightness),
        ),

        // 核心功能宫格
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: _buildQuickActions(context),
          ),
        ),

        // 功能组
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              ImBoySettingsTile(
                title: Text(t.main.favorites),
                leading: _buildIcon(
                  CupertinoIcons.star_fill,
                  AppColors.iosYellow,
                ),
                onTap: () => context.push('/favorites'),
              ),
              ImBoySettingsTile(
                title: Text(t.main.storageSpace),
                leading: _buildIcon(
                  CupertinoIcons.circle_grid_hex_fill,
                  AppColors.iosSkyBlue,
                ),
                onTap: () => context.push('/storage_space'),
              ),
              ImBoySettingsTile(
                title: Text(t.account.loginDeviceManagement),
                leading: _buildIcon(
                  CupertinoIcons.device_phone_portrait,
                  AppColors.iosPurple,
                ),
                onTap: () => context.push('/devices'),
              ),
            ],
          ),
        ),

        // 设置组
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            margin: const EdgeInsets.fromLTRB(16, 24, 16, 48),
            children: [
              ImBoySettingsTile(
                title: Text(t.main.setting),
                leading: _buildIcon(CupertinoIcons.settings, AppColors.iosGray),
                onTap: () => context.push('/mine/setting'),
              ),
              ImBoySettingsTile(
                title: Text(t.common.feedback),
                leading: _buildIcon(
                  CupertinoIcons.hand_thumbsup_fill,
                  AppColors.iosGreen,
                ),
                onTap: () => context.push('/feedback'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 标准 iOS 17 设置图标 (7.2pt 园角)
  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7.2),
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }

  /// 系统级 Header
  Widget _buildSystemHeader(
    BuildContext context,
    UserModel? user,
    Brightness brightness,
  ) {
    final hasAvatar = user != null && strNoEmpty(user.avatar);
    final nickname = user?.nickname ?? t.common.unknown;
    final isDark = brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: () => context.push('/personal_info/profile'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceGroupedTertiary
                : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // 头像
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: AppColors.primary.withValues(alpha: 0.1),
                  image: hasAvatar
                      ? DecorationImage(
                          image: avatarImageProvider(user.avatar),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasAvatar
                    ? Center(
                        child: Text(
                          nickname.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${user?.account ?? '-'}',
                      style: TextStyle(fontSize: 14, color: AppColors.iosGray),
                    ),
                  ],
                ),
              ),
              // 动作
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => context.push('/qrcode/user'),
                child: const Icon(
                  CupertinoIcons.qrcode,
                  size: 22,
                  color: AppColors.iosGray,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.iosGray3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final List<QuickActionItem> items = [
      if (AppFeatureRegistry.isEnabled(FeatureKeys.wallet))
        QuickActionItem(
          icon: const Icon(CupertinoIcons.creditcard_fill),
          label: t.account.wallet,
          onTap: () => context.push('/wallet'),
          color: AppColors.iosOrange,
        ),
      if (AppFeatureRegistry.isEnabled(FeatureKeys.channel))
        QuickActionItem(
          icon: const Icon(CupertinoIcons.dot_radiowaves_left_right),
          label: t.discovery.myChannels,
          onTap: () => context.push('/channel'),
          color: AppColors.primary,
        ),
      QuickActionItem(
        icon: const Icon(CupertinoIcons.bookmark_fill),
        label: t.main.favorites,
        onTap: () => context.push('/favorites'),
        color: AppColors.iosRed,
      ),
    ];

    return QuickActionGrid(items: items);
  }
}
