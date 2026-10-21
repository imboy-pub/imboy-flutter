import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_auth.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_prepare_sections.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

class DirectoryApi extends TalkRecordApi {
  Map<String, dynamic>? query;
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    query = queryParameters;
    expect(uri, endsWith('/talk-records/share-candidates'));
    return IMBoyHttpResponse.success({
      'list': [
        {'user_id': 7, 'display_name': 'Peer'},
      ],
      'next_cursor': '',
      'has_more': false,
    });
  }
}

class WaitingDirectory implements TalkRecordParticipantDirectory {
  final response = Completer<List<TalkRecordParticipantOption>>();
  int calls = 0;
  @override
  bool get isAvailable => true;
  @override
  Future<List<TalkRecordParticipantOption>> search(
    String organizationId,
    String q,
  ) {
    calls++;
    return response.future;
  }
}

void main() {
  test('production directory carries organization and workspace without global user listing', () async {
    final api = DirectoryApi();
    final directory = ApiTalkRecordParticipantDirectory(api);
    final result = await directory.searchContext(
      const TalkRecordEntryContext(
        scope: TalkRecordScope.organization,
        organizationId: '10',
        workspaceId: '20',
      ),
      'peer',
    );
    expect(api.query, containsPair('organization_id', 10));
    expect(api.query, containsPair('workspace_id', 20));
    expect(api.query, containsPair('scope', 'organization'));
    expect(result.single.userId, '7');
  });
  testWidgets(
    'account change hides directory and discards pending old options',
    (tester) async {
      final directory = WaitingDirectory();
      final listeners = <void Function()>[];
      final container = ProviderContainer(
        overrides: [
          talkRecordParticipantDirectoryProvider.overrideWithValue(directory),
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
          child: MaterialApp(
            home: Scaffold(
              body: TalkRecordCollabSection(
                organizationId: '10',
                workspaceId: '20',
                participants: const [],
                onToggleParticipant: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(t.talkRecord.collabSectionTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_participants_choose')),
      );
      await tester.pump();
      expect(directory.calls, 1);
      for (final listener in List.of(listeners)) {
        listener();
      }
      await tester.pump();
      directory.response.complete(const [
        TalkRecordParticipantOption(
          userId: '7',
          displayName: 'Old Private Peer',
        ),
      ]);
      await tester.pump();
      expect(find.text('Old Private Peer'), findsNothing);
    },
  );
}
