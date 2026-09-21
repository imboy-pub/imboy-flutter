/// 企业白标（客户部署）品牌配置模型（EPGZ-06 W1 / plan §7.3）
///
/// ── 与既有 [imboy.config.brand_config.BrandConfig] 的关系 ─────────────
/// `lib/config/brand_config.dart` 是**运行时**配置：后端 `GET /brand`
/// 下发的站点级品牌（siteName/logo/主题等），任何部署都能在线改。
/// 本文件是**构建期**配置：广州客户一期 Android 白标 product flavor
/// 的部署描述（applicationId 覆盖、客户图标/启动图资源、OA Tab 的
/// label 与 exact origin），随客户交付物固化，来源是构建注入的
/// dart-define / flavor 资源，而不是后端接口。
///
/// ── Android flavor 设计（W1 只做设计，不改 Gradle）──────────────────
/// 计划 §7.3：一个受控 Android product flavor/build profile，不 fork
/// 仓库。设计如下，W4 共享接线波次（A0 持 lease）落地到
/// `android/app/build.gradle`：
///
/// ```groovy
/// // android/app/build.gradle（W4 落地示意，W1 不改）
/// flavorDimensions "deploy"
/// productFlavors {
///   standard { dimension "deploy" }              // 自有完整版默认
///   gzCustomer {                                 // 广州客户白标
///     dimension "deploy"
///     applicationId "com.customer.pkg.imboy"     // ← applicationIdOverride
///     resValue "string", "app_display_name", "…" // ← displayName
///     resValue "string", "oa_label", "…"         // ← oaLabel
///     resValue "string", "oa_origin", "…"        // ← oaOrigin（唯一真源）
///   }
/// }
/// ```
///
/// - **资源覆盖**：图标/启动图走 `android/app/src/<flavor>/res/` 目录
///   覆盖（[iconAssetKey]/[splashAssetKey] 记录资源键名，二进制不入库）。
/// - **颜色**：`#RRGGBB` 十六进制（与运行时 BrandConfig 一致），解析
///   失败回退默认色。
/// - **构建变体命令**（计划 §10）：
///   `flutter build apk --debug --flavor gzCustomer`。
///
/// ── 秘密与签名材料（硬性边界）────────────────────────────────────────
/// 秘密**不进本模型、不进仓库**（plan §7.3 / 任务纪律）。模型只保留
/// 占位 key 名（[buildTimeSecretKeys]），值由本地/CI 环境在构建时注入：
///
/// ```text
/// IMBOY_WL_KEYSTORE_FILE   # .keystore/.jks 文件路径（不入库）
/// IMBOY_WL_KEYSTORE_PASSWORD
/// IMBOY_WL_KEY_ALIAS
/// IMBOY_WL_KEY_PASSWORD
/// ```
///
/// 客户未提供正式品牌或签名材料时，可完成可安装测试 APK；正式白标包
/// 保持 `BLOCKED_EXTERNAL`（plan §7.3）。
///
/// 纯 Dart（dart:ui Color 除外零 Flutter 依赖），fromJson/defaults 可单测。
library;

import 'dart:ui' show Color;

import 'package:imboy/theme/default/app_colors.dart';

/// 客户白标部署描述（构建期注入，非后端下发）。
class EnterpriseOaBrandConfig {
  const EnterpriseOaBrandConfig({
    required this.flavorId,
    required this.applicationIdOverride,
    required this.displayName,
    required this.iconAssetKey,
    required this.splashAssetKey,
    required this.primaryColor,
    required this.accentColor,
    required this.oaLabel,
    required this.oaOrigin,
    required this.oaEntryEnabled,
  });

  /// Android product flavor 标识（字母开头，仅字母/数字/下划线，
  /// 惯例 camelCase 如 `gzCustomer`）。
  final String flavorId;

  /// applicationId 覆盖；空 = 用默认 imboy applicationId（standard flavor）。
  final String applicationIdOverride;

  /// 应用显示名（launcher label）。空 = 默认名。
  final String displayName;

  /// 客户图标资源键名（资源引用字符串，非二进制路径承诺；空 = 内置默认）。
  final String iconAssetKey;

  /// 客户启动图资源键名；空 = 内置默认。
  final String splashAssetKey;

  /// 白标主色（#RRGGBB 解析产物；解析失败回退默认主色）。
  final Color primaryColor;

  /// 白标强调色；未配置为 null（主题自行推导）。
  final Color? accentColor;

  /// OA Tab 显示名（如「办公」「OA」）。空 = 默认「OA」。
  final String oaLabel;

  /// OA H5 唯一 exact HTTPS origin（scheme+host[+port]）。
  /// 空且 oaEntryEnabled=false = 未配置 OA 入口。
  final String oaOrigin;

  /// 是否启用 OA Tab 入口。
  final bool oaEntryEnabled;

  /// 默认形态 = imboy 原生 standard flavor（未白标、OA 关闭）。
  static const EnterpriseOaBrandConfig fallback = EnterpriseOaBrandConfig(
    flavorId: 'standard',
    applicationIdOverride: '',
    displayName: '',
    iconAssetKey: '',
    splashAssetKey: '',
    primaryColor: AppColors.primary,
    accentColor: null,
    oaLabel: '',
    oaOrigin: '',
    oaEntryEnabled: false,
  );

  /// 构建期注入的秘密占位 key（值永不进模型/仓库，见库文档）。
  static const List<String> buildTimeSecretKeys = <String>[
    'IMBOY_WL_KEYSTORE_FILE',
    'IMBOY_WL_KEYSTORE_PASSWORD',
    'IMBOY_WL_KEY_ALIAS',
    'IMBOY_WL_KEY_PASSWORD',
  ];

  /// Android applicationId 合法形态：Java 包名段（字母开头，字母/数字/
  /// 下划线），至少两段。
  static final RegExp _applicationIdPattern = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
  );

  /// flavorId 合法形态：字母开头，仅字母/数字/下划线（Android product
  /// flavor 惯例允许 camelCase，如 `gzCustomer`）。
  static final RegExp _flavorIdPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

  /// 从构建注入的配置段解析（dart-define 汇聚成的 Map 或等价来源）。
  ///
  /// 容错原则与运行时 BrandConfig 一致：单字段非法逐字段回退默认，
  /// 绝不因一个坏字段让整套白标不可用。唯一整体约束：启用 OA 入口
  /// 时 oaOrigin 必须是合法 HTTPS origin，否则回退 fallback 的
  /// oaEntryEnabled=false（入口不出现，而不是放行一个非法 origin）。
  factory EnterpriseOaBrandConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;
    final String flavor = _text(json['flavor_id'], fallback.flavorId);
    final String oaOrigin = _httpsOrigin(json['oa_origin']);
    final bool entryEnabled =
        json['oa_entry_enabled'] == true && oaOrigin.isNotEmpty;
    return EnterpriseOaBrandConfig(
      flavorId: _flavorIdPattern.hasMatch(flavor) ? flavor : fallback.flavorId,
      applicationIdOverride: _applicationIdOverride(json['application_id']),
      displayName: _text(json['display_name'], fallback.displayName),
      iconAssetKey: _text(json['icon_asset_key'], fallback.iconAssetKey),
      splashAssetKey: _text(json['splash_asset_key'], fallback.splashAssetKey),
      primaryColor: _hexColor(json['primary_color']) ?? fallback.primaryColor,
      accentColor: _hexColor(json['accent_color']),
      oaLabel: _text(json['oa_label'], fallback.oaLabel),
      oaOrigin: oaOrigin,
      oaEntryEnabled: entryEnabled,
    );
  }

  /// 是否为白标部署（applicationId 或显示名被覆盖即视为白标）。
  bool get isWhiteLabelled =>
      applicationIdOverride.isNotEmpty || displayName.isNotEmpty;

  /// OA Tab 实际展示 label（未配置回退「OA」由 i18n 层兜底）。
  bool get hasOaLabel => oaLabel.isNotEmpty;

  EnterpriseOaBrandConfig copyWith({
    String? flavorId,
    String? applicationIdOverride,
    String? displayName,
    String? iconAssetKey,
    String? splashAssetKey,
    Color? primaryColor,
    Color? accentColor,
    bool? clearAccentColor,
    String? oaLabel,
    String? oaOrigin,
    bool? oaEntryEnabled,
  }) {
    return EnterpriseOaBrandConfig(
      flavorId: flavorId ?? this.flavorId,
      applicationIdOverride:
          applicationIdOverride ?? this.applicationIdOverride,
      displayName: displayName ?? this.displayName,
      iconAssetKey: iconAssetKey ?? this.iconAssetKey,
      splashAssetKey: splashAssetKey ?? this.splashAssetKey,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: clearAccentColor == true
          ? null
          : (accentColor ?? this.accentColor),
      oaLabel: oaLabel ?? this.oaLabel,
      oaOrigin: oaOrigin ?? this.oaOrigin,
      oaEntryEnabled: oaEntryEnabled ?? this.oaEntryEnabled,
    );
  }

  // ---------------------------------------------------------------
  // 校验辅助（与运行时 BrandConfig 的规则风格对齐）
  // ---------------------------------------------------------------

  static String _text(Object? value, String fallbackValue) {
    if (value is! String) return fallbackValue;
    return value.trim();
  }

  /// applicationId 覆盖：非字符串/空/不合法一律视为未覆盖。
  static String _applicationIdOverride(Object? value) {
    if (value is! String) return '';
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return _applicationIdPattern.hasMatch(trimmed) ? trimmed : '';
  }

  /// 只接受 https:// 绝对 origin（scheme+host，端口可选）；带 path/query
  /// 的输入剥到 origin；其余（http:/javascript:/相对路径/空）视为未配置。
  static String _httpsOrigin(Object? value) {
    if (value is! String) return '';
    final String trimmed = value.trim();
    if (!trimmed.toLowerCase().startsWith('https://')) return '';
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return '';
    final String host = uri.host.toLowerCase();
    final int port = uri.hasPort || uri.port != 0 ? uri.port : 443;
    return port == 443 ? 'https://$host' : 'https://$host:$port';
  }

  /// `#RRGGBB` → Color；非法返回 null 由调用方回退。
  static Color? _hexColor(Object? value) {
    if (value is! String) return null;
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final int? parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
