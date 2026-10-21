import 'dart:async';

import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

import 'talk_record_list_page_test.dart' show FakeListService;

class DeferredListService extends FakeListService {
  final requests = <Completer<TalkRecordCursorPage<TalkRecordModel>>>[];
  @override
  Future<TalkRecordCursorPage<TalkRecordModel>> page({
    TalkRecordScope? scope,
    String? organizationId,
    String? workspaceId,
    TalkRecordListFilter? filter,
    String? q,
    String cursor = '',
    int? limit,
  }) {
    final request = Completer<TalkRecordCursorPage<TalkRecordModel>>();
    requests.add(request);
    return request.future;
  }
}

TalkRecordCursorPage<TalkRecordModel> result(String title) =>
    TalkRecordCursorPage(
      list: [
        TalkRecordModel.fromJson({
          'id': 1,
          'title': title,
          'capture_status': 'ended',
        }),
      ],
      nextCursor: '',
      hasMore: false,
    );

void main() {
  test(
    'auth event clears draft and list before old response completes',
    () async {
      final listeners = <void Function()>[];
      final service = DeferredListService();
      final container = ProviderContainer(
        overrides: [
          talkRecordListServiceProvider.overrideWithValue(service),
          talkRecordAuthSubscribeProvider.overrideWithValue((changed) {
            listeners.add(changed);
            return () => listeners.remove(changed);
          }),
        ],
      );
      final draft = container.read(talkRecordDraftProvider.notifier);
      draft.setTitle('private previous account');
      final notifier = container.read(talkRecordListProvider.notifier);
      final old = notifier.bind(const TalkRecordEntryContext.personal());
      for (final listener in List.of(listeners)) {
        listener();
      }
      expect(container.read(talkRecordDraftProvider).title, isEmpty);
      expect(container.read(talkRecordListProvider).records, isEmpty);
      expect(
        container.read(talkRecordListProvider).phase,
        TalkRecordListPhase.idle,
      );
      service.requests.single.complete(result('private old response'));
      await old;
      expect(container.read(talkRecordListProvider).records, isEmpty);
      container.dispose();
      expect(listeners, isEmpty);
    },
  );

  test('late list success cannot overwrite a newer search', () async {
    final service = DeferredListService();
    final container = ProviderContainer(
      overrides: [talkRecordListServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(talkRecordListProvider.notifier);
    final old = notifier.bind(const TalkRecordEntryContext.personal());
    final latest = notifier.setQuery('latest');
    service.requests[1].complete(result('latest'));
    await latest;
    service.requests[0].complete(result('private old response'));
    await old;
    expect(
      container.read(talkRecordListProvider).records.single.title,
      'latest',
    );
  });

  test('late list failure cannot replace the newer ready state', () async {
    final service = DeferredListService();
    final container = ProviderContainer(
      overrides: [talkRecordListServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(talkRecordListProvider.notifier);
    final old = notifier.bind(const TalkRecordEntryContext.personal());
    final latest = notifier.setQuery('latest');
    service.requests[1].complete(result('latest'));
    await latest;
    service.requests[0].completeError(StateError('old failure'));
    await old;
    expect(
      container.read(talkRecordListProvider).phase,
      TalkRecordListPhase.ready,
    );
  });
}
