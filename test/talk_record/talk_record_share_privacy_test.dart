import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_providers.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_fixture_service.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';

class DeferredShare extends FixtureTalkRecordShareService {
  DeferredShare()
    : super(TalkRecordShareFixtureScenarios.ownerWithGrants().entries);
  final pending = Completer<TalkRecordFetched<TalkRecordModel>>();
  int grantsCalls = 0;
  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(String id) =>
      pending.future;
  @override
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> grants(String id) {
    grantsCalls++;
    return super.grants(id);
  }
}

void main() {
  for (final fail in [false, true]) {
    test(
      'auth clears sharing and rejects late ${fail ? "error" : "success"}',
      () async {
        final service = DeferredShare();
        final listeners = <void Function()>[];
        final container = ProviderContainer(
          overrides: [
            talkRecordShareServiceProvider.overrideWithValue(service),
            talkRecordAuthSubscribeProvider.overrideWithValue((changed) {
              listeners.add(changed);
              return () => listeners.remove(changed);
            }),
          ],
        );
        final notifier = container.read(talkRecordShareCenterProvider.notifier);
        final request = notifier.bind('1001');
        for (final listener in List.of(listeners)) {
          listener();
        }
        expect(container.read(talkRecordShareCenterProvider).recordId, isEmpty);
        if (fail) {
          service.pending.completeError(StateError('old account failed'));
        } else {
          service.pending.complete(
            await TalkRecordShareFixtureScenarios.ownerWithGrants().record(
              '1001',
            ),
          );
        }
        await request;
        final state = container.read(talkRecordShareCenterProvider);
        expect(state.record, isNull);
        expect(state.grants, isEmpty);
        expect(state.phase, TalkRecordSharePhase.idle);
        expect(service.grantsCalls, 0);
        container.dispose();
        expect(listeners, isEmpty);
      },
    );
  }
}
