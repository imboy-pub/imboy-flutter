part of 'attachment_upload_task_repo_sqlite.dart';

enum BrowserMaterialFailure {
  missing,
  corrupt,
  ownership,
  storage,
  durabilityUnavailable,
}

class BrowserMaterialException implements Exception {
  const BrowserMaterialException(this.failure);
  final BrowserMaterialFailure failure;
  @override
  String toString() => 'BrowserMaterialException(${failure.name})';
}

enum BrowserMaterialKind { source, encryptedSource, upload }

class BrowserUploadMaterial {
  const BrowserUploadMaterial(this.kind, this.bytes);
  final BrowserMaterialKind kind;
  final Uint8List bytes;
  static String locator(String owner, String taskId, String materialId) =>
      'sqlite-upload-v1:$owner:${Uri.encodeComponent(taskId)}:$materialId';
  static String pending(String owner, String taskId) =>
      locator(owner, taskId, 'pending');
  static void requireOwner(String? value, String owner, String taskId) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(owner) ||
        value == null ||
        !value.startsWith(
          'sqlite-upload-v1:$owner:${Uri.encodeComponent(taskId)}:',
        ) ||
        value.split(':').length != 4) {
      throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
    }
  }
}

/// 复用现有账号 SQLite。事务同时发布 BLOB 与 journal 指针，不在此存 key/nonce。
class BrowserAttachmentMaterialStore {
  BrowserAttachmentMaterialStore(this.repo, {this.durabilityBarrier})
    : _boundOwner = null,
      _generation = null;
  BrowserAttachmentMaterialStore._bound(
    this.repo,
    this._boundOwner,
    this._generation,
  ) : durabilityBarrier = null;

  /// Explicit integration point after W11 acceptance. This does not change the
  /// default Web gate or claim browser capabilities from a review alone.
  factory BrowserAttachmentMaterialStore.forCurrentBrowserSession(
    AttachmentUploadTaskRepo repo,
  ) {
    if (!kIsWeb) throw UnsupportedError('Browser storage binding is Web-only');
    final owner = AccountLocalTaskOwner.capture();
    return BrowserAttachmentMaterialStore._bound(
      repo,
      owner,
      UserRepoLocal.to.sessionGeneration,
    );
  }

  final AttachmentUploadTaskRepo repo;
  final Future<void> Function()? durabilityBarrier;
  final AccountLocalTaskOwner? _boundOwner;
  final int? _generation;
  Database? _database;

  void _requireSession() {
    final owner = _boundOwner;
    if (owner == null) return;
    final actor = UserRepoLocal.to;
    if (actor.currentUid != owner.uid ||
        owner.uid.isEmpty ||
        !actor.isCurrentSession(_generation!) ||
        actor.isAuthTransitioning ||
        (currentEnv.isEmpty ? 'pro' : currentEnv) != owner.environment ||
        Env().apiBaseUrl != owner.endpoint) {
      throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
    }
    // DB and secure-key legacy paths are env/UID scoped. The persisted startup
    // inventory must prove they are not shared with another endpoint.
    try {
      LoginAccountHistoryService().requireIndependentStorage(
        LoginAccountIdentity(
          uid: owner.uid,
          environment: owner.environment,
          endpoint: owner.endpoint,
          aliases: const {},
        ),
      );
    } catch (_) {
      throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
    }
  }

  void _requireTask(AttachmentUploadTask task, String owner) {
    final binding = _boundOwner;
    if (binding != null &&
        (task.userId != binding.uid || owner != binding.storageDigest)) {
      throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
    }
  }

  Future<Database> _boundDatabase() async {
    final db = await repo._boundDb;
    if (db == null || !db.isOpen) {
      throw const BrowserMaterialException(BrowserMaterialFailure.storage);
    }
    if (_boundOwner != null) {
      if (_database != null && !identical(_database, db)) {
        throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
      }
      _database ??= db;
    }
    return db;
  }

  /// Storage-only callback permits the auth queue to discard a late publication
  /// in the captured old handle; it never rebinds to a new session database.
  Future<void> _persistDatabase(Database db) async {
    final owner = _boundOwner;
    try {
      if (owner != null) {
        if (!identical(_database, db)) {
          throw const BrowserMaterialException(
            BrowserMaterialFailure.ownership,
          );
        }
        await durableBrowserAccountDatabase(
          db,
          databaseName: '${owner.environment}_${owner.uid}.db',
        );
      } else {
        await durabilityBarrier?.call();
      }
    } on BrowserMaterialException {
      rethrow;
    } catch (_) {
      throw const BrowserMaterialException(BrowserMaterialFailure.storage);
    }
  }

  /// No barrier is called inside a SQLite transaction. The bound bridge holds
  /// the namespace lease, serializes COMMIT -> same-VFS flush and poisons errors.
  Future<void> ensureDurable() async {
    if (kIsWeb && _boundOwner == null) {
      throw const BrowserMaterialException(
        BrowserMaterialFailure.durabilityUnavailable,
      );
    }
    _requireSession();
    final db = await _boundDatabase();
    _requireSession();
    await _persistDatabase(db);
    _requireSession();
  }

  static const tableName = 'attachment_upload_browser_material';
  Future<void> _ensure(DatabaseExecutor db) => db.execute(
    'CREATE TABLE IF NOT EXISTS $tableName ('
    'locator TEXT PRIMARY KEY, user_id TEXT NOT NULL, owner_scope TEXT NOT NULL, '
    'task_id TEXT NOT NULL, kind TEXT NOT NULL, bytes BLOB NOT NULL, '
    'sha256 TEXT NOT NULL)',
  );

  Future<BrowserMaterialCommit> write({
    required AttachmentUploadTask task,
    required String owner,
    required BrowserMaterialKind kind,
    required Uint8List bytes,
    required AttachmentUploadStage stage,
    required String materialId,
    required int maxBytes,
    required bool Function() isCurrent,
    String? ciphertextSha256,
    String? expectedKeyRef,
  }) async {
    _requireTask(task, owner);
    BrowserUploadMaterial.requireOwner(task.uploadPath, owner, task.id);
    await ensureDurable();
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        materialId.contains(':') ||
        materialId.isEmpty) {
      throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
    }
    if ((kind == BrowserMaterialKind.source && task.cipher != null) ||
        (kind == BrowserMaterialKind.encryptedSource && task.cipher == null)) {
      throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
    }
    final snapshot = Uint8List.fromList(bytes);
    final hash = material_crypto.sha256.convert(snapshot).toString();
    if ((kind == BrowserMaterialKind.source ||
            (kind == BrowserMaterialKind.upload && task.cipher == null)) &&
        (bytes.length != task.plainSize || hash != task.plainSha256)) {
      throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
    }
    if (kind == BrowserMaterialKind.upload && hash != ciphertextSha256) {
      throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
    }
    final next = BrowserUploadMaterial.locator(owner, task.id, materialId);
    try {
      if (!isCurrent()) {
        throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
      }
      final db = await _boundDatabase();
      final commit = await db.transaction((tx) async {
        if (!isCurrent()) {
          throw const BrowserMaterialException(
            BrowserMaterialFailure.ownership,
          );
        }
        final rows = await tx.query(
          AttachmentUploadTaskRepo.tableName,
          where: 'id = ? AND user_id = ?',
          whereArgs: [task.id, task.userId],
          limit: 1,
        );
        if (rows.length != 1) {
          throw const BrowserMaterialException(
            BrowserMaterialFailure.ownership,
          );
        }
        final current = AttachmentUploadTask.fromMap(rows.single);
        BrowserUploadMaterial.requireOwner(current.uploadPath, owner, task.id);
        if (current.stage != stage ||
            current.stage.isTerminal ||
            current.plainSize != task.plainSize ||
            current.plainSha256 != task.plainSha256 ||
            current.scope != task.scope ||
            current.scopeRef != task.scopeRef ||
            current.anchorMsgId != task.anchorMsgId ||
            current.cipher != task.cipher ||
            current.bindingHash != task.bindingHash ||
            current.fileName != task.fileName ||
            current.mime != task.mime ||
            (expectedKeyRef != null && current.keyRef != expectedKeyRef)) {
          throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
        }
        await _ensure(tx);
        await tx.insert(tableName, {
          'locator': next,
          'user_id': task.userId,
          'owner_scope': owner,
          'task_id': task.id,
          'kind': kind.name,
          'bytes': snapshot,
          'sha256': hash,
        });
        final changed = await tx.update(
          AttachmentUploadTaskRepo.tableName,
          {
            'upload_path': next,
            'ciphertext_sha256': ?ciphertextSha256,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ? AND user_id = ? AND stage = ? AND upload_path = ?',
          whereArgs: [task.id, task.userId, stage.value, current.uploadPath],
        );
        if (changed != 1 || !isCurrent()) {
          throw const BrowserMaterialException(
            BrowserMaterialFailure.ownership,
          );
        }
        return BrowserMaterialCommit._(
          db,
          task.id,
          task.userId,
          owner,
          stage,
          next,
          current.uploadPath!,
          current.ciphertextSha256,
          () => _persistDatabase(db),
        );
      });
      await _persistDatabase(db);
      return commit;
    } on BrowserMaterialException {
      rethrow;
    } catch (_) {
      // 包括 SQLite/VFS quota。不得降级内存缓存或伪造 durable checkpoint。
      throw const BrowserMaterialException(BrowserMaterialFailure.storage);
    }
  }

  Future<BrowserUploadMaterial> read(
    AttachmentUploadTask task,
    String owner,
    bool Function() isCurrent,
  ) async {
    _requireTask(task, owner);
    BrowserUploadMaterial.requireOwner(task.uploadPath, owner, task.id);
    await ensureDurable();
    try {
      if (!isCurrent()) {
        throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
      }
      final db = await _boundDatabase();
      await _ensure(db);
      final rows = await db.query(
        tableName,
        where:
            'locator = ? AND user_id = ? AND owner_scope = ? AND task_id = ?',
        whereArgs: [task.uploadPath, task.userId, owner, task.id],
        limit: 1,
      );
      if (!isCurrent()) {
        throw const BrowserMaterialException(BrowserMaterialFailure.ownership);
      }
      if (rows.isEmpty) {
        throw const BrowserMaterialException(BrowserMaterialFailure.missing);
      }
      final row = rows.single;
      final raw = row['bytes'];
      if (raw is! Uint8List ||
          raw.isEmpty ||
          material_crypto.sha256.convert(raw).toString() != row['sha256']) {
        throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
      }
      final kind = BrowserMaterialKind.values
          .where((kind) => kind.name == row['kind'])
          .toList();
      if (kind.length != 1) {
        throw const BrowserMaterialException(BrowserMaterialFailure.corrupt);
      }
      return BrowserUploadMaterial(kind.single, Uint8List.fromList(raw));
    } on BrowserMaterialException {
      rethrow;
    } catch (_) {
      throw const BrowserMaterialException(BrowserMaterialFailure.storage);
    }
  }
}

/// 认证队列的迟到取消只回滚该次发布；保留前一个材料，不能删其他写者。
class BrowserMaterialCommit {
  BrowserMaterialCommit._(
    this._db,
    this.taskId,
    this.userId,
    this.owner,
    this.stage,
    this.locator,
    this.previous,
    this.previousHash,
    this._durabilityBarrier,
  );
  final Database _db;
  final Future<void> Function() _durabilityBarrier;
  final String taskId, userId, owner, locator, previous;
  final String? previousHash;
  final AttachmentUploadStage stage;
  Future<void> discard() async {
    try {
      await _db.transaction((tx) async {
        final changed = await tx.update(
          AttachmentUploadTaskRepo.tableName,
          {'upload_path': previous, 'ciphertext_sha256': previousHash},
          where: 'id = ? AND user_id = ? AND stage = ? AND upload_path = ?',
          whereArgs: [taskId, userId, stage.value, locator],
        );
        if (changed != 1) return;
        await tx.delete(
          BrowserAttachmentMaterialStore.tableName,
          where:
              'locator = ? AND user_id = ? AND owner_scope = ? AND task_id = ?',
          whereArgs: [locator, userId, owner, taskId],
        );
      });
      await _durabilityBarrier();
    } catch (_) {
      throw const BrowserMaterialException(BrowserMaterialFailure.storage);
    }
  }

  Future<void> finish() async {
    try {
      await _db.transaction((tx) async {
        final rows = await tx.query(
          AttachmentUploadTaskRepo.tableName,
          columns: ['id'],
          where: 'id = ? AND user_id = ? AND upload_path = ?',
          whereArgs: [taskId, userId, locator],
          limit: 1,
        );
        if (rows.length != 1) return;
        await tx.delete(
          BrowserAttachmentMaterialStore.tableName,
          where: 'user_id = ? AND owner_scope = ? AND task_id = ? AND locator != ?',
          whereArgs: [userId, owner, taskId, locator],
        );
      });
      await _durabilityBarrier();
    } catch (_) {
      throw const BrowserMaterialException(BrowserMaterialFailure.storage);
    }
  }
}
