import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/mine/account_security/account_security_view.dart';

import 'widget/bezier_container.dart';

/// ManageAccountPage
/// 注册成功后的引导页：引导用户前往“账户安全”绑定手机号或关联邮箱，或返回登录
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -Get.height * .15,
              right: -Get.width * .4,
              child: const BezierContainer(),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '提升账户安全'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '绑定手机号和邮箱，让您的账户更安全'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                    ),
                  ),
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
                          title: '绑定手机号'.tr,
                          subtitle: '用于登录、找回密码和接收重要通知'.tr,
                          onTap: () async {
                            // 替换当前页为主页的"我的"标签（index=2），然后延迟进入账户安全页
                            Get.off(
                              () => const BottomNavigationPage(),
                              arguments: {'index': 2},
                            );
                            await Future.delayed(const Duration(milliseconds: 100));
                            Get.to(() => AccountSecurityPage());
                          },
                        ),
                        _buildPage(
                          icon: Icons.alternate_email,
                          title: '关联邮箱'.tr,
                          subtitle: '用于登录、身份验证和接收账单'.tr,
                          onTap: () async {
                            // 替换当前页为主页的"我的"标签（index=2），然后延迟进入账户安全页
                            Get.off(
                              () => const BottomNavigationPage(),
                              arguments: {'index': 2},
                            );
                            await Future.delayed(const Duration(milliseconds: 100));
                            Get.to(() => AccountSecurityPage());
                          },
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      2,
                      (index) => _buildDot(index: index),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Get.offAllNamed(AppRoutes.signIn);
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Center(
                        child: Text(
                          '完成'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Get.off(() => BottomNavigationPage());
                    },
                    child: Text(
                      '以后再说'.tr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            flex: 2,
            child: Icon(icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 15),
          Flexible(
            flex: 1,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            flex: 2,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.blue,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: Text(
              '立即绑定'.tr,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({required int index}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 5),
      height: 6,
      width: _currentPage == index ? 20 : 6,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white54,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
