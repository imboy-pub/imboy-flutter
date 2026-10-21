import 'dart:async';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_detail_providers.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_participants_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/detail/talk_record_participants_provider.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_participant_picker.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

const _guest = TalkRecordParticipantInput(displayName: 'Guest');
TalkRecordFetched<TalkRecordParticipants> _response(
  String id,
  int revision, [
  String label = '',
]) => TalkRecordFetched(
  TalkRecordParticipants.fromJson({
    'record_id': id,
    'revision': revision,
    'list': label.isEmpty
        ? <Map<String, Object?>>[]
        : <Map<String, Object?>>[
            {
              'id': 9,
              'user_id': null,
              'display_name': label,
              'attendance_source': 'manual',
            },
          ],
  }),
  etag: '"$revision"',
);

class _Service implements TalkRecordParticipantsService {
  Future<TalkRecordFetched<TalkRecordParticipants>> Function(String) get = (
    id,
  ) async => _response(id, 1);
  Future<TalkRecordFetched<TalkRecordParticipants>> Function(String) put = (
    id,
  ) async => _response(id, 2, 'Guest');
  String? ifMatch;
  List<TalkRecordParticipantInput>? submitted;
  @override
  Future<TalkRecordFetched<TalkRecordParticipants>> load(String id) => get(id);
  @override
  Future<TalkRecordFetched<TalkRecordParticipants>> save(
    String id,
    List<TalkRecordParticipantInput> list,
    String etag,
  ) {
    ifMatch = etag;
    submitted = list;
    return put(id);
  }
}

class _Harness {
  final service = _Service();
  final listeners = <void Function()>[];
  late final container = ProviderContainer(
    overrides: [
      talkRecordParticipantsServiceProvider.overrideWithValue(service),
      talkRecordAuthSubscribeProvider.overrideWithValue((listener) {
        listeners.add(listener);
        return () => listeners.remove(listener);
      }),
    ],
  );
  late final subscription = container.listen(
    talkRecordParticipantsProvider,
    (_, _) {},
  );
  TalkRecordParticipantsNotifier get notifier {
    subscription.read();
    return container.read(talkRecordParticipantsProvider.notifier);
  }

  TalkRecordParticipantsState get state =>
      container.read(talkRecordParticipantsProvider);
  void auth() {
    for (final listener in List.of(listeners)) {
      listener();
    }
  }

  void dispose() => container.dispose();
}

class _Directory extends TalkRecordParticipantDirectory {
  final completers = <Completer<List<TalkRecordParticipantOption>>>[];
  final queries = <String>[];
  @override
  bool get isAvailable => true;
  @override
  Future<List<TalkRecordParticipantOption>> search(String org, String q) {
    queries.add(q);
    final c = Completer<List<TalkRecordParticipantOption>>();
    completers.add(c);
    return c.future;
  }
}

class _Detail extends TalkRecordDetailNotifier {
  _Detail(this.edit);
  final bool edit;
  @override
  TalkRecordDetailState build() => TalkRecordDetailState(
    recordId: '1',
    phase: TalkRecordDetailPhase.ready,
    record: TalkRecordModel.fromJson({
      'id': 1,
      'scope': 'personal',
      'capabilities_for_actor': {'edit': edit},
    }),
  );
}

void main() {
  for (final edit in [false, true]) {
    testWidgets('participants page edit capability=$edit', (tester) async {
      final service = _Service();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordDetailProvider.overrideWith(() => _Detail(edit)),
            talkRecordParticipantsServiceProvider.overrideWithValue(service),
            talkRecordAuthSubscribeProvider.overrideWithValue((_) => () {}),
          ],
          child: const MaterialApp(
            home: TalkRecordParticipantsPage(recordId: '1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.common.edit), edit ? findsOneWidget : findsNothing);
      expect(
        find.text(t.common.buttonSave),
        edit ? findsOneWidget : findsNothing,
      );
    });
  }

  test(
    'uses exact fetched ETag and explicit full list including clearing',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.notifier.bind('1');
      h.notifier.select([_guest]);
      await h.notifier.save();
      expect(h.service.ifMatch, '"1"');
      expect(h.service.submitted!.single.displayName, 'Guest');
      expect(h.state.notice, ParticipantNotice.saved);
      h.notifier.select([]);
      h.service.put = (id) async => _response(id, 3);
      await h.notifier.save();
      expect(h.service.submitted, isEmpty);
    },
  );

  test('transport response loss reconciles GET actual participants', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.notifier.bind('1');
    h.notifier.select([_guest]);
    h.service.put = (_) async => throw StateError('connection lost');
    h.service.get = (id) async => _response(id, 2, 'Guest');
    await h.notifier.save();
    expect(h.state.notice, ParticipantNotice.saved);
    expect(h.state.etag, '"2"');
  });

  test(
    'response loss and concurrent edit never upgrade an old selection ETag',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.notifier.bind('1');
      h.notifier.select([_guest]);
      h.service.put = (_) async => throw StateError('response lost');
      h.service.get = (id) async => _response(id, 3, 'Other editor');
      await h.notifier.save();
      expect(h.state.notice, ParticipantNotice.conflict);
      expect(h.state.etag, '"3"');
      expect(h.state.selected.single.displayName, 'Other editor');
      // A deliberate retry can only submit the refreshed projection, never the
      // abandoned local selection under the new version.
      h.service.put = (id) async => _response(id, 4, 'Other editor');
      await h.notifier.save();
      expect(h.service.ifMatch, '"3"');
      expect(h.service.submitted!.single.displayName, 'Other editor');
    },
  );

  test(
    '412 refreshes actual list without replay or claiming success',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.notifier.bind('1');
      h.notifier.select([_guest]);
      h.service.put = (_) async =>
          throw const TalkRecordApiException(412, 'stale');
      h.service.get = (id) async => _response(id, 3, 'Other');
      await h.notifier.save();
      expect(h.state.notice, ParticipantNotice.conflict);
      expect(h.state.selected.single.displayName, 'Other');
      expect(h.state.etag, '"3"');
    },
  );

  test('422 retains invalid selection for explicit correction', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.notifier.bind('1');
    h.notifier.select([_guest]);
    h.service.put = (_) async =>
        throw const TalkRecordApiException(422, 'invalid');
    await h.notifier.save();
    expect(h.state.notice, ParticipantNotice.invalid);
    expect(h.state.selected.single.displayName, 'Guest');
  });

  test(
    'access revocation clears participants and does not reconcile',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.notifier.bind('1');
      h.notifier.select([_guest]);
      h.service.put = (_) async =>
          throw const TalkRecordApiException(403, 'denied');
      h.service.get = (_) => throw StateError('must not load');
      await h.notifier.save();
      expect(h.state.ready, false);
      expect(h.state.selected, isEmpty);
    },
  );

  test(
    'reconciliation access loss clears retained participant facts',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.notifier.bind('1');
      h.notifier.select([_guest]);
      h.service.put = (_) async => throw StateError('lost response');
      h.service.get = (_) async =>
          throw const TalkRecordApiException(404, 'hidden');
      await h.notifier.save();
      expect(h.state.selected, isEmpty);
      expect(h.state.ready, false);
    },
  );

  test('same uid auth event clears and fences late GET', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    final late = Completer<TalkRecordFetched<TalkRecordParticipants>>();
    h.service.get = (_) => late.future;
    final pending = h.notifier.bind('1');
    h.auth();
    late.complete(_response('1', 2, 'Secret'));
    await pending;
    expect(h.state.recordId, '');
    expect(h.state.selected, isEmpty);
  });

  test(
    'record switch fences late save failure and GET reconciliation',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.notifier.bind('1');
      h.notifier.select([_guest]);
      final late = Completer<TalkRecordFetched<TalkRecordParticipants>>();
      h.service.put = (_) => late.future;
      final pending = h.notifier.save();
      await h.notifier.bind('2');
      late.completeError(StateError('late'));
      await pending;
      expect(h.state.recordId, '2');
      expect(h.state.notice, ParticipantNotice.none);
    },
  );

  test('failed reconciliation locks save until fresh load', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.notifier.bind('1');
    h.notifier.select([_guest]);
    h.service.put = (_) async => throw StateError('network');
    h.service.get = (_) async => throw StateError('offline');
    await h.notifier.save();
    expect(h.state.ready, false);
    expect(h.state.etag, '');
    expect(h.state.selected.single.displayName, 'Guest');
  });

  test(
    'auth event fences late successful save without exposing labels',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.notifier.bind('1');
      h.notifier.select([_guest]);
      final late = Completer<TalkRecordFetched<TalkRecordParticipants>>();
      h.service.put = (_) => late.future;
      final pending = h.notifier.save();
      h.auth();
      late.complete(_response('1', 2, 'Private'));
      await pending;
      expect(h.state.recordId, '');
      expect(h.state.selected, isEmpty);
      expect(h.state.notice, ParticipantNotice.none);
    },
  );

  testWidgets('guest picker returns informational selection only', (
    tester,
  ) async {
    final directory = _Directory();
    List<TalkRecordParticipantInput>? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          talkRecordParticipantDirectoryProvider.overrideWithValue(directory),
          talkRecordAuthSubscribeProvider.overrideWithValue((_) => () {}),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showTalkRecordParticipantPicker(
                    context,
                    entryContext: const TalkRecordEntryContext.personal(),
                    selected: [],
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    directory.completers.single.complete([]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '  Visitor  ');
    await tester.tap(find.text(t.talkRecord.participantsAddGuest));
    await tester.pump();
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(result!.single.userId, '');
    expect(result!.single.displayName, 'Visitor');
    expect(result!.single.toJson(), {'display_name': 'Visitor'});
  });

  testWidgets(
    'picker search hides stale directory response, auth clears labels',
    (tester) async {
      final directory = _Directory();
      void Function()? changed;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordParticipantDirectoryProvider.overrideWithValue(directory),
            talkRecordAuthSubscribeProvider.overrideWithValue((listener) {
              changed = listener;
              return () {};
            }),
          ],
          child: const MaterialApp(
            home: TalkRecordParticipantPicker(
              entryContext: TalkRecordEntryContext.personal(),
              selected: [_guest],
            ),
          ),
        ),
      );
      directory.completers.first.complete([
        const TalkRecordParticipantOption(userId: '10', displayName: 'First'),
      ]);
      await tester.pump();
      expect(find.text('First'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, 'Next');
      await tester.pump(const Duration(milliseconds: 350));
      changed!();
      await tester.pump();
      directory.completers.last.complete([
        const TalkRecordParticipantOption(userId: '11', displayName: 'Private'),
      ]);
      await tester.pump();
      expect(find.text('Guest'), findsNothing);
      expect(find.text('Private'), findsNothing);
      expect(find.text('First'), findsNothing);
    },
  );
}
