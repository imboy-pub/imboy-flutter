import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/qrcode/user_qrcode_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: 'synthetic-qr-user',
    });
    await StorageService.init();
    await StorageService.setMap(Keys.currentUser, {
      'uid': 'synthetic-qr-user',
      'account': 'synthetic',
      'nickname': '合成用户长昵称 Long name 中文🙂',
      'avatar': '',
      'region': '合成地区',
      'gender': 0,
    });
  });

  Future<void> pump(
    WidgetTester tester,
    double width,
    Brightness brightness, {
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 700);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: UserQrCodePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final width in [280.0, 400.0, 1200.0]) {
      testWidgets('二维码卡限宽，长昵称与操作可达 $brightness $width', (tester) async {
        await pump(tester, width, brightness, scale: 2);
        final page = tester.widget<UserQrCodePage>(find.byType(UserQrCodePage));
        final card = find.byKey(page.globalKey);
        expect(tester.getSize(card).width, lessThanOrEqualTo(400));
        final qr = tester.widget<QrImageView>(find.byType(QrImageView));
        expect(qr.size, lessThanOrEqualTo(220));
        expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.H);
        expect(qr.backgroundColor, AppColors.lightSurface);
        expect(qr.eyeStyle.color, AppColors.lightTextPrimary);
        expect(qr.padding, const EdgeInsets.all(16));
        expect(
          find.descendant(of: card, matching: find.text(t.common.share)),
          findsNothing,
        );
        final save = find.widgetWithText(CupertinoButton, t.common.saveQrCode);
        final share = find.widgetWithText(CupertinoButton, t.common.share);
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(share.hitTestable(), findsOneWidget);
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(save).height, tester.getSize(share).height);
        expect(
          tester.widget<CupertinoButton>(save).color,
          AppColors.primaryDark,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('深色页面导出的名片仍是白底黑码，保留静区', (tester) async {
    await pump(tester, 1200, Brightness.dark);
    final page = tester.widget<UserQrCodePage>(find.byType(UserQrCodePage));
    final card = tester.getRect(find.byKey(page.globalKey));
    final qr = tester.getRect(find.byType(QrImageView));
    final bytes = await tester.runAsync(
      () async => await RepaintBoundaryHelper().image(
        tester.element(find.byType(UserQrCodePage)),
        page.globalKey,
      ),
    );
    expect(bytes, isNotNull);
    final image = img.decodePng(bytes!)!;
    expect(image.width, closeTo(card.width, 1));
    final quiet = image.getPixel(
      (qr.left - card.left + 8).round(),
      (qr.top - card.top + 8).round(),
    );
    expect([quiet.r, quiet.g, quiet.b, quiet.a], [255, 255, 255, 255]);
  });
}
