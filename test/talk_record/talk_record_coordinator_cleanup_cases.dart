part of 'talk_record_recording_coordinator_test.dart';

void _registerRecordingCleanupTests({
  required TalkRecordRecordingCoordinator Function({
    LeaseGateway? gateway,
    TestUploader? uploader,
    FakeTalkRecordEngine? testEngine,
    Listenable? authChanges,
  })
  coordinator,
  required Future<void> Function() tick,
  required TalkRecordRecordingDraftRequest request,
  required TalkRecordAccount Function() account,
  required void Function(TalkRecordAccount) changeAccount,
  required TalkRecordBindingStore Function() store,
  required List<TalkRecordRecorderService> Function() recorders,
}) {
  test('restarted pending upload without binding cancels before a new account request', () async {
    final captured = coordinator();
    expect((await captured.launch(request)).started, isTrue);
    await tick();
    await captured.end();
    final originalAccount = account();
    final authChanges = ChangeNotifier();
    addTearDown(authChanges.dispose);
    final uploader = _DelayedDirectUploader(account);
    final restarted = coordinator(
      gateway: LeaseGateway(known: true),
      uploader: uploader,
      authChanges: authChanges,
    );
    final pending = (await restarted.pendingEnded()).single;
    expect(restarted.binding, isNull);
    final upload = restarted.retryPending(pending.binding);
    final failed = expectLater(
      upload,
      throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    try {
      await uploader.entered.future;
      changeAccount(TalkRecordAccount(originalAccount.endpoint, 'other-user'));
      authChanges.notifyListeners();
      expect(uploader.uploadCancel?.isCancelled, isTrue);
      await restarted.accountChanged();
      await expectLater(restarted.pendingEnded(), throwsStateError);
      uploader.release.complete();
      await failed;
      expect(uploader.dispatchedAs, isEmpty);
      expect((await store().list(originalAccount)).single.completed, isFalse);
      expect(await restarted.pendingEnded(), isEmpty);
    } finally {
      if (!uploader.release.isCompleted) uploader.release.complete();
      await failed;
    }
  });

  test(
    'account cleanup waits for active recorder close before it settles',
    () async {
      final engine = HeldCloseEngine();
      final c = coordinator(testEngine: engine);
      expect((await c.launch(request)).started, isTrue);
      await tick();
      final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(
        AccountLocalTaskOwner(
          uid: account().userId,
          endpoint: account().endpoint,
          environment: currentEnv.isEmpty ? 'pro' : currentEnv,
        ),
      );
      var stopped = false;
      final drained = cleanup.stopped.then((_) => stopped = true);
      try {
        await engine.closing.future;
        expect(stopped, isFalse);
        engine.releaseClose.complete();
        await drained;
        expect(engine.events, contains('close'));
        expect(c.microphoneStopUnconfirmed, isFalse);
        expect(recorders().single.phase, TalkRecordRecorderPhase.ended);
      } finally {
        if (!engine.releaseClose.isCompleted) engine.releaseClose.complete();
        await drained;
        cleanup.release();
      }
    },
  );

  test(
    'cleanup cancels held upload and drains it without a completion checkpoint',
    () async {
      final uploader = HeldUploader();
      final c = coordinator(
        gateway: LeaseGateway(known: true),
        uploader: uploader,
      );
      await c.launch(request);
      await tick();
      await c.end();
      final binding = c.binding!;
      final upload = c.uploadEnded(binding);
      final failed = expectLater(
        upload,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await uploader.entered.future;
      final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(
        AccountLocalTaskOwner(
          uid: account().userId,
          endpoint: account().endpoint,
          environment: currentEnv.isEmpty ? 'pro' : currentEnv,
        ),
      );
      var stopped = false;
      final drained = cleanup.stopped.then((_) => stopped = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(stopped, isFalse);
        expect(uploader.uploadCancel?.isCancelled, isTrue);
        uploader.release.complete();
        await failed;
        await drained;
        expect(uploader.calls, 0);
        expect((await store().list(binding.account)).single.completed, isFalse);
      } finally {
        if (!uploader.release.isCompleted) uploader.release.complete();
        await failed;
        await drained;
        cleanup.release();
      }
    },
  );
}

/// Models directUpload's internal await: its next HTTP step observes the token
/// before dispatch, without invoking the outer coordinator's account callback.
class _DelayedDirectUploader extends TestUploader {
  _DelayedDirectUploader(this.currentAccount);
  final TalkRecordAccount Function() currentAccount;
  final entered = Completer<void>(), release = Completer<void>();
  final dispatchedAs = <TalkRecordAccount>[];
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
    final cancelled = cancelToken?.cancelError;
    if (cancelled != null) throw cancelled;
    dispatchedAs.add(currentAccount());
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
