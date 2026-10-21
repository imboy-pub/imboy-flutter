import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_participant_sync.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

class ParticipantApi extends TalkRecordApi {
  List<Map<String, dynamic>> selected = [];
  int reads = 0, writes = 0, revision = 1;
  bool loseResponse = false;
  void Function()? afterRead;
  IMBoyHttpResponse response() => IMBoyHttpResponse.success({
    'record_id': 1,
    'revision': revision,
    'etag': '$revision',
    'list': [
      for (var i = 0; i < selected.length; i++)
        {
          ...selected[i],
          'id': i + 1,
          'attendance_source': selected[i]['user_id'] == null
              ? 'manual'
              : 'selected',
        },
    ],
  });
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    reads++;
    afterRead?.call();
    return response();
  }

  @override
  Future<IMBoyHttpResponse> put(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    expect(options?.headers?['If-Match'], '$revision');
    writes++;
    selected = List<Map<String, dynamic>>.from(
      (data as Map)['participants'] as List,
    );
    revision++;
    if (loseResponse) {
      loseResponse = false;
      throw StateError('response lost after commit');
    }
    return response();
  }
}

const local = TalkRecordLocalBinding(
  account: TalkRecordAccount('https://synthetic.example', '100'),
  clientRecordingId: 'client-1',
  deviceSessionId: 'device-1',
  context: TalkRecordEntryContext.personal(),
  title: 'draft',
  processingMode: 'record_only',
  processorConfigVersion: 'approved-bundle-v1',
  recordId: '1',
  participantsRequested: true,
  participants: [
    TalkRecordParticipantInput(userId: '9001'),
    TalkRecordParticipantInput(displayName: 'Guest'),
  ],
);

void main() {
  test('selection survives local binding roundtrip with explicit synchronization intent', () {
    final restored = TalkRecordLocalBinding.fromJson(local.toJson());
    expect(restored.processorConfigVersion, 'approved-bundle-v1');
    expect(restored.participantsRequested, isTrue);
    expect(restored.participantsSynced, isFalse);
    expect(restored.participants.map((item) => item.identityKey), [
      'user:9001',
      'guest:Guest',
    ]);
    final legacy = local.toJson()
      ..remove('participants')
      ..remove('participants_requested')
      ..remove('participants_synced');
    expect(
      TalkRecordLocalBinding.fromJson(legacy).participantsRequested,
      isFalse,
    );
  });
  test(
    'response-lost replacement reconciles server list without another PUT',
    () async {
      final api = ParticipantApi()..loseResponse = true;
      final checkpoints = <TalkRecordLocalBinding>[];
      Future<TalkRecordLocalBinding> sync() => syncTalkRecordParticipants(
        api: api,
        local: local,
        checkpoint: (value) async {
          checkpoints.add(value);
        },
        checkAccount: () {},
      );
      await expectLater(sync(), throwsStateError);
      expect(checkpoints, isEmpty);
      final synced = await sync();
      expect(api.writes, 1);
      expect(synced.participantsSynced, isTrue);
      expect(synced.recordEtag, '2');
    },
  );
  test('legacy binding never replaces existing server participants with empty list', () async {
    final api = ParticipantApi();
    final legacy = TalkRecordLocalBinding.fromJson(
      local.toJson()..remove('participants_requested'),
    );
    await syncTalkRecordParticipants(
      api: api,
      local: legacy,
      checkpoint: (_) async {},
      checkAccount: () {},
    );
    expect(api.reads, 0);
    expect(api.writes, 0);
  });
  test(
    'account transition during GET forbids PUT and local success checkpoint',
    () async {
      var changed = false;
      final api = ParticipantApi()
        ..afterRead = () {
          changed = true;
        };
      var checkpointed = false;
      await expectLater(
        syncTalkRecordParticipants(
          api: api,
          local: local,
          checkpoint: (_) async {
            checkpointed = true;
          },
          checkAccount: () {
            if (changed) throw StateError('account changed');
          },
        ),
        throwsStateError,
      );
      expect(api.writes, 0);
      expect(checkpointed, isFalse);
    },
  );
}
