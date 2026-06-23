import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// ManageAccountPage
/// 注册成功后的引导页：引导用户前往"账户安全"绑定手机号或关联邮箱，或返回登录
class ManageAccountPage extends StatefulWidget {
  const ManageAccountPage({super.key});

  @override
  State<ManageAccountPage> createState() => _ManageAccountPageState();
}

class _ManageAccountPageState extends State<ManageAccountPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 80),
            const SizedBox(height: 20),
            Text(
              t.account.accountSecurityEnhance,
              style: context.textStyle(
                FontSizeType.largeTitle,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                t.common.bindMobileAndEmailTips,
                textAlign: TextAlign.center,
                style: context
                    .textStyle(
                      FontSizeType.medium,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    )
                    .copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildPage(
                    context: context,
                    icon: Icons.phone_iphone,
                    title: t.account.bindMobile,
                    subtitle: t.account.bindMobileFor,
                    onTap: () async {
                      // 替换当前页为主页的"我的"标签（index=2），然后延迟进入账户安全页
                      context.go('/bottom_navigation?index=2');
                      await Future<dynamic>.delayed(
                        const Duration(milliseconds: 100),
                      );
                      if (!context.mounted) return;
                      context.push('/account_security');
                    },
                  ),
                  _buildPage(
                    context: context,
                    icon: Icons.alternate_email,
                    title: t.account.linkEmail,
                    subtitle: t.account.linkEmailFor,
                    onTap: () async {
                      // 替换当前页为主页的"我的"标签（index=2），然后延迟进入账户安全页
                      context.go('/bottom_navigation?index=2');
                      await Future<dynamic>.delayed(
                        const Duration(milliseconds: 100),
                      );
                      if (!context.mounted) return;
                      context.push('/account_security');
                    },
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) => _buildDot(index: index)),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: ElevatedButton(
                onPressed: () {
                  context.go('/sign_in');
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: AppColors.onPrimary,
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusRegular,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.regular,
                  ),
                  elevation: 0,
                ),
                child: Center(
                  child: Text(
                    t.common.buttonAccomplish,
                    style: context.textStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.go('/bottom_navigation');
              },
              child: Text(
                t.chat.later,
                style: context.textStyle(
                  FontSizeType.medium,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xLarge,
        vertical: AppSpacing.large,
      ),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainer,
        borderRadius: AppRadius.borderRadiusLarge,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.large),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: context.textStyle(
              FontSizeType.extraLarge,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context
                .textStyle(
                  FontSizeType.normal,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                )
                .copyWith(height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.borderRadiusRegular,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                t.common.bindNow,
                style: context.textStyle(
                  FontSizeType.medium,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? AppColors.primary
            : AppColors.lightTextDisabled,
        borderRadius: AppRadius.borderRadiusTiny,
      ),
    );
  }
}
