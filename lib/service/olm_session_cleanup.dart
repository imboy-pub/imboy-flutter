part of 'olm_session_service.dart';

void _clearOlmMemoryAfterLocalDataRemoval(OlmSessionService service) {
  service._sessions.clear();
  service._account = null;
  service._cryptoStore = null;
}

Future<void> _clearAllOlmState(OlmSessionService service) async {
  service._sessions.clear();
  service._account = null;
  // E2EE-030: ratchet 状态只在事务存储中，`olm_` 前缀擦除覆盖不到，须显式清。
  // DB 不可用时不阻断登出——SQLCipher 主钥同时被销毁，残留行不可读。
  final store = await service.cryptoStore;
  await store?.deleteAllSessions();
  // ⚠️ 登出后必须丢弃缓存的 CryptoStore：SqliteService 在登出时会 close
  // 底层 Database（E2eeSecretInventory.purgeAll），而本缓存仍持有已关闭
  // 句柄——下一账号登录后首次加密会抛 database_closed（真机黑盒实测，
  // 2026-08-25）。置 null 后下次访问经 cryptoStore getter 走
  // SqliteService.to.db 的 isOpen 检查自动重开。
  service._cryptoStore = null;
  await StorageSecureService.to.delete(key: _accountPickleStorageKey);
  await StorageSecureService.to.delete(key: _pickleKeyStorageKey);
  // 升级前版本遗留的 `olm_session_*` 明面副本由 E2eeSecretInventory 的
  // `olm_` 前缀全量 wipe 兜底。
  iPrint('[olm] all state cleared');
}
