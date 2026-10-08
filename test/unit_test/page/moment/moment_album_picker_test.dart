import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moment/moment_album_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class _BrokenPicker extends AssetPickerDelegate {
  const _BrokenPicker();
  @override
  Future<PermissionState> permissionCheck({
    PermissionRequestOption requestOption = const PermissionRequestOption(),
  }) async => throw StateError('unexpected picker failure');
}

void main() {
  const channel = MethodChannel('com.fluttercandies/photo_manager');
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() async {
    AssetPicker.setPickerDelegate(const AssetPickerDelegate());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await AppLoading.dismiss(animation: false);
  });

  for (final state in [PermissionState.denied, PermissionState.restricted]) {
    testWidgets('${state.name} returns cancellation with feedback', (
      tester,
    ) async {
      var permissionCalls = 0;
      var completed = false;
      List<AssetEntity>? selected = <AssetEntity>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'requestPermissionExtend');
            permissionCalls++;
            return state.index;
          });
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            builder: AppLoading.init(),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await pickMomentAlbum(context, maxAssets: 9);
                  completed = true;
                },
                child: const Text('pick album'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick album'));
      await tester.pumpAndSettle();
      expect(permissionCalls, 1);
      expect(completed, true);
      expect(selected, isNull);
      expect(find.text(t.common.permissionAcquisitionFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unexpected picker state errors still propagate', (tester) async {
    AssetPicker.setPickerDelegate(const _BrokenPicker());
    StateError? failure;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: AppLoading.init(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                try {
                  await pickMomentAlbum(context, maxAssets: 9);
                } on StateError catch (error) {
                  failure = error;
                }
              },
              child: const Text('pick album'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pick album'));
    await tester.pumpAndSettle();
    expect(failure?.message, 'unexpected picker failure');
    expect(find.text(t.common.permissionAcquisitionFailed), findsNothing);
  });
}
