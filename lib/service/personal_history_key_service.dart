import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:pointycastle/export.dart';

import 'account_local_task_registry.dart';
import 'auth_session_scope.dart';
import 'e2ee_crypto_service.dart';
import 'personal_history_kdf_native.dart'
    if (dart.library.js_interop) 'personal_history_kdf_web.dart';

enum PersonalHistoryKeyFailure {
  unauthorized,
  missingKey,
  malformedPackage,
  corruptPackage,
  authenticationFailed,
  versionConflict,
  kdfUnavailable,
}

class PersonalHistoryKeyException implements Exception {
  const PersonalHistoryKeyException(this.reason);

  final PersonalHistoryKeyFailure reason;

  @override
  String toString() => 'PersonalHistoryKeyException: ${reason.name}';
}

typedef PersonalHistoryPosition = ({
  String conversationId,
  String messageId,
  int actionVersion,
  BigInt sequence,
});

typedef PersonalHistoryCiphertext = ({
  int keyVersion,
  String algorithm,
  String nonce,
  String aad,
  String ciphertext,
});

/// A key ring for one verified account, deployment and authorization generation.
class PersonalHistoryKeyService {
  PersonalHistoryKeyService({
    required this.domain,
    required this.generation,
    required this.authorization,
    AuthSessionReader? sessionReader,
    AccountLocalTaskOwner? owner,
  }) : _reader = sessionReader ?? authSessionReader {
    _session = _reader.current;
    if (domain.isEmpty || !_safeInt(generation) || generation < 0) {
      throw ArgumentError('Invalid personal history scope');
    }
    _owner = identical(_reader, authSessionReader)
        ? AccountLocalTaskOwner.capture(uid: _session.uid)
        : owner;
    if (_owner != null && _owner.uid != _session.uid) {
      throw ArgumentError('Invalid personal history account owner');
    }
    _requireAuthorized();
    if (_owner != null) _active.add(this);
    _reader.addListener(_onAuthorizationChanged);
    authorization.addListener(_onAuthorizationChanged);
  }

  static const algorithm = 'AES-256-GCM';
  static const _purpose = 'imboy/personal-history/v1';
  static const _kdf = 'PBKDF2-HMAC-SHA256';
  static const _iterations = 310000;
  static const _keyBytes = 32;
  static const _saltBytes = 16;
  static const _nonceBytes = 12;
  static const _tagBytes = 16;
  static final _active = <PersonalHistoryKeyService>{};

  final String domain;
  final int generation;

  /// Bound by the caller to current server-authoritative opt-in and device state.
  final ValueListenable<bool> authorization;
  final AuthSessionReader _reader;
  late final AuthSessionScope _session;
  late final AccountLocalTaskOwner? _owner;
  final _keys = <int, Uint8List>{};
  final _pendingRestores = <Map<int, Uint8List>>{};
  bool _closed = false;
  int _latest = 0;

  bool get _isAuthorized {
    if (_reader.transitionFailed ||
        !_reader.isCurrent(_session) ||
        !authorization.value) {
      return false;
    }
    if (!identical(_reader, authSessionReader)) return true;
    try {
      return AccountLocalTaskOwner.capture(uid: _session.uid) == _owner;
    } on StateError {
      return false;
    }
  }

  void _onAuthorizationChanged() {
    if (!_isAuthorized) close();
  }

  void _requireAuthorized() {
    if (_closed || !_isAuthorized) {
      close();
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.unauthorized,
      );
    }
  }

  static void clearAccount(AccountLocalTaskOwner owner) {
    for (final service in _active.toList()) {
      if (service._owner == owner) service.close();
    }
  }

  /// Called on explicit history disable or when the owner disposes the session.
  void close() {
    if (_closed) return;
    _closed = true;
    _active.remove(this);
    _reader.removeListener(_onAuthorizationChanged);
    authorization.removeListener(_onAuthorizationChanged);
    _eraseKeys(_keys);
    for (final staged in _pendingRestores) {
      _eraseKeys(staged);
    }
    _pendingRestores.clear();
  }

  /// A new version is selected by the authorized caller. Old versions remain
  /// readable until the session ends.
  void rotate(int version) {
    _requireAuthorized();
    if (!_safeInt(version) || version <= _latest) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.versionConflict,
      );
    }
    final random = Random.secure();
    final key = Uint8List(_keyBytes);
    for (var i = 0; i < key.length; i++) {
      key[i] = random.nextInt(256);
    }
    _keys[version] = key;
    _latest = version;
  }

  PersonalHistoryCiphertext encrypt(
    Uint8List plaintext,
    PersonalHistoryPosition position,
  ) {
    _requireAuthorized();
    final key = _contentKey(_key(_latest), _latest);
    try {
      final nonce = E2EECryptoService.generateIV();
      final aad = _messageAad(_latest, position);
      return (
        keyVersion: _latest,
        algorithm: algorithm,
        nonce: base64.encode(nonce),
        aad: base64.encode(aad),
        ciphertext: base64.encode(_aead(true, key, nonce, aad, plaintext)),
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Position is the locally determined, authenticated identity of the entry.
  Uint8List decrypt(
    PersonalHistoryCiphertext envelope,
    PersonalHistoryPosition position,
  ) {
    _requireAuthorized();
    if (envelope.algorithm != algorithm) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.authenticationFailed,
      );
    }
    final version = envelope.keyVersion;
    final key = _contentKey(_key(version), version);
    try {
      final nonce = base64.decode(envelope.nonce);
      final ciphertext = base64.decode(envelope.ciphertext);
      if (nonce.length != _nonceBytes || ciphertext.length < _tagBytes) {
        throw const FormatException();
      }
      return _aead(
        false,
        key,
        nonce,
        _messageAad(version, position),
        ciphertext,
      );
    } on FormatException {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.authenticationFailed,
      );
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Only the ciphertext, algorithm parameters and hash are returned to the caller.
  Future<Map<String, Object>> sealPackage(int version, String password) async {
    _requireAuthorized();
    final key = _key(version);
    final salt = E2EECryptoService.generateSalt();
    final wrappingKey = await _wrappingKey(
      password,
      salt,
      _iterations,
      version,
    );
    try {
      _requireAuthorized();
      final nonce = E2EECryptoService.generateIV();
      final wrapped = Uint8List.fromList([
        ...nonce,
        ..._aead(
          true,
          wrappingKey,
          nonce,
          _packageAad(version, _iterations),
          key,
        ),
      ]);
      return {
        'key_version': version,
        'wrapped_key': base64.encode(wrapped),
        'kdf_meta': {
          'alg': _kdf,
          'iterations': _iterations,
          'salt': base64.encode(salt),
        },
        'integrity_hash': sha256.convert(wrapped).toString(),
      };
    } finally {
      wrappingKey.fillRange(0, wrappingKey.length, 0);
    }
  }

  /// Install an authenticated recovery package supplied by the authorized path.
  Future<void> restorePackage(Map<String, Object?> package, String password) =>
      restorePackages([package], password);

  /// Publish a recovered key ring only after every supplied version validates.
  Future<void> restorePackages(
    List<Map<String, Object?>> packages,
    String password,
  ) async {
    _requireAuthorized();
    final staged = <int, Uint8List>{};
    _pendingRestores.add(staged);
    try {
      for (final package in packages) {
        final (version, recovered) = await _unwrapPackage(package, password);
        final duplicate = staged[version];
        if (duplicate == null) {
          staged[version] = recovered;
        } else {
          try {
            _requireMatchingKey(duplicate, recovered);
          } finally {
            recovered.fillRange(0, recovered.length, 0);
          }
        }
      }

      _requireAuthorized();
      for (final entry in staged.entries) {
        final existing = _keys[entry.key];
        if (existing != null) _requireMatchingKey(existing, entry.value);
      }
      for (final version in staged.keys.toList()) {
        if (_keys.containsKey(version)) continue;
        _keys[version] = staged.remove(version)!;
        if (version > _latest) _latest = version;
      }
    } finally {
      _pendingRestores.remove(staged);
      _eraseKeys(staged);
    }
  }

  static void _eraseKeys(Map<int, Uint8List> keys) {
    for (final key in keys.values) {
      key.fillRange(0, key.length, 0);
    }
    keys.clear();
  }

  static void _requireMatchingKey(Uint8List known, Uint8List recovered) {
    var diff = 0;
    for (var i = 0; i < _keyBytes; i++) {
      diff |= known[i] ^ recovered[i];
    }
    if (diff != 0) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.versionConflict,
      );
    }
  }

  Future<(int, Uint8List)> _unwrapPackage(
    Map<String, Object?> package,
    String password,
  ) async {
    _requireAuthorized();
    final version = package['key_version'];
    final wrapped64 = package['wrapped_key'];
    final meta = package['kdf_meta'];
    if (version is! int ||
        version < 1 ||
        !_safeInt(version) ||
        wrapped64 is! String ||
        wrapped64.length != 80 ||
        meta is! Map ||
        meta['alg'] != _kdf) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.malformedPackage,
      );
    }
    final iterations = meta['iterations'];
    final salt64 = meta['salt'];
    if (iterations is! int ||
        iterations < _iterations ||
        iterations > 600000 ||
        salt64 is! String ||
        salt64.length != 24) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.malformedPackage,
      );
    }
    final Uint8List wrapped;
    final Uint8List salt;
    try {
      wrapped = base64.decode(wrapped64);
      salt = base64.decode(salt64);
      if (wrapped.length != _nonceBytes + _keyBytes + _tagBytes ||
          salt.length != _saltBytes) {
        throw const FormatException();
      }
    } on FormatException {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.malformedPackage,
      );
    }
    // The hash distinguishes changed bytes. Only the GCM tag authenticates them.
    if (sha256.convert(wrapped).toString() != package['integrity_hash']) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.corruptPackage,
      );
    }
    final wrappingKey = await _wrappingKey(password, salt, iterations, version);
    try {
      _requireAuthorized();
      final recovered = _aead(
        false,
        wrappingKey,
        Uint8List.sublistView(wrapped, 0, _nonceBytes),
        _packageAad(version, iterations),
        Uint8List.sublistView(wrapped, _nonceBytes),
      );
      return (version, recovered);
    } finally {
      wrappingKey.fillRange(0, wrappingKey.length, 0);
    }
  }

  static bool _safeInt(int value) => value <= 9007199254740991;

  Uint8List _key(int version) =>
      _keys[version] ??
      (throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.missingKey,
      ));

  Uint8List _packageAad(int version, int iterations) => _encode([
    _purpose,
    'key-package',
    algorithm,
    _kdf,
    iterations,
    _session.uid,
    domain,
    generation,
    version,
  ]);

  // The JSON array is positional. The sequence is serialized as a decimal
  // string to preserve authority-assigned 64-bit values in browsers.
  Uint8List _messageAad(int version, PersonalHistoryPosition position) {
    if (position.conversationId.isEmpty ||
        position.messageId.isEmpty ||
        position.actionVersion < 0 ||
        !_safeInt(position.actionVersion) ||
        position.sequence <= BigInt.zero ||
        position.sequence > BigInt.parse('9223372036854775807')) {
      throw ArgumentError('Invalid personal history position');
    }
    return _encode([
      version,
      algorithm,
      _session.uid,
      domain,
      position.conversationId,
      position.messageId,
      position.actionVersion,
      position.sequence.toString(),
      generation,
    ]);
  }

  Uint8List _contentKey(Uint8List key, int version) => _derive(
    key,
    _encode(['content', _session.uid, domain, generation, version]),
  );

  Future<Uint8List> _wrappingKey(
    String password,
    Uint8List salt,
    int iterations,
    int version,
  ) async {
    if (password.isEmpty) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.authenticationFailed,
      );
    }
    final Uint8List seed;
    try {
      seed = await derivePersonalHistoryPasswordKey(password, salt, iterations);
    } catch (_) {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.kdfUnavailable,
      );
    }
    try {
      return _derive(
        seed,
        _encode(['wrapping', _session.uid, domain, generation, version]),
      );
    } finally {
      seed.fillRange(0, seed.length, 0);
    }
  }

  static Uint8List _derive(Uint8List key, Uint8List salt) {
    final hkdf = HKDFKeyDerivator(SHA256Digest())
      ..init(HkdfParameters(key, _keyBytes, salt, _encodeText(_purpose)));
    final derived = Uint8List(_keyBytes);
    hkdf.deriveKey(null, 0, derived, 0);
    return derived;
  }

  static Uint8List _encodeText(String value) =>
      Uint8List.fromList(utf8.encode(value));
  static Uint8List _encode(List<Object> fields) =>
      _encodeText(jsonEncode(fields));

  static Uint8List _aead(
    bool encrypt,
    Uint8List key,
    Uint8List nonce,
    Uint8List aad,
    Uint8List input,
  ) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(encrypt, AEADParameters(KeyParameter(key), 128, nonce, aad));
    try {
      return cipher.process(input);
    } on InvalidCipherTextException {
      throw const PersonalHistoryKeyException(
        PersonalHistoryKeyFailure.authenticationFailed,
      );
    }
  }
}
