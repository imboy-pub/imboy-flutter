/// 钉住 `QrLoginConfirmContent` 的渲染 + 交互契约（slice-3 RED）。
///
/// 受控模式：父层持有 state + 四个回调（onConfirm/onCancel/onClose/
/// onAcknowledged），Widget 本身无状态。便于 widget test 不依赖
/// Riverpod / HTTP / 路由。
///
/// 验证点：
///   1. 10 个状态变体下的关键 UI 元素可见性
///   2. AwaitingConfirm 状态下 deviceInfo 可选渲染（null / 仅 name / 完整）
///   3. tap 交互回调正确触发（按钮可点）
///   4. 错误终态显示关闭按钮且语义清晰；Success 显示"已登录"+"我知道了"
///      （2026-11-19 起：成功态不自动退栈，改为显式确认终点）
library;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/scanner/qr_login_confirm_content.dart';
import 'package:imboy/page/scanner/qr_login_confirm_rules.dart';
import 'package:imboy/theme/default/app_colors.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  QrLoginConfirmContent build(
    QrLoginConfirmState state, {
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    VoidCallback? onClose,
    VoidCallback? onAcknowledged,
  }) {
    return QrLoginConfirmContent(
      state: state,
      onConfirm: onConfirm ?? () {},
      onCancel: onCancel ?? () {},
      onClose: onClose ?? () {},
      onAcknowledged: onAcknowledged ?? () {},
    );
  }

  group('QrLoginConfirmContent — 渲染（按状态）', () {
    testWidgets('Idle → 显示加载指示器', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmIdle())));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('Scanning → 显示加载指示器', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmScanning())));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('AwaitingConfirm（无 deviceInfo）→ 显示标题 + 确认按钮 + 取消按钮', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmAwaitingConfirm())),
      );
      // 关键 UI 元素可见
      expect(find.text('Web 端登录确认'), findsOneWidget);
      expect(find.text('确认登录'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('AwaitingConfirm + deviceInfo → 显示设备名称卡片', (tester) async {
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
    });

    testWidgets('Confirming → 显示加载指示器（登录中）', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmConfirming())));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    });

    testWidgets('Success → 绿色圆勾 + "已登录" + "我知道了"按钮', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmSuccess())));
      expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsOneWidget);
      expect(find.text('已登录'), findsOneWidget);
      expect(find.text('我知道了'), findsOneWidget);
      // 错误终态的"关闭"按钮在成功态不应出现
      expect(find.text('关闭'), findsNothing);
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
      await tester.pumpWidget(wrap(build(const QrLoginConfirmCancelledByMe())));
      expect(find.textContaining('已取消'), findsOneWidget);
    });

    testWidgets('CancelledByOther → 显示"已取消"文案 + 关闭按钮', (tester) async {
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmCancelledByOther())),
      );
      expect(find.textContaining('已取消'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('Failed(msg) → 显示自定义 msg + 关闭按钮', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmFailed('网络错误'))));
      expect(find.text('网络错误'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });
  });

  group('QrLoginConfirmContent — 终态无假成功投影（UX-01:LOCAL:01）', () {
    // 错误/取消终态绝不允许出现成功元素：绿勾、"已登录"、"我知道了"。
    // 任何一项泄漏都构成「假登录成功」投影。
    final errorTerminals = <String, QrLoginConfirmState>{
      'Expired': const QrLoginConfirmExpired(),
      'AlreadyUsed': const QrLoginConfirmAlreadyUsed(),
      'CancelledByOther': const QrLoginConfirmCancelledByOther(),
      'Failed': const QrLoginConfirmFailed('服务器错误'),
    };

    for (final entry in errorTerminals.entries) {
      testWidgets('${entry.key} → 无成功图标/已登录/我知道了，保留关闭恢复入口', (tester) async {
        await tester.pumpWidget(wrap(build(entry.value)));
        expect(
          find.byIcon(CupertinoIcons.checkmark_circle_fill),
          findsNothing,
          reason: '${entry.key} 是错误终态，不得出现成功勾',
        );
        expect(
          find.text('已登录'),
          findsNothing,
          reason: '${entry.key} 不得显示已登录（假登录成功）',
        );
        expect(find.text('我知道了'), findsNothing);
        expect(
          find.text('确认登录'),
          findsNothing,
          reason: '${entry.key} 已终态，不得再提供确认入口',
        );
        expect(
          find.text('关闭'),
          findsOneWidget,
          reason: '${entry.key} 必须保留真实恢复入口（关闭后可重扫码）',
        );
      });
    }

    testWidgets('CancelledByMe → 无成功元素（用户主动取消不是成功）', (tester) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmCancelledByMe())));
      expect(find.byIcon(CupertinoIcons.checkmark_circle_fill), findsNothing);
      expect(find.text('已登录'), findsNothing);
      expect(find.text('我知道了'), findsNothing);
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
          build(const QrLoginConfirmFailed('网络错误'), onClose: () => called++),
        ),
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('Success tap "我知道了" → onAcknowledged 被调用', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        wrap(
          build(const QrLoginConfirmSuccess(), onAcknowledged: () => called++),
        ),
      );
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('Success 我知道了按钮 minHeight ≥ 44pt（iOS HIG a11y）', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(build(const QrLoginConfirmSuccess())));
      final btnSize = tester.getSize(
        find.ancestor(
          of: find.text('我知道了'),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(btnSize.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('Expired tap "关闭" → onClose 被调用', (tester) async {
      var called = 0;
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmExpired(), onClose: () => called++)),
      );
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('Confirming 状态：tap 确认按钮无反应（按钮已被替换为 loading）', (tester) async {
      var confirmed = 0;
      await tester.pumpWidget(
        wrap(
          build(const QrLoginConfirmConfirming(), onConfirm: () => confirmed++),
        ),
      );
      // 验证确认按钮已不存在
      expect(find.text('确认登录'), findsNothing);
      expect(confirmed, 0);
    });
  });

  group('QrLoginConfirmContent — 触达可访问性', () {
    testWidgets('short viewport and large text keep both actions reachable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var confirmed = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: build(
            const QrLoginConfirmAwaitingConfirm(
              deviceInfo: QrLoginDeviceInfo(
                deviceName: 'A long desktop device name for confirmation',
                platform: 'macOS',
              ),
            ),
            onConfirm: () => confirmed++,
            onCancel: () => cancelled++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('确认登录'));
      await tester.tap(find.text('确认登录'));
      await tester.ensureVisible(find.text('取消'));
      await tester.tap(find.text('取消'));
      expect(confirmed, 1);
      expect(cancelled, 1);
    });

    testWidgets('device card uses the dark grouped surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: build(
            const QrLoginConfirmAwaitingConfirm(
              deviceInfo: QrLoginDeviceInfo(deviceName: 'Dark device'),
            ),
          ),
        ),
      );
      final card = tester.widget<Container>(
        find
            .ancestor(
              of: find.textContaining('Dark device'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (card.decoration! as BoxDecoration).color,
        AppColors.getSurfaceGrouped(Brightness.dark),
      );
    });

    testWidgets('确认按钮 minHeight ≥ 44pt（iOS HIG / Material a11y）', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmAwaitingConfirm())),
      );
      final size = tester.getSize(find.text('确认登录'));
      // 文本本身不必 44pt，但其父按钮容器需 ≥44pt
      // 通过 InkWell / Material 的祖先尺寸验证
      final btnSize = tester.getSize(
        find.ancestor(
          of: find.text('确认登录'),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(btnSize.height, greaterThanOrEqualTo(44.0));
      expect(size.width, greaterThan(0)); // sanity
    });

    testWidgets('实底确认按钮文字显式 onPrimary（防实底彩底叠主题字色回归）', (tester) async {
      await tester.pumpWidget(
        wrap(build(const QrLoginConfirmAwaitingConfirm())),
      );
      final text = tester.widget<Text>(find.text('确认登录'));
      expect(
        text.style?.color,
        AppColors.onPrimary,
        reason:
            'primary 实底按钮文字必须显式白色，'
            'context.textStyle 携带主题字色会叠出红/蓝底彩字（注销账号页同款 bug）',
      );
    });
  });
}
