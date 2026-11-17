import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';

/// A11Y-02 AN1：设置 tile 语义打包回归测试。
///
/// 缺陷背景（runs/a11y0405-06-20261116/a11y02-verdict.json AN1）：
/// settings tile role=button 但 aria-label 为空，可访问名只存在于
/// DOM textContent（子文本节点），探针 has_aria_label=false。
///
/// 修复契约：纯文本标题/副标题/值组合成单一可访问名挂 button 节点
/// （web 引擎渲染为 aria-label），被并名的可见文本用 ExcludeSemantics
/// 排除，避免「label + textContent」双重播报；非文本副标题（开关/下拉）
/// 保持自身语义节点。
Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.iOS, useMaterial3: true),
  home: Scaffold(body: ListView(children: [child])),
);

void main() {
  testWidgets('可点 tile 的可访问名并入 button 节点，可见文本不再单独成节点', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        DetailSettingsTile(
          title: const Text('深色模式'),
          value: '已关闭',
          onTap: () => taps++,
        ),
      ),
    );

    // 1) button 节点携带完整组合名（web 引擎渲染为 aria-label）
    final node = tester.getSemantics(find.text('深色模式'));
    expect(node.getSemanticsData().label, '深色模式\n已关闭');
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);

    // 2) 无重复命名节点：单独的「深色模式」或「已关闭」语义节点不存在
    expect(
      find.bySemanticsLabel(RegExp('^深色模式\$')),
      findsNothing,
      reason: '标题不应残留独立语义节点（双重播报）',
    );
    expect(
      find.bySemanticsLabel(RegExp('^已关闭\$')),
      findsNothing,
      reason: '值不应残留独立语义节点（双重播报）',
    );

    // 3) 激活路径保持不变
    await tester.tap(find.text('深色模式'));
    expect(taps, 1);
  });

  testWidgets('副标题并入命名，Center 包裹的纯文本标题（destructive）同样并名', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            DetailSettingsTile(
              title: const Text('允许搜索我'),
              subtitle: const Text('其他用户可以在搜索中找到我'),
              onTap: () {},
            ),
            DetailSettingsTile(
              title: Center(child: const Text('退出登录')),
              destructive: true,
              trailing: const SizedBox.shrink(),
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('允许搜索我')).getSemanticsData().label,
      '允许搜索我\n其他用户可以在搜索中找到我',
    );
    expect(
      tester.getSemantics(find.text('退出登录')).getSemanticsData().label,
      '退出登录',
    );
  });

  testWidgets('非文本副标题（开关）保持自身语义节点，不被并名排除', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      _wrap(
        DetailSettingsTile(
          title: const Text('允许搜索我'),
          trailing: CupertinoSwitch(
            value: false,
            onChanged: (v) => toggled = v,
          ),
          onTap: null,
        ),
      ),
    );

    // 行节点有名（仅标题），开关仍可独立找到并交互
    final row = tester.getSemantics(find.text('允许搜索我'));
    expect(row.getSemanticsData().label, '允许搜索我');
    expect(row.getSemanticsData().flagsCollection.isButton, isFalse);

    await tester.tap(find.byType(CupertinoSwitch));
    expect(toggled, isTrue);
  });

  testWidgets('只读 tile（无 onTap）不声明 button 角色，仍有可访问名', (tester) async {
    await tester.pumpWidget(
      _wrap(DetailSettingsTile(title: const Text('账号'), value: 'w13e_webmvp')),
    );

    final node = tester.getSemantics(find.text('账号'));
    expect(node.getSemanticsData().label, '账号\nw13e_webmvp');
    expect(node.getSemanticsData().flagsCollection.isButton, isFalse);
  });

  testWidgets('非纯文本标题回退既有结构：不并名、不排除、文本可见', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DetailSettingsTile(
          title: Row(
            children: const [
              Icon(CupertinoIcons.globe, size: 16),
              SizedBox(width: 6),
              Text('自定义行'),
            ],
          ),
          onTap: () {},
        ),
      ),
    );

    // 旧行为：文本仍在（视觉不丢）且 Text 节点保持独立语义（未被错误排除）
    expect(find.text('自定义行'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^自定义行\$')), findsOneWidget);
  });
}
