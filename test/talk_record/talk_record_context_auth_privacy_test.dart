import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_save_location_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

import 'talk_record_list_page_test.dart' show FakeListService;

class DeferredContexts extends FakeListService {
  final requests = <Completer<List<TalkRecordCreationContextModel>>>[];
  @override
  Future<List<TalkRecordCreationContextModel>> creationContexts({
    String cursor = '',
    int? limit,
  }) {
    final request = Completer<List<TalkRecordCreationContextModel>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  testWidgets(
    'auth reload hides previous organizations while new directory is pending',
    (tester) async {
      final service = DeferredContexts();
      final listeners = <void Function()>[];
      final container = ProviderContainer(
        overrides: [
          talkRecordListServiceProvider.overrideWithValue(service),
          talkRecordAuthSubscribeProvider.overrideWithValue((changed) {
            listeners.add(changed);
            return () => listeners.remove(changed);
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TalkRecordSaveLocationPage(
              entryContext: TalkRecordEntryContext.personal(),
            ),
          ),
        ),
      );
      service.requests.single.complete(const [
        TalkRecordCreationContextModel(
          scope: TalkRecordScope.organization,
          organizationId: '1',
          displayName: 'Private Old Organization',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Private Old Organization'), findsOneWidget);
      for (final listener in List.of(listeners)) {
        listener();
      }
      await tester.pump();
      expect(service.requests, hasLength(2));
      expect(service.requests.last.isCompleted, isFalse);
      expect(find.text('Private Old Organization'), findsNothing);
      expect(
        container.read(talkRecordCreationContextsProvider).isLoading,
        isTrue,
      );
      service.requests.last.complete(const []);
      await tester.pumpAndSettle();
    },
  );
}
