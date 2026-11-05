part of 'talk_record_attachment_upload_gateway_test.dart';

class UploadApi extends TalkRecordApi {
  String status = 'draft';
  String ownerId = '100', media = 'uploading';
  bool suppressProjection = false;
  int confirmedCount = 0;
  int lastSeq = -1, epoch = 0, verifyCount = 0, confirms = 0, completes = 0;
  bool revoked = false, loseEndResponse = false, loseCompleteResponse = false;
  bool missingSequence = false, expired = false, pendingTicket = false;
  TalkRecordAudioPartInput? part;
  final registrationKeys = <String>[],
      completeKeys = <String>[],
      markIds = <String>[];
  final eventIds = <String>[];
  String completedHash = '';
  bool missingCompletionHash = false, rejectCompletion = false;
  TalkRecordCapabilitiesModel cap = const TalkRecordCapabilitiesModel(
    recordingEnabled: true,
    processingAvailable: true,
    asrEnabled: true,
    summaryEnabled: true,
    policyVersion: 'v2',
    processorConfigVersion: 'pcv2',
  );
  @override
  Future<TalkRecordCapabilitiesModel> capabilities() async => cap;
  String? completedProcessorConfigVersion;
  TalkRecordCaptureModel get capture => TalkRecordCaptureModel.fromJson({
    'completion_manifest_hash': missingCompletionHash ? null : completedHash,
    'capture_id': 2,
    'record_id': 1,
    'device_session_id': 'device-session',
    'status': status,
    'parts': {
      'confirmed': confirmedCount,
      'pending': part != null && confirmedCount == 0 ? 1 : 0,
      'last_seq': part?.seq ?? -1,
      'effective_ms': confirmedCount > 0 ? (part!.endMs - part!.startMs) : 0,
    },
    'lease_epoch': epoch,
    if (!missingSequence) 'last_event_seq': lastSeq,
    'lease_until': DateTime.now()
        .add(Duration(minutes: expired ? -1 : 5))
        .toIso8601String(),
  });
  @override
  Future<List<TalkRecordCaptureModel>> captures(String id) async {
    if (revoked) throw StateError('revoked');
    return [capture];
  }

  @override
  Future<TalkRecordCaptureModel> postCaptureEvent(
    String id,
    String captureId,
    TalkRecordCaptureEventInput input,
  ) async {
    eventIds.add(input.clientEventId);
    lastSeq = input.seq;
    status = input.event == TalkRecordCaptureEventKind.end
        ? 'ended'
        : 'recording';
    if (loseEndResponse && status == 'ended') {
      loseEndResponse = false;
      throw StateError('lost response');
    }
    return capture;
  }

  @override
  Future<TalkRecordAudioUploadSession> createAudioPart(
    String id,
    String captureId,
    TalkRecordAudioPartInput input, {
    required String idempotencyKey,
  }) async {
    if (revoked) throw StateError('revoked');
    expect(
      input.codec,
      'aac',
      reason: 'Actual AAC-ADTS uses backend aac wire codec',
    );
    if (input.codec != 'aac') throw StateError('unsupported codec');
    part = input;
    registrationKeys.add(idempotencyKey);
    return TalkRecordAudioUploadSession.fromJson({
      'part_id': 3,
      'attachment_id': null,
      // attach_direct_logic s3_put descriptor；pendingTicket → descriptor
      // 不可用（缺 grant），门禁 fail closed。
      'upload_ref': {
        'state': 'GRANTED',
        'object_key': 'owner/record/audio.aac',
        'attempt_id': 1,
        'grant': pendingTicket
            ? <String, dynamic>{}
            : <String, dynamic>{
                'transport': 's3_put',
                'url':
                    'https://garage.example.test/owner/record/audio.aac'
                    '?X-Amz-Signature=synthetic',
                'method': 'PUT',
                'required_headers': <String, String>{
                  'Content-Type': 'audio/aac',
                  'x-amz-checksum-sha256': 'synthetic-checksum',
                },
                'expires_in': 3600,
              },
      },
    });
  }

  @override
  Future<TalkRecordAudioPartConfirmResult> confirmAudioPart(
    String id,
    String captureId,
    String partId,
  ) async {
    if (revoked) throw StateError('revoked');
    confirms++;
    if (verifyCount-- > 0) {
      return const TalkRecordAudioPartConfirmResult(status: 'verifying');
    }
    confirmedCount = 1;
    return TalkRecordAudioPartConfirmResult.fromJson({
      'status': 'confirmed',
      'part_id': 3,
      'capture_id': 2,
      'seq': part!.seq,
      'attachment_id': 4,
      'sha256': part!.sha256,
      'byte_size': part!.byteSize,
    });
  }

  @override
  Future<TalkRecordMarkModel> createMark(
    String id, {
    required String clientMarkId,
    required int positionMs,
    String text = '',
    String captureId = '',
    int captureOffsetMs = 0,
  }) async {
    if (status != 'ended') throw StateError('capture duration not final');
    markIds.add(clientMarkId);
    return TalkRecordMarkModel(id: '5', clientMarkId: clientMarkId);
  }

  @override
  Future<TalkRecordFetched<TalkRecordModel>> detail(String id) async {
    if (revoked) throw StateError('revoked');
    return TalkRecordFetched(
      TalkRecordModel(
        id: '1',
        ownerUserId: ownerId,
        clientRecordingId: 'record-client',
        scope: TalkRecordScope.personal,
        captureStatus: TalkRecordCaptureStatus.parse(status),
        mediaStatus: TalkRecordMediaStatus.parse(media),
        durationMs: status == 'ended' ? (part?.endMs ?? 1000) : 0,
      ),
      etag: '"record-4"',
    );
  }

  String? completedPolicyVersion;
  TalkRecordFinalAudioDecl? completedFinalAudio;
  @override
  Future<TalkRecordCompleteResult> complete(
    String id, {
    required List<TalkRecordCompleteCaptureInput> captures,
    required TalkRecordFinalAudioDecl finalAudio,
    required String policyVersion,
    String? processorConfigVersion,
    required String idempotencyKey,
    required String ifMatch,
  }) async {
    if (rejectCompletion) throw StateError('new policy ack required');
    completedPolicyVersion = policyVersion;
    completedProcessorConfigVersion = processorConfigVersion;
    completedFinalAudio = finalAudio;
    completes++;
    completeKeys.add(idempotencyKey);
    completedHash = captures.single.manifestHash;
    if (!suppressProjection) media = 'assembling';
    if (loseCompleteResponse) {
      loseCompleteResponse = false;
      throw StateError('lost response');
    }
    return const TalkRecordCompleteResult(
      mediaStatus: 'assembling',
      jobId: '6',
    );
  }
}

class UploadTransport implements TalkRecordPartTransport {
  int puts = 0;
  bool fail = false;
  String plaintextHash = '';
  @override
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard,
  ) async {
    guard();
    puts++;
    plaintextHash = (await sha256.bind(plaintext.openRead()).first).toString();
    if (fail) {
      fail = false;
      throw StateError('PUT response lost');
    }
  }
}

/// 成品 direct 通道 fake：register 同 client_upload_id 幂等、PUT 无网络、
/// finalize 态可控（[finalizeState]）；status 恢复第一跳返回 [sessionState]。
class FinalDirectFake {
  FinalDirectFake({this.sessionState = 'RESERVED'});
  String sessionState;
  String finalizeState = 'CONFIRMED';
  int uploads = 0, statuses = 0, registers = 0;
  final clientUploadIds = <String>[];
  final scopeRefs = <String>[];
  bool failFirstPut = false;
  String objectKeyOf(String id) => 'owner/record/final-$id.aac';
  TalkRecordFinalDirectRegister get register =>
      (String clientUploadId, String scopeRef) async {
        registers++;
        return objectKeyOf(clientUploadId);
      };
  TalkRecordFinalDirectUpload get upload =>
      (
        File file, {
        required String clientUploadId,
        required String scopeRef,
      }) async {
        uploads++;
        // 会话身份在 register 已确立；PUT 失败不否定 server 侧会话存在。
        clientUploadIds.add(clientUploadId);
        scopeRefs.add(scopeRef);
        if (failFirstPut && uploads == 1) {
          throw StateError('direct put lost');
        }
        return DirectUploadResult(
          objectKey: objectKeyOf(clientUploadId),
          state: finalizeState,
          attemptId: 1,
        );
      };
  TalkRecordFinalDirectStatus get status => (String objectKey) async {
    statuses++;
    return DirectUploadResult(
      objectKey: objectKey,
      state: sessionState,
      attemptId: 0,
    );
  };
}
