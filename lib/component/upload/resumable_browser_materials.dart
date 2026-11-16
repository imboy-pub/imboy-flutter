part of 'resumable_attachment_uploader.dart';

extension _BrowserUploadMaterials on ResumableAttachmentUploader {
  bool get _usesBrowserMaterials => kIsWeb || browserMaterialStore != null;
  BrowserAttachmentMaterialStore get _browserStore =>
      browserMaterialStore ?? BrowserAttachmentMaterialStore(_repo);
  String _browserOwner(String uid) => AccountLocalTaskOwner(
    uid: uid,
    environment: _environment.isEmpty ? 'pro' : _environment,
    endpoint: _endpoint,
  ).storageDigest;
  void _requireBrowserSession(String uid) {
    requireWebWriter();
    _requireSession(uid);
    if (Env().apiBaseUrl != _endpoint) {
      throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
    }
  }

  /// Retain native/test seams. Production control requests carry the captured
  /// owner to the shared adapter, after asynchronous HTTP preparation.
  DirectSessionFn? _directSessionFor(String uid) {
    if (!_usesBrowserMaterials) return directSessionFn;
    return (path, {body}) async {
      _requireBrowserSession(uid);
      final custom = directSessionFn;
      if (custom != null) {
        final response = await custom(path, body: body);
        _requireBrowserSession(uid);
        return response;
      }
      final client = app_http.HttpClient.client;
      guardWebWriterDio(client.dio);
      final options = Options(
        extra: {httpRequestGuard: () => _requireBrowserSession(uid)},
      );
      final response = path.endsWith('/status')
          ? await client.get(
              path,
              queryParameters: body,
              options: options,
              cancelToken: _cancel,
            )
          : await client.post(
              path,
              data: body,
              options: options,
              cancelToken: _cancel,
            );
      _requireBrowserSession(uid);
      return response;
    };
  }

  bool _browserCurrent(String uid) {
    try {
      _requireBrowserSession(uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _browserOwnsBusinessRow(
    AttachmentUploadTask row,
    String uid,
  ) async {
    _requireBrowserSession(uid);
    await _browserStore.ensureDurable();
    try {
      BrowserUploadMaterial.requireOwner(
        row.uploadPath,
        _browserOwner(uid),
        row.id,
      );
      if (row.anchorMsgId?.isNotEmpty == true) {
        for (final member in await _repo.findByAnchor(row.anchorMsgId!, uid)) {
          BrowserUploadMaterial.requireOwner(
            member.uploadPath,
            _browserOwner(uid),
            member.id,
          );
        }
      }
      _requireBrowserSession(uid);
      return true;
    } on BrowserMaterialException catch (error) {
      if (error.failure == BrowserMaterialFailure.ownership) return false;
      rethrow;
    }
  }

  Future<void> _commitBrowserMaterial(
    AttachmentUploadTask task,
    BrowserMaterialKind kind,
    Uint8List bytes,
    AttachmentUploadStage stage, {
    String? ciphertextSha256,
    String? expectedKeyRef,
  }) async {
    BrowserMaterialCommit? commit;
    Future<void> write() async {
      _requireBrowserSession(task.userId);
      commit = await _browserStore.write(
        task: task,
        owner: _browserOwner(task.userId),
        kind: kind,
        bytes: bytes,
        stage: stage,
        materialId: ResumableAttachmentUploader._newUuid(),
        maxBytes: AttachmentApi.maxUploadBytes * 2,
        isCurrent: () => _browserCurrent(task.userId),
        ciphertextSha256: ciphertextSha256,
        expectedKeyRef: expectedKeyRef,
      );
      _requireBrowserSession(task.userId);
    }

    Future<void> discard() async {
      await commit?.discard();
    }

    if (cacheWriter != null) {
      await cacheWriter!(write, discard);
    } else {
      await UserRepoLocal.to.writeSessionSecret(
        uid: task.userId,
        generation: _generation,
        write: write,
        discard: discard,
      );
    }
    await commit?.finish();
    _requireBrowserSession(task.userId);
  }

  Future<void> _cacheBrowserSource(
    AttachmentUploadTask task,
    Uint8List bytes,
  ) async {
    _requireBrowserSession(task.userId);
    final source = Uint8List.fromList(bytes);
    final validation = AttachmentApi.validateUpload(source.length, task.mime);
    if (validation != null) throw StateError(validation);
    if (source.length != task.plainSize ||
        sha256.convert(source).toString() != task.plainSha256) {
      throw LostCipherMaterialError(task.id);
    }
    var output = source;
    var kind = BrowserMaterialKind.source;
    if (task.cipher != null) {
      final material = await _loadMaterials(task);
      _requireBrowserSession(task.userId);
      if (material == null ||
          material['content_key'] == null ||
          material['base_nonce'] == null) {
        throw LostCipherMaterialError(task.id);
      }
      final descriptor = _sourceDescriptor(task, material);
      output = AttachmentEncryptor.seal(
        plaintext: source,
        bindingHash: _hexDecode(task.bindingHash!),
        attachmentId: descriptor.attachmentId,
        objectKey: descriptor.objectKey,
        mime: descriptor.mime,
        name: descriptor.name,
        contentKey: descriptor.contentKey,
        baseNonce: descriptor.baseNonce,
        chunkSize: descriptor.chunkSize,
      ).ciphertext;
      kind = BrowserMaterialKind.encryptedSource;
    }
    await _commitBrowserMaterial(
      task,
      kind,
      output,
      AttachmentUploadStage.pending,
      expectedKeyRef: task.keyRef,
    );
  }

  Future<void> _cacheBrowserUpload(
    AttachmentUploadTask task,
    UploadCheckpoint event,
    String? expectedKeyRef,
  ) async {
    final bytes = event.uploadBytes;
    if (bytes == null || bytes.length > AttachmentApi.maxUploadBytes) {
      throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
    }
    await _commitBrowserMaterial(
      task,
      BrowserMaterialKind.upload,
      bytes,
      AttachmentUploadStage.presigned,
      ciphertextSha256: event.ciphertextSha256,
      expectedKeyRef: expectedKeyRef,
    );
  }

  Future<List<String>> _resumeBrowserRows(
    String uid,
    List<AttachmentUploadTask> rows,
  ) async {
    await _browserStore.ensureDurable();
    final completed = <String>[];
    for (final row in rows) {
      var owned = false;
      try {
        _requireBrowserSession(uid);
        BrowserUploadMaterial.requireOwner(
          row.uploadPath,
          _browserOwner(uid),
          row.id,
        );
        owned = true;
        if (row.objectKey?.isNotEmpty == true) {
          final state = await DirectAttachmentApi.strictStatus(
            objectKey: row.objectKey!,
            sessionFn: _directSessionFor(uid),
            cancelToken: _cancel,
          );
          _requireBrowserSession(uid);
          if (state == null) throw LegacyUploadConflict();
          if (!{
            'RESERVED',
            'DECLARED',
            'GRANTED',
            'FINALIZING',
            'CONFIRMED',
          }.contains(state)) {
            throw UploadSessionRejected('direct session terminal');
          }
        }
        // Web 不执行依赖原生 File 的 legacy 迁移，不自动换 UUID/key。
        if (row.lastError?.startsWith('legacy_') == true) {
          throw LegacyUploadConflict();
        }
        final cached = await _browserStore.read(
          row,
          _browserOwner(uid),
          () => _browserCurrent(uid),
        );
        var materials = await _loadMaterials(row);
        _requireBrowserSession(uid);
        Uint8List bytes = cached.bytes;
        SealedAttachment? sealed;
        if (cached.kind == BrowserMaterialKind.upload) {
          if (sha256.convert(bytes).toString() != row.ciphertextSha256) {
            throw LostCipherMaterialError(row.id);
          }
          if (row.cipher != null) {
            final raw = materials?['descriptor'];
            if (raw == null) throw LostCipherMaterialError(row.id);
            final descriptor = AttachmentDescriptor.fromMap(
              jsonDecode(raw) as Map<String, dynamic>,
            );
            if (descriptor.objectKey != row.objectKey ||
                descriptor.plainSize != row.plainSize ||
                descriptor.name != row.fileName ||
                descriptor.mime != row.mime ||
                base64Encode(descriptor.contentKey) !=
                    materials?['content_key'] ||
                base64Encode(descriptor.baseNonce) !=
                    materials?['base_nonce'] ||
                descriptor.plainSha256
                        .map((b) => b.toRadixString(16).padLeft(2, '0'))
                        .join() !=
                    row.plainSha256) {
              throw LostCipherMaterialError(row.id);
            }
            sealed = SealedAttachment(bytes, descriptor);
          }
        } else {
          if (row.stage != AttachmentUploadStage.pending &&
              row.stage != AttachmentUploadStage.presigned) {
            throw LostCipherMaterialError(row.id);
          }
          if (cached.kind == BrowserMaterialKind.encryptedSource) {
            if (row.cipher == null || materials == null) {
              throw LostCipherMaterialError(row.id);
            }
            bytes = AttachmentEncryptor.open(
              ciphertext: bytes,
              descriptor: _sourceDescriptor(row, materials),
              bindingHash: _hexDecode(row.bindingHash!),
            );
          } else if (row.cipher != null) {
            throw LostCipherMaterialError(row.id);
          }
          if (bytes.length != row.plainSize ||
              sha256.convert(bytes).toString() != row.plainSha256) {
            throw LostCipherMaterialError(row.id);
          }
          if (row.mime.startsWith('video/') && row.cipher != null) {
            if (materials == null) throw LostCipherMaterialError(row.id);
            materials = {
              ...materials,
              'thumb': await _videoThumbDescriptor(row),
            };
          }
        }
        completed.add(
          await _runWithMaterials(
            row,
            materials,
            bytes: bytes,
            cachedSealed: sealed,
          ),
        );
      } on BrowserMaterialException catch (error) {
        _requireBrowserSession(uid);
        if (!owned || error.failure == BrowserMaterialFailure.ownership) {
          continue;
        }
        if (error.failure == BrowserMaterialFailure.missing ||
            error.failure == BrowserMaterialFailure.corrupt) {
          await _repo.abandon(
            row.id,
            uid,
            'upload cache lost; new task and key required',
          );
        } else {
          await _repo.setRecoveryReason(
            row,
            'upload recovery failed; original checkpoint retained',
          );
        }
      } on LostCipherMaterialError {
        _requireBrowserSession(uid);
        if (owned) {
          await _repo.abandon(
            row.id,
            uid,
            'cipher material lost; new task and key required',
          );
        }
      } on LegacyUploadConflict {
        _requireBrowserSession(uid);
        if (owned) await _repo.setRecoveryReason(row, 'legacy_return_page');
      } on UploadSessionRejected {
        _requireBrowserSession(uid);
        if (owned) {
          await _repo.abandon(
            row.id,
            uid,
            'upload session rejected; new task required',
          );
        }
      } on Object {
        _requireBrowserSession(uid);
        if (owned) {
          await _repo.setRecoveryReason(
            row,
            'upload recovery failed; original checkpoint retained',
          );
        }
      }
    }
    return completed;
  }
}
