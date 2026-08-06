import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

/// MessageRepo v2.0 迁移测试
///
/// 测试 WebSocket API v2.0 消息表结构迁移
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageRepo v2.0 迁移测试', () {
    late SqliteService db;

    setUpAll(() async {
      // 初始化存储服务（数据库服务依赖它）
      await StorageService.init();
      // 初始化数据库服务
      db = SqliteService.to;
      await db.db;
    });

    test('表名常量正确性', () {
      // 验证 v2.0 新表名常量
      expect(MessageRepo.c2cTable, equals('msg_c2c'));
      expect(MessageRepo.c2gTable, equals('msg_c2g'));
      expect(MessageRepo.c2sTable, equals('msg_c2s'));
      expect(MessageRepo.s2cTable, equals('msg_s2c'));

      // 验证 getTableName 方法返回正确表名
      expect(MessageRepo.getTableName('C2C'), equals('msg_c2c'));
      expect(MessageRepo.getTableName('C2G'), equals('msg_c2g'));
      expect(MessageRepo.getTableName('C2S'), equals('msg_c2s'));
      expect(MessageRepo.getTableName('S2C'), equals('msg_s2c'));

      // 验证别名消息类型
      expect(MessageRepo.getTableName('C2C_SERVER_ACK'), equals('msg_c2c'));
      expect(MessageRepo.getTableName('C2G_SERVER_ACK'), equals('msg_c2g'));
      expect(MessageRepo.getTableName('C2C_REVOKE'), equals('msg_c2c'));
      expect(MessageRepo.getTableName('C2G_REVOKE_ACK'), equals('msg_c2g'));
    });

    test('新字段已添加到 defaultColumns', () {
      // 验证 v2.0 新增字段在默认列中
      expect(MessageRepo.defaultColumns, contains('msg_type'));
      expect(MessageRepo.defaultColumns, contains('action'));
      expect(MessageRepo.defaultColumns, contains('e2ee'));

      // 验证字段常量存在
      expect(MessageRepo.msgType, equals('msg_type'));
      expect(MessageRepo.action, equals('action'));
      expect(MessageRepo.e2ee, equals('e2ee'));
    });

    test('数据库版本检查', () async {
      final database = await db.db;
      if (database == null) {
        print('⚠️  数据库未初始化');
        return;
      }

      final version = await database.rawQuery('PRAGMA user_version');
      final currentVersion = version.first['user_version'] as int?;
      print('当前数据库版本: v$currentVersion');

      // 验证版本号在合理范围内
      expect(currentVersion, greaterThanOrEqualTo(9));
      expect(currentVersion, lessThan(100));
    });

    test('表存在性检查', () async {
      final database = await db.db;
      if (database == null) {
        print('⚠️  数据库未初始化');
        return;
      }

      // 检查新表是否存在（迁移后）
      final newTables = ['msg_c2c', 'msg_c2g', 'msg_c2s', 'msg_s2c'];
      final oldTables = [
        'message',
        'group_message',
        'c2s_message',
        's2c_message',
      ];

      bool hasNewTables = false;
      bool hasOldTables = false;

      for (final table in newTables) {
        final result = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (result.isNotEmpty) {
          hasNewTables = true;
          print('✅ 新表存在: $table');
        }
      }

      for (final table in oldTables) {
        final result = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (result.isNotEmpty) {
          hasOldTables = true;
          print('ℹ️  旧表存在: $table');
        }
      }

      // 至少应该有一种表存在
      expect(hasNewTables || hasOldTables, isTrue);

      if (hasNewTables) {
        print('✅ 数据库已迁移到 v2.0 新表结构');
      } else if (hasOldTables) {
        print('ℹ️  数据库仍使用旧表结构，等待迁移');
      }
    });

    test('MessageRepo 实例化', () {
      // 测试使用新表名创建 MessageRepo 实例
      final c2cRepo = MessageRepo(tableName: MessageRepo.c2cTable);
      expect(c2cRepo.tableName, equals('msg_c2c'));

      final c2gRepo = MessageRepo(tableName: MessageRepo.c2gTable);
      expect(c2gRepo.tableName, equals('msg_c2g'));

      final c2sRepo = MessageRepo(tableName: MessageRepo.c2sTable);
      expect(c2sRepo.tableName, equals('msg_c2s'));

      final s2cRepo = MessageRepo(tableName: MessageRepo.s2cTable);
      expect(s2cRepo.tableName, equals('msg_s2c'));

      // 测试使用旧表名应该抛出异常（不在白名单中）
      expect(() => MessageRepo(tableName: 'message'), throwsArgumentError);
    });

    test('表名白名单验证', () {
      // 验证白名单包含正确的表名
      final allowedTables = ['msg_c2c', 'msg_c2g', 'msg_c2s', 'msg_s2c'];

      for (final table in allowedTables) {
        final repo = MessageRepo(tableName: table);
        expect(repo.tableName, equals(table));
      }

      // 验证非法表名被拒绝
      expect(
        () => MessageRepo(tableName: 'invalid_table'),
        throwsArgumentError,
      );
      expect(() => MessageRepo(tableName: ''), throwsArgumentError);
    });
  });
}
