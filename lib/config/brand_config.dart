import 'dart:ui' show Color;

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/hex_color.dart';

/// 白标品牌配置（C0-BRAND-01）
///
/// 单一真源：后端 `GET /brand` 返回的品牌字段。字段名、默认值与校验规则
/// 必须与 `imboy/src/api/brand_handler.erl` 的 `defaults/0` 和 `normalize/1`
/// 逐条对齐——两端任一侧改动都要同步另一侧的 fixture 测试。
///
/// 容错原则：拿不到配置、字段缺失或值非法，都逐字段回退默认值，
/// 绝不因为一个坏字段导致整套品牌不可用或界面崩溃。
class BrandConfig {
  const BrandConfig({
    required this.siteName,
    required this.logoUrl,
    required this.splashUrl,
    required this.primaryColor,
    required this.accentColor,
    required this.theme,
    required this.slogan,
    required this.copyright,
    required this.company,
    required this.supportUrl,
    required this.privacyUrl,
    required this.edition,
  });

  /// 应用名
  final String siteName;

  /// Logo 图片地址（空 = 用内置资源）
  final String logoUrl;

  /// 启动页图片地址（空 = 用内置资源）
  final String splashUrl;

  /// 主题主色
  final Color primaryColor;

  /// 强调色；未配置为 null，由主题自行推导
  final Color? accentColor;

  /// 主题模式，仅 light / dark
  final String theme;

  final String slogan;
  final String copyright;
  final String company;

  /// 客服入口地址。默认必须为空——对外联系方式只能由部署方人工填写，
  /// 代码不得预置任何邮箱、电话或 IM 账号。
  final String supportUrl;

  /// 隐私政策地址，同上，默认为空。
  final String privacyUrl;

  /// License 版次，只读展示用
  final String edition;

  /// 默认品牌 = 当前 imboy 原生外观（未配置任何 brand_* 时的形态）
  static const BrandConfig fallback = BrandConfig(
    siteName: 'imboy',
    logoUrl: '',
    splashUrl: '',
    primaryColor: AppColors.primary,
    accentColor: null,
    theme: themeLight,
    slogan: '',
    copyright: '',
    company: '',
    supportUrl: '',
    privacyUrl: '',
    edition: 'community',
  );

  static const String themeLight = 'light';
  static const String themeDark = 'dark';

  /// 解析后端 `GET /brand` 的 data 段；json 为 null 或非法结构时整体回退默认。
  factory BrandConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;
    return BrandConfig(
      siteName: _text(json['site_name'], fallback.siteName, allowEmpty: false),
      logoUrl: _httpUrl(json['logo_url']),
      splashUrl: _httpUrl(json['splash_url']),
      primaryColor: _hexColor(json['primary_color']) ?? fallback.primaryColor,
      accentColor: _hexColor(json['accent_color']),
      theme: _theme(json['theme']),
      slogan: _text(json['slogan'], fallback.slogan),
      copyright: _text(json['copyright'], fallback.copyright),
      company: _text(json['company'], fallback.company),
      supportUrl: _httpUrl(json['support_url']),
      privacyUrl: _httpUrl(json['privacy_url']),
      edition: _text(json['edition'], fallback.edition, allowEmpty: false),
    );
  }

  bool get isDark => theme == themeDark;

  /// 是否为白标部署（站点名被改过即视为已换品牌）
  bool get isWhiteLabelled => siteName != fallback.siteName;

  BrandConfig copyWith({
    String? siteName,
    String? logoUrl,
    String? splashUrl,
    Color? primaryColor,
    Color? accentColor,
    String? theme,
    String? slogan,
    String? copyright,
    String? company,
    String? supportUrl,
    String? privacyUrl,
    String? edition,
  }) {
    return BrandConfig(
      siteName: siteName ?? this.siteName,
      logoUrl: logoUrl ?? this.logoUrl,
      splashUrl: splashUrl ?? this.splashUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      theme: theme ?? this.theme,
      slogan: slogan ?? this.slogan,
      copyright: copyright ?? this.copyright,
      company: company ?? this.company,
      supportUrl: supportUrl ?? this.supportUrl,
      privacyUrl: privacyUrl ?? this.privacyUrl,
      edition: edition ?? this.edition,
    );
  }

  // ---------------------------------------------------------------
  // 校验：规则与后端 brand_handler:is_valid/2 一一对应
  // ---------------------------------------------------------------

  static String _text(
    Object? value,
    String fallbackValue, {
    bool allowEmpty = true,
  }) {
    if (value is! String) return fallbackValue;
    if (!allowEmpty && value.isEmpty) return fallbackValue;
    return value;
  }

  /// 只接受 http(s) 绝对地址；其余（javascript:/data:/相对路径等）一律视为未配置。
  /// 这是防止后端配置被污染后注入客户端的最后一道闸。
  static String _httpUrl(Object? value) {
    if (value is! String || value.isEmpty) return '';
    final bool ok =
        (value.startsWith('https://') && value.length > 'https://'.length) ||
        (value.startsWith('http://') && value.length > 'http://'.length);
    return ok ? value : '';
  }

  /// `#RRGGBB` → Color；非法返回 null 由调用方回退。转换下沉到主题层。
  static Color? _hexColor(Object? value) => hexToColor(value);

  static String _theme(Object? value) {
    return (value == themeLight || value == themeDark)
        ? value as String
        : fallback.theme;
  }
}
