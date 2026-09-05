import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';

/// P6/W7 RTL 专项回归测试。
///
/// 背景：lib/run.dart 曾在 MaterialApp 之上包裹全局
/// Directionality(TextDirection.ltr)，压过 MaterialApp 依据 locale 注入的
/// 方向，ar-SA 整树被强制 LTR。修复后方向由
/// MaterialApp + GlobalWidgetsLocalizations 依据 locale 决定。
///
/// 本文件复刻 run.dart 的本地化配置（同一组 delegates +
/// slang 生成的 supportedLocales），验证：
///   1. en-US → LTR
///   2. zh-CN → LTR
///   3. ar-SA → RTL
///   4. 运行时切换 locale 后方向随之更新
///   5. 防回归：lib/run.dart 不得再出现全局 Directionality 包裹
void main() {
  Future<TextDirection> pumpProbe(WidgetTester tester, Locale locale) async {
    TextDirection? dir;
    await tester.pumpWidget(
      MaterialApp(
        // 与 lib/run.dart 相同的本地化配置
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocaleUtils.supportedLocales,
        locale: locale,
        home: Builder(
          builder: (context) {
            dir = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return dir!;
  }

  testWidgets('en-US resolves to LTR', (tester) async {
    expect(
      await pumpProbe(tester, const Locale('en', 'US')),
      TextDirection.ltr,
    );
  });

  testWidgets('zh-CN resolves to LTR', (tester) async {
    expect(
      await pumpProbe(tester, const Locale('zh', 'CN')),
      TextDirection.ltr,
    );
  });

  testWidgets('ar-SA resolves to RTL', (tester) async {
    expect(
      await pumpProbe(tester, const Locale('ar', 'SA')),
      TextDirection.rtl,
    );
  });

  testWidgets('runtime locale switch updates direction', (tester) async {
    TextDirection? dir;
    Locale current = const Locale('zh', 'CN');

    // 模拟 run.dart 的模式：Stateful locale 字段 + setState 触发重建
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: current,
          home: Builder(
            builder: (context) {
              dir = Directionality.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dir, TextDirection.ltr, reason: 'zh-CN 初始应为 LTR');

    // 运行时切到 ar-SA（等价于 LocaleSettings.setLocale(AppLocale.arSa)）
    current = const Locale('ar', 'SA');
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          key: const ValueKey('rebuild'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: current,
          home: Builder(
            builder: (context) {
              dir = Directionality.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dir, TextDirection.rtl, reason: '运行时切到 ar-SA 后应变 RTL');
  });

  test(
    'guard: lib/run.dart must not wrap the app in a global Directionality',
    () {
      final code = File('lib/run.dart')
          .readAsLinesSync()
          // 剔除注释行，只检查真实代码
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code.contains('Directionality('),
        isFalse,
        reason:
            'run.dart 曾用全局 Directionality(TextDirection.ltr) 压过 '
            'locale 驱动的方向。方向必须交给 MaterialApp 的本地化机制；'
            '个别字段需要固定 LTR 时应在字段级 widget 局部包裹。',
      );
    },
  );
}
