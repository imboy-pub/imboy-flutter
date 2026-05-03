import 'package:flutter/material.dart';

import 'package:imboy/page/splash/splash_page.dart' show kBrandLogoHeroTag;
import 'package:imboy/theme/default/app_colors.dart';

/// Passport 系列页面（登录 / 注册 / 找回密码）的品牌标题组件。
///
/// 视觉构成：
///   1. 圆形品牌蓝底 + 白色 LOGO ICON（DESIGN.md §5.2 极淡投影）
///   2. 内嵌 [kBrandLogoHeroTag] Hero（接力 Splash → Welcome → 本页 logo）
///   3. wordmark "IMBoy"（统一品牌色，w700）
///   4. slogan "Simple · Secure · Reliable"（自适应亮/暗色）
///
/// [color] 可选品牌色覆盖，默认 [AppColors.primary]。
///
/// 抽离自原 `PassportNotifier.title({Color? color})`：
///   - StatelessWidget 让单独可测（不需要 Riverpod ref）
///   - Notifier 仅负责状态管理，不再混入 widget builder
class PassportTitle extends StatelessWidget {
  const PassportTitle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brandColor = color ?? AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: brandColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: brandColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Hero 接力 Splash → Welcome → SignIn 链路（kBrandLogoHeroTag）。
          // 白色 LOGO ICON 在品牌蓝底上高对比醒目。
          child: Hero(
            tag: kBrandLogoHeroTag,
            child: Image.asset(
              'assets/images/imboy_logo0.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Wordmark "IMBoy"：统一品牌色，w700 字重
        Text(
          'IMBoy',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: brandColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        // Slogan：自适应亮/暗色模式
        Text(
          'Simple · Secure · Reliable',
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}
