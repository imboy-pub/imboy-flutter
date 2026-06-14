import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 启动页（克制化版本，DESIGN.md §1 Clarity / Deference 原则）
///
/// 设计要点：
///   - 阶段化动效（fade-in / moveY），节奏由 0/200/550/900ms 递进，
///     避免一次性洪流；启动总时长 1400ms 保底，覆盖最长动画峰值
///   - 文字克制：w700（非 w800）、letterSpacing 0.5（非 2）、移除阴影
///     （DESIGN.md §3.3 字重 / §5.2 iOS 不用重投影）
///   - 响应式 logo 尺寸：屏幕短边 × 0.55，封顶 240pt（兼容 iPhone SE 320pt 宽）
///   - StatusBar 强制 light 内容色（亮 / 暗渐变都是深色背景），避免内容色冲突
///   - 屏幕方向不在本页处理：`run.dart` 启动时已全局
///     `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`
///     锁定，splash 永远不会出现横屏布局问题
///
/// 已知缺口（P2-10 诊断）：
///   native splash 用 splash_logo.png 320×320，Dart splash 用 imboy_logo0.png
///   200×200 — 两份不同 PNG，且 native UIImageView 默认显示 ~107pt（@3x），
///   Dart logoSize 214.5pt（iPhone 14） / 320pt（iPad），交接瞬间 logo 跳大
///   ~2x。修复需重出统一资源（≥1024×1024 SVG 优先），同步给 brand 团队。
///   - 顶部 RadialGradient 高光（atmosphere），打破纯渐变的"平"感
///   - **暗色模式自适应**：渐变改用 `splashGradient*Dark` 三 Token，亮度 ~27%→~9%，
///     与 darkSurface (#121212) 形成蓝调缓冲；高光从 12% 白压到 8% 白，避免脏点
///   - **无障碍**：Logo 与 DEV 角标 ExcludeSemantics（图像装饰 / dev 噪音不朗读），
///     wordmark + slogan 走默认 Text 语义；VoiceOver 朗读序列：
///     "ImBoy" → slogan（信息密度收敛到品牌核心，1.4s 内可完整朗读）
///   - **减弱动效**：监听 `MediaQuery.disableAnimationsOf`，系统"减弱动态效果"启用时
///     跳过全部 fade/scale/moveY，直接渲染终态（仍保留 1400ms 跳转保底）
///   - debug 模式右下角显示 "DEV" 角标，避免误把 debug 包当 release
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

/// 品牌 Logo Hero tag（Splash → Welcome 共享，制造"启动页 logo 缩到欢迎页角标"的连续感）
const String kBrandLogoHeroTag = 'imboy_brand_logo';

/// 品牌 Wordmark "ImBoy" Hero tag（Splash → Welcome 共享）
const String kBrandWordmarkHeroTag = 'imboy_brand_wordmark';

/// 首启 / 未登录用户保底时长 - 1400ms
const Duration kSplashMinHoldNew = Duration(milliseconds: 1400);

/// 已登录用户保底时长 - 900ms
const Duration kSplashMinHoldReturning = Duration(milliseconds: 900);

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  // ── 入场动画（logo→wordmark→slogan，总时长 950ms） ──
  late final AnimationController _entranceCtrl;

  // ── atmosphere 呼吸（2000ms 单程，无限循环） ──
  late final AnimationController _atmosphereCtrl;
  late final Animation<double> _atmosphereOpacity;

  // logo: 0ms-600ms (interval 0.0–0.632)
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // wordmark: 200ms-700ms (interval 0.210–0.737)
  late final Animation<double> _wordmarkFade;
  late final Animation<double> _wordmarkTranslate; // 8.0 → 0.0 px

  // slogan: 550ms-950ms (interval 0.579–1.0)
  late final Animation<double> _sloganFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Entrance controller: 950ms covers slogan completion (550+400ms)
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();

    // Atmosphere breathe: 2000ms single pass, reverse-repeating → 4000ms full cycle
    _atmosphereCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _atmosphereOpacity = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _atmosphereCtrl, curve: Curves.easeInOut),
    );

    _logoFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.632, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.632, curve: Curves.easeOutCubic),
      ),
    );

    _wordmarkFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.210, 0.737, curve: Curves.easeOut),
    );
    _wordmarkTranslate = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.210, 0.737, curve: Curves.easeOutCubic),
      ),
    );

    _sloganFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.579, 1.0, curve: Curves.easeOut),
    );

    _checkAuth();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _atmosphereCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final bool isLoggedIn = UserRepoLocal.to.isLoggedIn;
    final Duration hold = isLoggedIn
        ? kSplashMinHoldReturning
        : kSplashMinHoldNew;
    await Future<void>.delayed(hold);
    if (!mounted) return;
    if (isLoggedIn) {
      context.go('/bottom_navigation');
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final double logoCap = shortest > 600 ? 320.0 : 240.0;
    final logoSize = math.min(shortest * 0.55, logoCap);

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    final List<Color> gradientColors = isDark
        ? const [
            AppColors.splashGradientStartDark,
            AppColors.splashGradientMidDark,
            AppColors.splashGradientEndDark,
          ]
        : const [
            AppColors.splashGradientStart,
            AppColors.primary,
            AppColors.primaryDark,
          ];

    final Color highlightStart = isDark
        ? AppColors.overlayLight
        : AppColors.overlayLightStrong;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildAtmosphereHighlight(
                highlightStart: highlightStart,
                disableAnim: disableAnim,
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(logoSize: logoSize, disableAnim: disableAnim),
                  const SizedBox(height: 28),
                  _buildWordmark(disableAnim: disableAnim),
                  const SizedBox(height: 14),
                  _buildSlogan(context, disableAnim: disableAnim),
                ],
              ),
            ),
            if (kDebugMode)
              Positioned(
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.small,
                      bottom: AppSpacing.small,
                    ),
                    child: ExcludeSemantics(
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
              ),
          ],
        ),
      ),
    );
  }

  /// Atmosphere 呼吸高光。disableAnim=true 时返回静态终态（opacity=1.0）。
  Widget _buildAtmosphereHighlight({
    required Color highlightStart,
    required bool disableAnim,
  }) {
    final decoration = BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -0.35),
        radius: 0.95,
        colors: [highlightStart, AppColors.overlayWhiteTransparent],
      ),
    );
    final node = DecoratedBox(decoration: decoration);
    if (disableAnim) return node;
    return FadeTransition(opacity: _atmosphereOpacity, child: node);
  }

  /// Logo：Hero + fade-in + scale。
  Widget _buildLogo({required double logoSize, required bool disableAnim}) {
    final image = Hero(
      tag: kBrandLogoHeroTag,
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/images/imboy_logo0.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
    if (disableAnim) return image;
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(scale: _logoScale, child: image),
    );
  }

  /// Wordmark "ImBoy"：Hero + fade-in + 向上滑入 8px。
  Widget _buildWordmark({required bool disableAnim}) {
    const node = Hero(
      tag: kBrandWordmarkHeroTag,
      child: Material(
        type: MaterialType.transparency,
        child: Text(
          'ImBoy',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
      ),
    );
    if (disableAnim) return node;
    return FadeTransition(
      opacity: _wordmarkFade,
      child: AnimatedBuilder(
        animation: _wordmarkTranslate,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _wordmarkTranslate.value),
          child: child,
        ),
        child: node,
      ),
    );
  }

  Widget _buildSlogan(BuildContext context, {required bool disableAnim}) {
    final node = Text(
      context.t.splash.slogan,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.85),
        letterSpacing: 0.3,
      ),
    );
    if (disableAnim) return node;
    return FadeTransition(opacity: _sloganFade, child: node);
  }
}
