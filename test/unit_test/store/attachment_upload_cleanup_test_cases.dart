part of 'attachment_upload_task_recovery_test.dart';

Uint8List _hexDecode(String hex) => Uint8List.fromList(
  List<int>.generate(
    hex.length ~/ 2,
    (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
  ),
);

Uint8List _testBytes() =>
    Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));

void _registerAccountUploadCleanupTest(
  AttachmentUploadTaskRepo Function() repository,
  _MemKeyStore Function() keyStore,
  _Fakes Function() fakes,
) {
  test(
    'account cleanup drains held checkpoint and prevents the next PUT',
    () async {
      final repo = repository();
      final keys = keyStore();
      final f = fakes();
      final entered = Completer<void>();
      final release = Completer<void>();
      final uploader = _uploader(repo, keys);
      final upload = _runUpload(
        uploader,
        f,
        id: 'cleanup-held',
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.sealed) {
            entered.complete();
            await release.future;
          }
        },
      );
      final failed = expectLater(upload, throwsStateError);
      await entered.future;
      final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(
        AccountLocalTaskOwner.capture(uid: _uidA),
      );
      var stopped = false;
      final drained = cleanup.stopped.then((_) => stopped = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(stopped, isFalse);
        expect(f.putBodies, isEmpty);
        release.complete();
        await failed;
        await drained;
        expect(f.putBodies, isEmpty);
        expect(f.confirmBodies, isEmpty);
        final row = await repo.find('cleanup-held');
        expect(row?.stage, AttachmentUploadStage.presigned);
      } finally {
        if (!release.isCompleted) release.complete();
        await failed;
        await drained;
        cleanup.release();
      }
    },
  );
}
