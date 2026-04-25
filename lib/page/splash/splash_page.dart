import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // 最小展示时间 800ms（保证动画完成 + 防闪），与认证检查并行
    // 认证检查为本地同步操作，几乎瞬时完成；总时长由 800ms 保底
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 800)),
    ]);

    if (!mounted) return;

    final bool isLoggedIn = UserRepoLocal.to.isLoggedIn;

    if (isLoggedIn) {
      context.go('/bottom_navigation');
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.splashGradientStart, // #42A5F5 浅蓝
              AppColors.primary, // #2474E5 品牌蓝
              AppColors.primaryDark, // #1565C0 深蓝
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo 图片
                Image.asset(
                  'assets/images/imboy_logo0.png',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),

                const SizedBox(height: 32),

                // 应用名称
                const Text(
                      'ImBoy',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 4),
                            blurRadius: 12,
                            color: Color(0x33000000),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 1000.ms)
                    .moveY(begin: 30, end: 0),

                const SizedBox(height: 12),

                // Slogan
                Text(
                      context.t.splash.slogan,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 1000.ms)
                    .moveY(begin: 30, end: 0),
              ],
            ),

            // 底部信息：仅文案 + SafeArea 包裹避开 home indicator
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                        context.t.splash.security,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 700.ms, duration: 1000.ms),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

