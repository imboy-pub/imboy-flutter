part of 'talk_record_attachment_upload_gateway.dart';

extension _TalkRecordUploadParts on TalkRecordAttachmentUploadGateway {
  Future<void> _part(
    TalkRecordLocalBinding b,
    TalkRecordSegmentEntry segment,
    Directory directory,
    Directory plaintextDir,
    TalkRecordKeyStore keys,
    TalkRecordUploadCheckpoint cp,
    TalkRecordUploadCheckpointStore store,
    void Function() guard,
  ) async {
    final state = Map<String, dynamic>.from(
      cp.parts['${segment.seq}'] as Map? ?? {},
    );
    if (state['confirmed'] == true) return;
    state['key'] ??= TalkRecordIds.newUuidV4();
    cp.parts['${segment.seq}'] = state;
    await store.save(cp);
    if (state['put_done'] != true) {
      final session = await _register(b, segment, state, guard);
      cp.parts['${segment.seq}'] = state;
      await store.save(cp);
      await _put(b, segment, directory, plaintextDir, keys, session, guard);
      state['put_done'] = true;
      cp.parts['${segment.seq}'] = state;
      await store.save(cp);
    }
    await _confirm(b, segment, state, cp, store, guard);
  }

  Future<TalkRecordAudioUploadSession> _register(
    TalkRecordLocalBinding b,
    TalkRecordSegmentEntry segment,
    Map<String, dynamic> state,
    void Function() guard,
  ) async {
    guard();
    final session = await api.createAudioPart(
      b.recordId,
      b.captureId,
      TalkRecordAudioPartInput(
        seq: segment.seq,
        startMs: segment.startMs,
        endMs: segment.endMs,
        sha256: segment.plainSha256Hex,
        byteSize: segment.plainSize,
        codec: switch (segment.codec) {
          'aac_lc' || 'aac' => 'aac',
          _ => throw StateError('Unsupported local audio codec'),
        },
        sampleRate: segment.sampleRateHz,
        channels: segment.numChannels,
        captureOffsetMs: segment.startMs,
      ),
      idempotencyKey: state['key'] as String,
    );
    guard();
    if (session.partId.isEmpty ||
        !session.uploadRef.canUploadAt(DateTime.now())) {
      throw StateError('Part upload ticket unavailable');
    }
    for (final pair in {
      'part_id': session.partId,
      'object_key': session.uploadRef.objectKey,
      'client_upload_id': session.uploadRef.clientUploadId,
    }.entries) {
      if (state[pair.key] != null && state[pair.key] != pair.value) {
        throw StateError('Frozen upload location changed');
      }
      state[pair.key] = pair.value;
    }
    return session;
  }

  Future<void> _put(
    TalkRecordLocalBinding b,
    TalkRecordSegmentEntry segment,
    Directory directory,
    Directory plaintextDir,
    TalkRecordKeyStore keys,
    TalkRecordAudioUploadSession session,
    void Function() guard,
  ) async {
    guard();
    await plaintextDir.create(recursive: true);
    final plain = File('${plaintextDir.path}/part-${segment.seq}.aac');
    try {
      await _decrypt(b, segment, directory, plain, keys, guard);
      guard();
      await transport.put(session.uploadRef, plain, guard);
      guard();
    } finally {
      if (await plain.exists()) await plain.delete();
    }
  }

  Future<void> _decrypt(
    TalkRecordLocalBinding b,
    TalkRecordSegmentEntry segment,
    Directory directory,
    File plain,
    TalkRecordKeyStore keys,
    void Function() guard,
  ) async {
    guard();
    final stored = await keys.readRecordKey(b.sessionId);
    if (stored == null || stored.length != 32) {
      throw StateError('Audio key unavailable');
    }
    guard();
    final key = Uint8List.fromList(stored);
    try {
      await TalkRecordSegmentCrypto.openSegment(
        cipherFile: File('${directory.path}/${segment.cipherFileName}'),
        plainOutFile: plain,
        recordKey: key,
        sessionId: b.sessionId,
        seq: segment.seq,
        info: TalkRecordSegmentCipherInfo(
          plainSize: segment.plainSize,
          plainSha256Hex: segment.plainSha256Hex,
          cipherSize: segment.cipherSize,
          cipherSha256Hex: segment.cipherSha256Hex,
        ),
        mime: 'audio/aac',
      );
      if (await plain.length() != segment.plainSize ||
          (await sha256.bind(plain.openRead()).first).toString() !=
              segment.plainSha256Hex) {
        throw StateError('Plaintext audio integrity mismatch');
      }
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  Future<void> _confirm(
    TalkRecordLocalBinding b,
    TalkRecordSegmentEntry segment,
    Map<String, dynamic> state,
    TalkRecordUploadCheckpoint cp,
    TalkRecordUploadCheckpointStore store,
    void Function() guard,
  ) async {
    for (var attempt = 0; attempt < confirmAttempts; attempt++) {
      guard();
      final receipt = await api.confirmAudioPart(
        b.recordId,
        b.captureId,
        state['part_id'] as String,
      );
      guard();
      if (receipt.isConfirmed) {
        _receipt(b, segment, state, receipt.raw);
        state['attachment_id'] = entityIdOf(receipt.raw['attachment_id']);
        state['confirmed'] = true;
        cp.parts['${segment.seq}'] = state;
        await store.save(cp);
        return;
      }
      if (receipt.status != 'verifying') {
        throw StateError('Part confirmation rejected');
      }
      if (attempt + 1 < confirmAttempts) {
        await delay(const Duration(seconds: 1));
      }
    }
    throw StateError('Part verification pending; retry later');
  }

  void _receipt(
    TalkRecordLocalBinding b,
    TalkRecordSegmentEntry segment,
    Map<String, dynamic> state,
    Map<String, dynamic> raw,
  ) {
    if (entityIdOf(raw['part_id']) != state['part_id'] ||
        entityIdOf(raw['capture_id']) != b.captureId ||
        raw['seq'] != segment.seq ||
        raw['sha256'] != segment.plainSha256Hex ||
        raw['byte_size'] != segment.plainSize ||
        entityIdOf(raw['attachment_id']).isEmpty) {
      throw StateError('Part confirmation receipt mismatch');
    }
  }
}
