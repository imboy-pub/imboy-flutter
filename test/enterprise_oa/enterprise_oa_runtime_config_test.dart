/// EPGZ-06 W3 — OA 运行时配置（dart-define 汇聚）测试
///
/// 覆盖：fromMap 解析（brand 字段透传 + SSO 字段）、fail-closed 入口
/// 可见性（origin 非法/key 残缺/redirect 不同源 → 隐藏）、缓存与复位。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';

/// 完整合法配置（gzCustomer 形态）。
Map<String, dynamic> fullGzDefines() => <String, dynamic>{
  'IMBOY_WL_FLAVOR': 'gzCustomer',
  'IMBOY_WL_APPLICATION_ID': 'com.customer.pkg.imboy',
  'IMBOY_WL_DISPLAY_NAME': '客户办公',
  'IMBOY_WL_OA_LABEL': '办公',
  'IMBOY_WL_OA_ORIGIN': 'https://oa.customer.example.com',
  'IMBOY_WL_OA_ENTRY_ENABLED': 'true',
  'IMBOY_WL_OA_APPLICATION_KEY': 'ak_gz_customer_01',
  'IMBOY_WL_OA_REDIRECT_URI': 'https://oa.customer.example.com/sso/landing',
};

void main() {
  setUp(resetEnterpriseOaRuntimeConfigForTest);
  tearDown(resetEnterpriseOaRuntimeConfigForTest);

  group('fromMap — brand 字段透传', () {
    test('完整配置：brand 各字段 + SSO 字段', () {
      final config = EnterpriseOaRuntimeConfig.fromMap(fullGzDefines());
      expect(config.brand.flavorId, 'gzCustomer');
      expect(config.brand.applicationIdOverride, 'com.customer.pkg.imboy');
      expect(config.brand.displayName, '客户办公');
      expect(config.brand.oaLabel, '办公');
      expect(config.brand.oaOrigin, 'https://oa.customer.example.com');
      expect(config.brand.oaEntryEnabled, isTrue);
      expect(config.applicationKey, 'ak_gz_customer_01');
      expect(config.redirectUri, 'https://oa.customer.example.com/sso/landing');
    });

    test('空 Map → fallback 形态（standard：无 OA Tab）', () {
      final config = EnterpriseOaRuntimeConfig.fromMap(<String, dynamic>{});
      // BrandConfig 未覆写 ==（值对象按字段断言）。
      expect(config.brand.flavorId, 'standard');
      expect(config.brand.applicationIdOverride, isEmpty);
      expect(config.brand.oaOrigin, isEmpty);
      expect(config.brand.oaEntryEnabled, isFalse);
      expect(config.applicationKey, isEmpty);
      expect(config.redirectUri, isEmpty);
      expect(config.runtimeEntryEnabled, isFalse);
    });
  });

  group('runtimeEntryEnabled — fail-closed 入口可见性', () {
    test('完整配置 → 可见', () {
      expect(
        EnterpriseOaRuntimeConfig.fromMap(fullGzDefines()).runtimeEntryEnabled,
        isTrue,
      );
    });

    test('oa_entry_enabled 未开 → 隐藏', () {
      final defines = fullGzDefines()..['IMBOY_WL_OA_ENTRY_ENABLED'] = 'false';
      expect(
        EnterpriseOaRuntimeConfig.fromMap(defines).runtimeEntryEnabled,
        isFalse,
      );
    });

    test('origin 非 https → brand.oaEntryEnabled 已 false（W1 规则）→ 隐藏', () {
      final defines = fullGzDefines()
        ..['IMBOY_WL_OA_ORIGIN'] = 'http://oa.customer.example.com';
      final config = EnterpriseOaRuntimeConfig.fromMap(defines);
      expect(config.brand.oaEntryEnabled, isFalse);
      expect(config.runtimeEntryEnabled, isFalse);
    });

    test('application_key 残缺（<8 字符）→ 隐藏（SSO 必然失败不放行）', () {
      final defines = fullGzDefines()
        ..['IMBOY_WL_OA_APPLICATION_KEY'] = 'short';
      final config = EnterpriseOaRuntimeConfig.fromMap(defines);
      expect(config.brand.oaEntryEnabled, isTrue);
      expect(config.ssoConfigComplete, isFalse);
      expect(config.runtimeEntryEnabled, isFalse);
    });

    test('application_key 缺失 → 隐藏', () {
      final defines = fullGzDefines()..remove('IMBOY_WL_OA_APPLICATION_KEY');
      expect(
        EnterpriseOaRuntimeConfig.fromMap(defines).runtimeEntryEnabled,
        isFalse,
      );
    });

    test('redirect_uri 不同源（子域仿冒）→ 隐藏', () {
      final defines = fullGzDefines()
        ..['IMBOY_WL_OA_REDIRECT_URI'] =
            'https://oa.customer.example.com.evil.com/sso/landing';
      final config = EnterpriseOaRuntimeConfig.fromMap(defines);
      expect(config.redirectUriMatchesOrigin, isFalse);
      expect(config.runtimeEntryEnabled, isFalse);
    });

    test('redirect_uri 同 host 不同端口 → 隐藏（exact origin 含端口）', () {
      final defines = fullGzDefines()
        ..['IMBOY_WL_OA_REDIRECT_URI'] =
            'https://oa.customer.example.com:8443/sso/landing';
      expect(
        EnterpriseOaRuntimeConfig.fromMap(defines).runtimeEntryEnabled,
        isFalse,
      );
    });

    test('redirect_uri 带路径合法（origin 比较不含 path）', () {
      final defines = fullGzDefines()
        ..['IMBOY_WL_OA_REDIRECT_URI'] =
            'https://oa.customer.example.com/a/b/c';
      expect(
        EnterpriseOaRuntimeConfig.fromMap(defines).runtimeEntryEnabled,
        isTrue,
      );
    });
  });

  group('isValidApplicationKey — 合同区间', () {
    test('8..128 字符合法；边界外非法', () {
      expect(EnterpriseOaRuntimeConfig.isValidApplicationKey('a' * 8), isTrue);
      expect(
        EnterpriseOaRuntimeConfig.isValidApplicationKey('a' * 128),
        isTrue,
      );
      expect(EnterpriseOaRuntimeConfig.isValidApplicationKey('a' * 7), isFalse);
      expect(
        EnterpriseOaRuntimeConfig.isValidApplicationKey('a' * 129),
        isFalse,
      );
    });

    test('含空白非法（防 dart-define 注入畸形值）', () {
      expect(
        EnterpriseOaRuntimeConfig.isValidApplicationKey('abcd efgh'),
        isFalse,
      );
      expect(
        EnterpriseOaRuntimeConfig.isValidApplicationKey('ab\ncdefgh'),
        isFalse,
      );
    });
  });

  group('resolveEnterpriseOaRuntimeConfig — 缓存语义', () {
    test('同进程重复解析返回同一实例（编译期常量源，无热切换）', () {
      final a = resolveEnterpriseOaRuntimeConfig();
      final b = resolveEnterpriseOaRuntimeConfig();
      expect(identical(a, b), isTrue);
      // 未注入 dart-define 的测试构建 = fallback（入口隐藏）。
      expect(a.runtimeEntryEnabled, isFalse);
    });
  });

  group('oaTabLabel — 白标 label', () {
    test('label 透传；空串由导航层 i18n 兜底', () {
      expect(
        EnterpriseOaRuntimeConfig.fromMap(fullGzDefines()).oaTabLabel,
        '办公',
      );
      expect(
        EnterpriseOaRuntimeConfig.fromMap(
          fullGzDefines()..['IMBOY_WL_OA_LABEL'] = '',
        ).oaTabLabel,
        isEmpty,
      );
    });
  });
}
