import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/flat_list_tile.dart';
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

/// 我的页面 - 极简高效重构版本 (Minimalist & Flat)
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

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(brightness),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 顶部标题 - 极简标题
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  t.main.titleMine,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextColor(brightness),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),

          // 个人名片 - 无边框极简风格
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: _buildProfileCard(context, user, brightness),
            ),
          ),

          // 高频宫格区 - 快速直达
          SliverToBoxAdapter(child: _buildQuickActions(context)),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 低频管理列表 - 极简扁平化
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildListItem(
                  context,
                  title: t.main.favorites,
                  icon: Icons.favorite_outline,
                  iconColor: AppColors.iosRed,
                  onTap: () => context.push('/favorites'),
                  brightness: brightness,
                ),
                _buildListItem(
                  context,
                  title: t.main.storageSpace,
                  icon: Icons.sd_storage_outlined,
                  iconColor: AppColors.primary,
                  onTap: () => context.push('/storage_space'),
                  brightness: brightness,
                ),
                _buildListItem(
                  context,
                  title: t.account.loginDeviceManagement,
                  icon: Icons.devices_outlined,
                  iconColor: AppColors.iosTeal,
                  onTap: () => context.push('/devices'),
                  brightness: brightness,
                ),
                const SizedBox(height: 12),
                _buildListItem(
                  context,
                  title: t.main.setting,
                  icon: Icons.settings_outlined,
                  iconColor: AppColors.iosGray,
                  onTap: () => context.push('/mine/setting'),
                  brightness: brightness,
                ),
                _buildListItem(
                  context,
                  title: t.common.feedback,
                  icon: Icons.feedback_outlined,
                  iconColor: const Color(0xFF5C6BC0),
                  onTap: () => context.push('/feedback'),
                  brightness: brightness,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// 极简个人名片
  Widget _buildProfileCard(
    BuildContext context,
    UserModel? user,
    Brightness brightness,
  ) {
    final hasAvatar = user != null && strNoEmpty(user.avatar);
    final nickname = user?.nickname;
    final initial = (nickname != null && nickname.isNotEmpty)
        ? nickname.substring(0, 1).toUpperCase()
        : '?';
    final sign = user?.sign;
    final hasSign = sign != null && strNoEmpty(sign);

    return FlatListTile(
      onTap: () => context.push('/personal_info/profile'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      leading: CircleAvatar(
        radius: 36,
        backgroundColor: AppColors.primaryLight,
        backgroundImage: hasAvatar ? cachedImageProvider(user.avatar) : null,
        child: !hasAvatar
            ? Text(
                initial,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      title: Text(
        nickname ?? t.common.unknown,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('ID: ${user?.account ?? '-'}'),
          if (hasSign) ...[
            const SizedBox(height: 2),
            Text(sign, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => context.push('/qrcode/user'),
            icon: const Icon(Icons.qr_code_2, size: 24),
            color: AppColors.iosGray,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          const Icon(
            CupertinoIcons.chevron_right,
            color: AppColors.iosGray,
            size: 16,
          ),
        ],
      ),
    );
  }

  /// 构建高频快捷操作宫格
  Widget _buildQuickActions(BuildContext context) {
    final List<QuickActionItem> items = [
      QuickActionItem(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: t.account.wallet,
        onTap: () => context.push('/wallet'),
        color: AppColors.iosOrange,
      ),
      if (AppFeatureRegistry.isEnabled('channel'))
        QuickActionItem(
          icon: const Icon(Icons.campaign_outlined),
          label: t.discovery.myChannels,
          onTap: () => context.push('/channel'),
          color: AppColors.primary,
        ),
      // 占位功能，如果没有频道则补齐或留空
      QuickActionItem(
        icon: const Icon(Icons.auto_awesome_outlined),
        label: t.main.favorites, // 示例，可根据需要调整
        onTap: () => context.push('/favorites'),
        color: AppColors.iosRed,
      ),
    ];

    return QuickActionGrid(items: items);
  }

  /// 构建极简列表项
  Widget _buildListItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required Brightness brightness,
  }) {
    return FlatListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(title),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        color: AppColors.iosGray,
        size: 14,
      ),
    );
  }
}
