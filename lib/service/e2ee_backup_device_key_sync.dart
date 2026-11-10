import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'account_local_task_registry.dart';
import 'auth_session_scope.dart';
import 'storage_secure.dart';

/// Reports restored identity keys using this device's DID, never the DID in
/// the backup. Preparation and the network report belong to one login session.
abstract final class E2eeBackupDeviceKeySync {
  static Future<bool> synchronize({
    required Map<String, dynamic> restored,
    required AuthSessionScope session,
    required AccountLocalTaskOwner owner,
    required bool Function() isActive,
    Future<bool> Function(Map<String, dynamic>)? reporter,
  }) async {
    bool current() =>
        isActive() &&
        authSessionReader.isCurrent(session) &&
        session.uid == owner.uid &&
        AccountLocalTaskOwner.capture() == owner;
    if (!current()) return false;
    try {
      return await AccountLocalTaskRegistry.instance.run<bool>(
        owner,
        operation: (task) async {
          void ensureCurrent() {
            task.throwIfCancelled();
            if (!current()) throw const AccountLocalTaskCancelledException();
          }

          ensureCurrent();
          if (reporter != null) {
            final reported = await reporter(restored);
            ensureCurrent();
            return reported;
          }
          final storage = StorageSecureService.to;
          var deviceId = await storage.getDeviceId() ?? '';
          ensureCurrent();
          final detail = await DeviceExt.to.detail;
          ensureCurrent();
          if (deviceId.isEmpty) {
            deviceId = detail?['did']?.toString() ?? '';
            if (deviceId.isNotEmpty) {
              var attemptedWrite = false;
              await UserRepoLocal.to.writeSessionSecret(
                uid: session.uid,
                generation: session.generation,
                write: () async {
                  ensureCurrent();
                  attemptedWrite = true;
                  await storage.setDeviceId(deviceId);
                },
                discard: () async {
                  if (attemptedWrite &&
                      await storage.getDeviceId() == deviceId) {
                    await storage.delete(key: 'e2ee_device_id');
                  }
                },
              );
              ensureCurrent();
            }
          }
          if (deviceId.isEmpty) return false;
          // reportDeviceKey has no cancellation-token argument. Keep this
          // task registered until the request settles so cleanup can drain it.
          ensureCurrent();
          final response = await E2EEApi().reportDeviceKey(
            deviceId: deviceId,
            deviceType: detail?['cos']?.toString() ?? 'unknown',
            deviceName: detail?['deviceName']?.toString(),
            publicKey: restored['public_key'] as String,
            keyId: restored['key_id'] as String,
          );
          ensureCurrent();
          return response.ok;
        },
      );
    } on Object catch (error) {
      iPrint('[RESTORE] 设备公钥回写异常: ${error.runtimeType}');
      return false;
    }
  }
}
