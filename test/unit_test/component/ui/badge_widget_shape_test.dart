/// BadgeWidget 形状契约测试。
///
/// 修复前：未读角标是**竖椭圆**。高度 = 上下 padding + 文字行高，宽度 =
/// 左右 padding + 字宽，而数字的字宽比行高窄，实测 caption2 + padding:5
/// 得到 21.3 × 26.0。会话列表和底部导航「消息」用的是同一个组件，两处一起歪。
///
/// 修复后：有内容时高度锁定为 diameter、宽度 minWidth == diameter，
/// 1~2 位数是正圆，"99+" 这类超宽内容退化为胶囊（borderRadius 99，两端半圆）。
///
/// ⚠️ 断言避开绝对宽度：flutter_test 的默认字体把每个字形渲染成 1em 方块
/// （数字宽 11px，真机 PingFang 约 6.7px），拿测试里的宽度当真机值会误判。
/// 这里只钉"高度 == 直径"和"宽度 >= 高度"这两条与字体无关的不变量。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/badge_widget.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 未读角标的实际渲染盒（Stack 里唯一的 Container）。
Rect _badgeRect(WidgetTester tester) {
  return tester.getRect(
    find
        .descendant(of: find.byType(Stack), matching: find.byType(Container))
        .first,
  );
}

Future<void> _pumpBadge(
  WidgetTester tester, {
  Widget? content,
  EdgeInsetsGeometry padding = const EdgeInsets.all(5),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(
            body: Center(
              child: BadgeWidget(
                showBadge: true,
                content: content,
                padding: padding,
                child: const SizedBox(width: 56, height: 56),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _count(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
);

void main() {
  group('未读数角标形状', () {
    testWidgets('高度恒等于直径，不再被文字行高撑开', (tester) async {
      for (final t in ['1', '9', '12', '99+']) {
        await _pumpBadge(tester, content: _count(t));
        expect(
          _badgeRect(tester).height,
          18.0,
          reason: '"$t" 的高度应锁定为 18；被行高撑开就会变竖椭圆',
        );
      }
    });

    testWidgets('宽度永不小于高度（不会出现竖椭圆）', (tester) async {
      for (final t in ['1', '9', '12', '99+']) {
        await _pumpBadge(tester, content: _count(t));
        final r = _badgeRect(tester);
        expect(
          r.width,
          greaterThanOrEqualTo(r.height),
          reason: '"$t" 宽 ${r.width} < 高 ${r.height}，又变回竖椭圆了',
        );
      }
    });

    testWidgets('内容越长只横向变宽，高度不变（胶囊而非放大的圆）', (tester) async {
      await _pumpBadge(tester, content: _count('1'));
      final short = _badgeRect(tester);
      await _pumpBadge(tester, content: _count('99+'));
      final long = _badgeRect(tester);

      expect(long.height, short.height);
      expect(long.width, greaterThan(short.width));
    });

    testWidgets('调用方的 padding 不再影响高度（旧写法靠它撑圆，会撑歪）', (tester) async {
      await _pumpBadge(tester, content: _count('1'));
      final withDefault = _badgeRect(tester).height;
      await _pumpBadge(
        tester,
        content: _count('1'),
        padding: const EdgeInsets.all(12),
      );
      expect(_badgeRect(tester).height, withDefault);
    });

    testWidgets('大字号下直径跟随缩放，数字不会被挤掉', (tester) async {
      await _pumpBadge(
        tester,
        content: _count('1'),
        textScaler: const TextScaler.linear(1.5),
      );
      final r = _badgeRect(tester);
      expect(r.height, greaterThan(18.0));
      expect(r.width, greaterThanOrEqualTo(r.height));
    });

    testWidgets('缩放有上限，超大字号不会把角标撑得离谱', (tester) async {
      await _pumpBadge(
        tester,
        content: _count('1'),
        textScaler: const TextScaler.linear(4.0),
      );
      // clamp(1.0, 1.6) → 18 * 1.6
      expect(_badgeRect(tester).height, closeTo(18.0 * 1.6, 0.01));
    });
  });

  group('圆点角标（无 content）', () {
    testWidgets('尺寸只由 padding 决定，本来就是正方形 → 正圆', (tester) async {
      await _pumpBadge(tester, padding: const EdgeInsets.all(4));
      final r = _badgeRect(tester);
      expect(r.width, r.height);
      expect(r.width, 8.0);
    });
  });

  group('未读角标读屏语义（DESIGN.md 11.4）', () {
    testWidgets('传了 semanticLabel 就读「N 条未读」，不再念光秃秃的数字', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: BadgeWidget(
                semanticLabel: t.common.unreadCount(count: '5'),
                content: const Text('5'),
                child: const Icon(Icons.chat, key: Key('probe_child')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(t.common.unreadCount(count: '5')),
        findsOneWidget,
      );
      // 数字本身要被挡掉，否则读屏会连着念「5 条未读」和「5」。
      // 注意不能用 getSemantics(find.text('5')).label 判空——被 Exclude 掉的
      // 节点没有自己的语义节点，getSemantics 会上溯到外层，拿到的是那句标签。
      expect(
        find.bySemanticsLabel(RegExp(r'^5$')),
        findsNothing,
        reason: '内容未被 ExcludeSemantics 挡住，读屏会重复念数字',
      );

      handle.dispose();
    });

    testWidgets('不传 semanticLabel 时行为不变（老调用方不受影响）', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        TranslationProvider(
          child: const MaterialApp(
            home: Scaffold(
              body: BadgeWidget(
                content: const Text('7'),
                child: const Icon(Icons.chat),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSemantics(find.text('7')).label, '7');

      handle.dispose();
    });
  });
}
