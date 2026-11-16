import 'dart:io';
import 'dart:typed_data';

import 'account_local_files.dart';
import 'account_local_task_registry.dart';
import 'auth_session_scope.dart';
import 'storage_secure.dart';

/// Account ownership surrounds packing as well as the final file write.
abstract final class E2eeLocalBackupFiles {
  static Future<String> writeExport({
    required String? accountId,
    required Future<Uint8List> Function(String uid) pack,
  }) async {
    final storage = StorageSecureService.to;
    final keyGeneration = storage.e2eeKeyGeneration;
    final session = authSessionReader.current;
    if (!authSessionReader.isCurrent(session) ||
        (accountId != null && accountId != session.uid)) {
      throw const AccountLocalTaskCancelledException();
    }
    final owner = AccountLocalTaskOwner.capture(uid: session.uid);
    return AccountLocalTaskRegistry.instance.run<String>(
      owner,
      operation: (task) async {
        void ensureCurrent() {
          task.throwIfCancelled();
          if (!authSessionReader.isCurrent(session) ||
              AccountLocalTaskOwner.capture() != owner) {
            throw const AccountLocalTaskCancelledException();
          }
        }

        final bytes = await pack(session.uid);
        ensureCurrent();
        // An export packed before identity deletion must not recreate its
        // erased backup. Native file writes and purge use the identity queue.
        return storage.writeE2eeKeys(keyGeneration, () async {
          ensureCurrent();
          final tempDir = await AccountLocalFiles.directory(task);
          ensureCurrent();
          final timestamp = DateTime.now().toIso8601String().replaceAll(
            ':',
            '-',
          );
          final file = File('${tempDir.path}/imboy_e2ee_backup_$timestamp.enc');
          await file.writeAsBytes(bytes, flush: true);
          ensureCurrent();
          return file.path;
        });
      },
    );
  }
}
