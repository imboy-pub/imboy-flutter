/// 钉住 `QrLoginConfirmContent` 的渲染 + 交互契约（slice-3 RED）。
///
/// 受控模式：父层持有 state + 三个回调（onConfirm/onCancel/onClose），
/// Widget 本身无状态。便于 widget test 不依赖 Riverpod / HTTP / 路由。
///
/// 验证点：
///   1. 10 个状态变体下的关键 UI 元素可见性
///   2. AwaitingConfirm 状态下 deviceInfo 可选渲染（null / 仅 name / 完整）
///   3. tap 交互回调正确触发（按钮可点）
///   4. 终态（Success / 错误状态）显示关闭按钮且语义清晰
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/scanner/qr_login_confirm_content.dart';
import 'package:imboy/page/scanner/qr_login_confirm_rules.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  QrLoginConfirmContent build(
    QrLoginConfirmState state, {
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    VoidCallback? onClose,
  }) {
    return QrLoginConfirmContent(
      state: state,
      onConfirm: onConfirm ?? () {},
      onCancel: onCancel ?? () {},
      onClose: onClose ?? () {},
    );
  }

  group('QrLoginConfirmContent — 渲染（按状态）', () {
    testWidgets('Idle → 显示加载指示器', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmIdle())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Scanning → 显示加载指示器', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmScanning())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'AwaitingConfirm（无 deviceInfo）→ 显示标题 + 确认按钮 + 取消按钮',
      (tester) async {
        await tester.pumpWidget(
          wrap(build(const QrLoginConfirmAwaitingConfirm())),
        );
        // 关键 UI 元素可见
        expect(find.text('Web 端登录确认'), findsOneWidget);
        expect(find.text('确认登录'), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
      },
    );

    testWidgets(
      'AwaitingConfirm + deviceInfo → 显示设备名称卡片',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            build(
              const QrLoginConfirmAwaitingConfirm(
                deviceInfo: QrLoginDeviceInfo(
                  deviceName: 'Chrome 120',
                  platform: 'web',
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('Chrome 120'), findsOneWidget);
      },
    );

    testWidgets('Confirming → 显示加载指示器（登录中）', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmConfirming())));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Success → 显示成功 icon + 文案', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmSuccess())));
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('Expired → 显示"已过期"文案 + 关闭按钮', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmExpired())));
      expect(find.textContaining('过期'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('AlreadyUsed → 显示"已使用"文案 + 关闭按钮', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmAlreadyUsed())));
      expect(find.textContaining('已使用'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('CancelledByMe → 显示"已取消"文案', (tester) async {
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmCancelledByMe())),
      );
      expect(find.textContaining('已取消'), findsOneWidget);
    });

    testWidgets(
      'CancelledByOther → 显示"已取消"文案 + 关闭按钮',
      (tester) async {
        await tester.pumpWidget(
          wrap(build(const QrLoginConfirmCancelledByOther())),
        );
        expect(find.textContaining('已取消'), findsOneWidget);
        expect(find.text('关闭'), findsOneWidget);
      },
    );

    testWidgets('Failed(msg) → 显示自定义 msg + 关闭按钮', (tester) async {
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmFailed('网络错误'))),
      );
      expect(find.text('网络错误'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });
  });

  group('QrLoginConfirmContent — 交互回调', () {
    testWidgets('AwaitingConfirm tap "确认登录" → onConfirm 被调用', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        wrap(
          build(
            const QrLoginConfirmAwaitingConfirm(),
            onConfirm: () => called++,
          ),
        ),
      );
      await tester.tap(find.text('确认登录'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('AwaitingConfirm tap "取消" → onCancel 被调用', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        wrap(
          build(
            const QrLoginConfirmAwaitingConfirm(),
            onCancel: () => called++,
          ),
        ),
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('Failed tap "关闭" → onClose 被调用', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        wrap(
          build(
            const QrLoginConfirmFailed('网络错误'),
            onClose: () => called++,
          ),
        ),
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('Expired tap "关闭" → onClose 被调用', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        wrap(
          build(const QrLoginConfirmExpired(), onClose: () => called++),
        ),
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets(
      'Confirming 状态：tap 确认按钮无反应（按钮已被替换为 loading）',
      (tester) async {
        var confirmed = 0;
        await tester.pumpWidget(
          wrap(
            build(
              const QrLoginConfirmConfirming(),
              onConfirm: () => confirmed++,
            ),
          ),
        );
        // 验证确认按钮已不存在
        expect(find.text('确认登录'), findsNothing);
        expect(confirmed, 0);
      },
    );
  });

  group('QrLoginConfirmContent — 触达可访问性', () {
    testWidgets('确认按钮 minHeight ≥ 44pt（iOS HIG / Material a11y）', (tester) async {
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmAwaitingConfirm())),
      );
      final size = tester.getSize(find.text('确认登录'));
      // 文本本身不必 44pt，但其父按钮容器需 ≥44pt
      // 通过 InkWell / Material 的祖先尺寸验证
      final btnSize = tester.getSize(
        find.ancestor(
          of: find.text('确认登录'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(btnSize.height, greaterThanOrEqualTo(44.0));
      expect(size.width, greaterThan(0)); // sanity
    });
  });
}
