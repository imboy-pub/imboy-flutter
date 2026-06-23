import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/splash/splash_page.dart'
    show kBrandLogoHeroTag, kBrandWordmarkHeroTag;
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 支持的语言列表
final List<AppLocale> _supportedLocales = AppLocale.values;

/// 语言显示名称映射 - 使用翻译键
Map<AppLocale, String> localeNames(BuildContext context) {
  return {
    AppLocale.zhCn: context.t.main.zhCn,
    AppLocale.zhHant: context.t.main.zhHant,
    AppLocale.enUs: context.t.main.enUs,
    AppLocale.jaJp: context.t.main.jaJp,
    AppLocale.koKr: context.t.common.koKr,
    AppLocale.deDe: context.t.main.deDd,
    AppLocale.frFr: context.t.main.frFr,
    AppLocale.itIt: context.t.main.itIt,
    AppLocale.ruRu: context.t.main.ruRu,
    AppLocale.arSa: context.t.main.arSa,
  };
}

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  StreamSubscription<AppLocale>? _localeSubscription;

  @override
  void initState() {
    super.initState();
    // 监听语言变化
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      // 语言变化时触发重建
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _pages(BuildContext ctx) => [
    {
      'title': ctx.t.welcome.step1Title,
      'desc': ctx.t.welcome.step1Desc,
      'svg': _svgStep1,
    },
    {
      'title': ctx.t.welcome.step2Title,
      'desc': ctx.t.welcome.step2Desc,
      'svg': _svgStep2,
    },
    {
      'title': ctx.t.welcome.step3Title,
      'desc': ctx.t.welcome.step3Desc,
      'svg': _svgStep3,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.lightSurface, AppColors.primaryLight],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部：左侧品牌锚点（Logo + wordmark） + 右侧语言选择
              Padding(
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    // 品牌锚点：与 Splash 视觉延续（Hero animation 接力 ~240→28pt）
                    Hero(
                      tag: kBrandLogoHeroTag,
                      child: Image.asset(
                        'assets/images/imboy_logo0.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                    AppSpacing.horizontalSmall,
                    // P1-5: Hero 接力 Splash 36pt → Welcome 18pt 自然过渡
                    // Material(transparent) 防 Hero flight 期间失去 TextStyle 上下文
                    Hero(
                      tag: kBrandWordmarkHeroTag,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          'ImBoy',
                          style: TextStyle(
                            fontSize: FontSizeType.large.size,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _LanguageSelector(
                      currentLocale: LocaleSettings.currentLocale,
                      onLocaleChanged: () {
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages(context).length,
                  itemBuilder: (context, index) {
                    final page = _pages(context)[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xLarge,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 220,
                              child: SvgPicture.string(
                                page['svg'] as String,
                                width: 220,
                                height: 220,
                              ),
                            ),
                            AppSpacing.verticalXLarge,
                            Text(
                              page['title'] as String,
                              style: context
                                  .textStyle(
                                    FontSizeType.extraLargeTitle,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.bold,
                                  )
                                  .copyWith(letterSpacing: -0.5),
                              textAlign: TextAlign.center,
                            ),
                            AppSpacing.verticalMedium,
                            Text(
                              page['desc'] as String,
                              // context.textStyle 无 height 参数，copyWith 补回
                              style: context
                                  .textStyle(
                                    FontSizeType.medium,
                                    color: AppColors.slateText,
                                  )
                                  .copyWith(height: 1.6),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xLarge),
                child: Column(
                  children: [
                    // Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages(context).length, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.tiny,
                          ),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.borderRadiusTiny,
                            color: _currentPage == index
                                ? AppColors.primary
                                : AppColors.slateMuted,
                          ),
                        );
                      }),
                    ),
                    AppSpacing.verticalXXLarge,
                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _pages(context).length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            context.go('/sign_in');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.borderRadiusXLarge,
                          ),
                          elevation: 8,
                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        child: Text(
                          _currentPage == _pages(context).length - 1
                              ? context.t.welcome.getStarted
                              : context.t.welcome.next,
                          style: context.textStyle(
                            FontSizeType.large,
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.verticalRegular,
                    // Skip Link
                    if (_currentPage < _pages(context).length - 1)
                      GestureDetector(
                        onTap: () {
                          context.go('/sign_in');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.small),
                          child: Text(
                            context.t.welcome.skip,
                            style: context.textStyle(
                              FontSizeType.normal,
                              color: AppColors.slateText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 34),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 语言选择器组件
class _LanguageSelector extends StatelessWidget {
  final AppLocale currentLocale;
  final VoidCallback onLocaleChanged;

  const _LanguageSelector({
    required this.currentLocale,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final names = localeNames(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showLanguageSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: AppSpacing.small,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.borderRadiusMedium,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              // 投影固定半透明黑色，符合 Material 阴影规范
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 18, color: AppColors.primary),
            AppSpacing.horizontalSmall,
            Text(
              names[currentLocale] ?? currentLocale.languageCode,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.horizontalTiny,
            const Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final names = localeNames(context);
    // 获取渲染框的位置
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final Size buttonSize = button.size;

    showMenu<AppLocale>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + buttonSize.height,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy - buttonSize.height,
      ),
      items: _supportedLocales.map((locale) {
        return PopupMenuItem<AppLocale>(
          value: locale,
          child: Row(
            children: [
              Icon(
                Icons.check,
                size: 18,
                color: locale == currentLocale
                    ? AppColors.primary
                    : Colors.transparent,
              ),
              AppSpacing.horizontalMedium,
              Expanded(
                child: Text(
                  names[locale] ?? locale.languageCode,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: locale == currentLocale
                        ? AppColors.primary
                        : AppColors.slateText,
                    fontWeight: locale == currentLocale
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((selectedLocale) async {
      if (selectedLocale != null && selectedLocale != currentLocale) {
        // 使用异步方法加载语言
        await LocaleSettings.setLocale(selectedLocale);
        // 保存语言选择到本地存储（使用枚举名称，如 zhCn、enUs）
        await StorageService.to.setString(
          Keys.currentLanguageCode,
          selectedLocale.name,
        );
        onLocaleChanged();
      }
    });
  }
}

// Welcome 引导页 SVG 插画配色
//
// 严格遵循 DESIGN.md 双蓝品牌策略：
//   - 主渐变 gradBrand：splashGradientStart (#42A5F5) → primary (#2474E5)
//   - 装饰球 / 高光：primary 系（避免绿/橙破坏品牌一致性）
//   - 装饰星 / 强调点：primaryDark (#1565C0) 深蓝
const String _defs = '''
    <defs>
        <linearGradient id="gradBrand" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style="stop-color:#42A5F5;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#2474E5;stop-opacity:1" />
        </linearGradient>
        <radialGradient id="highlight" cx="30%" cy="30%" r="70%">
            <stop offset="0%" style="stop-color:#ffffff;stop-opacity:0.4" />
            <stop offset="100%" style="stop-color:#ffffff;stop-opacity:0" />
        </radialGradient>
        <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
            <feDropShadow dx="0" dy="10" stdDeviation="15" flood-color="#2474E5" flood-opacity="0.25"/>
        </filter>
    </defs>
''';

const String _svgStep1 =
    '''
<svg width="220" height="220" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
    $_defs
    <circle cx="60" cy="70" r="30" fill="url(#gradBrand)" opacity="0.3" />
    <circle cx="150" cy="130" r="40" fill="url(#gradBrand)" opacity="0.2" />
    <path d="M50 100 Q 50 60 90 60 H 130 Q 170 60 170 100 V 110 Q 170 150 130 150 H 90 Q 50 150 50 110 Z" fill="url(#gradBrand)" filter="url(#shadow)" />
    <path d="M50 100 Q 50 60 90 60 H 130 Q 170 60 170 100 V 110 Q 170 150 130 150 H 90 Q 50 150 50 110 Z" fill="url(#highlight)" />
    <rect x="80" y="90" width="60" height="8" rx="4" fill="white" opacity="0.9" />
    <rect x="80" y="110" width="40" height="8" rx="4" fill="white" opacity="0.6" />
    <circle cx="160" cy="70" r="12" fill="#1565C0" />
    <circle cx="160" cy="70" r="12" fill="url(#highlight)" />
</svg>
''';

const String _svgStep2 =
    '''
<svg width="220" height="220" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
    $_defs
    <circle cx="100" cy="100" r="80" stroke="url(#gradBrand)" stroke-width="2" fill="none" opacity="0.2" stroke-dasharray="10 10" />
    <path d="M100 50 L145 70 V110 C145 140 100 165 100 165 C100 165 55 140 55 110 V70 Z" fill="url(#gradBrand)" filter="url(#shadow)" />
    <path d="M100 50 L145 70 V110 C145 140 100 165 100 165 C100 165 55 140 55 110 V70 Z" fill="url(#highlight)" />
    <path d="M85 110 L100 125 L125 95" stroke="white" stroke-width="8" stroke-linecap="round" stroke-linejoin="round" fill="none" />
    <circle cx="50" cy="60" r="5" fill="#42A5F5" opacity="0.6" />
    <circle cx="160" cy="150" r="8" fill="#42A5F5" opacity="0.4" />
</svg>
''';

const String _svgStep3 =
    '''
<svg width="220" height="220" viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
    $_defs
    <path d="M60 140 Q 60 160 80 160 H 140 Q 160 160 160 140 Q 160 120 140 120 Q 130 100 110 100 Q 90 100 80 120 Q 60 120 60 140 Z" fill="#E3F2FD" />
    <path d="M50 110 L160 60 L110 150 L95 100 Z" fill="url(#gradBrand)" filter="url(#shadow)" transform="translate(-10, -10)" />
    <path d="M50 110 L160 60 L110 150 L95 100 Z" fill="url(#highlight)" transform="translate(-10, -10)" />
    <path d="M40 130 L20 140" stroke="#42A5F5" stroke-width="4" stroke-linecap="round" opacity="0.5" />
    <path d="M50 150 L30 160" stroke="#42A5F5" stroke-width="4" stroke-linecap="round" opacity="0.3" />
    <path d="M170 40 L175 50 L185 55 L175 60 L170 70 L165 60 L155 55 L165 50 Z" fill="#1565C0" />
</svg>
''';
