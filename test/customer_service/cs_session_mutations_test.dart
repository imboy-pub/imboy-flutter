import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

class MutationApi extends CsApi {
  final pending = Completer<void>();
  int calls = 0;
  CsApiException? error;
  int sends = 0, uploads = 0;
  Completer<EnterpriseAsset>? pendingUpload;
  @override
  Future<void> close(
    String orgId,
    String sessionId, {
    required int expectedVersion,
    String? reason,
    String workspaceId = '',
  }) async {
    calls++;
    await pending.future;
    if (error != null) throw error!;
  }

  @override
  Future<void> transfer(
    String orgId,
    String sessionId, {
    required String toIdentityId,
    required int expectedVersion,
    String workspaceId = '',
  }) async {
    calls++;
    await pending.future;
    if (error != null) throw error!;
  }

  @override
  Future<CsConversationMessage> sendConversationMessage(
    String orgId,
    String conversationId, {
    required String body,
    required String clientMsgId,
    required String identityId,
    List<String> assetIds = const [],
    String workspaceId = '',
  }) async {
    sends++;
    throw const CsApiException(503, 'synthetic unavailable');
  }

  @override
  Future<EnterpriseAsset> uploadEnterpriseAsset(
    String orgId, {
    required String workspaceId,
    required String conversationId,
    required String mime,
    required Uint8List bytes,
    String fileName = '',
    CsAssetUploadOperation? operation,
  }) async {
    uploads++;
    if (pendingUpload != null) return pendingUpload!.future;
    throw const CsApiException(503, 'synthetic unavailable');
  }
}

void main() {
  test('same-scope concurrent close dispatches only one CAS', () async {
    final api = MutationApi();
    final flow =
        CsSessionFlow(orgId: '1', sessionId: '3', identityId: '6', csApi: api)
          ..detail = const CsSessionDetail(
            sessionId: '3',
            status: 'active',
            version: 5,
          );
    final first = flow.closeSession();
    final second = flow.closeSession();
    final calls = api.calls;
    api.pending.complete();
    await Future.wait([first, second]);
    flow.dispose();
    expect(calls, 1);
  });
  test('frozen version/status/assignee reject stale intent and queued close remains valid', () async {
    final api = MutationApi();
    final flow = CsSessionFlow(
      orgId: '1',
      sessionId: '3',
      identityId: '6',
      csApi: api,
    );
    flow.detail = const CsSessionDetail(
      sessionId: '3',
      status: 'active',
      version: 5,
      assigneeIdentityId: '6',
    );
    final snapshot = CsSessionActionSnapshot(flow.detail!);
    for (final next in [
      const CsSessionDetail(
        sessionId: '3',
        status: 'active',
        version: 6,
        assigneeIdentityId: '6',
      ),
      const CsSessionDetail(
        sessionId: '3',
        status: 'closed',
        version: 5,
        assigneeIdentityId: '6',
      ),
      const CsSessionDetail(
        sessionId: '3',
        status: 'active',
        version: 5,
        assigneeIdentityId: '7',
      ),
    ]) {
      flow.detail = next;
      expect(
        await flow.closeSession(snapshot: snapshot),
        CsSeatFailureKind.conflict,
      );
    }
    expect(api.calls, 0);
    flow.detail = const CsSessionDetail(
      sessionId: '3',
      status: 'queued',
      version: 7,
    );
    expect(await flow.transferTo('9'), CsSeatFailureKind.conflict);
    expect(api.calls, 0);
    api.pending.complete();
    expect(await flow.closeSession(), isNull);
    expect(api.calls, 1);
    flow.dispose();
  });
  test(
    'public CAS refuses an unconfirmed message independently of the UI',
    () async {
      final api = MutationApi()..pending.complete();
      final f =
          CsSessionFlow(orgId: '1', sessionId: '3', identityId: '6', csApi: api)
            ..detail = const CsSessionDetail(
              sessionId: '3',
              status: 'active',
              version: 5,
            )
            ..pendingClientMsgId = 'synthetic-unconfirmed';
      expect(await f.closeSession(), CsSeatFailureKind.other);
      expect(await f.transferTo('9'), CsSeatFailureKind.other);
      expect(api.calls, 0);
      f.dispose();
    },
  );
  for (final code in [401, 403]) {
    for (final transfer in [false, true]) {
      test(
        'current $code ${transfer ? 'transfer' : 'close'} revokes all displayed authority',
        () async {
          final api = MutationApi()
            ..pending.complete()
            ..error = CsApiException(code, 'synthetic refused');
          final f =
              CsSessionFlow(
                  orgId: '1',
                  sessionId: '3',
                  identityId: '6',
                  csApi: api,
                )
                ..detail = const CsSessionDetail(
                  sessionId: '3',
                  status: 'active',
                  version: 5,
                )
                ..messages = [
                  const EnterpriseMessage(
                    id: '10',
                    conversationId: '4',
                    organizationId: '1',
                    content: 'synthetic body',
                  ),
                ]
                ..messageAssets = {
                  '10': [CsMessageAsset(id: '11')],
                }
                ..messageReadAt = {'10': DateTime.utc(2026)};
          if (transfer) {
            await f.transferTo('9');
          } else {
            await f.closeSession();
          }
          expect(f.readRevoked, isTrue);
          expect(f.messages, isEmpty);
          expect(f.messageAssets, isEmpty);
          expect(f.messageReadAt, isEmpty);
          expect(f.machine.canSend, isFalse);
          f.dispose();
        },
      );
    }
  }
  test('late old-scope 401 does not revoke current scope', () async {
    final api = MutationApi()
      ..error = const CsApiException(401, 'synthetic refused');
    var current = true;
    final f =
        CsSessionFlow(
            orgId: '1',
            sessionId: '3',
            identityId: '6',
            csApi: api,
            scopeCurrent: () => current,
          )
          ..detail = const CsSessionDetail(
            sessionId: '3',
            status: 'active',
            version: 5,
          );
    final pending = f.closeSession();
    current = false;
    api.pending.complete();
    await pending;
    expect(f.readRevoked, isFalse);
    f.dispose();
  });

  test('public send and upload cannot start during a pending CAS', () async {
    final api = MutationApi();
    final f =
        CsSessionFlow(
            orgId: '1',
            sessionId: '3',
            identityId: '6',
            workspaceId: '2',
            conversationId: '4',
            csApi: api,
          )
          ..detail = const CsSessionDetail(
            sessionId: '3',
            status: 'active',
            version: 5,
          );
    final close = f.closeSession();
    await f.send('synthetic');
    try {
      await f.uploadAsset(mime: 'text/plain', bytes: Uint8List(1));
    } on CsApiException {
      /* old upload may reach API */
    }
    final sends = api.sends, uploads = api.uploads;
    api.pending.complete();
    await close;
    expect(sends, 0);
    expect(uploads, 0);
    f.dispose();
  });
  test('public CAS cannot interleave with an already started upload', () async {
    final api = MutationApi()..pendingUpload = Completer();
    final f =
        CsSessionFlow(
            orgId: '1',
            sessionId: '3',
            identityId: '6',
            workspaceId: '2',
            conversationId: '4',
            csApi: api,
          )
          ..detail = const CsSessionDetail(
            sessionId: '3',
            status: 'active',
            version: 5,
          );
    final upload = f.uploadAsset(mime: 'text/plain', bytes: Uint8List(1));
    await Future<void>.delayed(Duration.zero);
    final close = f.closeSession();
    final calls = api.calls;
    api.pending.complete();
    await close;
    api.pendingUpload!.completeError(
      const CsApiException(503, 'synthetic unavailable'),
    );
    try {
      await upload;
    } on CsApiException {
      /* request has a real failure */
    }
    expect(calls, 0);
    f.dispose();
  });
  test(
    'upload workspace await cannot resume a write in a retired scope',
    () async {
      var current = true;
      final api = MutationApi();
      final f = CsSessionFlow(
        orgId: '1',
        sessionId: '3',
        identityId: '6',
        workspaceId: '2',
        conversationId: '4',
        csApi: api,
        scopeCurrent: () => current,
      );
      final pending = f.uploadAsset(mime: 'text/plain', bytes: Uint8List(1));
      current = false;
      expect(await pending, isEmpty);
      expect(api.uploads, 0);
      f.dispose();
    },
  );
}
