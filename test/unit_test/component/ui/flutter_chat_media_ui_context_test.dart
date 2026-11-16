import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_cache/cross_cache.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_chat_audio_message/flyer_chat_audio_message.dart';
import 'package:flyer_chat_video_message/flyer_chat_video_message.dart';
import 'package:imboy/component/video/video_controller.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/account_media_cache_store.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

const _audioChannel = MethodChannel('simform_audio_waveforms_plugin/methods');
const _signature =
    'X-Amz-Algorithm=AWS4-HMAC-SHA256&'
    'X-Amz-Credential=synthetic&X-Amz-Signature=synthetic';
const _audioUrl = 'https://media.example.test/voice.m4a?$_signature';
const _videoUrl = 'https://media.example.test/video.mp4?$_signature';
final _mediaBytes = Uint8List.fromList([1, 4, 9, 16, 25, 36, 49, 64]);

class _MediaPaths extends PathProviderPlatform {
  _MediaPaths(this.root);
  final Directory root;

  @override
  Future<String?> getApplicationCachePath() async => '${root.path}/cache';

  @override
  Future<String?> getTemporaryPath() async => '${root.path}/temp';
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Media UI fixtures must use their owned local cache');
  }
}

// Only the native video boundary is replaced; VideoPlayerController, the Flyer
// bubble, its private player route and VideoControllerOverlay stay real.
class _VideoPlatform extends VideoPlayerPlatform {
  final sources = <DataSource>[];
  final streams = <int, StreamController<VideoEvent>>{};
  final played = <int>[];
  final paused = <int>[];
  final looping = <(int, bool)>[];
  final disposed = <int>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length;
    sources.add(options.dataSource);
    final stream = StreamController<VideoEvent>();
    streams[id] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 3),
        size: const Size(320, 180),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await streams.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool value) async {
    looping.add((playerId, value));
  }

  @override
  Future<void> play(int playerId) async => played.add(playerId);

  @override
  Future<void> pause(int playerId) async => paused.add(playerId);

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool value) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool value) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      SizedBox.expand(key: ValueKey('native-video-${options.playerId}'));
}

Widget _host(ProviderContainer container, Widget child) {
  // This pinned Flyer fork uses the app's ThemeManager, not a ChatTheme lookup.
  // Supply the actual app provider plus only the extracted UI root/delegates.
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: container.read(themeProvider.notifier).currentTheme,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
}

Future<void> _seedMedia(String url) async {
  final uri = Uri.parse(url);
  final resource = '${uri.scheme}://${uri.host}:${uri.port}${uri.path}';
  final cache = CrossCache();
  try {
    await cache.set(
      AccountMediaCacheStore.cacheKey(
        AccountLocalTaskOwner.capture(),
        resource,
      ),
      _mediaBytes,
    );
  } finally {
    cache.dispose();
  }
}

Future<void> _waitForMedia(
  WidgetTester tester,
  bool Function() ready, {
  String phase = 'load its local fixture',
}) async {
  // The real account cache performs filesystem I/O outside FakeAsync. Yield to
  // that I/O and pump its FutureBuilder without waiting for an endless spinner.
  for (var attempt = 0; attempt < 200; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (ready()) return;
  }
  fail('The real media widget did not $phase');
}

void main() {
  late Directory temporary;
  late PathProviderPlatform previousPaths;
  late VideoPlayerPlatform previousVideo;
  late HttpOverrides? previousHttp;
  late _NoNetwork network;
  late _VideoPlatform video;
  late ProviderContainer container;
  late ProviderSubscription<ThemeState> themeSubscription;
  final waveformCalls = <MethodCall>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: 'media-ui-owner',
      'theme_follow_system': false,
      'theme_is_dark_mode': true,
    });
    await StorageService.init();
    temporary = await Directory.systemTemp.createTemp('media-ui-context-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _MediaPaths(temporary);
    previousHttp = HttpOverrides.current;
    network = _NoNetwork();
    HttpOverrides.global = network;
    previousVideo = VideoPlayerPlatform.instance;
    video = _VideoPlatform();
    VideoPlayerPlatform.instance = video;
    waveformCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_audioChannel, (call) async {
          waveformCalls.add(call);
          return switch (call.method) {
            'getDuration' => 15000,
            'extractWaveformData' => [0.1, 0.4, 0.8, 0.4, 0.1],
            'stopExtraction' => null,
            'preparePlayer' || 'stopPlayer' || 'releasePlayer' => true,
            _ => throw StateError(
              'Unexpected waveform operation: ${call.method}',
            ),
          };
        });
    container = ProviderContainer();
    themeSubscription = container.listen(themeProvider, (_, _) {});
    ThemeManager.instance.setProviderContainer(container);
    final notifier = container.read(themeProvider.notifier);
    await notifier.detectDynamicColorSupport();
    await notifier.loadThemePreference();
    await container.pump();
    await _seedMedia(_audioUrl);
    await _seedMedia(_videoUrl);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_audioChannel, null);
    VideoPlayerPlatform.instance = previousVideo;
    HttpOverrides.global = previousHttp;
    PathProviderPlatform.instance = previousPaths;
    themeSubscription.close();
    container.dispose();
    await temporary.delete(recursive: true);
  });

  testWidgets('real audio playback error reaches the new ScaffoldMessenger', (
    tester,
  ) async {
    const message = AudioMessage(
      id: 'audio-ui-fixture',
      authorId: 'media-ui-owner',
      source: _audioUrl,
      duration: Duration(seconds: 15),
      // Already-played fixtures keep this UI boundary independent of SQLite.
      metadata: {'played': true, 'duration_ms': 15000},
    );
    String? playedPath;
    Duration? requestedDuration;
    var playRequests = 0;
    try {
      await tester.pumpWidget(
        _host(
          container,
          FlyerChatAudioMessage(
            message: message,
            index: 0,
            onPlayPause: (path, requested, duration) {
              expect(requested, same(message));
              playedPath = path;
              requestedDuration = duration;
              playRequests++;
              throw StateError('synthetic playback failure');
            },
          ),
        ),
      );
      await _waitForMedia(
        tester,
        () => waveformCalls.any((call) => call.method == 'extractWaveformData'),
      );
      expect(find.byType(FlyerChatAudioMessage), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(playRequests, 1);
      expect(requestedDuration, const Duration(seconds: 15));
      expect(File(playedPath!).readAsBytesSync(), orderedEquals(_mediaBytes));
      final snackBar = find.byType(SnackBar);
      expect(snackBar, findsOneWidget);
      expect(
        find.descendant(
          of: snackBar,
          matching: find.textContaining('synthetic playback failure'),
        ),
        findsOneWidget,
      );
      final context = tester.element(snackBar);
      expect(ScaffoldMessenger.of(context), isA<ScaffoldMessengerState>());
      expect(MaterialLocalizations.of(context).closeButtonTooltip, '关闭');
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(network.attempts, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('real video bubble opens and controls its new Material route', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(
        _host(
          container,
          const FlyerChatVideoMessage(
            message: VideoMessage(
              id: 'video-ui-fixture',
              authorId: 'media-ui-owner',
              source: _videoUrl,
              width: 320,
              height: 180,
              metadata: {'played': true, 'duration_ms': 3000},
            ),
            index: 0,
          ),
        ),
      );
      await _waitForMedia(
        tester,
        () => find.byIcon(Icons.play_arrow).evaluate().isNotEmpty,
      );
      expect(find.byType(FlyerChatVideoMessage), findsOneWidget);
      expect(video.sources.single.sourceType, DataSourceType.file);
      final cachedFile = File.fromUri(Uri.parse(video.sources.single.uri!));
      expect(cachedFile.readAsBytesSync(), orderedEquals(_mediaBytes));
      expect(video.played, isEmpty);

      await tester.tap(find.byIcon(Icons.play_arrow));
      // The real controller polls playback periodically. Complete the route
      // transition explicitly instead of asking that active player to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final overlay = find.byType(VideoControllerOverlay);
      expect(overlay, findsOneWidget);
      expect(video.played, [0]);
      expect(video.looping, contains((0, true)));
      final context = tester.element(overlay);
      expect(Theme.of(context).brightness, Brightness.dark);
      final backTooltip = MaterialLocalizations.of(context).backButtonTooltip;
      expect(backTooltip, '返回');
      expect(find.byTooltip(backTooltip), findsOneWidget);
      // The retained bubble also renders this controller. Inspect the player
      // route's Material surface, anchored by its real controls, specifically.
      final playerSurface = find
          .ancestor(of: overlay, matching: find.byType(Material))
          .first;
      expect(
        find.descendant(
          of: playerSurface,
          matching: find.byKey(const ValueKey('native-video-0')),
        ),
        findsOneWidget,
      );
      expect(video.sources, hasLength(1));

      final pausesBefore = video.paused.length;
      await tester.tap(find.byTooltip(t.chat.groupFileMediaPause));
      // The surrounding overlay also recognizes double taps. Let the single
      // tap win that gesture arena before checking the platform command.
      await tester.pump(kDoubleTapTimeout);
      expect(video.paused.length, pausesBefore + 1);
      expect(
        tester
            .widget<VideoControllerOverlay>(overlay)
            .controller
            .value
            .isPlaying,
        isFalse,
      );
      expect(find.byTooltip(t.main.play), findsOneWidget);
      expect(network.attempts, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    await _waitForMedia(
      tester,
      () => video.disposed.isNotEmpty,
      phase: 'dispose its native video controller',
    );
    expect(video.disposed, [0]);
  });
}
