import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';

class _RecoverableImageFile extends Fake implements File {
  Uint8List? bytes;
  int reads = 0;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    final value = bytes;
    if (value == null) throw const FileSystemException('Missing fixture');
    return value;
  }
}

CupertinoButton _button(WidgetTester tester, String label) =>
    tester.widget<CupertinoButton>(
      find.ancestor(of: find.text(label), matching: find.byType(CupertinoButton)),
    );

void main() {
  setUp(() async {
    await StorageService.to.setString(Keys.currentUid, '990041');
    expect(authSessionReader.current.uid, '990041');
    expect(authSessionReader.current.transitioning, isFalse);
  });

  tearDown(() async {
    await StorageService.to.remove(Keys.currentUid);
  });

  testWidgets('missing image can recover on retry with safe large-text actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = _RecoverableImageFile();

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 34),
              textScaler: TextScaler.linear(2.5),
            ),
            child: child!,
          ),
          home: CropImageRoute(image, 'avatar'),
        ),
      ),
    );
    await tester.pump();

    expect(image.reads, 1);
    expect(find.text(t.common.imageLoadFailed), findsOneWidget);
    expect(find.text(t.common.buttonRetry), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(_button(tester, t.common.buttonAccomplish).onPressed, isNull);
    expect(_button(tester, t.common.buttonCancel).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    // Restore a valid PNG through the same File.readAsBytes boundary; no media,
    // filesystem, upload, or network capability is exercised by this fixture.
    image.bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGN0av3C'
      'gA0wYRUdtBIAXQcBy0IK/PYAAAAASUVORK5CYII=',
    );
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(image.reads, 2);
    expect(find.byType(Crop), findsOneWidget);
    expect(find.text(t.common.imageLoadFailed), findsNothing);
    expect(_button(tester, t.common.buttonAccomplish).onPressed, isNotNull);
    for (final label in [t.common.buttonCancel, t.common.buttonAccomplish]) {
      final action = find.ancestor(
        of: find.text(label),
        matching: find.byType(CupertinoButton),
      );
      final rect = tester.getRect(action);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.bottom, lessThanOrEqualTo(480 - 34));
      expect(rect.height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
