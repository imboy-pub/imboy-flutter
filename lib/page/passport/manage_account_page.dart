import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';

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
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 80),
            const SizedBox(height: 20),
            Text(
              t.account.accountSecurityEnhance,
              style: const TextStyle(
                color: AppColors.lightTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                t.common.bindMobileAndEmailTips,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 16,
                  height: 1.5,
                ),
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
                    icon: Icons.phone_iphone,
                    title: t.account.bindMobile,
                    subtitle: t.account.bindMobileFor,
                    onTap: () async {
                      // 替换当前页为主页的"我的"标签（index=2），然后延迟进入账户安全页
                      context.go('/bottom_navigation?index=2');
                      await Future<dynamic>.delayed(
                        const Duration(milliseconds: 100),
                      );
                      if (!mounted) return;
                      context.push('/account_security');
                    },
                  ),
                  _buildPage(
                    icon: Icons.alternate_email,
                    title: t.account.linkEmail,
                    subtitle: t.account.linkEmailFor,
                    onTap: () async {
                      // 替换当前页为主页的"我的"标签（index=2），然后延迟进入账户安全页
                      context.go('/bottom_navigation?index=2');
                      await Future<dynamic>.delayed(
                        const Duration(milliseconds: 100),
                      );
                      if (!mounted) return;
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
                  foregroundColor: Colors.white,
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusRegular,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Center(
                  child: Text(
                    t.common.buttonAccomplish,
                    style: const TextStyle(
                      fontSize: 16,
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
                style: const TextStyle(
                  color: AppColors.lightTextSecondary,
                  fontSize: 16,
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
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppColors.lightSurfaceContainer,
        borderRadius: AppRadius.borderRadiusLarge,
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.lightTextSecondary,
              height: 1.5,
            ),
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
                style: const TextStyle(
                  fontSize: 16,
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
