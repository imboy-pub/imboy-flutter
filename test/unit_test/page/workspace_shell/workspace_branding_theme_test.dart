/// WP5 (T12) — Branding 主题作用域 widget 测试
///
/// 计划锚点（T12 VALIDATE）：两个不同 branding 的 workspace 切换，主题
/// 各自生效且不影响 Chat 区域（作用域只包 workspace_shell 子树）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace_shell/workspace_branding_theme.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// 读取子树内生效的 primary。
Color _primaryOf(WidgetTester tester, Key probeKey) {
  final ctx = tester.element(find.byKey(probeKey));
  return Theme.of(ctx).colorScheme.primary;
}

Widget _harness({required WorkspaceBranding branding, required Key probeKey}) {
  return MaterialApp(
    theme: ThemeData(colorSchemeSeed: const Color(0xFF2474E5)),
    home: WorkspaceBrandingScope(
      branding: branding,
      child: Builder(
        builder: (context) => Container(
          key: probeKey,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('workspace A 的 branding 主色在作用域内生效', (tester) async {
    await tester.pumpWidget(
      _harness(
        branding: const WorkspaceBranding(primaryColor: '#FF5733'),
        probeKey: const ValueKey('probe-a'),
      ),
    );
    expect(
      _primaryOf(tester, const ValueKey('probe-a')),
      const Color(0xFFFF5733),
    );
  });

  testWidgets('切换到 workspace B（不同 branding）后主色各自生效', (tester) async {
    final key = const ValueKey('probe-switch');
    await tester.pumpWidget(
      _harness(
        branding: const WorkspaceBranding(primaryColor: '#FF5733'),
        probeKey: key,
      ),
    );
    final primaryA = _primaryOf(tester, key);
    expect(primaryA, const Color(0xFFFF5733));

    // 切换工作区：换 branding 参数重建（模拟 shell selectWorkspace）
    await tester.pumpWidget(
      _harness(
        branding: const WorkspaceBranding(primaryColor: '#3366FF'),
        probeKey: key,
      ),
    );
    await tester.pumpAndSettle();
    expect(_primaryOf(tester, key), const Color(0xFF3366FF));
  });

  testWidgets('primaryColor 缺失/非法 → 回落默认主题色（不覆盖）', (tester) async {
    final key = const ValueKey('probe-invalid');
    await tester.pumpWidget(
      _harness(branding: const WorkspaceBranding(), probeKey: key),
    );
    final outside = _primaryOf(tester, key);

    // 非法色同样回落
    await tester.pumpWidget(
      _harness(
        branding: const WorkspaceBranding(primaryColor: 'oops'),
        probeKey: key,
      ),
    );
    expect(_primaryOf(tester, key), outside);
  });

  testWidgets('离开作用域（切回 Chat 区域）即还原默认主题色', (tester) async {
    final key = const ValueKey('probe-leave');
    final theme = ThemeData(colorSchemeSeed: const Color(0xFF2474E5));

    // 1) Chat 区域（无作用域）默认 primary
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) =>
              Container(key: key, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
    final chatPrimary = _primaryOf(tester, key);

    // 2) 进入 workspace 作用域（branding 覆盖）
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: WorkspaceBrandingScope(
          branding: const WorkspaceBranding(primaryColor: '#FF5733'),
          child: Builder(
            builder: (context) => Container(
              key: key,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
    expect(_primaryOf(tester, key), const Color(0xFFFF5733));

    // 3) 离开作用域（子树销毁，还原）
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) =>
              Container(key: key, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
    expect(_primaryOf(tester, key), chatPrimary);
  });
}
