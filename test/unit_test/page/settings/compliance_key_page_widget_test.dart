import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/compliance_key_page.dart';
import 'package:imboy/service/compliance_key_service.dart';

import '../../../secure_storage_test_pin.dart';

// Display-only synthetic material: the page hashes and presents this fixture;
// it never performs encryption or contacts a key service in these tests.
const _publicKey =
    '-----BEGIN PUBLIC KEY-----\n'
    'U1lOVEhFVElDX0xBWU9VVF9GSVhUVVJFX09OTFk=\n'
    '-----END PUBLIC KEY-----';

Future<void> _pumpPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double scale = 2,
}) async {
  tester.view.physicalSize = const Size(320, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: TranslationProvider(child: child!),
      ),
      home: const ComplianceKeyPage(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secureStore = <String, String?>{};

  setUp(() {
    LocaleSettings.setLocaleRaw('zh-CN');
    secureStore.clear();
    ComplianceKeyService.instance.clearCache();
    ComplianceKeyService.debugFetcher = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final args = call.arguments as Map<Object?, Object?>?;
          switch (call.method) {
            case 'write':
              secureStore[args!['key'] as String] = args['value'] as String?;
              return null;
            case 'read':
              return secureStore[args!['key'] as String];
            case 'delete':
              secureStore.remove(args!['key'] as String);
              return null;
            case 'deleteAll':
              secureStore.clear();
              return null;
            case 'readAll':
              return Map<String, String?>.from(secureStore);
            case 'containsKey':
              return secureStore.containsKey(args!['key'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    ComplianceKeyService.instance.clearCache();
    ComplianceKeyService.debugFetcher = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  for (final brightness in Brightness.values) {
    testWidgets('合规密钥 $brightness / 2倍字号：指纹完整可选择，说明可滚动到达', (
      tester,
    ) async {
      var fetches = 0;
      ComplianceKeyService.debugFetcher = () async {
        fetches++;
        return {
          'key_id': 'synthetic-compliance-key',
          'public_key': _publicKey,
          'algorithm': 'RSA-OAEP-256',
          'created_at': '2026-11-10T00:00:00Z',
        };
      };
      await _pumpPage(tester, brightness: brightness);
      expect(fetches, 1);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      final fingerprint = ComplianceKeyService.fingerprintOf(_publicKey);
      final serverSection = find.widgetWithText(
        ImBoySettingsSection,
        t.main.complianceKeyInfoServerKey,
      );
      final displayedFingerprint = find.descendant(
        of: serverSection,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText &&
              widget.data?.replaceAll(' ', '') == fingerprint,
        ),
      );
      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(
        displayedFingerprint,
        150,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(displayedFingerprint, findsOneWidget);
      final text = tester.widget<SelectableText>(displayedFingerprint);
      expect(text.data!.replaceAll(' ', ''), hasLength(64));
      final editorFinder = find.descendant(
        of: displayedFingerprint,
        matching: find.byType(EditableText),
      );
      final editor = tester.widget<EditableText>(editorFinder);
      expect(editor.maxLines, isNull);
      expect(editor.controller.text.replaceAll(' ', ''), fingerprint);
      final editableState = tester.state<EditableTextState>(editorFinder);
      final boxes = editableState.renderEditable.getBoxesForSelection(
        TextSelection(
          baseOffset: 0,
          extentOffset: editor.controller.text.length,
        ),
      );
      expect(boxes.length, greaterThan(1), reason: '指纹应自然换行，不能藏在单行横向视口内');
      final tile = find.ancestor(
        of: displayedFingerprint,
        matching: find.byType(ImBoySettingsTile),
      ).first;
      final tileBounds = tester.getRect(tile).inflate(0.01);
      final textBounds = tester.getRect(displayedFingerprint);
      expect(tileBounds.contains(textBounds.topLeft), isTrue);
      expect(tileBounds.contains(textBounds.bottomRight), isTrue);
      expect(textBounds.left, greaterThanOrEqualTo(-0.01));
      expect(textBounds.right, lessThanOrEqualTo(320.01));

      final hint = find.text(t.main.complianceKeyInfoHint);
      await tester.scrollUntilVisible(hint, 180, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(hint, findsOneWidget);
      expect(tester.getRect(hint).bottom, lessThanOrEqualTo(480.01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('未配置密钥时空态列表仍有有限高度', (tester) async {
    ComplianceKeyService.debugFetcher = () async => null;
    await _pumpPage(tester);
    expect(find.text(t.main.complianceKeyNotConfigured), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(
      tester.getSize(find.byType(ListView)).height,
      lessThanOrEqualTo(480),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
