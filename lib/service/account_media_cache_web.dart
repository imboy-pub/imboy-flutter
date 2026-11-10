import 'package:idb_shim/idb_browser.dart';

import 'login_account_history_service.dart';

/// Inspect CrossCache's existing store without clearing its shared database.
Future<void> assertWebMediaOwnership(Set<String> registeredKeys) async {
  final database = await idbFactoryBrowser.open(
    'cross_cache_db',
    version: 1,
    onUpgradeNeeded: (event) {
      if (!event.database.objectStoreNames.contains('data')) {
        event.database.createObjectStore('data');
      }
    },
  );
  try {
    final transaction = database.transaction('data', 'readonly');
    final keys = await transaction.objectStore('data').getAllKeys();
    await transaction.completed;
    if (keys.any((key) => key is! String || !registeredKeys.contains(key))) {
      throw const AccountLocalDataOwnershipException();
    }
  } finally {
    database.close();
  }
}
