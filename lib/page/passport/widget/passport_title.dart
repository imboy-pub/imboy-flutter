import 'package:flutter/material.dart';

import 'package:imboy/page/splash/splash_page.dart' show kBrandLogoHeroTag;
import 'package:imboy/theme/default/app_colors.dart';

/// Passport 系列页面（登录 / 注册 / 找回密码）的品牌标题组件。
///
/// 视觉构成：
///   1. 圆形白底 + 品牌色淡投影容器（DESIGN.md §5.2 hero 元素允许稍强投影）
///   2. 内嵌 [kBrandLogoHeroTag] Hero（接力 Splash → Welcome → 本页 logo）
///   3. wordmark "IMBoy"（IM 用品牌色 / Boy 用 lightTextPrimary）
///   4. slogan "Simple · Secure · Reliable"
///
/// [color] 可选品牌色覆盖，默认 [AppColors.primary]。
/// 仅影响 logo 投影色 + "IM" 文字色，'Boy' / slogan 用固定色保持品牌字重对比。
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo 圆形容器（Hero 起飞元素）
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: brandColor.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // Hero 接力 Splash → Welcome → SignIn 链路（kBrandLogoHeroTag）。
          // PNG 实际是黑色形状（200×200 RGBA），在白色圆形容器 + 投影衬托下
          // 仍清晰可读；品牌识别由外层圆形 + 投影色（brand 18% alpha）承担。
          child: Hero(
            tag: kBrandLogoHeroTag,
            child: Image.asset(
              'assets/images/imboy_logo0.png',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Wordmark "IMBoy"：DESIGN.md §3.3 最大字重 w700
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: 'IM',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: brandColor,
              letterSpacing: 1.2,
            ),
            children: [
              TextSpan(
                text: 'Boy',
                style: TextStyle(
                  color: AppColors.lightTextPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Slogan
        Text(
          'Simple · Secure · Reliable',
          style: TextStyle(
            color: AppColors.lightTextSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}
