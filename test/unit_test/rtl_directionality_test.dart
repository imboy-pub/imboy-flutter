import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
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

  // ------------------------------------------------------------
  // FL-16:LOCAL:06 十语 locale、质量回退和 RTL
  //   locale 映射显式；缺失/暂定可区分；语言切换不改 ID；
  //   阿语 RTL、Unicode 和长名称可用。
  // ------------------------------------------------------------

  /// 显式期望表：业务申报的十个 locale（slang 配置 + assets/i18n 目录）
  /// 与语言/国家/文字子标签的映射必须一字不差，不允许隐式推导。
  const explicitLocaleTags = <AppLocale, (String, String?, String?)>{
    AppLocale.zhCn: ('zh', 'CN', null),
    AppLocale.arSa: ('ar', 'SA', null),
    AppLocale.deDe: ('de', 'DE', null),
    AppLocale.enUs: ('en', 'US', null),
    AppLocale.frFr: ('fr', 'FR', null),
    AppLocale.itIt: ('it', 'IT', null),
    AppLocale.jaJp: ('ja', 'JP', null),
    AppLocale.koKr: ('ko', 'KR', null),
    AppLocale.ruRu: ('ru', 'RU', null),
    // zh-Hant 靠 script 子标签区分于 zh-CN，丢失 script 会静默解析成 zh-CN。
    AppLocale.zhHant: ('zh', null, 'Hant'),
  };

  test('FL-16:LOCAL:06 十语 locale 映射显式（枚举=目录=flutter Locale）', () {
    expect(AppLocale.values, hasLength(10), reason: '十 locale 是产品承诺');

    // 枚举 → language/script/country 映射显式。
    for (final entry in explicitLocaleTags.entries) {
      final locale = entry.key;
      final (lang, country, script) = entry.value;
      expect(locale.languageCode, lang, reason: '$locale languageCode');
      expect(locale.countryCode, country, reason: '$locale countryCode');
      expect(locale.scriptCode, script, reason: '$locale scriptCode');
      final flutter = locale.flutterLocale;
      expect(flutter.languageCode, lang);
      expect(flutter.countryCode, country);
      expect(flutter.scriptCode, script);
    }

    // supportedLocales 与 assets/i18n 目录一一对应：目录里多/少一个 locale
    // 都会让映射失效（新增语言没翻译，或翻译了没接线）。
    final dirTags = Directory('assets/i18n')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2])
        .toSet();
    final enumTags = explicitLocaleTags.keys.map((l) {
      final (lang, country, script) = explicitLocaleTags[l]!;
      return country != null ? '$lang-$country' : '$lang-${script!}';
    }).toSet();
    expect(enumTags, dirTags, reason: 'AppLocale 枚举与 assets/i18n 目录必须一致');

    // MaterialApp 接线用的 supportedLocales 覆盖全部十语。
    final supportedRaw = AppLocaleUtils.supportedLocalesRaw.toSet();
    expect(supportedRaw, containsAll(enumTags));
    expect(supportedRaw, hasLength(10));
  });

  test('FL-16:LOCAL:06 质量回退策略显式声明（base_locale + fallback）', () {
    // 回退策略必须留在 slang.yaml 里被显式声明，不允许"删了配置悄悄换行为"。
    final raw = File('slang.yaml').readAsStringSync();
    expect(raw, contains('base_locale: zh-CN'));
    expect(raw, contains('fallback_strategy: base_locale'));
  });

  test('FL-16:LOCAL:06 缺失回退可解析、真实翻译可区分（非整仓复制）', () async {
    // 抽查 key：高可见 UI 文案，每个 locale 的 yaml 里都有真实翻译。
    const probeKeys = ['chat.titleMessage', 'common.accept'];
    final base = await AppLocale.zhCn.build();
    final baseTitle = base['chat.titleMessage'].toString();
    final baseAccept = base['common.accept'].toString();
    expect(baseTitle, '消息');
    expect(baseAccept, '接受');

    for (final locale in AppLocale.values) {
      final translations = await locale.build();
      for (final key in probeKeys) {
        // 缺失时按 fallback_strategy 回退 base：解析必须得到非空字符串，
        // 不允许 null/崩溃把整页文案打穿。
        final value = translations[key];
        expect(
          value,
          isA<String>().having((s) => s.trim().isNotEmpty, 'non-empty', isTrue),
          reason: '$locale $key 应可解析（缺失回退 base 而非空值）',
        );
      }
      if (locale == AppLocale.zhCn) continue;
      // 真实翻译与 base 可区分：抽查 key 在每个非 base locale 都不是
      // base 值——若生成流程退化成整仓复制（丢失翻译），这里立即红。
      expect(
        translations['chat.titleMessage'],
        isNot(baseTitle),
        reason: '$locale chat.titleMessage 应是真实翻译而非 base 回退',
      );
      expect(
        translations['common.accept'],
        isNot(baseAccept),
        reason: '$locale common.accept 应是真实翻译而非 base 回退',
      );
    }
  });

  testWidgets('FL-16:LOCAL:06 语言切换不改业务 ID（RTL 切换逐字保留）', (tester) async {
    // 业务标识（TSID 长整型、消息 ID、会话键）与 locale 无关：
    // 切语言只允许改变方向/文案，不允许让任何 ID 走一遍格式化。
    const fixedIds = [
      '758234659001234567', // TSID 风格 64-bit 整型（JSON integer 传输）
      'IMBOY-MSG-0192.758234659001234.987654321098', // msgId 样例
      'u-001/C2C', // 会话选择键
    ];
    var current = const Locale('zh', 'CN');
    late String rendered;

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
              rendered = fixedIds.join('|');
              return Column(
                children: [
                  for (final id in fixedIds)
                    Text(id, textDirection: TextDirection.ltr),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = rendered;
    var dir = Directionality.of(tester.element(find.text(fixedIds.first)));
    expect(dir, TextDirection.ltr);

    // 切到 ar-SA：方向翻转，但 ID 逐字不变。
    current = const Locale('ar', 'SA');
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          key: const ValueKey('fl16-locale-switch'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: current,
          home: Builder(
            builder: (context) {
              rendered = fixedIds.join('|');
              return Column(
                children: [
                  for (final id in fixedIds)
                    Text(id, textDirection: TextDirection.ltr),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(rendered, before, reason: '语言切换不得改写任何业务 ID');
    dir = Directionality.of(tester.element(find.text(fixedIds.first)));
    expect(dir, TextDirection.rtl, reason: '切到 ar-SA 后整树应 RTL');
    for (final id in fixedIds) {
      expect(find.text(id), findsOneWidget, reason: 'ID 文本必须完整保留');
    }
  });

  testWidgets('FL-16:LOCAL:06 Unicode 混排与长名称在 LTR/RTL 下可用', (tester) async {
    // 十语里最坏的文本形态：CJK + 阿拉伯文 + 西里尔 + emoji（含 ZWJ/代理对）
    // + 超长拉丁名。RTL 下渲染不得异常、rune 不得丢失。
    const unicodeName =
        '陈伟 Alexander Christophorus محمد عبد الرحمن '
        'Александр Игоревич 👨‍👩‍👧‍👦 🇨🇳 🇸🇦 ok';
    final expectedRunes = unicodeName.runes.length;

    for (final locale in [const Locale('zh', 'CN'), const Locale('ar', 'SA')]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: locale,
          home: Scaffold(
            body: ListView(
              children: [
                Text(unicodeName),
                const Text('Alexander Christophorus Иванов محمد'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$locale 渲染不得布局异常');
      final text = tester.widget<Text>(find.text(unicodeName));
      expect(
        text.data!.runes.length,
        expectedRunes,
        reason: '$locale 下 rune 不得丢失（代理对/ZWJ 完整）',
      );
    }
  });
}
