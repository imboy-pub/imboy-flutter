import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
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

/// 我的页面 - iOS InsetGrouped 风格（DESIGN.md §8.3）
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
      backgroundColor: AppColors.getSurfaceGrouped(brightness),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 系统状态栏 + 页面标题占位
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  t.titleMine,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0.36,
                  ),
                ),
              ),
            ),
          ),

          // 用户资料卡片（iOS Settings 风格 profile cell）
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildProfileCard(context, user),
            ),
          ),

          // 功能菜单
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 钱包
                const SizedBox(height: 28),
                _buildSection(context, [
                  _buildItem(
                    context,
                    title: t.wallet,
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.iosOrange,
                    onTap: () => context.push('/wallet'),
                  ),
                ]),

                // 频道（feature flag 控制）
                if (AppFeatureRegistry.isEnabled('channel')) ...[
                  const SizedBox(height: 28),
                  _buildSection(context, [
                    _buildItem(
                      context,
                      title: t.myChannels,
                      icon: Icons.campaign_outlined,
                      iconColor: AppColors.primary,
                      onTap: () => context.push('/channel'),
                    ),
                    _buildDivider(context),
                    _buildItem(
                      context,
                      title: t.channelSquare,
                      icon: Icons.explore_outlined,
                      iconColor: AppColors.iosTeal,
                      onTap: () => context.push('/channel/discover'),
                    ),
                  ]),
                ],

                // 常用功能
                const SizedBox(height: 28),
                _buildSection(context, [
                  _buildItem(
                    context,
                    title: t.favorites,
                    icon: Icons.favorite_outline,
                    iconColor: AppColors.iosRed,
                    onTap: () => context.push('/favorites'),
                  ),
                  _buildDivider(context),
                  _buildItem(
                    context,
                    title: t.storageSpace,
                    icon: Icons.sd_storage_outlined,
                    iconColor: AppColors.primary,
                    onTap: () => context.push('/storage_space'),
                  ),
                  _buildDivider(context),
                  _buildItem(
                    context,
                    title: t.loginDeviceManagement,
                    icon: Icons.devices_outlined,
                    iconColor: AppColors.iosTeal,
                    onTap: () => context.push('/devices'),
                  ),
                ]),

                // 设置与反馈
                const SizedBox(height: 28),
                _buildSection(context, [
                  _buildItem(
                    context,
                    title: t.setting,
                    icon: Icons.settings_outlined,
                    iconColor: AppColors.iosGray,
                    onTap: () => context.push('/mine/setting'),
                  ),
                  _buildDivider(context),
                  _buildItem(
                    context,
                    title: t.feedback,
                    icon: Icons.feedback_outlined,
                    iconColor: const Color(0xFF5C6BC0),
                    onTap: () => context.push('/feedback'),
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS Settings 风格 profile cell
  ///
  /// [user] 当用户未登录或本地数据缺失时为 null，本方法走 fallback 显示
  /// （`?` 占位首字母 + `t.unknown` 名 + `'-'` ID）。
  Widget _buildProfileCard(BuildContext context, UserModel? user) {
    final theme = Theme.of(context);
    final hasAvatar = user != null && strNoEmpty(user.avatar);
    final nickname = user?.nickname;
    final initial = (nickname != null && nickname.isNotEmpty)
        ? nickname.substring(0, 1).toUpperCase()
        : '?';
    final sign = user?.sign;
    final hasSign = sign != null && strNoEmpty(sign);

    return ClipRRect(
      borderRadius: AppRadius.borderRadiusCell,
      child: ColoredBox(
        color: theme.cardColor,
        child: CellPressable(
          onTap: () => context.push('/personal_info/profile'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // 头像
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage:
                      hasAvatar ? cachedImageProvider(user.avatar) : null,
                  child: !hasAvatar
                      ? Text(
                          initial,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),

                // 名称 + ID + 签名
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname ?? t.unknown,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.41,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ImBoy ID: ${user?.uid ?? '-'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.iosGray,
                          letterSpacing: -0.08,
                        ),
                      ),
                      if (hasSign) ...[
                        const SizedBox(height: 2),
                        Text(
                          sign,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.iosGray,
                            letterSpacing: -0.08,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // QR 码按钮
                IconButton(
                  onPressed: () => context.push('/qrcode/user'),
                  icon: Icon(
                    Icons.qr_code_2,
                    color: AppColors.iosGray,
                    size: 22,
                  ),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 2),

                // chevron
                Icon(
                  CupertinoIcons.chevron_right,
                  color: AppColors.iosGray,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// iOS InsetGrouped 分组容器
  Widget _buildSection(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusCell,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  /// 菜单项（与 SettingPage._buildSettingItem 对齐）
  Widget _buildItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return CellPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // 图标容器（圆角方形，10% 背景）
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusCell,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // 标题
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.32,
                ),
              ),
            ),

            // chevron
            Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.iosGray,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  /// iOS 原生内嵌分隔线（左 inset 56pt = 38 icon + 14 gap + 16 padding）
  Widget _buildDivider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: HorizontalLine(
        height: 0.33,
        color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.6),
      ),
    );
  }
}
