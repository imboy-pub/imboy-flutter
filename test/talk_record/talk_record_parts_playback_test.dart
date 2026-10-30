import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:just_audio/just_audio.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/store/api/talk_record_api.dart';

class _Api extends Mock implements TalkRecordApi {}

class _Parts implements TalkRecordPartsPlaybackGateway {
  int calls = 0;
  bool fail = false;
  bool singlePart = false;
  Duration ttl = const Duration(minutes: 5);
  Completer<TalkRecordPartsTicket>? pending;
  @override
  Future<TalkRecordPartsTicket> openTicket(String id) async {
    calls++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('denied');
    return TalkRecordPartsTicket([
      const TalkRecordPlaybackPart(0, 0, 1000, 'first'),
      if (!singlePart) const TalkRecordPlaybackPart(1, 1000, 1500, 'second'),
    ], DateTime.now().add(ttl));
  }
}

class _Backend implements TalkRecordPlayerBackend {
  final loads = <(String, int)>[];
  final seeks = <int>[];
  int plays = 0;
  int pauses = 0;
  int stops = 0;
  bool holdPlay = false;
  final pendingPlays = <Completer<void>>[];
  Completer<void>? nextLoad;
  String? activeUrl;
  Object? loadError;
  final events = StreamController<TalkRecordPlayerBackendState>.broadcast();
  @override
  Stream<TalkRecordPlayerBackendState> get states => events.stream;
  @override
  Future<void> load(String url, {int initialPositionMs = 0}) async {
    loads.add((url, initialPositionMs));
    final error = loadError;
    loadError = null;
    if (error != null) throw error;
    final wait = nextLoad;
    nextLoad = null;
    if (wait != null) await wait.future;
    activeUrl = url;
  }

  @override
  Future<void> play() async {
    plays++;
    if (holdPlay) {
      final pending = Completer<void>();
      pendingPlays.add(pending);
      await pending.future;
    }
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> seek(int positionMs) async {
    seeks.add(positionMs);
  }

  @override
  Future<void> stop() async {
    stops++;
    activeUrl = null;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Parts parts;
  late _Backend backend;
  late ProviderContainer container;
  late void Function() authChanged;
  setUp(() {
    parts = _Parts();
    backend = _Backend();
    container = ProviderContainer(
      overrides: [
        talkRecordPartsPlaybackGatewayProvider.overrideWithValue(parts),
        talkRecordPlaybackGatewayProvider.overrideWithValue(
          FixtureTalkRecordPlaybackGateway(),
        ),
        talkRecordPlayerBackendProvider.overrideWithValue(backend),
        talkRecordAuthSubscribeProvider.overrideWithValue((callback) {
          authChanged = callback;
          return () {};
        }),
      ],
    );
  });
  tearDown(() {
    for (final pending in backend.pendingPlays) {
      if (!pending.isCompleted) pending.complete();
    }
    container.dispose();
    backend.events.close();
  });

  test('plays the next part and seeks on the global timeline', () async {
    final p = container.read(talkRecordPlayerProvider.notifier);
    p.attach(
      recordId: '123',
      durationMs: 2500,
      playbackAllowed: true,
      useParts: true,
    );
    await p.play();
    expect(backend.loads, [('first', 0)]);
    backend.events.add(
      const TalkRecordPlayerBackendState(completed: true, positionMs: 1000),
    );
    await pumpEventQueue();
    expect(backend.loads, [('first', 0), ('second', 0)]);
    expect(backend.plays, 2);
    await p.seekTo(500, autoplay: false);
    expect(backend.loads.last, ('first', 500));
    expect(backend.seeks.last, 500);
    await p.seekTo(1700, autoplay: false);
    expect(backend.loads.last, ('second', 700));
    expect(backend.seeks.last, 700);
  });

  for (final seek in [false, true]) {
    test(
      'natural completion remains stopped after ${seek ? 'seek' : 'play'} returns',
      () async {
        parts.singlePart = !seek;
        backend.holdPlay = true;
        final player = container.read(talkRecordPlayerProvider.notifier);
        player.attach(
          recordId: '123',
          durationMs: seek ? 2500 : 1000,
          playbackAllowed: true,
          useParts: true,
        );
        final operation = seek ? player.seekTo(1700) : player.play();
        await pumpEventQueue();
        expect(backend.pendingPlays, hasLength(1));
        expect(container.read(talkRecordPlayerProvider).playing, isTrue);
        backend.events.add(
          TalkRecordPlayerBackendState(
            completed: true,
            positionMs: seek ? 1500 : 1000,
          ),
        );
        await pumpEventQueue();
        expect(container.read(talkRecordPlayerProvider).playing, isFalse);
        backend.pendingPlays.single.complete();
        await operation;
        expect(container.read(talkRecordPlayerProvider).playing, isFalse);
      },
    );
  }

  for (final useParts in [false, true]) {
    test(
      'replay after completion starts at zero (${useParts ? 'parts' : 'assembled'})',
      () async {
        backend.holdPlay = true;
        final player = container.read(talkRecordPlayerProvider.notifier);
        player.attach(
          recordId: '123',
          durationMs: 2500,
          playbackAllowed: true,
          useParts: useParts,
        );
        final first = useParts ? player.seekTo(1700) : player.play();
        await pumpEventQueue();
        expect(backend.pendingPlays, hasLength(1));
        backend.events.add(
          TalkRecordPlayerBackendState(
            completed: true,
            positionMs: useParts ? 1500 : 2500,
          ),
        );
        await pumpEventQueue();
        backend.pendingPlays.first.complete();
        await first;
        final replay = player.play();
        await pumpEventQueue();
        expect(backend.seeks.last, 0);
        if (useParts) expect(backend.loads.last, ('first', 0));
        expect(container.read(talkRecordPlayerProvider).positionMs, 0);
        expect(backend.pendingPlays, hasLength(2));
        backend.pendingPlays.last.complete();
        await replay;
      },
    );
  }

  test('denial cannot fall back and account change stops playback', () async {
    final p = container.read(talkRecordPlayerProvider.notifier);
    p.attach(
      recordId: '123',
      durationMs: 2500,
      playbackAllowed: true,
      useParts: true,
    );
    parts.fail = true;
    await p.play();
    expect(container.read(talkRecordPlayerProvider).failure, isTrue);
    expect(backend.loads, isEmpty);
    parts.fail = false;
    await p.play();
    authChanged();
    await pumpEventQueue();
    expect(backend.stops, greaterThan(0));
    expect(container.read(talkRecordPlayerProvider).recordId, isEmpty);
  });

  test(
    'busy source reports retryable failure without automatic retry',
    () async {
      final p = container.read(talkRecordPlayerProvider.notifier);
      p.attach(
        recordId: '123',
        durationMs: 2500,
        playbackAllowed: true,
        useParts: true,
      );
      backend.loadError = PlayerException(429, 'synthetic busy', 0);
      await p.play();
      final failed = container.read(talkRecordPlayerProvider);
      expect(failed.failure, isTrue);
      expect(failed.unavailable, isFalse);
      expect(failed.playing, isFalse);
      expect(parts.calls, 1);
      expect(backend.loads.length, 1);
      await pumpEventQueue();
      expect(parts.calls, 1);
      await p.play();
      expect(parts.calls, 2);
      expect(container.read(talkRecordPlayerProvider).failure, isFalse);
      expect(backend.plays, 1);
    },
  );

  test('asynchronous media failure is shown and can be retried', () async {
    final p = container.read(talkRecordPlayerProvider.notifier);
    p.attach(
      recordId: '123',
      durationMs: 2500,
      playbackAllowed: true,
      useParts: true,
    );
    await p.play();
    backend.events.add(const TalkRecordPlayerBackendState(failed: true));
    await pumpEventQueue();
    expect(container.read(talkRecordPlayerProvider).failure, isTrue);
    expect(container.read(talkRecordPlayerProvider).unavailable, isFalse);
    expect(parts.calls, 1);
    await p.play();
    expect(parts.calls, 2);
    expect(container.read(talkRecordPlayerProvider).failure, isFalse);
  });

  test(
    'late error from an old source stops the new source and allows retry',
    () async {
      final p = container.read(talkRecordPlayerProvider.notifier);
      p.attach(
        recordId: '123',
        durationMs: 2500,
        playbackAllowed: true,
        useParts: true,
      );
      await p.play();
      await p.seekTo(1700);
      expect(backend.activeUrl, 'second');
      final priorStops = backend.stops;
      // Native errorStream does not identify which setUrl produced the error.
      backend.events.add(const TalkRecordPlayerBackendState(failed: true));
      await pumpEventQueue();
      final failed = container.read(talkRecordPlayerProvider);
      expect(failed.failure, isTrue);
      expect(failed.unavailable, isFalse);
      expect(failed.playing, isFalse);
      expect(backend.stops, greaterThan(priorStops));
      expect(parts.calls, 1);
      await p.play();
      expect(parts.calls, 2);
      expect(backend.loads.last, ('second', 700));
      expect(container.read(talkRecordPlayerProvider).failure, isFalse);
    },
  );

  test('renewal denial stops the current part and clears its ticket', () async {
    final p = container.read(talkRecordPlayerProvider.notifier);
    p.attach(
      recordId: '123',
      durationMs: 2500,
      playbackAllowed: true,
      useParts: true,
    );
    parts.ttl = const Duration(seconds: 30);
    await p.play();
    parts.fail = true;
    backend.events.add(
      const TalkRecordPlayerBackendState(playing: true, positionMs: 100),
    );
    await pumpEventQueue();
    expect(parts.calls, 2);
    expect(container.read(talkRecordPlayerProvider).failure, isTrue);
    expect(container.read(talkRecordPlayerProvider).loaded, isFalse);
    expect(backend.stops, greaterThan(0));
  });

  test('a long-running play future does not block later renewals', () async {
    final p = container.read(talkRecordPlayerProvider.notifier);
    p.attach(
      recordId: '123',
      durationMs: 2500,
      playbackAllowed: true,
      useParts: true,
    );
    parts.ttl = const Duration(seconds: 30);
    backend.holdPlay = true;
    final firstPlay = p.play();
    await pumpEventQueue();
    backend.events.add(
      const TalkRecordPlayerBackendState(playing: true, positionMs: 100),
    );
    await pumpEventQueue();
    expect(parts.calls, 2);
    backend.events.add(
      const TalkRecordPlayerBackendState(playing: true, positionMs: 200),
    );
    await pumpEventQueue();
    expect(parts.calls, 3);
    for (final pending in backend.pendingPlays) {
      pending.complete();
    }
    await firstPlay;
  });

  for (final seek in [false, true]) {
    test(
      'pending renewal cannot restart after ${seek ? 'seek' : 'pause'}',
      () async {
        final p = container.read(talkRecordPlayerProvider.notifier);
        p.attach(
          recordId: '123',
          durationMs: 2500,
          playbackAllowed: true,
          useParts: true,
        );
        parts.ttl = const Duration(seconds: 30);
        await p.play();
        parts.pending = Completer<TalkRecordPartsTicket>();
        backend.events.add(
          const TalkRecordPlayerBackendState(playing: true, positionMs: 100),
        );
        await pumpEventQueue();
        expect(parts.calls, 2);
        final action = seek ? p.seekTo(1700, autoplay: false) : p.toggle();
        parts.pending!.complete(
          TalkRecordPartsTicket(const [
            TalkRecordPlaybackPart(0, 0, 1000, 'first'),
            TalkRecordPlaybackPart(1, 1000, 1500, 'second'),
          ], DateTime.now().add(const Duration(minutes: 5))),
        );
        await action;
        await pumpEventQueue();
        expect(backend.plays, 1);
        if (seek) {
          expect(backend.loads.last, ('second', 700));
          expect(backend.seeks.last, 700);
        } else {
          expect(backend.pauses, 1);
          expect(backend.loads.length, 1);
        }
      },
    );
  }

  test('late parts response after account change cannot load audio', () async {
    final p = container.read(talkRecordPlayerProvider.notifier);
    p.attach(
      recordId: '123',
      durationMs: 2500,
      playbackAllowed: true,
      useParts: true,
    );
    parts.pending = Completer<TalkRecordPartsTicket>();
    final playing = p.play();
    await pumpEventQueue();
    authChanged();
    parts.pending!.complete(
      TalkRecordPartsTicket(const [
        TalkRecordPlaybackPart(0, 0, 1000, 'first'),
      ], DateTime.now().add(const Duration(minutes: 5))),
    );
    await playing;
    expect(backend.loads, isEmpty);
    expect(container.read(talkRecordPlayerProvider).recordId, isEmpty);
  });

  test('a delayed renewal load cannot overwrite a later seek', () async {
    final p = container.read(talkRecordPlayerProvider.notifier);
    p.attach(
      recordId: '123',
      durationMs: 2500,
      playbackAllowed: true,
      useParts: true,
    );
    parts.ttl = const Duration(seconds: 30);
    await p.play();
    final oldLoad = backend.nextLoad = Completer<void>();
    backend.events.add(
      const TalkRecordPlayerBackendState(playing: true, positionMs: 100),
    );
    await pumpEventQueue();
    expect(backend.loads.length, 2);
    final seek = p.seekTo(1700, autoplay: false);
    await pumpEventQueue();
    expect(backend.loads.length, 2);
    oldLoad.complete();
    await seek;
    await pumpEventQueue();
    expect(backend.activeUrl, 'second');
    expect(backend.loads.last, ('second', 700));
    expect(backend.plays, 1);
  });

  for (final revoke in [false, true]) {
    test(
      'a delayed load is stopped after ${revoke ? 'revocation' : 'account switch'}',
      () async {
        final p = container.read(talkRecordPlayerProvider.notifier);
        p.attach(
          recordId: '123',
          durationMs: 2500,
          playbackAllowed: true,
          useParts: true,
        );
        final oldLoad = backend.nextLoad = Completer<void>();
        final playing = p.play();
        await pumpEventQueue();
        if (revoke) {
          p.attach(
            recordId: '123',
            durationMs: 2500,
            playbackAllowed: false,
            useParts: true,
          );
        } else {
          authChanged();
        }
        oldLoad.complete();
        await playing;
        await pumpEventQueue();
        expect(backend.activeUrl, isNull);
        expect(backend.plays, 0);
      },
    );
  }

  test(
    'parts gateway validates record, sequence, timeline and same origin',
    () async {
      final api = _Api();
      Map<String, dynamic> response = {
        'record_id': '123',
        'expiry':
            DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'parts': [
          {
            'seq': 0,
            'offset_ms': 0,
            'duration_ms': 1000,
            'url': '/api/v1/talk-records/123/playback/parts/0?ticket=a',
          },
          {
            'seq': 1,
            'offset_ms': 1000,
            'duration_ms': 1500,
            'url': '/api/v1/talk-records/123/playback/parts/1?ticket=a',
          },
        ],
      };
      when(() => api.playbackParts('123')).thenAnswer((_) async => response);
      final gateway = TalkRecordApiPartsPlaybackGateway(api);
      final ticket = await gateway.openTicket('123');
      expect(ticket.parts.length, 2);
      expect(
        ticket.expiresAt.difference(DateTime.now()).inSeconds,
        lessThanOrEqualTo(300),
      );
      response = {...response, 'record_id': '124'};
      await expectLater(gateway.openTicket('123'), throwsStateError);
      response = {
        ...response,
        'record_id': '123',
        'parts': [
          {
            'seq': 0,
            'offset_ms': 1,
            'duration_ms': 1000,
            'url': '/api/v1/talk-records/123/playback/parts/0?ticket=a',
          },
        ],
      };
      await expectLater(gateway.openTicket('123'), throwsStateError);
      response = {
        ...response,
        'parts': [
          {
            'seq': 0,
            'offset_ms': 0,
            'duration_ms': 1000,
            'url': 'https://evil.invalid/api/v1/talk-records/123/playback/parts/0?ticket=a',
          },
        ],
      };
      await expectLater(gateway.openTicket('123'), throwsStateError);
    },
  );
}
