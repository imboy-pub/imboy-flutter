part of 'init.dart';

/// 群成员关系自愈核心逻辑（自 init.dart 抽出，行为与调用方零变更）
Future<Map<String, int>> _runGroupMembershipSelfHeal({
  bool force = false,
  String source = 'internal',
}) async {
  if (!UserRepoLocal.to.isLoggedIn) {
    return {'skipped': 1, 'errors': 0, 'reason': 401};
  }
  final uid = UserRepoLocal.to.currentUid;
  if (uid.isEmpty) {
    return {'skipped': 1, 'errors': 0, 'reason': 400};
  }

  final connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult.contains(ConnectivityResult.none)) {
    AppLogger.info(
      'Group membership self-heal skipped (offline), source=$source',
    );
    return {'skipped': 1, 'errors': 0, 'reason': 0};
  }

  final dayMark = DateTime.now().toIso8601String().split('T').first;
  final markerKey = '${Keys.groupMembershipSelfHealPrefix}_${currentEnv}_$uid';
  final lastMark = StorageService.to.getString(markerKey);
  if (!force && lastMark == dayMark) {
    AppLogger.info(
      'Group membership self-heal skipped (already done today), source=$source',
    );
    return {'skipped': 1, 'errors': 0, 'reason': 1};
  }

  try {
    final result = await GroupListService().selfHealMembershipShadows();
    final errors = result['errors'] ?? 0;
    final groupRows = result['groupRows'] ?? 0;
    final ownerRows = result['ownerRows'] ?? 0;
    final joinRows = result['joinRows'] ?? 0;
    final managerRows = result['managerRows'] ?? 0;
    final beforeOwner = result['beforeOwner'] ?? 0;
    final beforeJoin = result['beforeJoin'] ?? 0;
    final beforeManager = result['beforeManager'] ?? 0;
    final afterOwner = result['afterOwner'] ?? 0;
    final afterJoin = result['afterJoin'] ?? 0;
    final afterManager = result['afterManager'] ?? 0;
    final deltaOwner = result['deltaOwner'] ?? 0;
    final deltaJoin = result['deltaJoin'] ?? 0;
    final deltaManager = result['deltaManager'] ?? 0;
    if (errors == 0) {
      await StorageService.to.setString(markerKey, dayMark);
    }
    AppLogger.info(
      'Group membership self-heal done: '
      'groupRows=$groupRows, ownerRows=$ownerRows, joinRows=$joinRows, '
      'managerRows=$managerRows, '
      'before(owner/join/manager)=($beforeOwner/$beforeJoin/$beforeManager), '
      'after(owner/join/manager)=($afterOwner/$afterJoin/$afterManager), '
      'delta(owner/join/manager)=($deltaOwner/$deltaJoin/$deltaManager), '
      'errors=$errors, source=$source',
    );
    return result;
  } on Exception catch (e) {
    AppLogger.warning('Group membership self-heal failed: ${e.runtimeType}');
    return {'skipped': 0, 'errors': 1, 'reason': 500};
  }
}
