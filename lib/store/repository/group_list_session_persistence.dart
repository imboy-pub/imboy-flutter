import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// The captured session or its environment is no longer authoritative.
class GroupListSessionCancelled implements Exception {
  const GroupListSessionCancelled();
}

typedef GroupListSelfProfile = ({
  String nickname,
  String avatar,
  String sign,
  String account,
});

/// One list/self-heal operation, bound to its original identity and database.
class GroupListSessionPersistence {
  GroupListSessionPersistence._(
    this.session,
    this.environment,
    this.endpoint,
    this._profile,
    this._reader,
    this._environmentNow,
    this._endpointNow,
    this._database,
    this._currentDatabase,
  );

  final AuthSessionScope session;
  final String environment;
  final String endpoint;
  final GroupListSelfProfile _profile;
  final AuthSessionReader _reader;
  final String Function() _environmentNow;
  final String Function() _endpointNow;
  final Database _database;
  final Future<Database?> Function() _currentDatabase;

  /// Call before the first network request and reuse for the entire operation.
  /// Overrides are only for deterministic tests; production uses the app state.
  static Future<GroupListSessionPersistence> bind({
    @visibleForTesting AuthSessionReader? reader,
    @visibleForTesting String Function()? environmentNow,
    @visibleForTesting String Function()? endpointNow,
    @visibleForTesting Future<Database?> Function()? database,
    @visibleForTesting GroupListSelfProfile Function()? selfProfile,
  }) async {
    final auth = reader ?? authSessionReader;
    final env = environmentNow ?? () => currentEnv;
    final api = endpointNow ?? () => Env().apiBaseUrl;
    final scope = auth.current;
    final capturedEnv = env();
    final capturedEndpoint = api();

    void check() {
      if (scope.uid.isEmpty ||
          scope.transitioning ||
          !auth.isCurrent(scope) ||
          env() != capturedEnv ||
          api() != capturedEndpoint) {
        throw const GroupListSessionCancelled();
      }
    }

    check();
    final profile = selfProfile?.call() ?? _currentProfile();
    check();
    Database? db;
    try {
      db = await (database ?? () => SqliteService.to.db)();
    } catch (_) {
      check();
      rethrow;
    }
    check();
    if (db == null || !db.isOpen) {
      throw StateError('Group list database unavailable');
    }
    return GroupListSessionPersistence._(
      scope,
      capturedEnv,
      capturedEndpoint,
      profile,
      auth,
      env,
      api,
      db,
      database ?? () => SqliteService.to.db,
    );
  }

  static GroupListSelfProfile _currentProfile() {
    final user = UserRepoLocal.to.current;
    return (
      nickname: user.nickname,
      avatar: user.avatar,
      sign: user.sign,
      account: user.account,
    );
  }

  /// Call after each network await as well as before publishing results.
  void checkCurrent() {
    if (session.uid.isEmpty ||
        session.transitioning ||
        !_reader.isCurrent(session) ||
        _environmentNow() != environment ||
        _endpointNow() != endpoint) {
      throw const GroupListSessionCancelled();
    }
  }

  /// Saves a group and its self-membership shadow atomically on the bound DB.
  /// Invalidation observed inside the callback throws and rolls back. A change
  /// after the last check but before native commit cannot be cancelled here;
  /// the fixed database still prevents a write to the next account's database.
  Future<GroupModel> saveGroup(
    Map<String, dynamic> json, {
    required String attr,
  }) async {
    checkCurrent();
    GroupModel result;
    try {
      result = await _database.transaction((txn) async {
        checkCurrent();
        final group = await GroupRepo().save(
          '',
          json,
          txn: txn,
          checkSession: checkCurrent,
        );
        checkCurrent();
        await _syncSelfMembership(txn, group, attr);
        checkCurrent();
        return group;
      });
    } catch (_) {
      checkCurrent();
      rethrow;
    }
    checkCurrent();
    // The cache is shared and invalidation is not database-scoped. Never
    // clear another session's entries after a database/session switch.
    Database? currentDb;
    try {
      currentDb = await _currentDatabase();
    } catch (_) {
      checkCurrent();
      rethrow;
    }
    checkCurrent();
    if (identical(currentDb, _database)) {
      SqliteService.to.clearQueryCache(GroupRepo.tableName);
      SqliteService.to.clearQueryCache(GroupMemberRepo.tableName);
    }
    return result;
  }

  Future<void> _syncSelfMembership(
    Transaction txn,
    GroupModel group,
    String attr,
  ) async {
    if (group.groupId == '0') return;
    final repo = GroupMemberRepo();
    final uid = session.uid;
    final existing = await repo.findByUserId(group.groupId, uid, txn: txn);
    checkCurrent();
    final isOwner = group.ownerUid == uid;
    if (existing != null) {
      final patch = <String, dynamic>{};
      if (existing.status != 1) patch[GroupMemberRepo.status] = 1;
      if (isOwner) {
        if (existing.role < 4) patch[GroupMemberRepo.role] = 4;
        if (existing.isJoin != 0) patch[GroupMemberRepo.isJoin] = 0;
      } else {
        if (attr == 'manager' && existing.role < 3) {
          patch[GroupMemberRepo.role] = 3;
        }
        if (existing.isJoin != 1) patch[GroupMemberRepo.isJoin] = 1;
      }
      if (patch.isNotEmpty) {
        await repo.update(group.groupId, uid, patch, txn: txn);
        checkCurrent();
      }
      return;
    }
    final now = DateTimeHelper.millisecond();
    await repo.insert(
      GroupMemberModel(
        id: null,
        groupId: group.groupId,
        userId: uid,
        nickname: _profile.nickname,
        avatar: _profile.avatar,
        sign: _profile.sign,
        account: _profile.account,
        alias: '',
        role: isOwner ? 4 : (attr == 'manager' ? 3 : 1),
        isJoin: isOwner ? 0 : 1,
        joinMode: 'page_sync_$attr',
        status: 1,
        updatedAt: now,
        createdAt: now,
      ),
      txn: txn,
    );
    checkCurrent();
  }
}
