import 'dart:convert';

import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// W5-01 密钥材料安全存储抽象。
///
/// 生产默认 [SecureUploadKeyStore]（flutter_secure_storage，经
/// [StorageSecureService]）；测试注入内存实现。contentKey/baseNonce
/// 绝不进 SQLite——任务行只保存 [ref] 引用。
abstract class UploadKeyStore {
  Future<void> write(String ref, Map<String, String> material);
  Future<Map<String, String>?> read(String ref);
}

/// 生产实现：安全存储（键前缀 utk_，值 JSON {content_key, base_nonce}，
/// 均为 base64）。
class SecureUploadKeyStore implements UploadKeyStore {
  SecureUploadKeyStore()
    : _uid = UserRepoLocal.to.currentUid,
      _generation = UserRepoLocal.to.sessionGeneration,
      _environment = currentEnv;

  final String _uid;
  final int _generation;
  final String _environment;

  String _storageKey(String ref) =>
      '$_prefix${Uri.encodeComponent(_environment)}:${Uri.encodeComponent(_uid)}:${Uri.encodeComponent(ref)}';

  static const String _prefix = 'utk_';

  @override
  Future<void> write(String ref, Map<String, String> material) async {
    await UserRepoLocal.to.writeSessionSecret(
      uid: _uid,
      generation: _generation,
      write: () async {
        _requireScope();
        await StorageSecureService.to.write(
          key: _storageKey(ref),
          value: jsonEncode(material),
        );
        _requireScope();
      },
      discard: () => StorageSecureService.to.delete(key: _storageKey(ref)),
    );
  }

  void _requireScope() {
    final actor = UserRepoLocal.to;
    if (_uid.isEmpty ||
        actor.currentUid != _uid ||
        !actor.isCurrentSession(_generation) ||
        actor.isAuthTransitioning ||
        currentEnv != _environment) {
      throw StateError('upload secret scope changed');
    }
  }

  @override
  Future<Map<String, String>?> read(String ref) async {
    _requireScope();
    final String? raw = await StorageSecureService.to.read(
      key: _storageKey(ref),
    );
    _requireScope();
    if (raw == null || raw.isEmpty) return null;
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded.cast<String, String>();
  }
}
