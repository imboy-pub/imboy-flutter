import 'dart:convert';

import 'auth_session_scope.dart';
import 'e2ee/e2ee_secret_inventory.dart';
import 'e2ee_local_backup_service.dart';
import 'storage.dart';
import 'storage_secure.dart';
import '../store/repository/user_repo_local.dart';

/// Restoration writes share the login/logout/cleanup queue. A response from an
/// earlier session must never recreate the selected account's erased secrets.
abstract final class E2eeBackupRestoreState {
  static Future<void> saveIdentity(
    Map<String, dynamic> result,
    AuthSessionScope session,
  ) => UserRepoLocal.to.writeSessionSecret(
    uid: session.uid,
    generation: session.generation,
    write: () async {
      await StorageSecureService.to.savePrivateKey(
        result['private_key'] as String,
      );
      await StorageSecureService.to.savePublicKey(
        result['public_key'] as String,
      );
      await StorageSecureService.to.setKeyId(result['key_id'] as String);
    },
    discard: () async {
      final inventory = E2eeSecretInventory.production();
      for (final key in [
        'e2ee_private_key',
        'e2ee_public_key',
        'e2ee_key_id',
      ]) {
        await inventory.deleteKey(key);
      }
    },
  );

  static Future<void> writePreference(
    String key,
    Object value,
    AuthSessionScope session,
  ) => UserRepoLocal.to.writeSessionSecret(
    uid: session.uid,
    generation: session.generation,
    write: () => StorageService.to.persistPreference(
      () => value is bool
          ? StorageService.to.setBool(key, value)
          : StorageService.to.setString(key, value as String),
    ),
    discard: () => StorageService.to.persistPreference(
      () => StorageService.to.remove(key),
    ),
  );

  static Future<void> writeMarker(
    Map<String, dynamic> result,
    AuthSessionScope session,
  ) => writePreference(
    E2EELocalBackupService.kLastRestoreMarkerKey,
    jsonEncode({
      'created_at': result['created_at']?.toString() ?? '',
      'key_id': result['key_id']?.toString() ?? '',
    }),
    session,
  );
}
