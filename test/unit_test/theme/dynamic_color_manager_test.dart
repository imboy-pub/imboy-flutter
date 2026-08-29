/// DynamicColorManager 单元测试。
///
/// 覆盖公开 API：instance / isDynamicColorSupported /
/// getDynamicColorSchemes / createColorScheme / clearCache /
/// getDynamicColorInfo。
///
/// 平台边界说明：动态取色仅 Android 12+ 可用（内部依赖
/// DynamicColorPlugin.getCorePalette 原生通道），单测宿主（macOS/Linux）
/// 必然走「不支持」分支——本文件聚焦该分支的契约与基础配色方案的
/// 正确性；Android 真机上的动态合并路径由真机回归覆盖，不在单测范围。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/dynamic_color_manager.dart';

void main() {
  // 单例的 _isDynamicColorSupported / 配色缓存是可变静态状态，
  // 每个用例前重置，避免用例间泄漏。
  setUp(DynamicColorManager.instance.clearCache);

  group('DynamicColorManager.instance', () {
    test('重复访问返回同一实例（单例）', () {
      final a = DynamicColorManager.instance;
      final b = DynamicColorManager.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('isDynamicColorSupported', () {
    test('非 Android 平台返回 false（单测宿主必然非 Android）', () async {
      final supported = await DynamicColorManager.instance
          .isDynamicColorSupported();
      expect(supported, isFalse);
    });

    test('多次调用结果一致（缓存后仍可用）', () async {
      final manager = DynamicColorManager.instance;
      final first = await manager.isDynamicColorSupported();
      final second = await manager.isDynamicColorSupported();
      expect(first, second);
    });
  });

  group('getDynamicColorSchemes', () {
    test('不支持动态颜色的平台返回 null', () async {
      final schemes = await DynamicColorManager.instance
          .getDynamicColorSchemes();
      expect(schemes, isNull);
    });
  });

  group('createColorScheme', () {
    test('亮色模式返回品牌基础配色方案', () async {
      final scheme = await DynamicColorManager.instance.createColorScheme(
        isDark: false,
      );

      expect(scheme.brightness, Brightness.light);
      // 主色系取自 AppColors 品牌 token
      expect(scheme.primary, AppColors.primary);
      expect(scheme.onPrimary, Colors.white);
      expect(scheme.secondary, AppColors.secondary);
      // 表面色系为亮色 token，而非暗色
      expect(scheme.surface, AppColors.lightSurface);
      expect(scheme.onSurface, AppColors.lightTextPrimary);
      expect(scheme.outline, AppColors.lightBorder);
    });

    test('暗色模式返回暗色基础配色方案', () async {
      final scheme = await DynamicColorManager.instance.createColorScheme(
        isDark: true,
      );

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, AppColors.primaryLight);
      expect(scheme.surface, AppColors.darkSurface);
      expect(scheme.onSurface, AppColors.darkTextPrimary);
      expect(scheme.outline, AppColors.darkBorder);
    });

    test('亮暗两套方案互不相同', () async {
      final light = await DynamicColorManager.instance.createColorScheme(
        isDark: false,
      );
      final dark = await DynamicColorManager.instance.createColorScheme(
        isDark: true,
      );

      expect(light.primary, isNot(dark.primary));
      expect(light.surface, isNot(dark.surface));
    });

    test('显式关闭动态颜色时仍返回完整基础方案', () async {
      final scheme = await DynamicColorManager.instance.createColorScheme(
        isDark: false,
        useDynamicColor: false,
      );

      expect(scheme.primary, AppColors.primary);
      expect(scheme.surface, AppColors.lightSurface);
    });
  });

  group('clearCache', () {
    test('清缓存后检测可重入且结果稳定', () async {
      final manager = DynamicColorManager.instance;

      // 首次探测会写入 _isDynamicColorSupported 缓存
      expect(await manager.isDynamicColorSupported(), isFalse);

      manager.clearCache();

      // 清空后立即重测，不应抛异常且口径不变
      expect(await manager.isDynamicColorSupported(), isFalse);
    });

    test('清缓存后 getDynamicColorInfo 仍可正常工作', () async {
      final manager = DynamicColorManager.instance;
      await manager.getDynamicColorInfo();

      manager.clearCache();

      final info = await manager.getDynamicColorInfo();
      expect(info['supported'], isFalse);
    });
  });

  group('getDynamicColorInfo', () {
    test('不支持的平台返回结构化诊断信息', () async {
      final info = await DynamicColorManager.instance.getDynamicColorInfo();

      expect(info['supported'], isFalse);
      expect(info['platform'], isA<String>());
      expect(info['platform'], isNotEmpty);
      expect(info['reason'], isA<String>());
      // reason 字段是给开发者看的人类可读说明
      expect(info['reason'], isNotEmpty);
    });

    test('不支持时不含配色字段（lightPrimary 等仅在支持分支返回）', () async {
      final info = await DynamicColorManager.instance.getDynamicColorInfo();

      expect(info.containsKey('lightPrimary'), isFalse);
      expect(info.containsKey('darkPrimary'), isFalse);
      expect(info.containsKey('error'), isFalse);
    });
  });
}
