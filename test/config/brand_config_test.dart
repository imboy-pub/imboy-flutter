import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/brand_config.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 默认 fixture：后端未配置任何 brand_* 时返回的形态
Map<String, dynamic> defaultFixture() => <String, dynamic>{
  'site_name': 'imboy',
  'logo_url': '',
  'splash_url': '',
  'primary_color': '#2474E5',
  'accent_color': '',
  'theme': 'light',
  'slogan': '',
  'copyright': '',
  'company': '',
  'support_url': '',
  'privacy_url': '',
  'edition': 'community',
};

/// 白标 fixture：私有化客户完整换品牌
Map<String, dynamic> whiteLabelFixture() => <String, dynamic>{
  'site_name': '某企业IM',
  'logo_url': 'https://cdn.example.com/logo.png',
  'splash_url': 'https://cdn.example.com/splash.png',
  'primary_color': '#1A73E8',
  'accent_color': '#FF6D00',
  'theme': 'dark',
  'slogan': '高效协作',
  'copyright': '© 2026 某企业',
  'company': '某企业股份有限公司',
  'support_url': 'https://support.example.com',
  'privacy_url': 'https://example.com/privacy',
  'edition': 'enterprise',
};

void main() {
  group('BrandConfig 默认 fixture', () {
    test('默认配置解析后等于内置 fallback 外观', () {
      final BrandConfig b = BrandConfig.fromJson(defaultFixture());

      expect(b.siteName, 'imboy');
      expect(b.theme, BrandConfig.themeLight);
      expect(b.isDark, isFalse);
      expect(b.isWhiteLabelled, isFalse);
      // 默认主色必须与 App 原生主色一致，否则「未配置 = 原样」不成立
      expect(b.primaryColor, AppColors.primary);
      expect(b.accentColor, isNull);
    });

    test('客服与隐私链接默认为空，代码不得预置任何联系方式', () {
      final BrandConfig b = BrandConfig.fromJson(defaultFixture());
      expect(b.supportUrl, isEmpty);
      expect(b.privacyUrl, isEmpty);
      expect(BrandConfig.fallback.supportUrl, isEmpty);
      expect(BrandConfig.fallback.privacyUrl, isEmpty);
    });

    test('null 或空 json 整体回退默认', () {
      expect(
        BrandConfig.fromJson(null).siteName,
        BrandConfig.fallback.siteName,
      );
      final BrandConfig empty = BrandConfig.fromJson(<String, dynamic>{});
      expect(empty.siteName, BrandConfig.fallback.siteName);
      expect(empty.primaryColor, BrandConfig.fallback.primaryColor);
      expect(empty.theme, BrandConfig.fallback.theme);
    });
  });

  group('BrandConfig 白标 fixture', () {
    test('完整合法配置原样生效', () {
      final BrandConfig b = BrandConfig.fromJson(whiteLabelFixture());

      expect(b.siteName, '某企业IM');
      expect(b.logoUrl, 'https://cdn.example.com/logo.png');
      expect(b.splashUrl, 'https://cdn.example.com/splash.png');
      expect(b.primaryColor, const Color(0xFF1A73E8));
      expect(b.accentColor, const Color(0xFFFF6D00));
      expect(b.theme, BrandConfig.themeDark);
      expect(b.isDark, isTrue);
      expect(b.isWhiteLabelled, isTrue);
      expect(b.supportUrl, 'https://support.example.com');
      expect(b.privacyUrl, 'https://example.com/privacy');
      expect(b.edition, 'enterprise');
    });
  });

  group('BrandConfig 非法值逐字段回退', () {
    test('非法主色回退 App 主色', () {
      for (final Object? bad in <Object?>[
        '2474E5',
        '#2474E',
        '#GGGGGG',
        '#-12345',
        'blue',
        '',
        123,
        null,
      ]) {
        final BrandConfig b = BrandConfig.fromJson(<String, dynamic>{
          'primary_color': bad,
        });
        expect(
          b.primaryColor,
          AppColors.primary,
          reason: 'primary_color=$bad 应回退',
        );
      }
      // 大小写混合十六进制合法
      expect(
        BrandConfig.fromJson(<String, dynamic>{
          'primary_color': '#aAbBcC',
        }).primaryColor,
        const Color(0xFFAABBCC),
      );
    });

    test('非 http(s) 的 URL 一律视为未配置', () {
      const List<String> urlFields = <String>[
        'logo_url',
        'splash_url',
        'support_url',
        'privacy_url',
      ];
      const List<Object?> bad = <Object?>[
        'javascript:alert(1)',
        'data:text/html,<script>',
        'file:///etc/passwd',
        '//evil.example.com',
        '/relative/path.png',
        'https://',
        'http://',
        42,
        null,
      ];
      for (final String field in urlFields) {
        for (final Object? v in bad) {
          final BrandConfig b = BrandConfig.fromJson(<String, dynamic>{
            field: v,
          });
          expect(_urlOf(b, field), isEmpty, reason: '$field=$v 应被拒绝');
        }
        final BrandConfig ok = BrandConfig.fromJson(<String, dynamic>{
          field: 'https://ok.example.com/a.png',
        });
        expect(_urlOf(ok, field), 'https://ok.example.com/a.png');
      }
    });

    test('非法主题回退 light', () {
      for (final Object? bad in <Object?>['Dark', 'auto', '', 1, null]) {
        expect(
          BrandConfig.fromJson(<String, dynamic>{'theme': bad}).theme,
          BrandConfig.themeLight,
        );
      }
      expect(
        BrandConfig.fromJson(<String, dynamic>{'theme': 'dark'}).theme,
        BrandConfig.themeDark,
      );
    });

    test('空应用名回退 imboy', () {
      for (final Object? bad in <Object?>['', 0, null]) {
        expect(
          BrandConfig.fromJson(<String, dynamic>{'site_name': bad}).siteName,
          'imboy',
        );
      }
    });

    test('单个坏字段不污染其余合法字段', () {
      final BrandConfig b = BrandConfig.fromJson(<String, dynamic>{
        'site_name': '某企业IM',
        'primary_color': 'not-a-color',
        'logo_url': 'https://cdn.example.com/logo.png',
      });
      expect(b.siteName, '某企业IM');
      expect(b.logoUrl, 'https://cdn.example.com/logo.png');
      expect(b.primaryColor, AppColors.primary);
    });
  });

  group('BrandConfig copyWith', () {
    test('只替换指定字段', () {
      final BrandConfig b = BrandConfig.fallback.copyWith(siteName: 'X');
      expect(b.siteName, 'X');
      expect(b.primaryColor, BrandConfig.fallback.primaryColor);
      expect(b.supportUrl, BrandConfig.fallback.supportUrl);
    });
  });
}

String _urlOf(BrandConfig b, String field) {
  switch (field) {
    case 'logo_url':
      return b.logoUrl;
    case 'splash_url':
      return b.splashUrl;
    case 'support_url':
      return b.supportUrl;
    case 'privacy_url':
      return b.privacyUrl;
  }
  fail('未知字段 $field');
}
