import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mine_page.g.dart';

/// Mine 模块的状态管理
///
/// 注意：当前 MinePage 使用 ConsumerStatefulWidget
/// 所有状态管理已内联到 UI 中
/// 此 Provider 保留用于未来扩展
class MineState {
  const MineState();

  MineState copyWith() {
    return const MineState();
  }
}

@riverpod
class MineNotifier extends _$MineNotifier {
  @override
  MineState build() {
    return const MineState();
  }
}

/// 我的页面 - 个人中心主页
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 顶部背景和用户信息
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // 背景渐变
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
                // 用户信息
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 20,
                    right: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 头像
                          GestureDetector(
                            onTap: () => context.push('/personal_info/profile'),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: theme.colorScheme.surface,
                                backgroundImage: strNoEmpty(user?.avatar)
                                    ? cachedImageProvider(user!.avatar)
                                    : null,
                                child: !strNoEmpty(user?.avatar)
                                    ? Text(
                                        user!.nickname
                                                .substring(0, 1)
                                                .toUpperCase(),
                                        style: theme.textTheme.headlineLarge
                                            ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // 昵称和ID
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.nickname ?? t.unknown,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'ID: ${user?.uid ?? '-'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 二维码
                          IconButton(
                            onPressed: () => context.push('/qrcode/user'),
                            icon: const Icon(
                              Icons.qr_code_2,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // 个性签名
                      if (strNoEmpty(user?.sign))
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            user!.sign,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 功能列表
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 钱包
                _buildMenuSection(context, [
                  _buildMenuItem(
                    context,
                    title: t.wallet,
                    leadingIcon: Icons.account_balance_wallet_outlined,
                    leadingIconColor: Colors.orange,
                    onTap: () => context.push('/wallet'),
                  ),
                ]),

                const SizedBox(height: 16),

                // 常用功能
                _buildMenuSection(context, [
                  _buildMenuItem(
                    context,
                    title: t.favorites,
                    leadingIcon: Icons.favorite_outline,
                    leadingIconColor: Colors.redAccent,
                    onTap: () => context.push('/favorites'),
                  ),
                  _buildDivider(context),
                  _buildMenuItem(
                    context,
                    title: t.storageSpace,
                    leadingIcon: Icons.sd_storage_outlined,
                    leadingIconColor: Colors.blueAccent,
                    onTap: () => context.push('/storage_space'),
                  ),
                  _buildDivider(context),
                  _buildMenuItem(
                    context,
                    title: t.loginDeviceManagement,
                    leadingIcon: Icons.devices_outlined,
                    leadingIconColor: Colors.teal,
                    onTap: () => context.push('/devices'),
                  ),
                ]),

                const SizedBox(height: 16),

                // 设置
                _buildMenuSection(context, [
                  _buildMenuItem(
                    context,
                    title: t.setting,
                    leadingIcon: Icons.settings_outlined,
                    leadingIconColor: Colors.grey,
                    onTap: () => context.push('/mine/setting'),
                  ),
                  _buildDivider(context),
                  _buildMenuItem(
                    context,
                    title: t.feedback,
                    leadingIcon: Icons.feedback_outlined,
                    leadingIconColor: Colors.purpleAccent,
                    onTap: () => context.push('/feedback'),
                  ),
                ]),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建菜单分组
  Widget _buildMenuSection(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.borderRadiusRegular,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    IconData? leadingIcon,
    Color? leadingIconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusRegular,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  color: leadingIconColor ?? theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                trailing,
              ] else if (onTap != null) ...[
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.hintColor.withValues(alpha: 0.3),
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建分割线
  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
    );
  }

}
