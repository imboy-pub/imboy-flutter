import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
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
    // 模拟最小展示时间，配合动画
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 检查是否登录
    final bool isLoggedIn = UserRepoLocal.to.isLoggedIn;

    // 检查是否是第一次打开 (这里假设没有引导页标志位，默认未登录且非首次进入Home的话去Welcome)
    // 实际项目中应该有一个 isFirstRun 的标记
    // 暂时逻辑：已登录 -> Home, 未登录 -> Welcome

    if (isLoggedIn) {
      // TODO: Replace with actual Home route
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
              Color(0xFF42A5F5), // Light Blue
              Color(0xFF2474E5), // Primary Blue
              Color(0xFF1565C0), // Dark Blue
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 动态背景图案 (简化版)
            Positioned.fill(
              child: Opacity(
                opacity: 0.06,
                child: CustomPaint(painter: PatternPainter()),
              ),
            ),

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
                            color: Color.fromRGBO(0, 0, 0, 0.2),
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

            // 底部信息
            Positioned(
              bottom: 50,
              child: Column(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.t.splash.security,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 700.ms, duration: 1000.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (var i = 0; i < size.width; i += 50) {
      for (var j = 0; j < size.height; j += 50) {
        canvas.drawCircle(Offset(i.toDouble(), j.toDouble()), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
