import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/location/widget.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_local.dart';
import 'package:imboy/config/init.dart' show AppInitializer;
import 'package:imboy/config/local_external_services_policy.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../chat/support/c2c_journey_support.dart'
    show sendTextViaInput, settledStatuses;
import '../enterprise/macos_storage_isolation.dart';
import '../flows/test_utils.dart';
import '../micro_community/owned_ui_launch.dart';
import 'location_poi_response_gate.dart';
import 'location_render_review.dart';

const _uid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peer = String.fromEnvironment('PEER_UID');
const _tag = String.fromEnvironment('UX01_RUN_TAG');
const _storageTag = String.fromEnvironment('UX_STORAGE_TAG');
const _restoreStorage = String.fromEnvironment('UX_RESTORE_STORAGE');
bool _surfaceConverted = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('UX01 physical Android real location replacement and send', (
    tester,
  ) async {
    await _prerequisites();
    final gate = LocationPoiResponseGate();
    final scope = await tester.runAsync(
      () => isolateH2NativeStorage(
        _storageTag,
        _uid,
        restore: _restoreStorage == 'true',
      ),
    );
    expect(scope, isNotNull);
    await tester.runAsync(() async {
      final receipt = await File('${scope!.path}/.ux01-run-$_tag')
          .create(exclusive: true);
      expect(
        (await Process.run('/system/bin/chmod', [
          '600',
          receipt.path,
        ])).exitCode,
        0,
      );
    });
    addTearDown(() async {
      gate.release();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        try {
          await AppInitializer.dispose();
          await SqliteService.to.close();
        } finally {
          gate.close();
        }
      });
    });
    await _loginAndChat(tester);
    // Startup installs its own global override; install the gate only afterwards.
    final previousOverrides = Zone.root.run(() => HttpOverrides.current);
    HttpOverrides.global = gate;
    expect(Zone.root.run(() => HttpOverrides.current), same(gate));
    try {
      await HttpOverrides.runZoned(() async {
        await _openPicker(tester);
        await _verifyNativeDrag(tester, gate);
        await _replaceAndRace(tester, gate);
        await _exitDuringResponse(tester, gate);
        await _sendCurrent(tester);
        expect(gate.held, 3);
        expect(gate.released, 3);
        expect(gate.consumed, 3);
        expect(tester.takeException(), isNull);
      }, createHttpClient: gate.createHttpClient);
    } on Object {
      debugPrint(
        'UX01_TEXT_RESPONSE_DIAGNOSTIC ${jsonEncode({'response': gate.lastTextResponse, 'held': gate.held, 'released': gate.released, 'consumed': gate.consumed, 'searches': gate.searches})}',
      );
      rethrow;
    } finally {
      HttpOverrides.global = previousOverrides;
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _prerequisites() async {
  expect(
    const bool.fromEnvironment('UX01_ALLOW_EXTERNAL_REQUESTS'),
    isTrue,
    reason: 'Explicit user authorization for AMap requests is required',
  );
  expect(const bool.fromEnvironment('TEST_ALLOW_BUSINESS_WRITES'), isTrue);
  expect(const bool.fromEnvironment('IMBOY_ANDROID_QA_BUILD'), isTrue);
  expect(const bool.fromEnvironment('IMBOY_TEST_ISOLATED'), isTrue);
  expect(const String.fromEnvironment('APP_ENV'), 'local');
  expect(LocalExternalServicesPolicy.suppressed, isTrue);
  expect(LocalExternalServicesPolicy.mapsSuppressed, isFalse);
  expect(
    const bool.fromEnvironment('IMBOY_LOCAL_MAP_REQUESTS_ALLOWED'),
    isTrue,
  );
  expect(Platform.isAndroid, isTrue);
  expect((await DeviceInfoPlugin().androidInfo).isPhysicalDevice, isTrue);
  expect(
    (await PackageInfo.fromPlatform()).packageName,
    'pub.imboy.app.uiuxqa',
  );
  expect(_uid, matches(RegExp(r'^[1-9][0-9]+$')));
  expect(_peer, matches(RegExp(r'^[1-9][0-9]+$')));
  expect(_uid, isNot(_peer));
  expect(_tag, matches(RegExp(r'^[A-Za-z0-9_-]{8,64}$')));
  expect(_storageTag, matches(RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$')));
  expect(
    _storageTag,
    isNot(_tag),
    reason: 'storage identity must be independent of each message run',
  );
  expect(
    _restoreStorage,
    anyOf('true', 'false'),
    reason: 'explicit strict restore mode required',
  );
  expect(FlowConfig.hasCredentials, isTrue);
  expect(
    EnvLocal().aMapAndroidKey.isNotEmpty,
    isTrue,
    reason: 'Authorized Android key required',
  );
  expect(
    EnvLocal().aMapWebKey.isNotEmpty,
    isTrue,
    reason: 'Authorized JS/REST config required',
  );
  final endpoint = Uri.parse(
    const String.fromEnvironment('API_BASE_URL_OVERRIDE'),
  );
  expect(endpoint.host, '127.0.0.1');
  expect(endpoint.scheme, 'http');
}

Future<void> _loginAndChat(WidgetTester tester) async {
  await launchOwnedUi(tester);
  expect(
    Env().aMapAndroidKey.isNotEmpty,
    isTrue,
    reason: 'Android AMap key required',
  );
  expect(
    Env().aMapWebKey.isNotEmpty,
    isTrue,
    reason: 'Authorized JS/REST AMap config required',
  );
  await _wait(
    tester,
    () =>
        UserRepoLocal.to.isLoggedIn ||
        isOnLoginPage(tester) ||
        isOnWelcomePage(tester),
    'login or restored identity',
  );
  if (_restoreStorage == 'true') {
    expect(
      UserRepoLocal.to.isLoggedIn,
      isTrue,
      reason: 'restored scope must not register a replacement identity',
    );
    expect(
      UserRepoLocal.to.currentUid == _uid,
      isTrue,
      reason: 'restored scope must belong to the authorized actor',
    );
    expect(
      UserRepoLocal.to.lastLoginAccount == FlowConfig.testPhone,
      isTrue,
      reason: 'restored account must match the authorized fixture',
    );
  } else {
    if (isOnWelcomePage(tester)) await leaveWelcomePage(tester);
    if (isOnLoginPage(tester)) {
      expect(
        await performLogin(
          tester,
          phone: FlowConfig.testPhone,
          password: FlowConfig.testPassword,
        ),
        isTrue,
      );
    }
  }
  await _wait(tester, () => UserRepoLocal.to.isLoggedIn, 'authorized login');
  expect(UserRepoLocal.to.currentUid, _uid);
  await dismissRecoveryGuide(tester);
  final shell = find.byType(ChatShellBootstrap);
  if (tester.any(shell)) {
    await ProviderScope.containerOf(tester.element(shell))
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.personal);
  }
  expect(AppFeatureRegistry.isEnabled('location'), isTrue);
  final context = tester.element(find.byType(Navigator).first);
  unawaited(GoRouter.of(context).push('/chat/$_peer?type=C2C'));
  await _wait(tester, () => tester.any(find.byType(ChatPage)), 'C2C route');
  expect(tester.widget<ChatPage>(find.byType(ChatPage)).peerId, _peer);
  await sendTextViaInput(tester, find.byType(ChatPage), 'UX01-$_tag');
}

Future<void> _openPicker(
  WidgetTester tester, {
  String renderStage = 'before-native-drag',
}) async {
  expect(UserRepoLocal.to.currentUid, _uid);
  await tester.tap(find.byKey(const ValueKey('extra_button')));
  await _wait(
    tester,
    () => tester.any(find.text(t.groupSchedule.location)),
    'location action',
  );
  await tester.tap(find.text(t.groupSchedule.location));
  await _wait(
    tester,
    () => tester.any(find.byType(MapLocationPicker)),
    'real foreground permission and location fix',
  );
  expect(
    await Geolocator.checkPermission(),
    anyOf(LocationPermission.whileInUse, LocationPermission.always),
  );
  final view = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
  Object? mapReady;
  for (var i = 0; i < 30; i++) {
    mapReady = await tester.runAsync(
      () => view.platform.params.controller.runJavaScriptReturningResult(
        'typeof AMap !== "undefined" && '
        'typeof map !== "undefined" && !!map.getCenter()',
      ),
    );
    if (mapReady == true || mapReady == 'true') break;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
  }
  expect(
    mapReady == true || mapReady == 'true',
    isTrue,
    reason:
        'AMap JS initialization is only a prerequisite, not render evidence',
  );
  await _verifyMapTiles(tester, stage: renderStage);
  await _wait(tester, () => tester.any(_rows), 'real nearby POI result');
}

Future<Object> _mapProbe(WidgetTester tester, String script) async {
  final view = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
  final result = await tester.runAsync(
    () => view.platform.params.controller.runJavaScriptReturningResult(script),
  );
  expect(result, isNotNull);
  return result!;
}

const _rasterMapTileProbe =
    '''Array.from(document.querySelectorAll('.amap-layer img'))
    .some(function(img) {
      var r = img.getBoundingClientRect();
      var s = getComputedStyle(img);
      for (var parent = img.parentElement; parent; parent = parent.parentElement) {
        var ancestor = getComputedStyle(parent);
        if (ancestor.display === 'none' || ancestor.visibility === 'hidden' ||
            Number(ancestor.opacity) === 0) return false;
      }
      return img.complete && img.naturalWidth >= 128 && img.naturalHeight >= 128 &&
        r.width > 0 && r.height > 0 && r.right > 0 && r.bottom > 0 &&
        r.left < innerWidth && r.top < innerHeight * 0.3 &&
        s.display !== 'none' && s.visibility !== 'hidden' && Number(s.opacity) > 0;
    })''';

const _canvasMapProbe = '''(function () {
    if (typeof AMap === 'undefined' || typeof map === 'undefined' ||
        !map.getCenter() || !map.getLayers().length) return false;
    var container = document.getElementById('map');
    if (!container) return false;
    var mapRect = container.getBoundingClientRect();
    if (mapRect.width <= 0 || mapRect.height <= 0) return false;
    return Array.from(container.querySelectorAll('canvas')).some(function(canvas) {
      var r = canvas.getBoundingClientRect();
      for (var node = canvas; node; node = node.parentElement) {
        var style = getComputedStyle(node);
        if (style.display === 'none' || style.visibility === 'hidden' ||
            Number(style.opacity) === 0) return false;
      }
      return canvas.width > 0 && canvas.height > 0 &&
        r.width >= mapRect.width * 0.8 && r.height >= mapRect.height * 0.8 &&
        r.left < innerWidth && r.right > 0 && r.top < innerHeight && r.bottom > 0;
    });
  })()''';

Future<void> _verifyMapTiles(
  WidgetTester tester, {
  required String stage,
  bool requireSceneChanged = false,
}) async {
  var decodedTiles = false;
  for (var i = 0; i < 30 && !decodedTiles; i++) {
    final value = await _mapProbe(tester, _rasterMapTileProbe);
    decodedTiles = value == true || value == 'true';
    if (!decodedTiles) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
    }
  }
  if (decodedTiles) {
    if (stage == 'after-native-drag') await _captureMap(tester, stage);
    return;
  }
  final canvasReady = await _mapProbe(tester, _canvasMapProbe);
  if (canvasReady == true || canvasReady == 'true') {
    final capture = await _captureMap(tester, stage);
    await _awaitRootRenderReview(
      tester,
      capture,
      stage,
      requireSceneChanged: requireSceneChanged,
    );
    return;
  }
  if (!decodedTiles) {
    await _captureMap(tester, 'render-pending');
    fail(
      'UX01_MAP_RENDER_PENDING: no visible decoded map tiles; canvas/WebGL '
      'requires independent native render acceptance. JS objects are insufficient.',
    );
  }
}

const _trustedMapTouchPredicate = '''function(event) {
  return event != null && event.isTrusted === true &&
    (event.type === 'touchmove' ||
      (event.type === 'pointermove' && event.pointerType === 'touch'));
}''';

const _installTrustedMapTouchProbe =
    '''(function() {
  var root = document.getElementById('map');
  if (!root || window.__imboyUx01TouchProbe ||
      typeof PointerEvent !== 'function') return false;
  var accepts = $_trustedMapTouchPredicate;
  if (accepts(new Event('touchmove')) ||
      accepts(new PointerEvent('pointermove', {pointerType: 'touch'}))) return false;
  var probe = {root: root, count: 0};
  probe.listener = function(event) { if (accepts(event)) probe.count++; };
  root.addEventListener('touchmove', probe.listener, {capture: true, passive: true});
  root.addEventListener('pointermove', probe.listener, {capture: true, passive: true});
  window.__imboyUx01TouchProbe = probe;
  return true;
})()''';

const _removeTrustedMapTouchProbe = '''(function() {
  var probe = window.__imboyUx01TouchProbe;
  if (!probe) return true;
  probe.root.removeEventListener('touchmove', probe.listener, true);
  probe.root.removeEventListener('pointermove', probe.listener, true);
  delete window.__imboyUx01TouchProbe;
  return true;
})()''';

const _mapCenterProbe =
    'JSON.stringify([map.getCenter().lng, map.getCenter().lat])';
const _trustedMoveCountProbe = 'window.__imboyUx01TouchProbe.count';

Future<void> _reportMarkerImages(WidgetTester tester) async {
  try {
    final details = await _mapProbe(tester, '''JSON.stringify((function() {
      var images = Array.from(document.querySelectorAll('.amap-marker img'));
      return {count: images.length, images: images.map(function(image) {
        var scheme = 'unresolved', host = '';
        try {
          var url = new URL(image.currentSrc || image.src, document.baseURI);
          scheme = url.protocol.replace(':', ''); host = url.hostname;
        } catch (_) {}
        return {complete: image.complete, naturalWidth: image.naturalWidth,
          naturalHeight: image.naturalHeight, src_scheme: scheme, src_host: host};
      })};
    })())''');
    debugPrint('UX01_MARKER_IMAGE_DIAGNOSTIC $details');
  } on Object {
    debugPrint('UX01_MARKER_IMAGE_DIAGNOSTIC_FAILED true');
  }
}

Future<({int trustedMoves, bool centerChanged})> _waitNativeDrag(
  WidgetTester tester,
  LocationPoiResponseGate gate,
  Object before,
  int responses,
) async {
  var moves = 0;
  var changed = false;
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    moves = (await _mapProbe(tester, _trustedMoveCountProbe) as num).toInt();
    changed = await _mapProbe(tester, _mapCenterProbe) != before;
    if (moves > 0 && changed && gate.aroundResponses > responses) break;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  return (trustedMoves: moves, centerChanged: changed);
}

void _assertNativeDrag(
  ({int trustedMoves, bool centerChanged}) observed,
  LocationPoiResponseGate gate,
  int responses,
) {
  expect(
    observed.trustedMoves,
    greaterThan(0),
    reason: 'actual trusted native WebView touch movement required',
  );
  expect(
    observed.centerChanged,
    isTrue,
    reason: 'native WebView map center must change',
  );
  expect(
    gate.aroundResponses,
    greaterThan(responses),
    reason: 'real dragend bridge must cause successful actual POI response consumption',
  );
}

Future<void> _dragFailure(
  WidgetTester tester,
  LocationPoiResponseGate gate,
  Object before,
  int responses,
  int flutterMoves,
) async {
  try {
    final trusted = (await _mapProbe(tester, _trustedMoveCountProbe) as num)
        .toInt();
    final changed = await _mapProbe(tester, _mapCenterProbe) != before;
    debugPrint(
      'UX01_NATIVE_DRAG_DIAGNOSTIC ${jsonEncode({'flutter_moves': flutterMoves, 'trusted_moves': trusted, 'center_changed': changed, 'around_delta': gate.aroundResponses - responses, 'around_requests': gate.aroundRequests, 'around_responses': gate.aroundResponses, 'global_gate_active': identical(Zone.root.run(() => HttpOverrides.current), gate)})}',
    );
  } on Object {
    debugPrint('UX01_NATIVE_DRAG_DIAGNOSTIC_FAILED true');
  }
  try {
    await _captureMap(tester, 'native-drag-failure');
  } on Object {
    debugPrint('UX01_NATIVE_DRAG_FAILURE_CAPTURE_FAILED true');
  }
}

Future<void> _removeTouchProbe(
  WidgetTester tester, {
  required bool preserveFailure,
}) async {
  try {
    final removed = await _mapProbe(tester, _removeTrustedMapTouchProbe);
    expect(removed == true || removed == 'true', isTrue);
  } on Object {
    if (!preserveFailure) rethrow;
    debugPrint('UX01_NATIVE_DRAG_CLEANUP_FAILED true');
  }
}

Future<void> _verifyNativeDrag(
  WidgetTester tester,
  LocationPoiResponseGate gate,
) async {
  final before = await _mapProbe(tester, _mapCenterProbe);
  final responses = gate.aroundResponses;
  var flutterMoves = 0;
  void observe(PointerEvent event) {
    if (event is PointerMoveEvent && event.kind == PointerDeviceKind.touch) {
      flutterMoves++;
    }
  }

  final previous = tester.binding.shouldPropagateDevicePointerEvents;
  tester.binding.shouldPropagateDevicePointerEvents = true;
  GestureBinding.instance.pointerRouter.addGlobalRoute(observe);
  var failed = false;
  try {
    await _reportMarkerImages(tester);
    final installed = await _mapProbe(tester, _installTrustedMapTouchProbe);
    expect(
      installed == true || installed == 'true',
      isTrue,
      reason: 'un-dispatched synthetic touch events must be rejected',
    );
    debugPrint('UX01_NATIVE_INPUT_READY drag_visible_map_top_area');
    final observed = await _waitNativeDrag(tester, gate, before, responses);
    _assertNativeDrag(observed, gate, responses);
    await _verifyMapTiles(
      tester,
      stage: 'after-native-drag',
      requireSceneChanged: true,
    );
    expect(tester.takeException(), isNull);
  } on Object {
    failed = true;
    await _dragFailure(tester, gate, before, responses, flutterMoves);
    rethrow;
  } finally {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(observe);
    tester.binding.shouldPropagateDevicePointerEvents = previous;
    await _removeTouchProbe(tester, preserveFailure: failed);
  }
}

Future<File> _captureMap(WidgetTester tester, String stage) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  if (!_surfaceConverted) {
    await binding.convertFlutterSurfaceToImage();
    _surfaceConverted = true;
  }
  await tester.pump();
  final bytes = await binding.takeScreenshot('ux01-$stage-$_tag');
  expect(bytes, isNotEmpty);
  final capture = await tester.runAsync(() async {
    final directory = await Directory.systemTemp.createTemp(
      'ux01-render-evidence-',
    );
    expect(
      (await Process.run('/system/bin/chmod', [
        '700',
        directory.path,
      ])).exitCode,
      0,
    );
    final file = await File('${directory.path}/$stage.png').create();
    expect(
      (await Process.run('/system/bin/chmod', ['600', file.path])).exitCode,
      0,
    );
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('UX01_RENDER_EVIDENCE ${file.path}');
    return file;
  });
  expect(capture, isNotNull);
  return capture!;
}

Future<void> _awaitRootRenderReview(
  WidgetTester tester,
  File capture,
  String stage, {
  required bool requireSceneChanged,
}) async {
  final bytes = await tester.runAsync(capture.readAsBytes);
  expect(bytes, isNotNull);
  final hash = crypto.sha256.convert(bytes!).toString();
  final receipt = File('${capture.parent.path}/review.json');
  debugPrint(
    'UX01_NATIVE_RENDER_REVIEW_REQUIRED ${jsonEncode({'run_tag': _tag, 'stage': stage, 'screenshot_sha256': hash, 'screenshot_path': capture.path, 'review_path': receipt.path, 'scene_changed_required': requireSceneChanged})}',
  );
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final exists = await tester.runAsync(receipt.exists);
    if (exists == true) {
      final type = await tester.runAsync(
        () => FileSystemEntity.type(receipt.path, followLinks: false),
      );
      expect(
        type,
        FileSystemEntityType.file,
        reason: 'real root review file required',
      );
      final text = await tester.runAsync(receipt.readAsString);
      expect(text, isNotNull);
      expect(
        matchesLocationRenderReview(
          jsonDecode(text!),
          runTag: _tag,
          stage: stage,
          screenshotSha256: hash,
          requireSceneChanged: requireSceneChanged,
        ),
        isTrue,
        reason: 'root render observations must match this capture exactly',
      );
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  fail('UX01_NATIVE_RENDER_REVIEW_MISSING: root capture review timed out');
}

Finder get _search => find.descendant(
  of: find.byType(MapLocationPicker),
  matching: find.byType(TextField),
);
Finder get _rows => find.descendant(
  of: find.byType(MapLocationPicker),
  matching: find.byType(CellPressable),
);
Finder get _send => find.ancestor(
  of: find.text(t.common.buttonSend),
  matching: find.byType(CupertinoButton),
);

void _cannotSend(WidgetTester tester) {
  expect(
    tester.widget<CupertinoButton>(_send).onPressed,
    isNull,
    reason: 'changed query cannot send a previous POI',
  );
}

Future<String> _selectFirst(WidgetTester tester) async {
  final row = _rows.first;
  final title = tester
      .widget<Text>(find.descendant(of: row, matching: find.byType(Text)).first)
      .data!;
  await tester.tap(row);
  await tester.pump();
  expect(tester.widget<CupertinoButton>(_send).onPressed, isNotNull);
  return title;
}

Future<void> _held(WidgetTester tester, LocationPoiResponseGate gate) async {
  var observed = false;
  final pending = gate.observed.then((_) => observed = true);
  await _wait(tester, () => observed, 'actual POI response held');
  await pending;
}

Future<void> _replaceAndRace(
  WidgetTester tester,
  LocationPoiResponseGate gate,
) async {
  final original = await _selectFirst(tester);
  final empty = 'UX01-no-poi-$_tag';
  gate.arm(empty);
  await tester.enterText(_search, empty);
  await tester.pump();
  _cannotSend(tester);
  await _held(tester, gate);
  _cannotSend(tester);
  gate.release();
  await _wait(
    tester,
    () => tester.any(find.text(t.common.searchNoResults)),
    'real successful empty search',
  );
  _cannotSend(tester);
  expect(find.text(original), findsNothing);

  final older = 'UX01-older-$_tag';
  gate.arm(older);
  await tester.enterText(_search, older);
  await _held(tester, gate);
  // Clearing the field performs a real nearby query with usable current results.
  await tester.enterText(_search, '');
  await _wait(tester, () => tester.any(_rows), 'newer real nearby result');
  final current = await _selectFirst(tester);
  gate.release();
  await _wait(
    tester,
    () => gate.consumed == 2,
    'older actual response consumed',
  );
  await tester.pump(const Duration(seconds: 1));
  expect(find.text(current), findsOneWidget);
  expect(
    tester.widget<CupertinoButton>(_send).onPressed,
    isNotNull,
    reason: 'older response cannot invalidate current selection',
  );
}

Future<void> _exitDuringResponse(
  WidgetTester tester,
  LocationPoiResponseGate gate,
) async {
  gate.arm('UX01-exit-$_tag');
  await tester.enterText(_search, 'UX01-exit-$_tag');
  await _held(tester, gate);
  _cannotSend(tester);
  await tester.binding.handlePopRoute();
  await _wait(
    tester,
    () => !tester.any(find.byType(MapLocationPicker)),
    'picker exit',
  );
  gate.release();
  await _wait(
    tester,
    () => gate.consumed == 3,
    'exited page response consumed',
  );
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
}

Future<void> _sendCurrent(WidgetTester tester) async {
  final before = tester
      .widgetList<ChatMessageItem>(find.byType(ChatMessageItem))
      .map((item) => item.message.id)
      .toSet();
  await _openPicker(tester, renderStage: 'before-send');
  final selected = await _selectFirst(tester);
  await tester.tap(_send);
  await _wait(
    tester,
    () => !tester.any(find.byType(MapLocationPicker)),
    'send current POI',
  );
  final sent = find.byWidgetPredicate(
    (widget) =>
        widget is ChatMessageItem &&
        !before.contains(widget.message.id) &&
        widget.message.authorId == _uid &&
        widget.message.metadata?['msg_type'] == 'location' &&
        widget.message.metadata?['title'] == selected &&
        settledStatuses.contains(widget.message.status),
  );
  await _wait(tester, () => tester.any(sent), 'location acknowledged');
  expect(sent, findsOneWidget);
  final message = tester.widget<ChatMessageItem>(sent).message;
  // IDs only; the receiver must independently verify this message and preceding marker.
  debugPrint(
    'UX01_SEND_RECEIPT tag=$_tag message_id=${message.id} peer=$_peer',
  );
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(ready(), isTrue, reason: 'UX01 native $stage');
  expect(tester.takeException(), isNull);
}
