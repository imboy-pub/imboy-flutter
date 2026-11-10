import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';

class _HistoryNotifier extends PassportNotifier {
  @override
  PassportState build() {
    final controller = TextEditingController();
    ref.onDispose(controller.dispose);
    return PassportState(loginAccountCtl: controller);
  }
}

ProviderContainer _historyContainer() {
  final container = ProviderContainer(
    overrides: [passportProvider.overrideWith(_HistoryNotifier.new)],
  );
  container.listen(passportProvider, (_, _) {});
  return container;
}

void main() {
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    container = _historyContainer();
  });
  tearDown(() => container.dispose());

  test('repeated saved login moves one account to the front and survives rereading', () async {
    final notifier = container.read(passportProvider.notifier);
    await notifier.saveHistory('account', 'alice');
    await notifier.saveHistory('account', 'bob');
    await notifier.saveHistory('account', 'alice');
    await notifier.saveHistory('email', 'alice@example.test');
    await notifier.saveHistory('email', 'alice@example.test');

    expect(container.read(passportProvider).accountHistory, ['alice', 'bob']);
    expect(StorageService.to.getList(Keys.loginHistoryAccount), [
      'alice',
      'bob',
    ]);
    expect(StorageService.to.getList(Keys.loginHistoryEmail), [
      'alice@example.test',
    ]);

    container.dispose();
    await StorageService.init();
    container = _historyContainer();
    container.read(passportProvider.notifier).initLoginHistory();
    expect(container.read(passportProvider).accountHistory, ['alice', 'bob']);
    expect(container.read(passportProvider).emailHistory, [
      'alice@example.test',
    ]);
  });

  test(
    'history limit preserves other deployments and deduplicates legacy entries',
    () async {
      await LoginAccountHistoryService().rememberLogin(
        account: 'remote-user',
        profile: {'user_id': 'synthetic-other-uid'},
        environment: 'synthetic-other-environment',
        endpoint: Env().apiBaseUrl,
      );
      await StorageService.to.setList(Keys.loginHistoryAccount, [
        'alice',
        'remote-user',
        'bob',
        'alice',
        'carol',
        'dave',
        'erin',
        'frank',
      ]);
      final notifier = container.read(passportProvider.notifier);
      notifier.initLoginHistory();
      await notifier.saveHistory('account', 'bob');

      expect(container.read(passportProvider).accountHistory, [
        'bob',
        'alice',
        'carol',
        'dave',
        'erin',
      ]);
      expect(StorageService.to.getList(Keys.loginHistoryAccount), [
        'bob',
        'alice',
        'carol',
        'dave',
        'erin',
        'remote-user',
      ]);
    },
  );

  test(
    'damaged ownership metadata does not reintroduce duplicate history',
    () async {
      await StorageService.to.setString(
        LoginAccountHistoryService.storageKey,
        '{',
      );
      await StorageService.to.setList(Keys.loginHistoryAccount, [
        'alice',
        'bob',
        'alice',
      ]);
      final notifier = container.read(passportProvider.notifier);
      notifier.initLoginHistory();
      expect(container.read(passportProvider).accountHistory, ['alice', 'bob']);
      await notifier.saveHistory('account', 'alice');
      expect(StorageService.to.getList(Keys.loginHistoryAccount), [
        'alice',
        'bob',
      ]);
    },
  );
}
