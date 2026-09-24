import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/i18n/strings.g.dart';

/// ENT-FND-02 — AsyncStateView 四态（Loading/Permission/Error/Empty）单测。
///
/// 覆盖：每态独占渲染、权限态优先于错误态、权限态不渲染重试入口
/// （403 是终态，重试不改变结果）、默认文案取 t.common（zh-CN base）。
void main() {
  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('loading 态渲染指示器且不渲染内容', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AsyncStateView(
          isLoading: true,
          isEmpty: false,
          child: Text('CONTENT'),
        ),
      ),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('CONTENT'), findsNothing);
  });

  testWidgets('permission 态渲染默认权限文案与锁图标，无重试入口', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      wrap(
        AsyncStateView(
          isLoading: false,
          permissionDenied: true,
          isEmpty: false,
          onRetry: () => retried = true,
          child: const Text('CONTENT'),
        ),
      ),
    );
    expect(find.text(t.common.noPermission), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_fill), findsOneWidget);
    expect(find.text('CONTENT'), findsNothing);
    // 权限态不引导重试：默认重试文案（t.common.buttonRetry）不应出现。
    expect(find.text(t.common.buttonRetry), findsNothing);
    expect(retried, isFalse);
  });

  testWidgets('permission 态支持自定义文案与图标', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AsyncStateView(
          isLoading: false,
          permissionDenied: true,
          isEmpty: false,
          permissionText: '仅限本组织在职成员',
          permissionIcon: CupertinoIcons.lock_shield,
          child: SizedBox.shrink(),
        ),
      ),
    );
    expect(find.text('仅限本组织在职成员'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_shield), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_fill), findsNothing);
  });

  testWidgets('permission 优先于 error（同持两者按权限态呈现）', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AsyncStateView(
          isLoading: false,
          error: 'network down',
          permissionDenied: true,
          isEmpty: false,
          child: SizedBox.shrink(),
        ),
      ),
    );
    expect(find.text(t.common.noPermission), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
  });

  testWidgets('error 态渲染默认错误文案与重试入口，回调可达', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        AsyncStateView(
          isLoading: false,
          error: StateError('boom'),
          isEmpty: false,
          onRetry: () => retried++,
          child: const Text('CONTENT'),
        ),
      ),
    );
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.exclamationmark_circle), findsOneWidget);
    expect(find.text('CONTENT'), findsNothing);
    await tester.tap(find.text(t.common.buttonRetry));
    expect(retried, 1);
  });

  testWidgets('error 态支持自定义错误文案', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AsyncStateView(
          isLoading: false,
          error: 'x',
          isEmpty: false,
          errorText: '依赖事实不可用',
          child: SizedBox.shrink(),
        ),
      ),
    );
    expect(find.text('依赖事实不可用'), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
  });

  testWidgets('empty 态渲染默认空态文案且无重试入口', (tester) async {
    await tester.pumpWidget(
      wrap(
        AsyncStateView(
          isLoading: false,
          isEmpty: true,
          onRetry: () {},
          child: const Text('CONTENT'),
        ),
      ),
    );
    expect(find.text(t.common.noData), findsOneWidget);
    expect(find.text(t.common.buttonRetry), findsNothing);
    expect(find.text('CONTENT'), findsNothing);
  });

  testWidgets('四态皆否时渲染 child（content 态）', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AsyncStateView(
          isLoading: false,
          isEmpty: false,
          child: Text('CONTENT'),
        ),
      ),
    );
    expect(find.text('CONTENT'), findsOneWidget);
    expect(find.text(t.common.noData), findsNothing);
    expect(find.text(t.common.noPermission), findsNothing);
  });
}
