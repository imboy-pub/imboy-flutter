import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/permission_gate.dart';

/// ENT-FND-02 — PermissionGate widget 测试。
///
/// 覆盖：放行透传 / hide 策略（默认隐藏 + deniedReplacement 占位）/
/// disable 策略（可见但 IgnorePointer + 半透明 + Semantics 禁用）。
/// 权限判定回调由页面注入——此处验证回调求值与两种降级形态。
void main() {
  const gateChild = Text('ADMIN_ACTION');

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('判定通过时原样渲染 child', (tester) async {
    await tester.pumpWidget(
      wrap(const PermissionGate(check: _allow, child: gateChild)),
    );
    expect(find.text('ADMIN_ACTION'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('hide 策略：判定失败时不渲染 child（默认收縮为空）', (tester) async {
    await tester.pumpWidget(
      wrap(const PermissionGate(check: _deny, child: gateChild)),
    );
    // 默认占位是 SizedBox.shrink，不产生溢出/异常。
    expect(find.text('ADMIN_ACTION'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hide 策略：支持注入 deniedReplacement 占位', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PermissionGate(
          check: _deny,
          deniedReplacement: Text('需要管理员权限'),
          child: gateChild,
        ),
      ),
    );
    expect(find.text('ADMIN_ACTION'), findsNothing);
    expect(find.text('需要管理员权限'), findsOneWidget);
  });

  testWidgets('disable 策略：child 可见但不可交互且降透明', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        PermissionGate(
          check: _deny,
          behavior: PermissionGateBehavior.disable,
          child: TextButton(
            onPressed: () => tapped++,
            child: const Text('ADMIN_ACTION'),
          ),
        ),
      ),
    );
    // 可见性保留。
    expect(find.text('ADMIN_ACTION'), findsOneWidget);
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 0.4);
    // 交互被阻断：tap 落在 IgnorePointer 上，回调不可达。
    await tester.tap(find.text('ADMIN_ACTION'));
    expect(tapped, 0);
    // 无障碍层同步禁用（enabled 是 tri-state，未显式 false 的隐式
    // Semantics 不算命中，避免误配到框架内置节点）。
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.enabled == false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('判定回调在 build 时求值：同一 gate 随开关翻转', (tester) async {
    var allowed = false;
    await tester.pumpWidget(
      wrap(PermissionGate(check: () => allowed, child: gateChild)),
    );
    expect(find.text('ADMIN_ACTION'), findsNothing);
    allowed = true;
    await tester.pumpWidget(
      wrap(PermissionGate(check: () => allowed, child: gateChild)),
    );
    expect(find.text('ADMIN_ACTION'), findsOneWidget);
  });
}

bool _allow() => true;
bool _deny() => false;
