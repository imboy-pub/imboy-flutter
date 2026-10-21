import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' as app;
import 'package:imboy/modules/talk_record/application/talk_record_capture_api_gateway.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

import 'talk_record_capture_binding_test.dart' show RecoveryApi;

class PolicyApi extends RecoveryApi {
  int lookups = 0, creates = 0;
  bool late = false, loseResponse = false;
  String currentPolicy = 'v2', actualOwner = '100';
  final policies = <String>[];
  TalkRecordFetched<TalkRecordModel>? result;
  TalkRecordFetched<TalkRecordModel> mapping() => TalkRecordFetched(
    TalkRecordModel(
      id: '1',
      ownerUserId: actualOwner,
      clientRecordingId: 'record-client',
      scope: TalkRecordScope.personal,
    ),
    etag: '"1"',
  );
  @override
  Future<TalkRecordFetched<TalkRecordModel>?> lookupRecording({
    required String clientRecordingId,
    required TalkRecordScope scope,
    String? organizationId,
    String? workspaceId,
  }) async {
    lookups++;
    expect(clientRecordingId, 'record-client');
    return result;
  }

  @override
  Future<TalkRecordCapabilitiesModel> capabilities() async =>
      TalkRecordCapabilitiesModel(
        policyVersion: currentPolicy,
        recordingEnabled: true,
      );
  @override
  Future<TalkRecordFetched<TalkRecordModel>> create({
    required String clientRecordingId,
    required TalkRecordScope scope,
    required String language,
    required TalkRecordProcessingMode processingMode,
    required String policyVersion,
    required String idempotencyKey,
    String title = '',
    String? organizationId,
    String? workspaceId,
    TalkRecordSourceType sourceType = TalkRecordSourceType.liveRecording,
    DateTime? reportedStartedAt,
  }) async {
    creates++;
    expect(idempotencyKey, 'record-client');
    policies.add(policyVersion);
    if (late || loseResponse) {
      result = mapping();
      throw StateError(late ? 'idempotency_conflict' : 'response lost');
    }
    return mapping();
  }
}

const local = TalkRecordLocalBinding(
  account: TalkRecordAccount('https://local.example', '100'),
  clientRecordingId: 'record-client',
  deviceSessionId: 'device-session',
  context: TalkRecordEntryContext.personal(),
  title: '',
  processingMode: 'record_only',
);
void main() {
  setUp(() {
    app.deviceId = 'synthetic-install-device';
  });

  test('legacy unknown policy/time stay unknown across durable roundtrip', () {
    final v = TalkRecordLocalBinding.fromJson(local.toJson());
    expect(v.policyVersion, '');
    expect(v.uploadPolicyAcknowledgedAt, isNull);
    expect(v.uploadAttempted, false);
    final ack = v.copyWith(
      uploadPolicyVersion: 'v2',
      uploadPolicyAcknowledgedAt: DateTime.utc(2026),
    );
    final saved = TalkRecordLocalBinding.fromJson(ack.toJson());
    expect(saved.policyVersion, '');
    expect(saved.effectiveUploadPolicy, 'v2');
    expect(saved.uploadPolicyAcknowledgedAt, DateTime.utc(2026));
  });
  test(
    'offline draft requires explicit current acknowledgement before create',
    () async {
      final api = PolicyApi();
      await expectLater(
        TalkRecordApiCaptureGateway(api).bind(local, (_) async {}, () {}),
        throwsA(isA<TalkRecordUploadPolicyRequired>()),
      );
      expect(api.creates, 0);
    },
  );
  test(
    'acknowledged upload pins submitted policy before server request',
    () async {
      final api = PolicyApi();
      final saved = <TalkRecordLocalBinding>[];
      final bound = await TalkRecordApiCaptureGateway(api).bind(
        local.copyWith(
          uploadPolicyVersion: 'v2',
          uploadPolicyAcknowledgedAt: DateTime.utc(2026),
        ),
        (value) async {
          saved.add(value);
        },
        () {},
      );
      expect(saved.first.submittedPolicyVersion, 'v2');
      expect(saved.first.recordId, isEmpty);
      expect(bound.recordId, '1');
      expect(bound.policyVersion, isEmpty);
      expect(api.policies, ['v2']);
    },
  );
  for (final conflict in [true, false]) {
    test(
      'lookup none then late create/response loss reconciles same UUID $conflict',
      () async {
        final api = PolicyApi()
          ..late = conflict
          ..loseResponse = !conflict;
        final bound = await TalkRecordApiCaptureGateway(api).bind(
          local.copyWith(
            uploadPolicyVersion: 'v2',
            uploadPolicyAcknowledgedAt: DateTime.utc(2026),
          ),
          (_) async {},
          () {},
        );
        expect(api.lookups, 2);
        expect(api.creates, 1);
        expect(bound.recordId, '1');
        expect(bound.uploadAttempted, true);
      },
    );
  }
  test(
    'existing old-policy record recovered without rewriting policy or create',
    () async {
      final api = PolicyApi()
        ..result = const TalkRecordFetched(
          TalkRecordModel(
            id: '1',
            ownerUserId: '100',
            clientRecordingId: 'record-client',
            scope: TalkRecordScope.personal,
          ),
          etag: '"1"',
        );
      final bound = await TalkRecordApiCaptureGateway(api)
          .bind(local, (_) async {}, () {});
      expect(bound.policyVersion, isEmpty);
      expect(bound.uploadPolicyVersion, isEmpty);
      expect(api.creates, 0);
    },
  );
  test('wrong owner from lookup never maps or creates', () async {
    final api = PolicyApi()..actualOwner = '200';
    api.result = api.mapping();
    await expectLater(
      TalkRecordApiCaptureGateway(api).bind(local, (_) async {}, () {}),
      throwsStateError,
    );
    expect(api.creates, 0);
  });
  test('auth change during lookup cannot map late response', () async {
    final api = PolicyApi()
      ..result = const TalkRecordFetched(
        TalkRecordModel(
          id: '1',
          ownerUserId: '100',
          clientRecordingId: 'record-client',
          scope: TalkRecordScope.personal,
        ),
        etag: '"1"',
      );
    var checks = 0;
    await expectLater(
      TalkRecordApiCaptureGateway(api).bind(local, (_) async {}, () {
        if (++checks >= 3) throw StateError('account changed');
      }),
      throwsStateError,
    );
    expect(api.creates, 0);
  });
}
