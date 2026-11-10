import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/page/passport/widget/web_login_layout.dart';

class _LayoutQrLogin extends QRLogin {
  @override
  QRLoginState build() => const QRLoginState(qrData: 'synthetic-layout-qr');

  // Web initState and the switch-back action share this boundary; neither
  // starts HTTP, polling, expiry timers or SSE in a layout test.
  @override
  Future<void> generateQRCode() async {}
}

class _LayoutPassport extends PassportNotifier {
  @override
  PassportState build() {
    final controller = TextEditingController();
    ref.onDispose(controller.dispose);
    return PassportState(loginAccountCtl: controller);
  }
}

void main() {
  for (final width in [320.0, 800.0, 899.0, 900.0, 1200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('WebLoginPage $width / $scale：二维码完整并可实际切换密码登录', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              qRLoginProvider.overrideWith(_LayoutQrLogin.new),
              passportProvider.overrideWith(_LayoutPassport.new),
            ],
            child: MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: TranslationProvider(child: child!),
              ),
              home: const WebLoginPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('ImBoy Web'),
          width >= 900 ? findsOneWidget : findsNothing,
        );
        final panelBounds = tester.getRect(find.byType(WebLoginLayout));
        expect(panelBounds.width, width);
        expect(panelBounds.left, 0);
        final qr = find.byType(QrImageView);
        expect(qr, findsOneWidget);
        final frame = find.ancestor(
          of: qr,
          matching: find.byType(Container),
        ).first;
        await tester.ensureVisible(frame);
        await tester.pumpAndSettle();
        expect(tester.getSize(frame), const Size(256, 256));
        expect(tester.getSize(qr), const Size(224, 224));
        final bounds = tester.getRect(frame);
        expect(bounds.left, greaterThanOrEqualTo(-0.01));
        expect(bounds.right, lessThanOrEqualTo(width + 0.01));
        expect(bounds.top, greaterThanOrEqualTo(-0.01));
        expect(bounds.bottom, lessThanOrEqualTo(480.01));
        expect(tester.takeException(), isNull);

        final passwordAction = find.widgetWithText(
          CupertinoButton,
          t.account.webSwitchToPassword,
        );
        await tester.ensureVisible(passwordAction);
        await tester.pumpAndSettle();
        await tester.tap(passwordAction);
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsNothing);
        expect(find.text(t.account.webPasswordLoginTitle), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(tester.getRect(find.byType(WebLoginLayout)), panelBounds);

        final qrAction = find.widgetWithText(
          CupertinoButton,
          t.main.webSwitchToQR,
        );
        await tester.ensureVisible(qrAction);
        await tester.pumpAndSettle();
        await tester.tap(qrAction);
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
