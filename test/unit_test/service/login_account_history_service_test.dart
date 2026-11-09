import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final history = LoginAccountHistoryService();
  const endpoint = 'https://example.test/api';

  Future<void> remember(
    String uid,
    String alias, {
    String environment = 'pro',
    String api = endpoint,
    Map<String, dynamic> profile = const {},
  }) async {
    final identity = await history.rememberLogin(
      account: alias,
      profile: {'user_id': uid, ...profile},
      environment: environment,
      endpoint: api,
    );
    await StorageService.setMap(Keys.currentUser, {
      'user_id': uid,
      LoginAccountHistoryService.localProfileKey: identity.toJson(),
    });
  }

  LoginAccountIdentity resolve(
    String alias, {
    String environment = 'pro',
    String api = endpoint,
  }) => history.resolve(value: alias, environment: environment, endpoint: api);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('preparing history before a failed token write does not transfer session ownership', () async {
    await remember('1001', 'alice');
    final alice = resolve('alice');
    final bob = await history.rememberLogin(
      account: 'bob',
      profile: {'user_id': '1002'},
      environment: 'pro',
      endpoint: endpoint,
    );
    expect(history.ownsLastSession(alice), isTrue);
    expect(history.ownsLastSession(bob), isFalse);
  });

  test(
    'same uid in another deployment prevents deleting shared storage',
    () async {
      await remember('1001', 'alice');
      final alice = resolve('alice');
      expect(() => history.requireIndependentStorage(alice), returnsNormally);
      await remember('1001', 'alice-dev', environment: 'dev');
      expect(
        () => history.requireIndependentStorage(alice),
        throwsA(isA<LoginAccountSharedDataException>()),
      );
      expect(
        () => history.requireIndependentStorage(
          resolve('alice-dev', environment: 'dev'),
        ),
        throwsA(isA<LoginAccountSharedDataException>()),
      );
    },
  );

  test(
    'interrupted history cleanup retains its retry entry across new logins',
    () async {
      await remember('1001', 'alice');
      final persisted = jsonDecode(
        StorageService.to.getString(LoginAccountHistoryService.storageKey),
      ) as Map<String, dynamic>;
      persisted['retryHistory'] = {
        Keys.loginHistoryAccount: ['alice', 'bob'],
      };
      await StorageService.to.setString(
        LoginAccountHistoryService.storageKey,
        jsonEncode(persisted),
      );
      // Native storage persisted only the first removal before interruption.
      await StorageService.to.setList(Keys.loginHistoryAccount, ['bob']);
      expect(history.readHistory(Keys.loginHistoryAccount), ['bob', 'alice']);
      await remember('1002', 'bob');
      expect(history.readHistory(Keys.loginHistoryAccount), ['bob', 'alice']);
      await history.forget(resolve('alice'));
      expect(history.readHistory(Keys.loginHistoryAccount), ['bob']);
      expect(
        jsonDecode(
          StorageService.to.getString(LoginAccountHistoryService.storageKey),
        ),
        isNot(contains('retryHistory')),
      );
    },
  );

  test(
    'legacy hints never guess uid from numeric or similar account text',
    () async {
      await StorageService.to.setList(Keys.loginHistoryAccount, [
        '1001',
        'alice',
      ]);
      expect(
        () => resolve('1001'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
      await remember('1001', 'alice');
      expect(resolve('alice').uid, '1001');
      expect(
        () => resolve('1001'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
      expect(
        () => resolve('alic'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
    },
  );

  test(
    'authenticated response binds aliases without persisting credentials',
    () async {
      await remember(
        '1001',
        'alice@example.test',
        profile: {
          'account': 'alice',
          'email': 'alice@example.test',
          'mobile': '+8613900000001',
          'token': 'synthetic-token',
          'refreshtoken': 'synthetic-refresh',
        },
      );
      for (final alias in ['alice', 'alice@example.test', '+8613900000001']) {
        expect(resolve(alias).uid, '1001');
      }
      final stored = StorageService.to.getString(
        LoginAccountHistoryService.storageKey,
      );
      expect(stored, isNot(contains('synthetic-token')));
      expect(stored, isNot(contains('synthetic-refresh')));
    },
  );

  test(
    'same alias on another deployment cannot authorize this deployment',
    () async {
      await remember('1001', 'alice', environment: 'dev');
      expect(
        () => resolve('alice'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
      expect(
        history.visibleHistory(
          ['alice', 'legacy'],
          environment: 'pro',
          endpoint: endpoint,
        ),
        ['legacy'],
      );
      await remember('2002', 'alice');
      expect(resolve('alice').uid, '2002');
      expect(resolve('alice', environment: 'dev').uid, '1001');
      expect(
        () => resolve('alice', api: 'https://another.test/api'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
    },
  );

  test('alias reassignment follows latest successful authentication', () async {
    await remember('1001', 'alice', profile: {'email': 'old@example.test'});
    await remember('1002', 'bob', profile: {'email': 'old@example.test'});
    expect(resolve('old@example.test').uid, '1002');
    expect(resolve('alice').aliases, isNot(contains('old@example.test')));
    await remember('1001', 'alice');
    expect(resolve('old@example.test').uid, '1002');
  });

  test(
    'forget removes all account aliases and retains other account data hints',
    () async {
      await remember(
        '1001',
        'alice',
        profile: {'email': 'a@example.test', 'mobile': '+8613900000001'},
      );
      await remember('10010', 'alice-other');
      await StorageService.to.setList(Keys.loginHistory, [
        'alice',
        'a@example.test',
        'alice-other',
      ]);
      await StorageService.to.setList(Keys.loginHistoryAccount, [
        'alice',
        'alice-other',
      ]);
      await StorageService.to.setList(Keys.loginHistoryEmail, [
        'a@example.test',
        'b@example.test',
      ]);
      await StorageService.to.setList(Keys.loginHistoryMobile, [
        '+8613900000001',
      ]);
      await StorageService.to.setString(Keys.lastLoginAccount, 'alice');
      await history.forget(resolve('alice'));
      expect(StorageService.to.getList(Keys.loginHistory), ['alice-other']);
      expect(StorageService.to.getList(Keys.loginHistoryAccount), [
        'alice-other',
      ]);
      expect(StorageService.to.getList(Keys.loginHistoryEmail), [
        'b@example.test',
      ]);
      expect(StorageService.to.getList(Keys.loginHistoryMobile), isEmpty);
      expect(StorageService.to.getString(Keys.lastLoginAccount), isEmpty);
      expect(
        () => resolve('alice'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
      expect(resolve('alice-other').uid, '10010');
      expect(history.ownsLastSession(resolve('alice-other')), isTrue);
    },
  );

  test(
    'forget preserves an alias still owned by another environment',
    () async {
      await remember('1001', 'alice', environment: 'dev');
      await remember('2002', 'alice');
      await StorageService.to.setList(Keys.loginHistoryAccount, ['alice']);
      await history.forget(resolve('alice'));
      expect(StorageService.to.getList(Keys.loginHistoryAccount), ['alice']);
      expect(
        history.visibleHistory(
          ['alice'],
          environment: 'pro',
          endpoint: endpoint,
        ),
        isEmpty,
      );
      expect(resolve('alice', environment: 'dev').uid, '1001');
    },
  );

  test(
    'last-session ownership stays exact after newer account login',
    () async {
      await remember('1001', 'alice');
      final alice = resolve('alice');
      expect(history.ownsLastSession(alice), isTrue);
      await remember('1002', 'bob');
      expect(history.ownsLastSession(alice), isFalse);
      expect(history.ownsLastSession(resolve('bob')), isTrue);
      await history.forget(resolve('bob'));
      expect(history.ownsLastSession(alice), isFalse);
    },
  );

  test(
    'endpoint is preserved exactly as used by existing local cache scopes',
    () async {
      await remember('1001', 'alice', api: '$endpoint/');
      expect(resolve('alice', api: '$endpoint/').endpoint, '$endpoint/');
      expect(
        () => resolve('alice'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
      expect(
        () => resolve('alice', api: 'https://example.test/other'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
    },
  );

  test(
    'corrupted identity metadata cannot authorize deletion or break history UI',
    () async {
      await StorageService.to.setString(
        LoginAccountHistoryService.storageKey,
        '{',
      );
      expect(
        () => resolve('alice'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
      expect(
        history.visibleHistory(
          ['alice'],
          environment: 'pro',
          endpoint: endpoint,
        ),
        ['alice'],
      );
      await remember('1001', 'alice');
      expect(resolve('alice').uid, '1001');
    },
  );

  test(
    'invalid registry entries cannot silently disappear during deletion',
    () async {
      await StorageService.to.setString(
        LoginAccountHistoryService.storageKey,
        jsonEncode({
          'version': 1,
          'accounts': [
            {'uid': '1001'},
          ],
        }),
      );
      expect(
        () => resolve('alice'),
        throwsA(isA<LoginAccountIdentityUnavailableException>()),
      );
    },
  );
}
