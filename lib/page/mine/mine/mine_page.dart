import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // appBar: GlassAppBar(
      //   automaticallyImplyLeading: false,
      //   title: t.titleMine,
      // ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // const SizedBox(height: 16),

            // 用户信息卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .shadowColor
                        .withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 用户头像和基本信息
                  _buildUserInfoItem(context, userRepo),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 钱包
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .shadowColor
                        .withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildMenuItem(
                context,
                title: t.wallet,
                leadingIcon: Icons.account_balance_wallet_outlined,
                leadingIconColor: AppColors.primary,
                onTap: () {
                  context.push('/wallet');
                },
              ),
            ),

            // 功能菜单列表
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .shadowColor
                        .withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 收藏
                  _buildMenuItem(
                    context,
                    title: t.favorites,
                    leadingIcon: Icons.favorite_outline,
                    leadingIconColor: AppColors.lightError,
                    onTap: () {
                      context.push('/favorites');
                    },
                  ),

                  _buildDivider(context),

                  // 存储空间
                  _buildMenuItem(
                    context,
                    title: t.storageSpace,
                    leadingIcon: Icons.sd_storage_outlined,
                    leadingIconColor: Colors.orange,
                    onTap: () {
                      context.push('/storage_space');
                    },
                  ),

                  _buildDivider(context),

                  // 设备管理
                  _buildMenuItem(
                    context,
                    title: t.loginDeviceManagement,
                    leadingIcon: Icons.devices_outlined,
                    leadingIconColor: AppColors.info,
                    onTap: () {
                      context.push('/devices');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 设置与反馈
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .shadowColor
                        .withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    title: t.setting,
                    leadingIcon: Icons.settings_outlined,
                    leadingIconColor: AppColors.textSecondary,
                    onTap: () {
                      context.push('/mine/setting');
                    },
                  ),
                  _buildDivider(context),
                  _buildMenuItem(
                    context,
                    title: t.feedback,
                    leadingIcon: Icons.feedback_outlined,
                    leadingIconColor: AppColors.primary,
                    onTap: () {
                      context.push('/feedback');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// 构建用户信息项
  Widget _buildUserInfoItem(BuildContext context, dynamic userRepo) {
    final user = userRepo.currentUser;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 跳转到个人信息页
          context.push('/personal_info/profile');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // 头像
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: strNoEmpty(user?.avatar)
                    ? NetworkImage(user!.avatar!)
                    : null,
                child: !strNoEmpty(user?.avatar)
                    ? Text(
                        user?.nickname?.substring(0, 1).toUpperCase() ?? 'U',
                        style: ref
                            .read(themeProvider.notifier)
                            .getTextStyle(
                              FontSizeType.title,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      )
                    : null,
              ),

              const SizedBox(width: 16),

              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? '',
                      style: ref
                          .read(themeProvider.notifier)
                          .getTextStyle(
                            FontSizeType.large,
                            color:
                                Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (user?.uid != null && user!.uid!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${user.uid}',
                        style: ref
                            .read(themeProvider.notifier)
                            .getTextStyle(
                              FontSizeType.small,
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              // QR Code
              InkWell(
                onTap: () {
                  context.push('/qrcode/user');
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.qr_code_2,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
              ),

              // 右箭头
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // 前导图标
              if (leadingIcon != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (leadingIconColor ?? AppColors.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    leadingIcon,
                    color: leadingIconColor ?? AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
              ],

              // 标题
              Expanded(
                child: Text(
                  title,
                  style: ref.read(themeProvider.notifier).getTextStyle(
                        FontSizeType.normal,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),

              // 尾部组件
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 16,
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
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
      ),
    );
  }
}
