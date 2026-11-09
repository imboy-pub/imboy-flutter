part of 'attachment_api.dart';

Future<String> _uploadDirect(
  Uint8List bytes,
  String fileName,
  String mime, {
  required bool process,
  required String scope,
  String? scopeRef,
  String? anchorMsgId,
  String? clientUploadId,
  AttachmentSealRequest? seal,
  ResumableUploadState? resume,
  Future<void> Function(UploadCheckpoint event)? checkpoint,
  DirectSessionFn? sessionFn,
  DirectFilePutFn? putFn,
  void Function()? requireSession,
  CancelToken? cancelToken,
}) async {
  requireSession?.call();
  final requestCancel = cancelToken ?? CancelToken();
  final localTask = AccountLocalTaskRegistry.instance.register(
    AccountLocalTaskOwner.capture(),
    onCancel: () => requestCancel.cancel('account local data cleanup'),
  );
  try {
    localTask.throwIfCancelled();
    final actor = UserRepoLocal.to;
    final generation = actor.sessionGeneration;
    final environment = currentEnv;

    Future<IMBoyHttpResponse> guardedSession(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      localTask.throwIfCancelled();
      requireSession?.call();
      final response = sessionFn != null
          ? await sessionFn(path, body: body)
          : path.endsWith('/status')
          ? await HttpClient.client.get(
              path,
              queryParameters: body,
              cancelToken: requestCancel,
            )
          : await HttpClient.client.post(
              path,
              data: body,
              cancelToken: requestCancel,
            );
      localTask.throwIfCancelled();
      requireSession?.call();
      if (path.endsWith('/register') &&
          !response.ok &&
          response.msg == 'legacy_session_conflict') {
        throw LegacyUploadConflict();
      }
      if (path.endsWith('/register') &&
          !response.ok &&
          response.msg == 'declaration_conflict') {
        throw UploadSessionRejected('upload declaration conflict');
      }
      return response;
    }

    final validationError = AttachmentApi.validateUpload(bytes.length, mime);
    if (validationError != null) throw StateError(validationError);
    final id = clientUploadId ?? newClientUploadId();
    final groupMessage =
        scope == 'group' && anchorMsgId != null && anchorMsgId.isNotEmpty;
    final purpose = groupMessage ? 'message' : 'attachment';
    final anchor = groupMessage ? anchorMsgId : null;
    final cipher = seal == null ? null : AttachmentDescriptor.supportedCipher;
    String state = '';
    final key = await DirectAttachmentApi.registerSession(
      fileName: fileName,
      scope: scope,
      scopeRef: scopeRef,
      clientUploadId: id,
      cipher: cipher,
      purpose: purpose,
      anchorMsgId: anchor,
      sessionFn: guardedSession,
      onState: (value) => state = value,
    );
    if (!{
      'RESERVED',
      'DECLARED',
      'GRANTED',
      'FINALIZING',
      'CONFIRMED',
    }.contains(state)) {
      throw UploadSessionRejected('direct session terminal: $state');
    }
    if (resume?.objectKey.isNotEmpty == true && resume!.objectKey != key) {
      throw UploadSessionRejected('upload object identity changed');
    }
    if (resume?.objectKey.isNotEmpty != true) {
      await checkpoint?.call(UploadCheckpoint.presigned(objectKey: key));
    }
    SealedAttachment? sealed = resume?.sealedAttachment;
    if (seal != null && sealed == null) {
      if (resume?.skipPut == true &&
          (resume?.contentKey == null || resume?.baseNonce == null)) {
        throw StateError(
          'confirmed encrypted upload requires original material',
        );
      }
      sealed = AttachmentEncryptor.seal(
        plaintext: bytes,
        bindingHash: seal.bindingHash,
        attachmentId: seal.attachmentId,
        objectKey: key,
        mime: mime,
        name: fileName,
        contentKey:
            resume?.contentKey ?? AttachmentEncryptor.randomContentKey(),
        baseNonce: resume?.baseNonce ?? AttachmentEncryptor.randomBaseNonce(),
        chunkSize: seal.chunkSize,
        thumb: seal.thumbDescriptor,
      );
    }
    if (sealed != null) {
      if (seal == null || sealed.descriptor.objectKey != key) {
        throw UploadSessionRejected('upload ciphertext identity changed');
      }
      seal.descriptor = sealed.descriptor;
    }
    final body = sealed?.ciphertext ?? bytes;
    final hash = sealed?.ciphertextSha256Hex ?? sha256.convert(body).toString();
    seal?.uploadedFileHash256 = hash;
    if (resume?.skipPut != true) {
      await checkpoint?.call(
        UploadCheckpoint(
          UploadCheckpointStage.sealed,
          contentKey: sealed?.descriptor.contentKey,
          baseNonce: sealed?.descriptor.baseNonce,
          ciphertextSha256: hash,
          uploadBytes: body,
          descriptor: sealed?.descriptor,
        ),
      );
    }
    localTask.throwIfCancelled();
    requireSession?.call();
    final ownerDirectory = await AccountLocalFiles.directory(localTask);
    final directory = await ownerDirectory.createTemp('direct-');
    final progress = process
        ? UploadProgressSession(actor, generation, environment, requireSession)
        : null;
    try {
      localTask.throwIfCancelled();
      requireSession?.call();
      final file = File('${directory.path}/body');
      await file.writeAsBytes(body, flush: true);
      bool putCheckpoint = resume?.skipPut == true;
      final result = await DirectAttachmentApi.uploadFile(
        file,
        fileName: fileName,
        mime: mime,
        scope: scope,
        scopeRef: scopeRef,
        clientUploadId: id,
        cipher: cipher,
        purpose: purpose,
        anchorMsgId: anchor,
        sessionFn: guardedSession,
        putFn: putFn,
        cancelToken: requestCancel,
        onProgress: (sent, total) {
          progress?.update(sent, total);
        },
        checkpoint: (event) async {
          localTask.throwIfCancelled();
          requireSession?.call();
          if (event.objectKey != null && event.objectKey != key) {
            throw UploadSessionRejected('upload object identity changed');
          }
          if (event.stage == DirectCheckpointStage.putDone && !putCheckpoint) {
            await checkpoint?.call(
              UploadCheckpoint.putDone(ciphertextSha256: hash),
            );
            putCheckpoint = true;
          }
        },
      );
      if (result.objectKey != key ||
          result.state != DirectAttachmentApi.stateConfirmed ||
          result.quarantined) {
        throw StateError('direct upload not confirmed');
      }
      if (!putCheckpoint) {
        await checkpoint?.call(
          UploadCheckpoint.putDone(ciphertextSha256: hash),
        );
      }
      await checkpoint?.call(const UploadCheckpoint.confirmed());
      return key;
    } finally {
      await progress?.dispose();
      await directory.delete(recursive: true);
    }
  } finally {
    localTask.finish();
  }
}
