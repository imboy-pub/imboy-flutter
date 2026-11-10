import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'account_local_task_registry.dart';

/// Temporary app-owned exports and recordings. A task must stay registered
/// until its final file write/close so cleanup can wait before deleting here.
abstract final class AccountLocalFiles {
  static String folderFor(String temporaryRoot, AccountLocalTaskOwner owner) {
    if (owner.uid.isEmpty) {
      throw ArgumentError('Account files require a signed-in owner');
    }
    return path.join(temporaryRoot, 'account_local_data', owner.storageDigest);
  }

  static Future<Directory> directory(AccountLocalTask task) async {
    task.throwIfCancelled();
    final temporaryRoot = await getTemporaryDirectory();
    task.throwIfCancelled();
    final directory = Directory(folderFor(temporaryRoot.path, task.owner));
    await directory.create(recursive: true);
    task.throwIfCancelled();
    return directory;
  }
}
