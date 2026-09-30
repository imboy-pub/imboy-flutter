/// EPGZ-06 W3 — 主导航 OA Tab 注册接线测试（源码接线断言）
///
/// BottomNavigationPage 完整 mount 需 4 子页 WebSocket/Sqlite 副作用
/// （既有 bottom_navigation_page_test.dart 的同一定性），故本文件按仓内
/// 惯用法（glass_app_bar_policy_test.dart 的 readAsStringSync 接线断言）
/// 固化 OA Tab 的注册形态：
/// - 页面列表与导航项**成对**注册，且都由 `_isOaTabEnabled()` 门控
///   （BrandConfig 驱动显隐：未配置 OA 的构建 Tab 不出现）；
/// - 门控最终链到 [EnterpriseOaRuntimeConfig.runtimeEntryEnabled]
///   （fail-closed：origin 非法/SSO 字段残缺 → 隐藏，已由
///   enterprise_oa_runtime_config_test 单测覆盖）；
/// - Tab label 走白标 oaLabel + i18n 兜底；导航项 Key('tab_oa')。
library;

import 'dart:io' show File;

import 'package:flutter_test/flutter_test.dart';

void main() {
  final File navSource = File(
    'lib/page/bottom_navigation/bottom_navigation_page.dart',
  );

  test('源码在位（导航文件可读）', () {
    expect(navSource.existsSync(), isTrue);
  });

  test('页面列表注册 OaTabPage 且由 _isOaTabEnabled 门控', () {
    final String src = navSource.readAsStringSync();
    expect(
      src.contains("if (_isOaTabEnabled()) _buildOaPage(),") &&
          src.contains('CurrentOrganizationStore.forAccount(uid).listenable') &&
          src.contains("organizationId: org?.id ?? ''") &&
          src.contains('accountKey: uid'),
      isTrue,
      reason: 'OA Tab 页面须在 Mine 之前注册并受 BrandConfig 门控',
    );
  });

  test('导航项成对注册（图标/label/Key），与页面列表同一门控', () {
    final String src = navSource.readAsStringSync();
    expect(
      src.contains('if (_isOaTabEnabled())'),
      isTrue,
      reason: '页面列表与导航项必须成对门控，否则越界',
    );
    final int gateCount = '_isOaTabEnabled()'.allMatches(src).length;
    expect(gateCount, greaterThanOrEqualTo(3), reason: '定义 + 页面 + 导航项');
    expect(src.contains("const Key('tab_oa')"), isTrue);
    expect(src.contains('_oaTabLabel()'), isTrue);
  });

  test('门控实现链到 runtimeEntryEnabled（fail-closed 入口可见性）', () {
    final String src = navSource.readAsStringSync();
    expect(
      src.contains('bool _isOaTabEnabled() => _oaConfig.runtimeEntryEnabled;'),
      isTrue,
      reason: 'OA Tab 显隐唯一真源是 EnterpriseOaRuntimeConfig',
    );
    expect(
      src.contains('resolveEnterpriseOaRuntimeConfig()'),
      isTrue,
      reason: 'dart-define 编译期配置源，解析一次缓存',
    );
  });

  test('OA Tab 只 import 模块 barrel（分析器边界约定）', () {
    final String src = navSource.readAsStringSync();
    expect(
      src.contains("import 'package:imboy/modules/enterprise_oa/public.dart'"),
      isTrue,
    );
    // 不得深入模块内部路径（barrel 先例）。
    expect(
      src.contains('modules/enterprise_oa/presentation/'),
      isFalse,
      reason: '上层调用方只 import public.dart',
    );
  });
}
