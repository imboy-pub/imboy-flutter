import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/http/http_exceptions.dart' as http;
import 'package:imboy/config/const.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/migrations/manifest_all.dart';
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _FailSecondColumn implements DatabaseExecutor {
  _FailSecondColumn(this.inner);
  final DatabaseExecutor inner;
  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    if (sql.contains('ADD COLUMN workspace_id')) {
      throw StateError('injected migration failure');
    }
    return inner.execute(sql, arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) => inner.rawQuery(sql, arguments);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineApi extends ChannelApi {
  @override
  Future<ChannelModel?> getChannel(String channelId) async => null;
  @override
  Future<ChannelModel> getChannelChecked(String channelId) async =>
      throw http.NetworkException(message: 'offline');
  @override
  Future<ChannelPageResult<ChannelMessageModel>> getMessagesPage({
    required String channelId,
    String? cursor,
    int limit = 20,
  }) async =>
      const ChannelPageResult(list: [], nextCursor: null, hasMore: false);
}

ChannelModel _channel(int id, String? scope, String? workspaceId) =>
    ChannelModel(
      id: id,
      scope: scope,
      workspaceId: workspaceId,
      name: 'fixture-$id',
      creatorId: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await MigrationService.to.init();
  });

  test('v37 中途失败时回滚首列和数据库版本', () async {
    final db = await openFixtureDatabaseAtVersion(version: 36);
    addTearDown(db.close);
    await expectLater(
      db.transaction((txn) async {
        final result = await MigrationService.to.migrate(
          db: _FailSecondColumn(txn),
          fromVersion: 36,
          toVersion: 37,
          isUpgrade: true,
        );
        if (!result.success) throw StateError(result.error!);
      }),
      throwsStateError,
    );
    final columns = (await db.rawQuery('PRAGMA table_info(channel)'))
        .map((row) => row['name'])
        .toSet();
    expect(columns, isNot(contains('scope')));
    expect(columns, isNot(contains('workspace_id')));
    expect(await db.getVersion(), 36);
  });

  test('v36 升级保留未知来源并支持权威来源往返', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, 'scope-test');
    final db = await openFixtureDatabaseAtVersion(version: 36);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    await db.insert('channel', {
      'id': 10,
      'name': 'old',
      'creator_id': 1,
      'created_at': 1,
      'updated_at': 1,
    });
    await db.transaction((txn) async {
      final result = await MigrationService.to.migrate(
        db: txn,
        fromVersion: 36,
        toVersion: 37,
        isUpgrade: true,
      );
      if (!result.success) throw StateError(result.error!);
    });
    expect(await db.getVersion(), 37);
    expect(await SchemaContract.verifyInvariants(db, version: 37), isEmpty);
    final old = (await db.query(
      'channel',
      where: 'id = ?',
      whereArgs: [10],
    )).single;
    expect(old['scope'], isNull);
    expect(old['workspace_id'], isNull);
    SqliteService.setDbForTest(db);
    final repo = ChannelRepo();
    await repo.saveChannel(_channel(11, 'personal', null));
    await repo.saveChannel(_channel(12, 'workspace', '9223372036854775807'));
    expect((await repo.getChannel('11'))?.scope, 'personal');
    expect((await repo.getChannel('12'))?.workspaceId, '9223372036854775807');
    await repo.saveChannel(_channel(11, null, null));
    expect((await repo.getChannel('11'))?.scope, 'personal');
    expect(kMigrationManifest.edge(37, 36), isNull);
    final api = _OfflineApi();
    final service = ChannelService.forTest(
      api: api,
      repo: repo,
      bindPublishDatabase: true,
    );
    final container = ProviderContainer(
      overrides: [
        channelApiProvider.overrideWithValue(api),
        channelServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(channelDetailProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(channelDetailProvider.notifier).loadChannel('11');
    expect(container.read(channelDetailProvider).channel?.scope, 'personal');
    expect(container.read(channelDetailProvider).channel?.id, 11);
  });
}
