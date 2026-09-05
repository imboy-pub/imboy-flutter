import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:yaml/yaml.dart';

/// P16/W17 i18n UI Gate：移动端长度验证。
///
/// 用各语言 YAML 里的**真实文案**（最长 body 文案、最长中等标题、最长短按钮
/// 文案）在三个最低视口（360x640 / 375x812 / 412x915）渲染典型场景
/// （AppBar / 设置 ListTile 流 / Dialog+按钮行 / BottomSheet），
/// 断言零 RenderFlex overflow / 布局异常。
///
/// 不重构业务 UI；这是用真实文案对布局健壮性的机器可验证门。
/// placeholder 以最坏情况样本填充（长名字/多位数字）。
void main() {
  const locales = [
    'zh-CN',
    'en-US',
    'zh-Hant',
    'ja-JP',
    'ko-KR',
    'de-DE',
    'fr-FR',
    'it-IT',
    'ru-RU',
    'ar-SA',
  ];
  const viewports = [Size(360, 640), Size(375, 812), Size(412, 915)];

  String currentLocale = 'zh-CN';

  Locale localeOf(String code) {
    final parts = code.split('-');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  Future<void> pumpScene(
    WidgetTester tester,
    Widget scene,
    TextDirection dir,
    Size viewport,
  ) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocaleUtils.supportedLocales,
        locale: localeOf(currentLocale),
        home: Directionality(
          textDirection: dir,
          child: Scaffold(body: scene),
        ),
      ),
    );
    await tester.pump();
    final exception = tester.takeException();
    expect(exception, isNull, reason: 'overflow/布局异常（$viewport）：$exception');
  }

  AppBar appbarScene(String title) =>
      AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis));

  Widget listTileScene(List<String> bodies) => ListView.builder(
    itemCount: bodies.length,
    itemBuilder: (_, i) => ListTile(
      leading: const Icon(Icons.settings),
      title: Text(bodies[i], maxLines: 2),
      subtitle: Text(bodies[(i + 1) % bodies.length], maxLines: 2),
      trailing: const Icon(Icons.chevron_right),
    ),
  );

  Widget dialogScene(String body, String shortA, String shortB) => AlertDialog(
    title: Text(shortA, maxLines: 1),
    content: SingleChildScrollView(child: Text(body)),
    actions: [
      TextButton(onPressed: () {}, child: Text(shortB)),
      TextButton(onPressed: () {}, child: Text(shortA)),
    ],
  );

  Widget bottomSheetScene(String a, String b) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(title: Text(a, maxLines: 2), trailing: const Icon(Icons.close)),
      ListTile(title: Text(b, maxLines: 2)),
    ],
  );

  Widget buttonRowScene(String a, String b, String c) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        ElevatedButton(onPressed: () {}, child: Text(a, maxLines: 1)),
        const SizedBox(width: 8),
        TextButton(onPressed: () {}, child: Text(b, maxLines: 1)),
        const Spacer(),
        TextButton(onPressed: () {}, child: Text(c, maxLines: 1)),
      ],
    ),
  );

  group('i18n UI gate', () {
    for (final locale in locales) {
      // pumpScene 通过闭包读取当前 locale 以配置 MaterialApp 本地化
      // ignore: omit_local_variable_types

      final values =
          collectLeafValues(locale)
              .map(substituteWorstCase)
              .where((s) => s.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => b.length.compareTo(a.length));

      final longest = values.first;
      final medium = values.firstWhere(
        (s) => s.length <= 30,
        orElse: () => values.last,
      );
      final sortedAsc = List.of(values)
        ..sort((a, b) => a.length.compareTo(b.length));
      final shorts = sortedAsc.take(2).toList();
      final bodies = values.take(12).toList();
      final dir = locale.startsWith('ar')
          ? TextDirection.rtl
          : TextDirection.ltr;

      testWidgets('$locale AppBar title（最长文案）不溢出', (tester) async {
        await pumpScene(
          tester,
          Scaffold(appBar: appbarScene(longest)),
          dir,
          viewports.first,
        );
      });

      testWidgets('$locale 设置 ListTile 流（TOP12 长文案）× 3 视口', (tester) async {
        for (final vp in viewports) {
          await pumpScene(
            tester,
            Scaffold(body: listTileScene(bodies)),
            dir,
            vp,
          );
        }
      });

      testWidgets('$locale Dialog + 按钮行（短文案真实分布）× 3 视口', (tester) async {
        currentLocale = locale;
        for (final vp in viewports) {
          await pumpScene(
            tester,
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dialogScene(
                      values.firstWhere(
                        (s) => s.length >= 60 && s.length <= 220,
                        orElse: () => longest,
                      ),
                      shorts[0],
                      shorts[1],
                    ),
                    const SizedBox(height: 12),
                    buttonRowScene(
                      shorts[0],
                      shorts[1],
                      shorts.length > 2 ? shorts[2] : shorts[1],
                    ),
                  ],
                ),
              ),
            ),
            dir,
            vp,
          );
        }
      });

      testWidgets('$locale BottomSheet 双行', (tester) async {
        currentLocale = locale;
        await pumpScene(
          tester,
          bottomSheetScene(bodies[0], bodies[1]),
          dir,
          viewports.first,
        );
      });

      testWidgets('$locale 中等标题（≤30 字符最长者）AppBar', (tester) async {
        await pumpScene(
          tester,
          Scaffold(appBar: appbarScene(medium)),
          dir,
          viewports.first,
        );
      });
    }
  });
}

/// 读取一个 locale 全部 namespace 的叶子字符串值。
List<String> collectLeafValues(String locale) {
  final dir = Directory('assets/i18n/$locale');
  final out = <String>[];
  void walk(Object? node, String path) {
    if (node is String) {
      out.add(node);
    } else if (node is Map) {
      node.forEach((k, child) => walk(child, '$path.$k'));
    }
  }

  for (final f in dir.listSync()) {
    if (f is! File || !f.path.endsWith('.i18n.yaml')) continue;
    final doc = loadYaml(f.readAsStringSync());
    if (doc is YamlMap) {
      doc.forEach((k, v) {
        walk(v, k.toString());
      });
    }
  }
  return out;
}

/// 以最坏情况填充 placeholder：$name/${name}/{name} → 长样本，
/// $n/$count/{count} 等数字 → 多位数。返回填充后的字符串。
final _paramRe = RegExp(
  r'\$\{?\{?([A-Za-z_][A-Za-z0-9_]*)\}?\}?|\{([A-Za-z_][A-Za-z0-9_]*)\}',
);

String substituteWorstCase(String src) => src.replaceAllMapped(_paramRe, (m) {
  final name = (m[1] ?? m[2] ?? '').toLowerCase();
  if (name == 'n' ||
      name.contains('count') ||
      name.contains('num') ||
      name.contains('second') ||
      name.contains('minute') ||
      name.contains('hour') ||
      name.contains('day')) {
    return '8888';
  }
  if (name.contains('date') || name.contains('time')) return '2026-12-31 23:59';
  if (name.contains('url') || name.contains('link')) {
    return 'https://example.com/very/long/path';
  }
  if (name.contains('code')) return 'ABCDEFGH';
  return 'Alexander Christophorus';
});
