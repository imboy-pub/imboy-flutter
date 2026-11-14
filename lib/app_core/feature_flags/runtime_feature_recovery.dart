import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'app_feature_registry.dart';
import 'app_manifest_service.dart';
import 'feature_refresh_loop.dart';
import 'feature_scope.dart';
import 'feature_keys.dart';

/// One account-bound recovery pipeline for startup, network and S2C triggers.
class RuntimeFeatureRecovery {
  static FeatureRefreshLoop? _loop;
  static String? _scope;
  static int _epoch = -1;

  static Future<bool> refreshNow() {
    if (!UserRepoLocal.to.isLoggedIn || FeatureScope.key == null) {
      dispose();
      return Future.value(false);
    }
    if (_scope != FeatureScope.key || _epoch != FeatureScope.epoch) {
      dispose();
      _scope = FeatureScope.key;
      _epoch = FeatureScope.epoch;
      final scope = _scope!;
      final epoch = _epoch;
      _loop = FeatureRefreshLoop(refresh: () => _refresh(scope, epoch));
    }
    return _loop!.request();
  }

  static Future<bool> _refresh(String scope, int epoch) async {
    final flagsAccepted = await AppFeatureRegistry.refresh();
    if (!FeatureScope.matches(scope, epoch)) return false;
    final manifestAccepted = await AppManifestService.refresh();
    if (!FeatureScope.matches(scope, epoch)) return false;
    await EncryptionModeService.refresh();
    if (!FeatureScope.matches(scope, epoch)) return false;
    if (!flagsAccepted ||
        !AppFeatureRegistry.isComplete ||
        !manifestAccepted ||
        !EncryptionModeService.isInitialized) {
      return false;
    }
    if (AppFeatureRegistry.isEnabled(FeatureKeys.e2ee)) {
      await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm);
      if (!FeatureScope.matches(scope, epoch)) return false;
    }
    return true;
  }

  static void dispose() {
    _loop?.dispose();
    _loop = null;
    _scope = null;
    _epoch = -1;
  }
}
