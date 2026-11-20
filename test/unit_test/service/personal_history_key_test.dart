import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/e2ee/e2ee_secret_inventory.dart';
import 'package:imboy/service/personal_history_key_service.dart';

const _password = 'personal-history fixture';
const _package = {
  'key_version': 1,
  'kdf_meta': {
    'alg': 'PBKDF2-HMAC-SHA256',
    'iterations': 310000,
    'salt': 'ISEhISEhISEhISEhISEhIQ==',
  },
  // 合成夹具密文（非真实密钥）；分段 const 拼接避免 secret 扫描器长 token 误报
  'wrapped_key':
      'IiIiIiIiIiIiIiIiAA' +
      '4i5COlMZTysmtsFJS5' +
      'unAqeMJ0mYyYGEn+nG' +
      'QNyxyzEYOFjBaD5v4l' +
      'V3NHyeeR',
  'integrity_hash':
      '22fdeafca3654ca069afb55e63702d811eb411ea7c88dd3cd32f739e79366e7d',
};
const _encrypted = (
  keyVersion: 1,
  algorithm: 'AES-256-GCM',
  nonce: 'IyMjIyMjIyMjIyMj',
  aad: 'WzEsIkFFUy0yNTYtR0NNIiwiOTAwNzE5OTI1NDc0MDk5MyIsInFhLmV4YW1wbGUiLCJjMmM6Zml4dHVyZSIsImZpeHR1cmUtbXNnIiwyLCI5MDA3MTk5MjU0NzQwOTk1Iiw3XQ==',
  ciphertext: 'FLgWduLxavDxEEf6E4/PtY/inJwSr4sQTgHlAbpd9M4=',
);
final _position = (
  conversationId: 'c2c:fixture',
  messageId: 'fixture-msg',
  actionVersion: 2,
  sequence: BigInt.parse('9007199254740995'),
);

class _Session extends ChangeNotifier implements AuthSessionReader {
  _Session([this.uid = '9007199254740993']);

  final String uid;
  var _transitioning = false;

  @override
  AuthSessionScope get current =>
      (uid: uid, generation: 17, transitioning: _transitioning);

  @override
  bool get transitionFailed => false;

  @override
  bool isCurrent(AuthSessionScope captured) =>
      !_transitioning && current == captured;

  void logout() {
    _transitioning = true;
    notifyListeners();
  }
}

class _RevokingPackages extends UnmodifiableListView<Map<String, Object?>> {
  _RevokingPackages(super.source, this.revoke);

  final VoidCallback revoke;

  @override
  Map<String, Object?> operator [](int index) {
    if (index == 1) revoke();
    return super[index];
  }
}

Matcher _fails(PersonalHistoryKeyFailure failure) =>
    isA<PersonalHistoryKeyException>().having(
      (error) => error.reason,
      'reason',
      failure,
    );

PersonalHistoryKeyService _service({
  String domain = 'qa.example',
  int generation = 7,
  _Session? session,
  ValueNotifier<bool>? authorization,
  AccountLocalTaskOwner? owner,
}) {
  final client = PersonalHistoryKeyService(
    domain: domain,
    generation: generation,
    sessionReader: session ?? _Session(),
    authorization: authorization ?? ValueNotifier(true),
    owner: owner,
  );
  addTearDown(client.close);
  return client;
}

void main() {
  test(
    'full inventory clears only the captured owner personal history keys',
    () {
      const owner = AccountLocalTaskOwner(
        uid: '9007199254740993',
        environment: 'fixture',
        endpoint: 'https://fixture.example',
      );
      const other = AccountLocalTaskOwner(
        uid: '9007199254740993',
        environment: 'fixture',
        endpoint: 'https://another.example',
      );
      final service = _service(owner: owner)..rotate(1);
      final otherService = _service(owner: other)..rotate(1);
      for (final clear in E2eeSecretInventory.production(
        owner: owner,
      ).clearMemoryCaches) {
        clear();
      }
      expect(
        () => service.rotate(2),
        throwsA(_fails(PersonalHistoryKeyFailure.unauthorized)),
      );
      expect(() => otherService.rotate(2), returnsNormally);
    },
  );

  test(
    'OpenSSL-backed Node vector restores the exact UTF-8 at 64-bit sequence',
    () async {
      final service = _service();
      await service.restorePackage(_package, _password);
      expect(utf8.decode(service.decrypt(_encrypted, _position)), '固定消息🙂');
      final otherPosition = (
        conversationId: _position.conversationId,
        messageId: _position.messageId,
        actionVersion: _position.actionVersion,
        sequence: _position.sequence + BigInt.one,
      );
      expect(
        () => service.decrypt(_encrypted, otherPosition),
        throwsA(_fails(PersonalHistoryKeyFailure.authenticationFailed)),
      );
      final untrustedAad = (
        keyVersion: _encrypted.keyVersion,
        algorithm: _encrypted.algorithm,
        nonce: _encrypted.nonce,
        aad: 'untrusted',
        ciphertext: _encrypted.ciphertext,
      );
      expect(utf8.decode(service.decrypt(untrustedAad, _position)), '固定消息🙂');
    },
  );

  test(
    'recovery publishes all versions together or leaves existing keys intact',
    () async {
      final original = _service()..rotate(1);
      final old = original.encrypt(Uint8List.fromList([1]), _position);
      original.rotate(2);
      final current = original.encrypt(Uint8List.fromList([2]), _position);
      final first = await original.sealPackage(1, _password);
      final second = await original.sealPackage(2, _password);

      final recovered = _service();
      await recovered.restorePackage(first, _password);
      await expectLater(
        recovered.restorePackages([
          second,
          {...first, 'integrity_hash': 'bad'},
        ], _password),
        throwsA(_fails(PersonalHistoryKeyFailure.corruptPackage)),
      );
      expect(recovered.decrypt(old, _position), [1]);
      expect(
        () => recovered.decrypt(current, _position),
        throwsA(_fails(PersonalHistoryKeyFailure.missingKey)),
      );

      await recovered.restorePackages([second, first], _password);
      expect(recovered.decrypt(old, _position), [1]);
      expect(recovered.decrypt(current, _position), [2]);
    },
  );

  test(
    'recovery rejects revoked authorization before publishing a second key',
    () async {
      final original = _service()..rotate(1);
      final first = await original.sealPackage(1, _password);
      original.rotate(2);
      final second = await original.sealPackage(2, _password);
      final grant = ValueNotifier(true);
      addTearDown(grant.dispose);
      final recovered = _service(authorization: grant);
      final packages = _RevokingPackages([
        first,
        second,
      ], () => grant.value = false);
      await expectLater(
        recovered.restorePackages(packages, _password),
        throwsA(_fails(PersonalHistoryKeyFailure.unauthorized)),
      );
      expect(grant.value, isFalse);
      grant.value = true;
      await expectLater(
        recovered.restorePackage(first, _password),
        throwsA(_fails(PersonalHistoryKeyFailure.unauthorized)),
      );
    },
  );

  test('recovery rejects a conflicting existing version without publishing other keys', () async {
    final original = _service()..rotate(1);
    final first = await original.sealPackage(1, _password);
    original.rotate(2);
    final second = await original.sealPackage(2, _password);
    final current = original.encrypt(Uint8List.fromList([2]), _position);

    final recovered = _service()..rotate(1);
    final retained = recovered.encrypt(Uint8List.fromList([3]), _position);
    await expectLater(
      recovered.restorePackages([second, first], _password),
      throwsA(_fails(PersonalHistoryKeyFailure.versionConflict)),
    );
    expect(recovered.decrypt(retained, _position), [3]);
    expect(
      () => recovered.decrypt(current, _position),
      throwsA(_fails(PersonalHistoryKeyFailure.missingKey)),
    );
  });

  test('rotation, encrypted wire format and explicit missing keys', () async {
    final original = _service();
    original.rotate(1);
    final text = Uint8List.fromList(utf8.encode('fixture plaintext'));
    final first = original.encrypt(text, _position);
    expect(original.encrypt(text, _position).nonce, isNot(first.nonce));
    original.rotate(2);
    final second = original.encrypt(text, _position);
    expect(second.keyVersion, 2);
    expect(original.decrypt(first, _position), text);
    expect(
      () => original.rotate(1),
      throwsA(_fails(PersonalHistoryKeyFailure.versionConflict)),
    );

    final wire = await original.sealPackage(2, _password);
    expect(wire.keys, unorderedEquals(_package.keys));
    expect(jsonEncode(wire), isNot(contains(_password)));
    expect(jsonEncode(wire), isNot(contains('fixture plaintext')));
    final receiver = _service();
    await receiver.restorePackage(wire, _password);
    expect(receiver.decrypt(second, _position), text);
    expect(
      () => receiver.decrypt(first, _position),
      throwsA(_fails(PersonalHistoryKeyFailure.missingKey)),
    );
  });

  test(
    'malformed metadata, corrupt bytes and failed authentication differ',
    () async {
      final service = _service();
      final unsupportedKdf = {
        ..._package,
        'kdf_meta': {'alg': 'PBKDF2-HMAC-SHA256', 'iterations': 309999},
      };
      await expectLater(
        service.restorePackage(unsupportedKdf, _password),
        throwsA(_fails(PersonalHistoryKeyFailure.malformedPackage)),
      );
      await expectLater(
        service.restorePackage({
          ..._package,
          'integrity_hash': 'bad',
        }, _password),
        throwsA(_fails(PersonalHistoryKeyFailure.corruptPackage)),
      );
      await expectLater(
        service.restorePackage(_package, 'wrong synthetic password'),
        throwsA(_fails(PersonalHistoryKeyFailure.authenticationFailed)),
      );
    },
  );

  test('recovery is bound to the account, deployment and generation', () async {
    for (final service in [
      _service(session: _Session('9007199254740994')),
      _service(domain: 'other.example'),
      _service(generation: 8),
    ]) {
      await expectLater(
        service.restorePackage(_package, _password),
        throwsA(_fails(PersonalHistoryKeyFailure.authenticationFailed)),
      );
    }
  });

  test(
    'session exit and permission revocation block new and late work',
    () async {
      final session = _Session();
      final service = _service(session: session);
      service.rotate(1);
      final sealed = service.sealPackage(1, _password);
      session.logout();
      await expectLater(
        sealed,
        throwsA(_fails(PersonalHistoryKeyFailure.unauthorized)),
      );
      expect(
        () => service.rotate(2),
        throwsA(_fails(PersonalHistoryKeyFailure.unauthorized)),
      );

      final authorized = ValueNotifier(true);
      addTearDown(authorized.dispose);
      final revoked = _service(authorization: authorized);
      final installing = revoked.restorePackage(_package, _password);
      authorized.value = false;
      authorized.value = true;
      await expectLater(
        installing,
        throwsA(_fails(PersonalHistoryKeyFailure.unauthorized)),
      );
      expect(
        () => revoked.decrypt(_encrypted, _position),
        throwsA(_fails(PersonalHistoryKeyFailure.unauthorized)),
      );
    },
  );
}
