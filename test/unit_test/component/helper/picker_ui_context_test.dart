import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:extended_image/extended_image.dart' show ExtendedImageSlidePage;
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart'
    show
        AssetEntity,
        AssetPathEntity,
        AssetPicker,
        AssetPickerConfig,
        AssetPickerDelegate,
        AssetPickerPageRoute,
        AssetPickerViewer,
        AssetPickerViewerProvider,
        AssetSelectPredicate,
        AssetType,
        DefaultAssetPickerBuilderDelegate,
        DefaultAssetPickerProvider,
        DefaultAssetPickerViewerBuilderDelegate,
        PermissionRequestOption,
        PermissionState;
import 'package:wechat_camera_picker/wechat_camera_picker.dart'
    show CameraPicker, CameraPickerConfig, CameraPickerState;
import 'package:wechat_picker_library/wechat_picker_library.dart'
    show PlatformProgressIndicator, buildTheme;

const _openPicker = 'Open picker';

class _PendingPermissionDelegate extends AssetPickerDelegate {
  _PendingPermissionDelegate(this.permission);

  final Future<PermissionState> permission;
  int permissionRequests = 0;

  @override
  Future<PermissionState> permissionCheck({
    PermissionRequestOption requestOption = const PermissionRequestOption(),
  }) {
    permissionRequests++;
    return permission;
  }
}

class _TrackedViewerProvider extends AssetPickerViewerProvider<AssetEntity> {
  _TrackedViewerProvider() : super(<AssetEntity>[]);

  bool wasDisposed = false;
  int selectCalls = 0;

  @override
  void selectAsset(AssetEntity asset) {
    selectCalls++;
    super.selectAsset(asset);
  }

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}

class _SelectionLifecycleDelegate
    extends
        DefaultAssetPickerViewerBuilderDelegate<
          _TrackedViewerProvider,
          DefaultAssetPickerProvider
        > {
  _SelectionLifecycleDelegate({
    required _TrackedViewerProvider super.provider,
    required AssetEntity asset,
    required AssetSelectPredicate<AssetEntity> super.selectPredicate,
  }) : super(
         currentIndex: 0,
         previewAssets: [asset],
         themeData: ThemeData(),
         selectedAssets: <AssetEntity>[],
       );

  // Keep the real viewer's lifecycle and selection behavior, while avoiding
  // media loading and native permissions in this host lifecycle regression.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _openButtonPage(
  WidgetTester tester,
  WidgetBuilder buildButton, {
  required Locale locale,
}) async {
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Builder(builder: buildButton)),
            ),
          ),
          child: const Text(_openPicker),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(_openPicker));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asset picker cancels after its permission caller is unmounted', (
    tester,
  ) async {
    final permission = Completer<PermissionState>();
    final delegate = _PendingPermissionDelegate(permission.future);
    late BuildContext caller;
    var routeBuilds = 0;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            caller = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final pending = delegate.pickAssets(
      caller,
      pageRouteBuilder: (picker) {
        routeBuilds++;
        return AssetPickerPageRoute<List<AssetEntity>>(builder: (_) => picker);
      },
    );
    expect(delegate.permissionRequests, 1);
    expect(routeBuilds, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(caller.mounted, isFalse);

    permission.complete(PermissionState.authorized);
    expect(await pending, isNull);
    expect(routeBuilds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'viewer ignores selection resolved after its provider is disposed',
    (tester) async {
      const viewerKey = ValueKey('selection-lifecycle-viewer');
      final decision = Completer<bool>();
      final provider = _TrackedViewerProvider();
      final asset = AssetEntity(
        id: 'selection-lifecycle-asset',
        typeInt: AssetType.image.index,
        width: 1,
        height: 1,
      );
      var delayDecision = false;
      var predicateCalls = 0;
      final delegate = _SelectionLifecycleDelegate(
        provider: provider,
        asset: asset,
        selectPredicate: (context, candidate, isSelected) {
          predicateCalls++;
          expect(candidate, same(asset));
          expect(isSelected, isFalse);
          return delayDecision ? decision.future : true;
        },
      );
      await tester.pumpWidget(
        _host(
          AssetPickerViewer<
            AssetEntity,
            AssetPathEntity,
            _TrackedViewerProvider,
            _SelectionLifecycleDelegate
          >(key: viewerKey, builder: delegate),
        ),
      );
      final context = tester.element(find.byKey(viewerKey));

      // A mounted positive control proves the real selection path still writes.
      expect(await delegate.onChangingSelected(context, asset, false), isTrue);
      expect(provider.currentlySelectedAssets, [asset]);
      expect(delegate.selectedAssets, [asset]);
      expect(provider.selectCalls, 1);
      delegate.unSelectAsset(asset);

      delayDecision = true;
      final pending = delegate.onChangingSelected(context, asset, false);
      expect(predicateCalls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(context.mounted, isFalse);
      expect(provider.wasDisposed, isTrue);

      decision.complete(true);
      expect(await pending, isFalse);
      expect(provider.selectCalls, 1);
      expect(provider.currentlySelectedAssets, isEmpty);
      expect(delegate.selectedAssets, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final labels in const [
    (locale: Locale('en'), close: 'Close', back: 'Back'),
    (locale: Locale('zh'), close: '关闭', back: '返回'),
  ]) {
    testWidgets(
      'asset back button uses ${labels.locale.languageCode} localizations and pops',
      (tester) async {
        final delegate = DefaultAssetPickerBuilderDelegate(
          provider: DefaultAssetPickerProvider.forTest(),
          initialPermission: PermissionState.authorized,
          locale: labels.locale,
        );
        addTearDown(delegate.dispose);

        // The public test provider avoids media enumeration. The production
        // delegate still builds its real localized button and navigation action.
        await _openButtonPage(
          tester,
          delegate.backButton,
          locale: labels.locale,
        );

        expect(tester.takeException(), isNull);
        expect(find.byTooltip(labels.close), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.text(_openPicker), findsNothing);

        await tester.tap(find.byTooltip(labels.close));
        await tester.pumpAndSettle();
        expect(find.text(_openPicker), findsOneWidget);
        expect(find.byTooltip(labels.close), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'camera back button uses ${labels.locale.languageCode} localizations and pops',
      (tester) async {
        // This public builder only needs the supplied context. The camera
        // State is not mounted: initState, cameras and sensors are not started.
        final camera = CameraPickerState();
        await _openButtonPage(
          tester,
          camera.buildBackButton,
          locale: labels.locale,
        );

        expect(tester.takeException(), isNull);
        expect(find.byTooltip(labels.back), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        expect(find.text(_openPicker), findsNothing);

        await tester.tap(find.byTooltip(labels.back));
        await tester.pumpAndSettle();
        expect(find.text(_openPicker), findsOneWidget);
        expect(find.byTooltip(labels.back), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    test('picker public APIs share standalone ${brightness.name} themes', () {
      const accent = Colors.deepOrange;
      final ThemeData custom = ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ),
      );
      final assets = AssetPickerConfig(pickerTheme: custom);
      final camera = CameraPickerConfig(theme: custom);
      expect(assets.pickerTheme, same(custom));
      expect(camera.theme, same(custom));

      // These explicit types also guard the public library boundary at compile
      // time: a legacy SDK ThemeData cannot satisfy the standalone ThemeData.
      final List<ThemeData> generated = [
        AssetPicker.themeData(accent, light: brightness == Brightness.light),
        CameraPicker.themeData(accent, light: brightness == Brightness.light),
        buildTheme(accent, light: brightness == Brightness.light),
      ];
      for (final theme in generated) {
        expect(theme.brightness, brightness);
        expect(theme.colorScheme.secondary, accent);
      }
    });

    testWidgets(
      'image slide page follows the standalone ${brightness.name} background',
      (tester) async {
        const pageKey = ValueKey('image-slide-page');
        final background = brightness == Brightness.light
            ? const Color(0xfff6ecd4)
            : const Color(0xff123456);
        final theme = ThemeData(
          brightness: brightness,
          scaffoldBackgroundColor: background,
        );

        await tester.pumpWidget(
          _host(
            const ExtendedImageSlidePage(
              key: pageKey,
              child: SizedBox.expand(),
            ),
            theme: theme,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final surface = find.descendant(
          of: find.byKey(pageKey),
          matching: find.byType(Container),
        );
        expect(surface, findsOneWidget);
        expect(tester.widget<Container>(surface).color, background);

        const changedBackground = Color(0xff684c77);
        await tester.pumpWidget(
          _host(
            const ExtendedImageSlidePage(
              key: pageKey,
              child: SizedBox.expand(),
            ),
            theme: theme.copyWith(scaffoldBackgroundColor: changedBackground),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<Container>(surface).color, changedBackground);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final platform in [
    foundation.TargetPlatform.android,
    foundation.TargetPlatform.iOS,
  ]) {
    testWidgets('picker progress uses standalone widgets on ${platform.name}', (
      tester,
    ) async {
      final previous = foundation.debugDefaultTargetPlatformOverride;
      foundation.debugDefaultTargetPlatformOverride = platform;
      addTearDown(() {
        foundation.debugDefaultTargetPlatformOverride = previous;
      });

      await tester.pumpWidget(
        _host(
          const PlatformProgressIndicator(
            value: 0.4,
            radius: 13,
            color: Colors.deepOrange,
            brightness: Brightness.light,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      if (platform == foundation.TargetPlatform.android) {
        final progress = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progress.value, 0.4);
        expect(progress.valueColor?.value, Colors.deepOrange);
        expect(find.byType(cupertino.CupertinoActivityIndicator), findsNothing);
      } else {
        final progress = tester.widget<cupertino.CupertinoActivityIndicator>(
          find.byType(cupertino.CupertinoActivityIndicator),
        );
        expect(progress.radius, 13);
        expect(
          cupertino.CupertinoTheme.of(
            tester.element(find.byType(cupertino.CupertinoActivityIndicator)),
          ).brightness,
          Brightness.light,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      }

      // The Cupertino indicator animates continuously; settling it would
      // hang. Unmount the real widget instead of suppressing its animation.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
