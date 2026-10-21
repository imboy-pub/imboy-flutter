import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_providers.dart';
import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_fixture_service.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

class _Auth {
  final listeners = <void Function()>[];
  void Function() subscribe(void Function() callback) {
    listeners.add(callback);
    return () => listeners.remove(callback);
  }

  void change() {
    for (final callback in List.of(listeners)) {
      callback();
    }
  }
}

class _Service extends FixtureTalkRecordResultsService {
  _Service()
    : super([
        TalkRecordResultsFixtureScenarios.entry(recordId: 'a'),
        TalkRecordResultsFixtureScenarios.entry(recordId: 'b'),
      ]);
  final blocked = <String, Completer<void>>{};
  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(String id) async {
    if (blocked[id] case final gate?) await gate.future;
    return super.record(id);
  }
}

void main() {
  for (final kind in ['export', 'transfer', 'delete']) {
    test(
      '$kind auth event clears synchronously and ignores late success',
      () async {
        final auth = _Auth();
        final service = _Service();
        final container = ProviderContainer(
          overrides: [
            talkRecordAuthSubscribeProvider.overrideWithValue(auth.subscribe),
            talkRecordResultsServiceProvider.overrideWithValue(service),
          ],
        );
        dynamic notifier() => switch (kind) {
          'export' => container.read(talkRecordExportCenterProvider.notifier),
          'transfer' => container.read(
            talkRecordTransferCenterProvider.notifier,
          ),
          _ => container.read(talkRecordDeleteCenterProvider.notifier),
        };
        dynamic state() => switch (kind) {
          'export' => container.read(talkRecordExportCenterProvider),
          'transfer' => container.read(talkRecordTransferCenterProvider),
          _ => container.read(talkRecordDeleteCenterProvider),
        };
        await notifier().bind('a');
        expect(state().record, isNotNull);
        final gate = service.blocked['a'] = Completer<void>();
        final pending = notifier().reload() as Future<void>;
        auth.change();
        expect(state().record, isNull);
        expect(state().recordId, '');
        gate.complete();
        await pending;
        expect(state().record, isNull);
        expect(state().recordId, '');
        container.dispose();
        expect(auth.listeners, isEmpty);
      },
    );
    test(
      '$kind record switch rejects old reload completion and error',
      () async {
        for (final fail in [false, true]) {
          final auth = _Auth();
          final service = _Service();
          final container = ProviderContainer(
            overrides: [
              talkRecordAuthSubscribeProvider.overrideWithValue(auth.subscribe),
              talkRecordResultsServiceProvider.overrideWithValue(service),
            ],
          );
          dynamic notifier() => switch (kind) {
            'export' => container.read(talkRecordExportCenterProvider.notifier),
            'transfer' => container.read(
              talkRecordTransferCenterProvider.notifier,
            ),
            _ => container.read(talkRecordDeleteCenterProvider.notifier),
          };
          dynamic state() => switch (kind) {
            'export' => container.read(talkRecordExportCenterProvider),
            'transfer' => container.read(talkRecordTransferCenterProvider),
            _ => container.read(talkRecordDeleteCenterProvider),
          };
          final gate = service.blocked['a'] = Completer<void>();
          final old = notifier().bind('a') as Future<void>;
          await notifier().bind('b');
          if (fail) {
            gate.completeError(StateError('old request'));
          } else {
            gate.complete();
          }
          await old;
          expect(state().recordId, 'b');
          expect(state().record.id, 'b');
          container.dispose();
          expect(auth.listeners, isEmpty);
        }
      },
    );
  }
}
