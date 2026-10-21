import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_service.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_account_session.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_playback_request.dart';

class _NativePlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });
  const path = '/api/v1/talk-records/800001/playback/stream?ticket=synthetic';
  final base = Uri.parse('https://api.example.test');

  test('trusted relative stream becomes absolute and keeps fresh device/auth headers', () async {
    var token = 'synthetic-one';
    final resolver = TalkRecordPlaybackRequestResolver(
      baseUri: () => base,
      accountId: () => '700001',
      authenticationHeaders: () async => {
        'authorization': token,
        for (final k in ['vsn', 'pkg', 'did', 'cos', 'method', 'sign', 'sk'])
          k: 'synthetic-$k',
      },
    );
    final first = await resolver.resolve(path);
    expect(first.uri.toString(), 'https://api.example.test$path');
    expect(first.headers['authorization'], 'synthetic-one');
    expect(
      first.headers.keys,
      containsAll(['vsn', 'pkg', 'did', 'cos', 'method', 'sign', 'sk']),
    );
    token = 'synthetic-two';
    final renewed = await resolver.resolve(path);
    expect(renewed.headers['authorization'], 'synthetic-two');
    expect(first.headers['authorization'], 'synthetic-one');
  });

  test('cross-origin, other record, raw assets and ambiguous tickets are denied before auth', () async {
    var authCalls = 0;
    final resolver = TalkRecordPlaybackRequestResolver(
      baseUri: () => base,
      accountId: () => '700001',
      authenticationHeaders: () async {
        authCalls++;
        return {'authorization': 'synthetic'};
      },
    );
    for (final input in [
      'https://evil.example.test$path',
      '//evil.example.test$path',
      '/raw/audio.aac',
      '$path&ticket=duplicate',
      '$path&extra=1',
      '$path#fragment',
      '/api/v1/talk-records/800001/playback/stream',
    ]) {
      await expectLater(resolver.resolve(input), throwsStateError);
    }
    expect(authCalls, 0);
    expect(
      () => talkRecordPlaybackUri(path, base, recordId: '800002'),
      throwsStateError,
    );
  });

  test('account changes while auth is pending and later loads cannot reuse credentials', () async {
    var uid = '700001';
    final pending = Completer<Map<String, String>>();
    final resolver = TalkRecordPlaybackRequestResolver(
      baseUri: () => base,
      accountId: () => uid,
      authenticationHeaders: () => pending.future,
    );
    final request = resolver.resolve(path);
    final fails = expectLater(request, throwsStateError);
    uid = '700002';
    pending.complete({'authorization': 'synthetic-old'});
    await fails;
    await expectLater(resolver.resolve(path), throwsStateError);
  });

  test('anonymous and missing token requests fail closed', () async {
    var uid = '';
    final resolver = TalkRecordPlaybackRequestResolver(
      baseUri: () => base,
      accountId: () => uid,
      authenticationHeaders: () async => {},
    );
    await expectLater(resolver.resolve(path), throwsStateError);
    uid = '700001';
    await expectLater(resolver.resolve(path), throwsStateError);
  });

  test('production backend passes signed auth to native setUrl and account event stops/disposes', () async {
    final native = _NativePlayer();
    when(() => native.positionStream).thenAnswer((_) => const Stream.empty());
    when(() => native.durationStream).thenAnswer((_) => const Stream.empty());
    when(() => native.playerStateStream)
        .thenAnswer((_) => const Stream.empty());
    when(
      () => native.setUrl(
        any(),
        headers: any(named: 'headers'),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => const Duration(seconds: 10));
    when(() => native.stop()).thenAnswer((_) async {});
    when(() => native.dispose()).thenAnswer((_) async {});
    var uid = '700001';
    final listeners = <void Function()>[];
    final backend = JustAudioTalkRecordPlayerBackend(
      player: native,
      requestResolver: TalkRecordPlaybackRequestResolver(
        baseUri: () => base,
        accountId: () => uid,
        authenticationHeaders: () async => {
          'authorization': 'synthetic',
          'sign': 'signed',
        },
      ),
      addAuthListener: listeners.add,
      removeAuthListener: listeners.remove,
    );
    await backend.load(path, initialPositionMs: 7);
    verify(
      () => native.setUrl(
        'https://api.example.test$path',
        headers: {'authorization': 'synthetic', 'sign': 'signed'},
        initialPosition: const Duration(milliseconds: 7),
      ),
    ).called(1);
    uid = '700002';
    listeners.single();
    await expectLater(backend.play(), throwsStateError);
    await pumpEventQueue();
    verify(() => native.stop()).called(1);
    verify(() => native.dispose()).called(1);
    backend.dispose();
    await pumpEventQueue();
    verifyNever(() => native.dispose());
  });

  test(
    'account event blocks synchronously, stops then disposes once',
    () async {
      var uid = '700001';
      final listeners = <void Function()>[];
      final stopped = Completer<void>();
      var stops = 0, disposals = 0;
      final session = TalkRecordPlaybackAccountSession(
        accountKey: () => uid,
        addListener: listeners.add,
        removeListener: listeners.remove,
        stop: () {
          stops++;
          return stopped.future;
        },
        disposeNative: () async {
          disposals++;
        },
        onBlocked: () {},
        onFailure: (e, s) => fail('Unexpected ${e.runtimeType}'),
      );
      uid = '700002';
      listeners.single();
      expect(session.blocked, isTrue);
      expect(session.check, throwsStateError);
      expect(stops, 1);
      expect(disposals, 0);
      expect(listeners, isEmpty);
      stopped.complete();
      await session.close();
      await session.close();
      expect(disposals, 1);
      expect(stops, 1);
    },
  );

  test('auth transition blocks before persisted UID changes', () async {
    final listeners = <void Function()>[];
    var stopped = false, disposed = false;
    final session = TalkRecordPlaybackAccountSession(
      accountKey: () => 'same-uid-before-persistence',
      addListener: listeners.add,
      removeListener: listeners.remove,
      stop: () async {
        stopped = true;
      },
      disposeNative: () async {
        disposed = true;
      },
      onBlocked: () {},
      onFailure: (e, s) => fail('Unexpected teardown failure'),
    );
    listeners.single();
    expect(session.blocked, isTrue);
    expect(session.check, throwsStateError);
    expect(stopped, isTrue);
    await session.close();
    expect(disposed, isTrue);
  });

  test(
    'failed native stop still disposes and reports a blocked session',
    () async {
      var uid = '700001';
      final listeners = <void Function()>[];
      final reported = Completer<Object>();
      var disposed = false;
      final session = TalkRecordPlaybackAccountSession(
        accountKey: () => uid,
        addListener: listeners.add,
        removeListener: listeners.remove,
        stop: () async => throw StateError('synthetic native failure'),
        disposeNative: () async {
          disposed = true;
        },
        onBlocked: () {},
        onFailure: (e, s) {
          reported.complete(e);
        },
      );
      uid = '';
      listeners.single();
      expect(await reported.future, isStateError);
      expect(session.blocked, isTrue);
      expect(disposed, isTrue);
    },
  );
}
