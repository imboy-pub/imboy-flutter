part of 'attachment_upload_task_recovery_test.dart';

class _ObservedBrowserMaterials extends BrowserAttachmentMaterialStore {
  _ObservedBrowserMaterials(super.repo, this.events);
  final List<String> events;
  @override
  Future<BrowserUploadMaterial> read(
    AttachmentUploadTask task,
    String owner,
    bool Function() isCurrent,
  ) {
    events.add('cache-read');
    return super.read(task, owner, isCurrent);
  }
}

void _registerBrowserMaterialTests(
  Database Function() database,
  AttachmentUploadTaskRepo Function() repository,
  _MemKeyStore Function() keyStore,
) {
  const id = '10000000-0000-4000-8000-000000000001';
  const objectKey = 'u101/browser/material';
  Uint8List body() => _testBytes();
  Future<String> prepare(
    ResumableAttachmentUploader uploader, {
    bool only = true,
  }) => uploader.upload(
    idempotencyKey: id,
    userId: _uidA,
    bytes: body(),
    fileName: 'resume.bin',
    mime: 'application/octet-stream',
    bindingHashHex: _binding,
    anchorMsgId: 'original-browser-anchor',
    prepareOnly: only,
  );
  ResumableAttachmentUploader uploader({
    bool encrypted = true,
    BrowserAttachmentMaterialStore? store,
    DirectSessionFn? session,
    DirectSourcePutFn? put,
  }) => ResumableAttachmentUploader(
    repo: repository(),
    keyStore: keyStore(),
    sessionGuard: (_) => true,
    encrypt: encrypted,
    process: false,
    cacheDirectory: Directory('${_uploadCache.path}/must-not-create'),
    cacheWriter: (write, _) => write(),
    browserMaterialStore: store ?? BrowserAttachmentMaterialStore(repository()),
    directSessionFn: session,
    directSourcePutFn:
        put ??
        (url, source, length, headers, {cancelToken, onProgress}) async {
          fail('unexpected Browser PUT');
        },
  );

  Future<IMBoyHttpResponse> Function(String, {Map<String, dynamic>? body})
  session(List<String> events, {bool killGrant = false}) =>
      (path, {body}) async {
        final action = path.split('/').last;
        events.add(action);
        switch (action) {
          case 'register':
            return IMBoyHttpResponse.success({
              'state': 'DECLARED',
              'object_key': objectKey,
            });
          case 'status':
            return IMBoyHttpResponse.success({
              'state': 'DECLARED',
              'object_key': objectKey,
            });
          case 'declare':
            return IMBoyHttpResponse.success({'state': 'DECLARED'});
          case 'grant':
            if (killGrant) throw _KillSignal('browser-before-put');
            final task = (await repository().find(id))!;
            final checksum = base64Encode(
              List.generate(
                32,
                (index) => int.parse(
                  task.ciphertextSha256!.substring(index * 2, index * 2 + 2),
                  radix: 16,
                ),
              ),
            );
            return IMBoyHttpResponse.success({
              'state': 'GRANTED',
              'attempt_id': 1,
              'grant': {
                'transport': 's3_put',
                'method': 'PUT',
                'url': 'https://storage.example/owned-material',
                'required_headers': [
                  ['Content-Type', 'application/octet-stream'],
                  ['x-amz-checksum-sha256', checksum],
                ],
              },
            });
          case 'finalize':
            return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
          default:
            throw StateError(action);
        }
      };

  test(
    'Browser prepare persists original encrypted source without native files',
    () async {
      final events = <String>[];
      await prepare(uploader(session: session(events)));
      final row = (await repository().find(id))!;
      final owner = row.uploadPath!.split(':')[1];
      final cached = await BrowserAttachmentMaterialStore(repository())
          .read(row, owner, () => true);
      expect(cached.kind, BrowserMaterialKind.encryptedSource);
      expect(cached.bytes, isNot(equals(body())));
      expect(row.anchorMsgId, 'original-browser-anchor');
      expect(keyStore().store[row.keyRef!]?['content_key'], isNotNull);
      expect(events, isEmpty);
      expect(
        Directory('${_uploadCache.path}/must-not-create').existsSync(),
        isFalse,
      );
    },
  );

  test('missing durable acknowledgement fails before creating a task or making requests', () async {
    final events = <String>[];
    final unavailable = BrowserAttachmentMaterialStore(
      repository(),
      durabilityBarrier: () async {
        throw StateError('synthetic durable barrier failure');
      },
    );
    await expectLater(
      prepare(
        uploader(store: unavailable, session: session(events)),
        only: false,
      ),
      throwsA(isA<BrowserMaterialException>()),
    );
    expect(await repository().find(id), isNull);
    expect(keyStore().store, isEmpty);
    expect(events, isEmpty);
  });

  test(
    'Browser plaintext profile stores original bytes and generates no keys',
    () async {
      await prepare(uploader(encrypted: false));
      final row = (await repository().find(id))!;
      final cached = await BrowserAttachmentMaterialStore(repository())
          .read(row, row.uploadPath!.split(':')[1], () => true);
      expect(cached.kind, BrowserMaterialKind.source);
      expect(cached.bytes, body());
      expect(keyStore().store, isEmpty);
    },
  );

  test('Browser refresh checks status before cache and reuses exact cipher/key/anchor', () async {
    final events = <String>[];
    final store = _ObservedBrowserMaterials(repository(), events);
    await expectLater(
      prepare(
        uploader(store: store, session: session(events, killGrant: true)),
        only: false,
      ),
      throwsA(isA<_KillSignal>()),
    );
    final before = (await repository().find(id))!;
    final cached = await store.read(
      before,
      before.uploadPath!.split(':')[1],
      () => true,
    );
    final keysBefore = jsonEncode(keyStore().store);
    events.clear();
    Uint8List? uploaded;
    final restarted = uploader(
      store: store,
      session: session(events),
      put: (url, source, length, headers, {cancelToken, onProgress}) async {
        uploaded = Uint8List.fromList(
          await source
              .openRead(cancelToken: cancelToken)
              .expand((chunk) => chunk)
              .toList(),
        );
      },
    );
    expect(await restarted.resumeAll(_uidA), [objectKey]);
    expect(events.first, 'status');
    expect(events.indexOf('cache-read'), greaterThan(events.indexOf('status')));
    expect(uploaded, cached.bytes);
    expect(jsonEncode(keyStore().store), keysBefore);
    final after = (await repository().find(id))!;
    expect(after.stage, AttachmentUploadStage.confirmed);
    expect(after.id, before.id);
    expect(after.keyRef, before.keyRef);
    expect(after.anchorMsgId, before.anchorMsgId);
    expect(after.objectKey, before.objectKey);
  });

  test(
    'missing Browser material never fabricates recovery or fresh keys',
    () async {
      final events = <String>[];
      await expectLater(
        prepare(
          uploader(session: session(events, killGrant: true)),
          only: false,
        ),
        throwsA(isA<_KillSignal>()),
      );
      final row = (await repository().find(id))!;
      final before = jsonEncode(keyStore().store);
      await database().delete(
        BrowserAttachmentMaterialStore.tableName,
        where: 'task_id = ? AND user_id = ?',
        whereArgs: [id, _uidA],
      );
      events.clear();
      final result = await uploader(
        session: session(events),
        put: (url, source, length, headers, {cancelToken, onProgress}) async {
          fail('missing material must not PUT');
        },
      ).resumeAll(_uidA);
      expect(result, isEmpty);
      expect(events, ['status']);
      expect(
        (await repository().find(id))!.stage,
        AttachmentUploadStage.abandoned,
      );
      expect(jsonEncode(keyStore().store), before);
      expect(row.objectKey, objectKey);
    },
  );

  test('storage failure rolls back Blob pointer and prevents all control requests', () async {
    final owner = List.filled(64, 'a').join();
    final seed =
        (await _seedRow(
          'schema-only',
          uid: _uidA,
          stage: AttachmentUploadStage.pending,
          objectKey: '',
        )).copyWith(
          uploadPath: BrowserUploadMaterial.pending(owner, 'schema-only'),
        );
    final store = BrowserAttachmentMaterialStore(repository());
    await expectLater(
      store.read(seed, owner, () => true),
      throwsA(isA<BrowserMaterialException>()),
    );
    await database().execute(
      'CREATE TRIGGER browser_material_quota BEFORE INSERT ON '
      "${BrowserAttachmentMaterialStore.tableName} BEGIN SELECT RAISE(ABORT, 'synthetic quota'); END",
    );
    final events = <String>[];
    await expectLater(
      prepare(uploader(session: session(events)), only: false),
      throwsA(
        isA<BrowserMaterialException>().having(
          (e) => e.failure,
          'failure',
          BrowserMaterialFailure.storage,
        ),
      ),
    );
    final row = (await repository().find(id))!;
    expect(row.uploadPath, endsWith(':pending'));
    expect(row.objectKey, isNull);
    expect(row.stage, AttachmentUploadStage.pending);
    expect(events, isEmpty);
    expect(
      await database().query(BrowserAttachmentMaterialStore.tableName),
      isEmpty,
    );
  });

  test('unknown or foreign owner is not queried or mutated during Browser recovery', () async {
    final owner = List.filled(64, 'b').join();
    final row = (await _seedRow(
      id,
      uid: _uidA,
      stage: AttachmentUploadStage.pending,
      objectKey: objectKey,
    )).copyWith(uploadPath: BrowserUploadMaterial.pending(owner, id));
    await repository().insert(row);
    final events = <String>[];
    expect(await uploader(session: session(events)).resumeAll(_uidA), isEmpty);
    final unchanged = (await repository().find(id))!;
    expect(unchanged.stage, row.stage);
    expect(unchanged.lastError, row.lastError);
    expect(unchanged.uploadPath, row.uploadPath);
    expect(events, isEmpty);
  });

  test(
    'late cache publication discard restores previous material only',
    () async {
      await prepare(uploader(encrypted: false));
      final previous = (await repository().find(id))!;
      final owner = previous.uploadPath!.split(':')[1];
      final store = BrowserAttachmentMaterialStore(repository());
      final otherOwner = List.filled(64, 'b').join();
      final other = AttachmentUploadTask.fromMap({
        ...previous.toMap(),
        'id': 'other-owner-task',
        'user_id': _uidB,
        'key_ref': 'other-owner-task',
        'upload_path': BrowserUploadMaterial.pending(
          otherOwner,
          'other-owner-task',
        ),
      });
      await repository().insert(other);
      final otherCommit = await store.write(
        task: other,
        owner: otherOwner,
        kind: BrowserMaterialKind.source,
        bytes: body(),
        stage: AttachmentUploadStage.pending,
        materialId: 'other-material',
        maxBytes: AttachmentApi.maxUploadBytes,
        isCurrent: () => true,
      );
      await otherCommit.finish();
      final commit = await store.write(
        task: previous,
        owner: owner,
        kind: BrowserMaterialKind.source,
        bytes: body(),
        stage: AttachmentUploadStage.pending,
        materialId: 'late-copy',
        maxBytes: AttachmentApi.maxUploadBytes,
        isCurrent: () => true,
        expectedKeyRef: previous.keyRef,
      );
      expect((await repository().find(id))!.uploadPath, commit.locator);
      await commit.discard();
      final restored = (await repository().find(id))!;
      expect(restored.uploadPath, previous.uploadPath);
      expect((await store.read(restored, owner, () => true)).bytes, body());
      final rows = await database().query(
        BrowserAttachmentMaterialStore.tableName,
      );
      expect(rows.length, 2);
      expect(rows.map((row) => row['locator']), contains(previous.uploadPath));
      final otherRow = (await repository().find(other.id))!;
      expect(
        (await store.read(otherRow, otherOwner, () => true)).bytes,
        body(),
      );
    },
  );
}
