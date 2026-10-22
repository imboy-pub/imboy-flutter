import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:synchronized/synchronized.dart';

enum TalkRecordAiProvider {
  doubao('', ''),
  minimax('asr-1.0', 'https://api.minimax.cn/v1/speech_to_text'),
  zhipu(
    'glm-5.3-flash',
    'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  );

  const TalkRecordAiProvider(this.model, this.endpoint);
  final String model;
  final String endpoint;
  bool get isTranscription => this != zhipu;
  bool get executionAvailable => this != doubao;
}

/// Deployment and account scope; credentials never cross these boundaries.
class TalkRecordAiCredentialScope {
  TalkRecordAiCredentialScope({
    required String deploymentOrigin,
    required this.accountId,
  }) : deploymentOrigin = _origin(deploymentOrigin) {
    if (accountId.isEmpty ||
        accountId.length > 128 ||
        accountId.trim() != accountId ||
        _unsafe.hasMatch(accountId)) {
      throw const TalkRecordAiCredentialException('invalid_scope');
    }
  }

  final String deploymentOrigin;
  final String accountId;
  static final _unsafe = RegExp(r'[\s\x00-\x1f\x7f]');

  static String _origin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        _unsafe.hasMatch(value)) {
      throw const TalkRecordAiCredentialException('invalid_scope');
    }
    return uri.origin;
  }

  String get _digest => sha256
      .convert(utf8.encode(jsonEncode([deploymentOrigin, accountId])))
      .toString();

  bool matches(TalkRecordAiCredentialScope? other) =>
      other != null &&
      deploymentOrigin == other.deploymentOrigin &&
      accountId == other.accountId;

  @override
  String toString() => 'TalkRecordAiCredentialScope(redacted)';
}

/// A stable safe code only: platform exception messages can contain secrets.
class TalkRecordAiCredentialException implements Exception {
  const TalkRecordAiCredentialException(this.code);
  final String code;
  @override
  String toString() => 'TalkRecordAiCredentialException($code)';
}

class TalkRecordAiCredentialStatus {
  const TalkRecordAiCredentialStatus({required this.configured});
  final bool configured;
  // Do not expose a prefix, suffix or the actual length of the credential.
  String? get maskedKey => configured ? '••••••••' : null;
}

abstract interface class TalkRecordAiSecureStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class _DeviceSecureStore implements TalkRecordAiSecureStore {
  static final instance = _DeviceSecureStore();
  @override
  Future<void> write(String key, String value) =>
      StorageSecureService.to.write(key: key, value: value);
  @override
  Future<String?> read(String key) => StorageSecureService.to.read(key: key);
  @override
  Future<void> delete(String key) => StorageSecureService.to.delete(key: key);
}

class _CredentialSlot {
  final lock = Lock();
  int generation = 0;
  bool blocked = false;
}

class TalkRecordAiDispatchCredential {
  const TalkRecordAiDispatchCredential._(this.value, this.verifyCurrent);
  final String value;
  final void Function() verifyCurrent;

  @override
  String toString() => 'TalkRecordAiDispatchCredential(redacted)';
}

// The default adapter is shared. Injected adapters for the same backing store
// must also share one object, so separate consumers cannot bypass tombstones.
final _slots = Expando<Map<String, _CredentialSlot>>();

/// No network access, JSON export, ordinary checkpoint or plaintext fallback.
/// Callers must reacquire credentials for every dispatch after permission checks.
class TalkRecordAiCredentials {
  TalkRecordAiCredentials({
    required this.scope,
    required this.currentScope,
    required this.authSessionEpoch,
    required this.currentAuthSessionEpoch,
    TalkRecordAiSecureStore? store,
  }) : _store = store ?? _DeviceSecureStore.instance {
    if (authSessionEpoch < 0) {
      throw const TalkRecordAiCredentialException('invalid_auth_epoch');
    }
  }

  final TalkRecordAiCredentialScope scope;
  final TalkRecordAiCredentialScope? Function() currentScope;
  // The auth owner must advance this on every login/logout, including A -> A.
  final int authSessionEpoch;
  final int? Function() currentAuthSessionEpoch;
  final TalkRecordAiSecureStore _store;

  void _checkContext() {
    // Desktop backup/secure-store behavior is not verified for this feature.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw const TalkRecordAiCredentialException('unsupported_platform');
    }
    if (!scope.matches(currentScope()) ||
        currentAuthSessionEpoch() != authSessionEpoch) {
      throw const TalkRecordAiCredentialException('account_changed');
    }
  }

  String _key(TalkRecordAiProvider provider) =>
      'talk_record_ai_v1_${scope._digest}_${provider.name}';

  static bool _valid(String value) =>
      value.length >= 16 &&
      value.length <= 4096 &&
      !RegExp(r'[^\x21-\x7e]').hasMatch(value);

  _CredentialSlot _slot(TalkRecordAiProvider provider) {
    final byKey = _slots[_store] ??= <String, _CredentialSlot>{};
    return byKey.putIfAbsent(_key(provider), _CredentialSlot.new);
  }

  void _checkGeneration(_CredentialSlot slot, int generation) {
    _checkContext();
    if (slot.generation != generation) {
      throw const TalkRecordAiCredentialException('credential_changed');
    }
  }

  Future<void> save(TalkRecordAiProvider provider, String value) async {
    _checkContext();
    if (!_valid(value)) {
      throw const TalkRecordAiCredentialException('invalid_key');
    }
    await _mutate(provider, value);
  }

  Future<void> _mutate(TalkRecordAiProvider provider, String? value) async {
    _checkContext();
    final slot = _slot(provider);
    final generation = ++slot.generation;
    // Also keep failures blocked: a failed delete must not expose the old key.
    slot.blocked = true;
    await slot.lock.synchronized(() async {
      _checkGeneration(slot, generation);
      try {
        if (value == null) {
          await _store.delete(_key(provider));
        } else {
          await _store.write(_key(provider), value);
        }
      } catch (_) {
        throw const TalkRecordAiCredentialException('secure_storage_failed');
      }
      _checkGeneration(slot, generation);
      slot.blocked = false;
    });
  }

  Future<TalkRecordAiCredentialStatus> status(
    TalkRecordAiProvider provider,
  ) async => TalkRecordAiCredentialStatus(
    configured: await readForDispatch(provider) != null,
  );

  /// Only the isolated provider HTTP client should consume this return value.
  /// Do not log, serialize, cache or include it in server requests.
  Future<String?> readForDispatch(TalkRecordAiProvider provider) async =>
      (await acquireForDispatch(provider))?.value;

  Future<TalkRecordAiDispatchCredential?> acquireForDispatch(
    TalkRecordAiProvider provider,
  ) async {
    _checkContext();
    final slot = _slot(provider);
    final generation = slot.generation;
    if (slot.blocked) {
      throw const TalkRecordAiCredentialException('credential_changed');
    }
    final String? value;
    try {
      value = await _store.read(_key(provider));
    } catch (_) {
      throw const TalkRecordAiCredentialException('secure_storage_failed');
    }
    _checkGeneration(slot, generation);
    if (slot.blocked) {
      throw const TalkRecordAiCredentialException('credential_changed');
    }
    if (value != null && !_valid(value)) {
      throw const TalkRecordAiCredentialException('invalid_stored_key');
    }
    if (value == null) return null;
    return TalkRecordAiDispatchCredential._(value, () {
      _checkGeneration(slot, generation);
      if (slot.blocked) {
        throw const TalkRecordAiCredentialException('credential_changed');
      }
    });
  }

  Future<void> remove(TalkRecordAiProvider provider) => _mutate(provider, null);

  @override
  String toString() => 'TalkRecordAiCredentials(redacted)';
}
