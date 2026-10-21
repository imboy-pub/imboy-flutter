import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';

class _Service extends Mock implements TalkRecordDetailService {}

class _Gateway extends Mock implements TalkRecordPlaybackGateway {}

class _Backend implements TalkRecordPlayerBackend {
  final loads = <String>[], plays = <int>[];
  int stops = 0;
  final events = StreamController<TalkRecordPlayerBackendState>.broadcast();
  @override
  Stream<TalkRecordPlayerBackendState> get states => events.stream;
  @override
  Future<void> load(String url, {int initialPositionMs = 0}) async {
    loads.add(url);
  }

  @override
  Future<void> play() async {
    plays.add(1);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(int p) async {}
  @override
  void dispose() {}
}

class _Harness {
  final service = _Service(), gateway = _Gateway(), backend = _Backend();
  final listeners = <void Function()>[];
  late final ProviderContainer container;
  _Harness() {
    when(() => service.record(any())).thenAnswer(
      (i) async => TalkRecordFetched(
        TalkRecordModel(
          id: i.positionalArguments.first as String,
          title: 'private',
        ),
        etag: '1',
      ),
    );
    when(() => service.summary(any())).thenAnswer(
      (_) async => const TalkRecordFetched(
        TalkRecordSummaryModel(id: 'summary', overview: 'private'),
      ),
    );
    when(() => service.marks(any())).thenAnswer(
      (_) async => const TalkRecordCursorPage<TalkRecordMarkModel>(
        list: [TalkRecordMarkModel(id: 'mark')],
      ),
    );
    when(() => service.segments(any())).thenAnswer(
      (_) async => const TalkRecordCursorPage<TalkRecordSegmentModel>(
        list: [TalkRecordSegmentModel(id: 'segment', text: 'private')],
      ),
    );
    when(() => service.speakers(any())).thenAnswer(
      (_) async => const [
        TalkRecordSpeakerModel(id: 'speaker', displayName: 'private'),
      ],
    );
    container = ProviderContainer(
      overrides: [
        talkRecordDetailServiceProvider.overrideWithValue(service),
        talkRecordPlaybackGatewayProvider.overrideWithValue(gateway),
        talkRecordPlayerBackendProvider.overrideWithValue(backend),
        talkRecordAuthSubscribeProvider.overrideWithValue((f) {
          listeners.add(f);
          return () => listeners.remove(f);
        }),
      ],
    );
  }
  void auth() {
    for (final f in List.of(listeners)) {
      f();
    }
  }

  void close() {
    container.dispose();
    unawaited(backend.events.close());
  }
}

TalkRecordPlaybackTicket ticket(String id) => TalkRecordPlaybackTicket(
  recordId: id,
  sessionId: id,
  url: 'fixture://$id',
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
);

void main() {
  setUpAll(() {
    registerFallbackValue(ticket('fallback'));
  });
  test('auth event synchronously clears all loaded detail projections without UID change', () async {
    final h = _Harness();
    addTearDown(h.close);
    final c = h.container;
    await c.read(talkRecordDetailProvider.notifier).bind('a');
    await c.read(talkRecordSegmentsProvider.notifier).bind('a');
    c.read(talkRecordSegmentsProvider.notifier).setQuery('private');
    await c.read(talkRecordSpeakersProvider.notifier).bind('a');
    expect(c.read(talkRecordDetailProvider).record, isNotNull);
    h.auth();
    expect(c.read(talkRecordDetailProvider).record, isNull);
    expect(c.read(talkRecordDetailProvider).summary, isNull);
    expect(c.read(talkRecordDetailProvider).marks, isEmpty);
    expect(c.read(talkRecordDetailProvider).recordEtag, isEmpty);
    expect(c.read(talkRecordSegmentsProvider).segments, isEmpty);
    expect(c.read(talkRecordSegmentsProvider).query, isEmpty);
    expect(c.read(talkRecordSpeakersProvider).speakers, isEmpty);
  });

  for (final error in [false, true]) {
    test(
      'late metadata/segments/speakers ${error ? 'failure' : 'success'} cannot restore auth-cleared state',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        final c = h.container;
        final record = Completer<TalkRecordFetched<TalkRecordModel>>();
        final segments =
            Completer<TalkRecordCursorPage<TalkRecordSegmentModel>>();
        final speakers = Completer<List<TalkRecordSpeakerModel>>();
        when(() => h.service.record('a')).thenAnswer((_) => record.future);
        when(() => h.service.segments('a')).thenAnswer((_) => segments.future);
        when(() => h.service.speakers('a')).thenAnswer((_) => speakers.future);
        final pending = [
          c.read(talkRecordDetailProvider.notifier).bind('a'),
          c.read(talkRecordSegmentsProvider.notifier).bind('a'),
          c.read(talkRecordSpeakersProvider.notifier).bind('a'),
        ];
        h.auth();
        if (error) {
          record.completeError(StateError('old'));
          segments.completeError(StateError('old'));
          speakers.completeError(StateError('old'));
        } else {
          record.complete(const TalkRecordFetched(TalkRecordModel(id: 'a')));
          segments.complete(
            const TalkRecordCursorPage(
              list: [TalkRecordSegmentModel(id: 'old')],
            ),
          );
          speakers.complete(const [TalkRecordSpeakerModel(id: 'old')]);
        }
        await Future.wait(pending);
        expect(
          c.read(talkRecordDetailProvider).phase,
          TalkRecordDetailPhase.idle,
        );
        expect(
          c.read(talkRecordSegmentsProvider).phase,
          TalkRecordSegmentsPhase.idle,
        );
        expect(
          c.read(talkRecordSpeakersProvider).phase,
          TalkRecordSpeakersPhase.idle,
        );
        verifyNever(() => h.service.summary('a'));
      },
    );

    test(
      'late notes ${error ? 'failure' : 'success'} after auth returns false and no saved/conflict state',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        final c = h.container;
        await c.read(talkRecordDetailProvider.notifier).bind('a');
        final pending = Completer<TalkRecordFetched<TalkRecordModel>>();
        when(() => h.service.patchNotes('a', 'private', ifMatch: '1'))
            .thenAnswer((_) => pending.future);
        final saving = c
            .read(talkRecordDetailProvider.notifier)
            .saveNotes('private');
        h.auth();
        if (error) {
          pending.completeError(StateError('old'));
        } else {
          pending.complete(
            const TalkRecordFetched(TalkRecordModel(id: 'a', notes: 'private')),
          );
        }
        expect(await saving, isFalse);
        expect(c.read(talkRecordDetailProvider).record, isNull);
        expect(
          c.read(talkRecordDetailProvider).notesPhase,
          TalkRecordNotesPhase.idle,
        );
      },
    );

    test(
      'late player ticket ${error ? 'failure' : 'success'} after auth never loads or plays',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        final c = h.container;
        final pending = Completer<TalkRecordPlaybackTicket>();
        when(() => h.gateway.openTicket('a', positionMs: 0))
            .thenAnswer((_) => pending.future);
        final player = c.read(talkRecordPlayerProvider.notifier);
        player.attach(recordId: 'a', durationMs: 10, playbackAllowed: true);
        final playing = player.play();
        await pumpEventQueue();
        h.auth();
        expect(c.read(talkRecordPlayerProvider).recordId, isEmpty);
        if (error) {
          pending.completeError(StateError('old'));
        } else {
          pending.complete(ticket('a'));
        }
        await playing;
        expect(h.backend.loads, isEmpty);
        expect(h.backend.plays, isEmpty);
        expect(c.read(talkRecordPlayerProvider).failure, isFalse);
      },
    );
  }

  test(
    'late summary cannot schedule marks or restore auth-cleared data',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      final c = h.container;
      final summary = Completer<TalkRecordFetched<TalkRecordSummaryModel>>();
      when(() => h.service.summary('a')).thenAnswer((_) => summary.future);
      final loading = c.read(talkRecordDetailProvider.notifier).bind('a');
      await pumpEventQueue();
      h.auth();
      summary.complete(
        const TalkRecordFetched(
          TalkRecordSummaryModel(id: 'old', overview: 'private'),
        ),
      );
      await loading;
      expect(c.read(talkRecordDetailProvider).summary, isNull);
      verifyNever(() => h.service.marks('a'));
    },
  );

  test('late speaker claim cannot reload into a new account', () async {
    final h = _Harness();
    addTearDown(h.close);
    final c = h.container;
    await c.read(talkRecordSpeakersProvider.notifier).bind('a');
    final pending = Completer<TalkRecordSpeakerModel>();
    when(() => h.service.claimSpeaker('a', 'speaker'))
        .thenAnswer((_) => pending.future);
    final claiming = c
        .read(talkRecordSpeakersProvider.notifier)
        .claimSelf('speaker');
    h.auth();
    pending.complete(
      const TalkRecordSpeakerModel(id: 'speaker', displayName: 'private'),
    );
    expect(await claiming, isFalse);
    expect(c.read(talkRecordSpeakersProvider).speakers, isEmpty);
    expect(c.read(talkRecordSpeakersProvider).claimConflict, isFalse);
    verify(() => h.service.speakers('a')).called(1);
  });

  test('record switch fences old metadata success and old player failure without stopping new playback', () async {
    final h = _Harness();
    addTearDown(h.close);
    final c = h.container;
    final old = Completer<TalkRecordFetched<TalkRecordModel>>();
    when(() => h.service.record('a')).thenAnswer((_) => old.future);
    final loading = c.read(talkRecordDetailProvider.notifier).bind('a');
    await c.read(talkRecordDetailProvider.notifier).bind('b');
    old.complete(const TalkRecordFetched(TalkRecordModel(id: 'a')));
    await loading;
    expect(c.read(talkRecordDetailProvider).record!.id, 'b');
    final open = Completer<TalkRecordPlaybackTicket>();
    when(() => h.gateway.openTicket('a', positionMs: 0))
        .thenAnswer((_) => open.future);
    when(() => h.gateway.openTicket('b', positionMs: 0))
        .thenAnswer((_) async => ticket('b'));
    final p = c.read(talkRecordPlayerProvider.notifier);
    p.attach(recordId: 'a', durationMs: 10, playbackAllowed: true);
    final playing = p.play();
    await pumpEventQueue();
    p.attach(recordId: 'b', durationMs: 20, playbackAllowed: true);
    await p.play();
    final stops = h.backend.stops;
    open.completeError(StateError('old'));
    await playing;
    expect(c.read(talkRecordPlayerProvider).recordId, 'b');
    expect(c.read(talkRecordPlayerProvider).playing, isTrue);
    expect(h.backend.loads, ['fixture://b']);
    expect(h.backend.stops, stops);
  });

  test('disposed container ignores late record and player responses without disposed-ref errors', () async {
    final h = _Harness();
    final c = h.container;
    final record = Completer<TalkRecordFetched<TalkRecordModel>>(),
        open = Completer<TalkRecordPlaybackTicket>();
    when(() => h.service.record('a')).thenAnswer((_) => record.future);
    when(() => h.gateway.openTicket('a', positionMs: 0))
        .thenAnswer((_) => open.future);
    final loading = c.read(talkRecordDetailProvider.notifier).bind('a');
    final p = c.read(talkRecordPlayerProvider.notifier);
    p.attach(recordId: 'a', durationMs: 10, playbackAllowed: true);
    final playing = p.play();
    await pumpEventQueue();
    h.close();
    record.complete(const TalkRecordFetched(TalkRecordModel(id: 'a')));
    open.complete(ticket('a'));
    await Future.wait([loading, playing]);
    expect(h.backend.loads, isEmpty);
  });
  for (final error in [false, true]) {
    test(
      'late renewal after auth never reloads or restarts ($error)',
      () async {
        final h = _Harness();
        addTearDown(h.close);
        final c = h.container;
        final pending = Completer<TalkRecordPlaybackTicket>();
        when(() => h.gateway.openTicket('a', positionMs: 0)).thenAnswer(
          (_) async => TalkRecordPlaybackTicket(
            recordId: 'a',
            sessionId: 'short',
            url: 'fixture://first',
            expiresAt: DateTime.now().add(const Duration(seconds: 30)),
          ),
        );
        when(() => h.gateway.renewTicket('a', any()))
            .thenAnswer((_) => pending.future);
        final p = c.read(talkRecordPlayerProvider.notifier);
        p.attach(recordId: 'a', durationMs: 100, playbackAllowed: true);
        await p.play();
        h.backend.events.add(
          const TalkRecordPlayerBackendState(playing: true, positionMs: 1),
        );
        await pumpEventQueue();
        h.auth();
        if (error) {
          pending.completeError(StateError('old'));
        } else {
          pending.complete(ticket('a'));
        }
        await pumpEventQueue();
        expect(h.backend.loads, ['fixture://first']);
        expect(h.backend.plays, [1]);
        expect(c.read(talkRecordPlayerProvider).recordId, isEmpty);
        expect(c.read(talkRecordPlayerProvider).failure, isFalse);
      },
    );
  }
}
