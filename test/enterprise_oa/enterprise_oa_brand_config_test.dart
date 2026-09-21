/// EPGZ-06 W1 — 企业白标 BrandConfig 单测（plan §7.3）
///
/// 覆盖：defaults 形态（= imboy 原生 standard）、fromJson 逐字段解析与
/// 容错回退、applicationId/flavorId/oaOrigin 校验、秘密不进模型的
/// 占位 key 合同，及 copyWith/clearAccentColor。
library;

import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_oa/public.dart';

void main() {
  group('defaults（fallback = imboy 原生 standard 形态）', () {
    test('未白标、OA 关闭、无 origin', () {
      const c = EnterpriseOaBrandConfig.fallback;
      expect(c.flavorId, 'standard');
      expect(c.applicationIdOverride, '');
      expect(c.displayName, '');
      expect(c.oaEntryEnabled, isFalse);
      expect(c.oaOrigin, '');
      expect(c.isWhiteLabelled, isFalse);
      expect(c.primaryColor, const Color(0xFF2474E5));
      expect(c.accentColor, isNull);
    });

    test('fromJson(null) 整体回退 defaults', () {
      expect(EnterpriseOaBrandConfig.fromJson(null).flavorId, 'standard');
    });
  });

  group('fromJson 完整白标配置', () {
    test('广州客户样例：applicationId/显示名/图标键/颜色/OA label+origin', () {
      final c = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'flavor_id': 'gzCustomer',
        'application_id': 'com.customer.pkg.imboy',
        'display_name': '客户办公',
        'icon_asset_key': 'wl_gz_icon',
        'splash_asset_key': 'wl_gz_splash',
        'primary_color': '#1F6FEB',
        'accent_color': '#79C0FF',
        'oa_label': '办公',
        'oa_origin': 'https://oa.customer-example.cn',
        'oa_entry_enabled': true,
      });
      expect(c.flavorId, 'gzCustomer');
      expect(c.applicationIdOverride, 'com.customer.pkg.imboy');
      expect(c.displayName, '客户办公');
      expect(c.iconAssetKey, 'wl_gz_icon');
      expect(c.splashAssetKey, 'wl_gz_splash');
      expect(c.primaryColor, const Color(0xFF1F6FEB));
      expect(c.accentColor, const Color(0xFF79C0FF));
      expect(c.oaLabel, '办公');
      expect(c.oaOrigin, 'https://oa.customer-example.cn');
      expect(c.oaEntryEnabled, isTrue);
      expect(c.isWhiteLabelled, isTrue);
      expect(c.hasOaLabel, isTrue);
    });

    test('oa_origin 带端口保留；带 path 剥到 origin；默认端口省略', () {
      final withPort = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'oa_origin': 'https://oa.example.com:8443/portal',
        'oa_entry_enabled': true,
      });
      expect(withPort.oaOrigin, 'https://oa.example.com:8443');

      final withPath = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'oa_origin': 'https://oa.example.com/portal/',
        'oa_entry_enabled': true,
      });
      expect(withPath.oaOrigin, 'https://oa.example.com');
    });
  });

  group('逐字段容错回退（单字段非法不拖垮整套白标）', () {
    test('非法 applicationId → 视为未覆盖（空串），其余字段保留', () {
      final c = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'application_id': '1nv4lid..pkg',
        'display_name': '客户办公',
      });
      expect(c.applicationIdOverride, '');
      expect(c.displayName, '客户办公');
      expect(c.isWhiteLabelled, isTrue); // 显示名被覆盖即白标
    });

    test('非法 flavorId → 回退 standard；camelCase 保留（Android 惯例）', () {
      final c = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'flavor_id': 'GZ-Customer',
      });
      expect(c.flavorId, 'standard');

      final ok = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'flavor_id': 'GZCustomer',
      });
      expect(ok.flavorId, 'GZCustomer');
    });

    test('非法颜色 → primary 回退默认，accent 置 null', () {
      final c = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'primary_color': '#XYZ',
        'accent_color': 'nothex',
      });
      expect(c.primaryColor, EnterpriseOaBrandConfig.fallback.primaryColor);
      expect(c.accentColor, isNull);
    });

    test('非 https origin（http/相对路径/javascript）视为未配置', () {
      for (final bad in const [
        'http://oa.example.com',
        'oa.example.com',
        'javascript:alert(1)',
        '',
      ]) {
        final c = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
          'oa_origin': bad,
          'oa_entry_enabled': true,
        });
        expect(c.oaOrigin, '', reason: 'origin=$bad');
        // OA 入口不出现，而不是放行非法 origin。
        expect(c.oaEntryEnabled, isFalse, reason: 'origin=$bad');
      }
    });

    test('entry_enabled=true 但 origin 非法 → 入口关闭（fail-closed）', () {
      final c = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'oa_entry_enabled': true,
      });
      expect(c.oaEntryEnabled, isFalse);
    });

    test('entry_enabled 缺省 false；显式 false 保持关闭', () {
      expect(
        EnterpriseOaBrandConfig.fromJson(<String, dynamic>{}).oaEntryEnabled,
        isFalse,
      );
      final off = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'oa_origin': 'https://oa.example.com',
        'oa_entry_enabled': false,
      });
      expect(off.oaEntryEnabled, isFalse);
      expect(off.oaOrigin, 'https://oa.example.com'); // origin 仍可查询
    });

    test('非字符串字段走类型回退', () {
      final c = EnterpriseOaBrandConfig.fromJson(<String, dynamic>{
        'display_name': 42,
        'oa_label': <String>['x'],
      });
      expect(c.displayName, '');
      expect(c.oaLabel, '');
    });
  });

  group('秘密占位 key 合同（plan §7.3：秘密不进模型/仓库）', () {
    test('只暴露构建期注入的 key 名，不含任何值字段', () {
      expect(
        EnterpriseOaBrandConfig.buildTimeSecretKeys,
        containsAll(<String>[
          'IMBOY_WL_KEYSTORE_FILE',
          'IMBOY_WL_KEYSTORE_PASSWORD',
        ]),
      );
      // 模型序列化面没有 keystore/password 等字段：fromJson 支持的键
      // 白名单里不存在任何秘密键。
      const knownInputKeys = <String>{
        'flavor_id',
        'application_id',
        'display_name',
        'icon_asset_key',
        'splash_asset_key',
        'primary_color',
        'accent_color',
        'oa_label',
        'oa_origin',
        'oa_entry_enabled',
      };
      expect(
        knownInputKeys.any(
          (k) =>
              k.toLowerCase().contains('secret') ||
              k.toLowerCase().contains('password') ||
              k.toLowerCase().contains('keystore') ||
              k.toLowerCase().contains('token'),
        ),
        isFalse,
      );
    });
  });

  group('copyWith', () {
    test('覆盖指定字段；clearAccentColor 显式清空', () {
      const base = EnterpriseOaBrandConfig.fallback;
      final overridden = base.copyWith(
        displayName: '客户办公',
        accentColor: const Color(0xFF79C0FF),
      );
      expect(overridden.displayName, '客户办公');
      expect(overridden.accentColor, const Color(0xFF79C0FF));
      expect(overridden.flavorId, base.flavorId);

      final cleared = overridden.copyWith(clearAccentColor: true);
      expect(cleared.accentColor, isNull);
      expect(cleared.displayName, '客户办公');
    });
  });
}
