import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 启动页（克制化版本，DESIGN.md §1 Clarity / Deference 原则）
///
/// 设计要点：
///   - 阶段化动效（fade-in / moveY），节奏由 0/200/550/900ms 递进，
///     避免一次性洪流；启动总时长 1400ms 保底，覆盖最长动画峰值
///   - 文字克制：w700（非 w800）、letterSpacing 0.5（非 2）、移除阴影
///     （DESIGN.md §3.3 字重 / §5.2 iOS 不用重投影）
///   - 响应式 logo 尺寸：屏幕短边 × 0.55，封顶 240pt（兼容 iPhone SE 320pt 宽）
///   - StatusBar 强制 light 内容色，避免与品牌蓝渐变背景冲突
///   - 顶部 RadialGradient 高光（atmosphere），打破纯渐变的"平"感
///   - debug 模式右下角显示 "DEV" 角标，避免误把 debug 包当 release
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

/// 品牌 Logo Hero tag（Splash → Welcome 共享，制造"启动页 logo 缩到欢迎页角标"的连续感）
///
/// Splash 的 logo 是 ~240pt 居中大图，Welcome 顶部 wordmark 旁的 logo 是 28×28，
/// 尺寸落差由 Flutter Hero 默认 RectTween 自然过渡（hero flight ~300ms）。
const String kBrandLogoHeroTag = 'imboy_brand_logo';

class _SplashPageState extends ConsumerState<SplashPage> {
  // 启动页保底时长：覆盖最长动画峰值（slogan 在 950ms 后才完整显示），
  // 加 ~400ms 体感停留，避免"动画刚演完就被切走"的突兀感。
  static const Duration _minHoldDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    // 渐变背景为深蓝，强制使用浅色 StatusBar 内容色（白色文字/icon）
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // 认证检查为本地同步操作，几乎瞬时完成；总时长由 _minHoldDuration 保底
    await Future<void>.delayed(_minHoldDuration);

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
    // 响应式 logo 尺寸：短边 0.55，封顶 240
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = math.min(shortest * 0.55, 240.0);

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
          children: [
            // ── 顶部光晕（atmosphere），低透明度径向白光打破纯渐变 ──
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.35),
                    radius: 0.95,
                    colors: [
                      Color(0x1FFFFFFF), // 白 12%
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),

            // ── 主内容（Logo + 标题 + Slogan） ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo：fade + 微 scale（移除 elasticOut 弹性）
                  // Hero 包在最外层，跳转 Welcome 时品牌锚点缩到顶部 28×28 wordmark 旁
                  Hero(
                    tag: kBrandLogoHeroTag,
                    child: Image.asset(
                      'assets/images/imboy_logo0.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                      .scale(
                        begin: const Offset(0.92, 0.92),
                        end: const Offset(1, 1),
                        duration: 600.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  const SizedBox(height: 28),

                  // 应用名称（克制：w700 + letterSpacing 0.5 + 无阴影）
                  const Text(
                    'ImBoy',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      height: 1.0,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: 200.ms,
                        duration: 500.ms,
                        curve: Curves.easeOut,
                      )
                      .moveY(
                        begin: 8,
                        end: 0,
                        delay: 200.ms,
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                      ),

                  const SizedBox(height: 14),

                  // Slogan（半透明白，与主标题拉开层级）
                  Text(
                    context.t.splash.slogan,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: 550.ms,
                        duration: 400.ms,
                        curve: Curves.easeOut,
                      ),
                ],
              ),
            ),

            // ── 底部安全文案（最末段进入） ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                minimum: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.t.splash.security,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ).animate().fadeIn(delay: 900.ms, duration: 300.ms),
                ),
              ),
            ),

            // ── debug 模式角标：避免把 debug 包当 release ──
            if (kDebugMode)
              Positioned(
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: Text(
                      'DEV',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.45),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
