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
///   - StatusBar 强制 light 内容色（亮 / 暗渐变都是深色背景），避免内容色冲突
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
///
/// Splash 的 logo 是 ~240pt 居中大图，Welcome 顶部 wordmark 旁的 logo 是 28×28，
/// 尺寸落差由 Flutter Hero 默认 RectTween 自然过渡（hero flight ~300ms）。
const String kBrandLogoHeroTag = 'imboy_brand_logo';

/// 品牌 Wordmark "ImBoy" Hero tag（Splash → Welcome 共享，与 Logo 共同形成
/// "品牌锚点连续过渡"，不再让用户感到 wordmark 在切页时"突然变小并瞬移"）。
///
/// Splash 的 wordmark 是 36pt w700 白色，Welcome 顶部 wordmark 是 18pt w700
/// AppColors.primaryDark。RectTween 自然处理位置 + 尺寸过渡；颜色 white → navy
/// 在 ~300ms hero flight 内跳变，因用户视线锁定在缩放过程，色变几乎不可察。
const String kBrandWordmarkHeroTag = 'imboy_brand_wordmark';

/// 首启 / 未登录用户保底时长 - 1400ms
///
/// 覆盖最长动画峰值（slogan 在 950ms 完整显示）+ ~400ms 体感停留，
/// 避免"动画刚演完就被切走"的突兀感。首启用户对品牌曝光价值高，保留较长。
const Duration kSplashMinHoldNew = Duration(milliseconds: 1400);

/// 已登录用户保底时长 - 900ms
///
/// 已登录用户每天打开 N 次，1400ms 累计成可感知的"等待感"。
/// 业界基线：WhatsApp ~500ms / Telegram ~600ms / 微信 800-1000ms。
/// 取 900ms 折中：900ms 跳转时 slogan 已 fade-in 87%，余 50ms 由路由切换
/// 的 ~300ms 自然过渡掩盖；比 1400ms 缩短 35.7%，高频用户每次省 500ms。
const Duration kSplashMinHoldReturning = Duration(milliseconds: 900);

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    // 渐变背景为深蓝，强制使用浅色 StatusBar 内容色（白色文字/icon）
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // 认证检查为本地同步操作，几乎瞬时完成；总时长由保底 duration 决定。
    // **关键**：在 await 前快照登录态，避免 await 期间 UserRepoLocal 状态变化
    // 导致用户经历"长 hold（首启分支）但实际已登录"的不一致体验。
    final bool isLoggedIn = UserRepoLocal.to.isLoggedIn;
    final Duration hold =
        isLoggedIn ? kSplashMinHoldReturning : kSplashMinHoldNew;

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
    // 响应式 logo 尺寸：短边 0.55，按设备类别两档封顶。
    //
    // 断点取 600pt：与 Material 3 / iOS 设计共识对齐 —
    //   - 短边 ≤ 600pt → 手机（含 Foldable 折叠态、iPhone Mini ~ Pro Max 全系）
    //   - 短边 > 600pt → 平板 / 大屏（iPad 768+, iPad Pro 12.9 ~ Foldable 展开态）
    //
    // 手机 cap 240pt：iPhone Pro Max 短边 430，0.55 → 236.5，封顶 240 几乎不裁切；
    // 平板 cap 320pt：iPad 短边 768，0.55 → 422.4 → 封顶 320，避免 logo 占满屏幕；
    //                  iPad Pro 12.9 短边 1024，0.55 → 563.2 → 320 仍合理（屏占比 ~31%）
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final double logoCap = shortest > 600 ? 320.0 : 240.0;
    final logoSize = math.min(shortest * 0.55, logoCap);

    // 暗色模式自适应：读取系统 platformBrightness（独立于 app theme，
    // 因为 splash 在 ThemeManager 之前渲染，无法依赖 Theme.of(context).brightness）
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    // 减弱动效：响应系统 "Reduce Motion" / "Remove animations"。
    // 启用后所有 fade / scale / moveY 跳过，直接渲染终态。
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    final List<Color> gradientColors = isDark
        ? const [
            AppColors.splashGradientStartDark, // #1E3A8A
            AppColors.splashGradientMidDark, //   #172554
            AppColors.splashGradientEndDark, //   #0F1729
          ]
        : const [
            AppColors.splashGradientStart, // #42A5F5 浅蓝
            AppColors.primary, //             #2474E5 品牌蓝
            AppColors.primaryDark, //         #1565C0 深蓝
          ];

    // 高光透明度：暗色背景上压低 4 个百分点，避免"灰雾"脏感
    final Color highlightStart =
        isDark ? const Color(0x14FFFFFF) /* 8% */ : const Color(0x1FFFFFFF) /* 12% */;

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
            // ── 顶部光晕（atmosphere），低透明度径向白光打破纯渐变 ──
            // P1-6: 4000ms 全周期（2000ms 单程）opacity 0.85 ↔ 1.0 呼吸脉动，
            //       让静态渐变有"激活感"。1.4s splash 内能感受到 ~10% 亮度缓变。
            //       减弱动效启用时跳过呼吸（与 4 段 entrance 保持一致策略）。
            Positioned.fill(
              child: _buildAtmosphereHighlight(
                highlightStart: highlightStart,
                disableAnim: disableAnim,
              ),
            ),

            // ── 主内容（Logo + 标题 + Slogan） ──
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

            // ── debug 模式角标：避免把 debug 包当 release ──
            // ExcludeSemantics：dev-only 标识，不应被 VoiceOver 朗读
            if (kDebugMode)
              Positioned(
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
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

  /// 顶部 atmosphere 高光层。disableAnim=true 时返回静态终态，
  /// 否则用 `.animate(onPlay: repeat reverse).fade(0.85 → 1.0, 2000ms)`
  /// 形成 4000ms 全周期呼吸脉动（cubic easeInOut，无几何变化，零 GPU 额外成本）。
  Widget _buildAtmosphereHighlight({
    required Color highlightStart,
    required bool disableAnim,
  }) {
    final node = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 0.95,
          colors: [
            highlightStart,
            const Color(0x00FFFFFF),
          ],
        ),
      ),
    );
    if (disableAnim) return node;
    return node
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(
          begin: 0.85,
          end: 1.0,
          duration: 2000.ms,
          curve: Curves.easeInOut,
        );
  }

  /// Logo：Hero + ExcludeSemantics（图像装饰，wordmark 已承担"ImBoy"语义朗读）。
  /// disableAnim=true 时直接返回 Hero 终态，跳过 fade + scale。
  ///
  /// 资源现状：`imboy_logo0.png` 仅 200×200，目标显示 240pt × DPR 3x = 720px，
  /// 拉伸 ~3.6x → 欠采样。`filterQuality: FilterQuality.high` 启用三线性 + Mipmap
  /// 替代 Flutter 默认 `low`（双线性），对欠采样模糊有 ~5-15% 视觉缓解。
  /// 不加 `cacheWidth/cacheHeight`：原图小于目标解码尺寸时 Flutter 不会上采样，
  /// cacheWidth 在此场景无收益。
  ///
  /// TODO(brand): 重导出 imboy_logo0.png ≥1024×1024 或迁移 SVG（与 Welcome 页 flutter_svg 一致）；
  ///              资源升级后改为 cacheWidth = (logoSize * DPR).round() 真正"防过采样"。
  Widget _buildLogo({required double logoSize, required bool disableAnim}) {
    final node = Hero(
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
    if (disableAnim) return node;
    return node
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
          duration: 600.ms,
          curve: Curves.easeOutCubic,
        );
  }

  /// 品牌 wordmark "ImBoy"：保留默认 Text 语义（VoiceOver 朗读 "ImBoy"），
  /// 是 Splash 屏唯一承担品牌识别朗读的节点（Logo 已被 ExcludeSemantics）。
  ///
  /// Hero 包裹（kBrandWordmarkHeroTag）→ Welcome 顶部 18pt wordmark 自然过渡，
  /// 与 Logo Hero 共同构成 Splash → Welcome 的品牌锚点连续 flight。
  Widget _buildWordmark({required bool disableAnim}) {
    const node = Hero(
      tag: kBrandWordmarkHeroTag,
      // Material wrap 防 Hero flight 期间 Text 失去 ancestor TextStyle。
      // 透明 Material 不引入视觉副作用。
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
    return node
        .animate()
        .fadeIn(delay: 200.ms, duration: 500.ms, curve: Curves.easeOut)
        .moveY(
          begin: 8,
          end: 0,
          delay: 200.ms,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
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
    return node.animate().fadeIn(
          delay: 550.ms,
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

}
