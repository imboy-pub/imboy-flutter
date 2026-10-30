import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/search/message_search_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _TestEnv implements Env {
  @override
  final String apiBaseUrl;
  _TestEnv(this.apiBaseUrl);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedHistoryStore extends InMemorySharedPreferencesStore {
  _DelayedHistoryStore() : super.empty();
  final entered = Completer<void>();
  final release = Completer<void>();
  bool delay = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (delay && key.contains('message_search_history_v2_')) {
      delay = false;
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'history is scoped to account and service and ignores legacy data',
    () async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '100',
        'message_search_history': ['legacy'],
      });
      await StorageService.init();
      final previousEnv = currentEnv;
      final previousDev = envMap['dev']!;
      final previousPro = envMap['pro']!;
      envMap['dev'] = _TestEnv('https://first.invalid');
      envMap['pro'] = _TestEnv('https://second.invalid');
      currentEnv = 'dev';
      Future<List<String>> history() async {
        final container = ProviderContainer();
        final subscription = container.listen(messageSearchProvider, (_, _) {});
        final result = container.read(messageSearchProvider).searchHistory;
        subscription.close();
        container.dispose();
        return result;
      }

      try {
        final container = ProviderContainer();
        final subscription = container.listen(messageSearchProvider, (_, _) {});
        expect(container.read(messageSearchProvider).searchHistory, isEmpty);
        final notifier = container.read(messageSearchProvider.notifier);
        await Future.wait([
          notifier.addToHistory('first'),
          notifier.addToHistory('second'),
        ]);
        expect(container.read(messageSearchProvider).searchHistory, [
          'second',
          'first',
        ]);
        subscription.close();
        container.dispose();
        expect(await history(), ['second', 'first']);
        await StorageService.to.setString(Keys.currentUid, '200');
        expect(await history(), isEmpty);
        await StorageService.to.setString(Keys.currentUid, '100');
        currentEnv = 'pro';
        expect(await history(), isEmpty);
        currentEnv = 'dev';
        expect(await history(), ['second', 'first']);
        expect(StorageService.to.getStringList('message_search_history'), [
          'legacy',
        ]);
      } finally {
        currentEnv = previousEnv;
        envMap['dev'] = previousDev;
        envMap['pro'] = previousPro;
      }
    },
  );

  test(
    'disposed session cannot restore its pending history into a new view',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = _DelayedHistoryStore();
      SharedPreferencesStorePlatform.instance = store;
      await StorageService.init();
      await StorageService.to.setString(Keys.currentUid, '100');
      final oldContainer = ProviderContainer();
      final oldSubscription = oldContainer.listen(
        messageSearchProvider,
        (_, _) {},
      );
      final pending = oldContainer
          .read(messageSearchProvider.notifier)
          .addToHistory('old');
      await store.entered.future;
      oldSubscription.close();
      oldContainer.dispose();
      final newContainer = ProviderContainer();
      final newSubscription = newContainer.listen(
        messageSearchProvider,
        (_, _) {},
      );
      try {
        expect(newContainer.read(messageSearchProvider).searchHistory, isEmpty);
        store.release.complete();
        await pending;
        await Future<void>.delayed(Duration.zero);
        expect(newContainer.read(messageSearchProvider).searchHistory, isEmpty);
      } finally {
        if (!store.release.isCompleted) store.release.complete();
        newSubscription.close();
        newContainer.dispose();
        SharedPreferences.setMockInitialValues({});
        await StorageService.init();
      }
    },
  );
}
