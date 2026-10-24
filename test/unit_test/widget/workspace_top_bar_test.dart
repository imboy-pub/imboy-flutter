// WorkspaceTopBar 单元/组件测试（T06 / imboyapp-uiux-v1）。
//
// 覆盖：subtitle 为空保持 44pt 单行（零回归基线）、subtitle 非空双行
// 52pt、长文本省略不溢出、深浅色副行用次级文本色、leading/actions
// 布局不受 subtitle 影响。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/workspace_shell/workspace_top_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';

Widget _wrap({
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('WorkspaceTopBar 单行基线（subtitle 缺省）', () {
    testWidgets('无 subtitle：高度 44 且无副行文本', (tester) async {
      await tester.pumpWidget(_wrap(child: const WorkspaceTopBar(title: '消息')));

      final bar = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(bar.height, 44);
      expect(find.text('消息'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('空字符串 subtitle 视同无副行', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const WorkspaceTopBar(title: '通讯录', subtitle: ''),
        ),
      );

      final bar = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(bar.height, 44);
    });
  });

  group('WorkspaceTopBar 双行上下文（spec D1）', () {
    testWidgets('subtitle 非空：高度 52 且两级文本可见', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const WorkspaceTopBar(title: '消息', subtitle: '深圳云科技 · 主工作区'),
        ),
      );

      final bar = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(bar.height, 52);
      expect(find.text('消息'), findsOneWidget);
      expect(find.text('深圳云科技 · 主工作区'), findsOneWidget);
    });

    testWidgets('仅单段上下文时不产生孤立分隔符', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const WorkspaceTopBar(title: '工作台', subtitle: '深圳云科技'),
        ),
      );

      expect(find.text('深圳云科技'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('超长上下文省略号截断不横向溢出', (tester) async {
      const longCtx = '一个特别特别长的企业名称有限公司 · 一个特别特别长的工作区名称用于验证截断';
      await tester.pumpWidget(
        _wrap(
          child: SizedBox(
            width: 320,
            child: Column(
              children: const [WorkspaceTopBar(title: '消息', subtitle: longCtx)],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final ctx = tester.widget<Text>(find.text(longCtx));
      expect(ctx.overflow, TextOverflow.ellipsis);
    });

    testWidgets('深色模式副行使用次级文本色', (tester) async {
      await tester.pumpWidget(
        _wrap(
          brightness: Brightness.dark,
          child: const WorkspaceTopBar(title: '消息', subtitle: '企业 · 工作区'),
        ),
      );

      final ctx = tester.widget<Text>(find.text('企业 · 工作区'));
      expect(ctx.style?.color, AppColors.darkTextSecondary);
    });

    testWidgets('浅色模式副行使用次级文本色', (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: const WorkspaceTopBar(title: '消息', subtitle: '企业 · 工作区'),
        ),
      );

      final ctx = tester.widget<Text>(find.text('企业 · 工作区'));
      expect(ctx.style?.color, AppColors.lightTextSecondary);
    });

    testWidgets('leading 与 actions 在双行模式下正常布局', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          child: WorkspaceTopBar(
            title: '消息',
            subtitle: '企业 · 工作区',
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => tapped = true,
            ),
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: () {}),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.menu));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('WorkspaceTopBar 几何（右对齐 / 绝对居中）', () {
    // 回归钉：中央槽位曾是 loose Flexible，未用满的宽度堆在 Row 末尾，
    // 导致只有右侧动作时按钮离屏缘 ~28pt、标题左偏。
    for (final width in [360.0, 528.0, 1024.0]) {
      testWidgets('仅右侧动作时按钮贴边、标题居中（宽 $width）', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _wrap(
            child: WorkspaceTopBar(
              title: '通讯录',
              subtitle: 'org117 · 工作区：默认工作区',
              actions: [
                SizedBox(
                  key: const ValueKey('topbar-action'),
                  width: 44,
                  height: 44,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.person_add),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        );

        final bar = tester.getRect(find.byType(WorkspaceTopBar));
        final action = tester.getRect(
          find.byKey(const ValueKey('topbar-action')),
        );
        expect(action.right, moreOrLessEquals(bar.right, epsilon: 0.5));
        final title = tester.getRect(find.text('通讯录'));
        expect(title.center.dx, moreOrLessEquals(bar.center.dx, epsilon: 1.0));
        final subtitle = tester.getRect(find.text('org117 · 工作区：默认工作区'));
        expect(
          subtitle.center.dx,
          moreOrLessEquals(bar.center.dx, epsilon: 1.0),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('leading 与 actions 同时存在：leading 距左 8、actions 贴右', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _wrap(
          child: WorkspaceTopBar(
            title: '消息',
            leading: SizedBox(
              key: const ValueKey('topbar-leading'),
              width: 44,
              height: 44,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.menu),
                onPressed: () {},
              ),
            ),
            actions: [
              SizedBox(
                key: const ValueKey('topbar-action'),
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      );

      final bar = tester.getRect(find.byType(WorkspaceTopBar));
      final leading = tester.getRect(
        find.byKey(const ValueKey('topbar-leading')),
      );
      final action = tester.getRect(
        find.byKey(const ValueKey('topbar-action')),
      );
      expect(leading.left, moreOrLessEquals(bar.left + 8, epsilon: 0.5));
      expect(action.right, moreOrLessEquals(bar.right, epsilon: 0.5));
      expect(
        tester.getRect(find.text('消息')).center.dx,
        moreOrLessEquals(bar.center.dx, epsilon: 1.0),
      );
    });
  });
}
