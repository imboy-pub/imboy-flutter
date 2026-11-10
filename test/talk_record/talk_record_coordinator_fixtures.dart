part of 'talk_record_recording_coordinator_test.dart';

class NotificationFailingEngine extends FakeTalkRecordEngine {
  NotificationFailingEngine(this.code);
  final String code;
  @override
  Future<void> open() async {
    throw PlatformException(code: code);
  }
}

class LeaseGateway implements TalkRecordCaptureGateway {
  LeaseGateway({this.known = false, this.ended = false});
  final bool known, ended;
  int calls = 0;
  @override
  Future<TalkRecordLocalBinding> bind(
    TalkRecordLocalBinding local,
    Future<void> Function(TalkRecordLocalBinding) checkpoint,
    void Function() checkAccount,
  ) async {
    checkAccount();
    calls++;
    return local.copyWith(
      recordId: '1',
      captureId: '2',
      leaseEpoch: known ? 0 : -1,
      captureStatus: ended ? 'ended' : 'recording',
      leaseUntil: known
          ? DateTime.now().add(Duration(minutes: ended ? -60 : 5))
          : null,
    );
  }
}

class TestUploader implements TalkRecordUploadGateway {
  int calls = 0;
  TalkRecordLocalBinding? lastBinding;
  @override
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
    CancelToken? cancelToken,
  }) async {
    checkAccount();
    lastBinding = binding;
    calls++;
  }
}

class HeldUploader extends TestUploader {
  final entered = Completer<void>(), release = Completer<void>();
  CancelToken? uploadCancel;
  @override
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
    CancelToken? cancelToken,
  }) async {
    uploadCancel = cancelToken;
    entered.complete();
    await release.future;
    await super.upload(
      binding: binding,
      manifest: manifest,
      directory: directory,
      keys: keys,
      checkAccount: checkAccount,
      cancelToken: cancelToken,
    );
  }
}

class ProgressHeldUploader extends HeldUploader
    implements TalkRecordUploadProgressSource {
  TalkRecordUploadSnapshot? progress;
  @override
  TalkRecordUploadSnapshot? get uploadSnapshot => progress;
  @override
  Stream<TalkRecordUploadSnapshot> get uploadUpdates => const Stream.empty();
  @override
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
    CancelToken? cancelToken,
  }) async {
    progress = TalkRecordUploadSnapshot(
      account: binding.account,
      recordId: binding.recordId,
      sessionId: binding.sessionId,
      totalParts: manifest.segments.length,
      confirmedParts: 0,
      phase: TalkRecordUploadPhase.upload,
    );
    await super.upload(
      binding: binding,
      manifest: manifest,
      directory: directory,
      keys: keys,
      checkAccount: checkAccount,
      cancelToken: cancelToken,
    );
  }
}

class HeldCloseEngine extends FakeTalkRecordEngine {
  final closing = Completer<void>();
  final releaseClose = Completer<void>();
  @override
  Future<void> close() async {
    if (!closing.isCompleted) closing.complete();
    await releaseClose.future;
    await super.close();
  }
}
