import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// MessageRepo v2.0 简单测试
///
/// 测试 WebSocket API v2.0 消息表结构常量和方法
/// 不依赖数据库，可快速验证代码更改
void main() {
  group('MessageRepo v2.0 基本测试', () {
    test('表名常量正确性', () {
      // 验证 v2.0 新表名常量
      expect(MessageRepo.c2cTable, equals('msg_c2c'));
      expect(MessageRepo.c2gTable, equals('msg_c2g'));
      expect(MessageRepo.c2sTable, equals('msg_c2s'));
      expect(MessageRepo.s2cTable, equals('msg_s2c'));

      print('✅ 表名常量正确:');
      print('  - C2C: ${MessageRepo.c2cTable}');
      print('  - C2G: ${MessageRepo.c2gTable}');
      print('  - C2S: ${MessageRepo.c2sTable}');
      print('  - S2C: ${MessageRepo.s2cTable}');
    });

    test('getTableName 方法正确性', () {
      // 验证 getTableName 方法返回正确表名
      expect(MessageRepo.getTableName('C2C'), equals('msg_c2c'));
      expect(MessageRepo.getTableName('C2G'), equals('msg_c2g'));
      expect(MessageRepo.getTableName('C2S'), equals('msg_c2s'));
      expect(MessageRepo.getTableName('S2C'), equals('msg_s2c'));

      // 验证别名消息类型
      expect(MessageRepo.getTableName('C2C_SERVER_ACK'), equals('msg_c2c'));
      expect(MessageRepo.getTableName('C2G_SERVER_ACK'), equals('msg_c2g'));
      expect(MessageRepo.getTableName('C2S_SERVER_ACK'), equals('msg_c2s'));
      expect(MessageRepo.getTableName('S2C_SERVER_ACK'), equals('msg_s2c'));

      // 验证撤回消息类型
      expect(MessageRepo.getTableName('C2C_REVOKE'), equals('msg_c2c'));
      expect(MessageRepo.getTableName('C2G_REVOKE'), equals('msg_c2g'));
      expect(MessageRepo.getTableName('C2C_REVOKE_ACK'), equals('msg_c2c'));
      expect(MessageRepo.getTableName('C2G_REVOKE_ACK'), equals('msg_c2g'));

      print('✅ getTableName 方法正确映射所有消息类型');
    });

    test('新字段常量正确性', () {
      // 验证 v2.0 新增字段常量
      expect(MessageRepo.msgType, equals('msg_type'));
      expect(MessageRepo.action, equals('action'));
      expect(MessageRepo.e2ee, equals('e2ee'));

      print('✅ 新字段常量正确:');
      print('  - msg_type: ${MessageRepo.msgType}');
      print('  - action: ${MessageRepo.action}');
      print('  - e2ee: ${MessageRepo.e2ee}');
    });

    test('新字段已添加到 defaultColumns', () {
      // 验证 v2.0 新增字段在默认列中
      expect(MessageRepo.defaultColumns, contains('msg_type'));
      expect(MessageRepo.defaultColumns, contains('action'));
      expect(MessageRepo.defaultColumns, contains('e2ee'));

      // 验证 defaultColumns 包含所有必需字段
      expect(
        MessageRepo.defaultColumns,
        containsAll([
          'auto_id',
          'id',
          'type',
          'from_id',
          'to_id',
          'payload',
          'created_at',
          'is_author',
          'status',
          'conversation_uk3',
          'topic_id',
          'msg_type',
          'action',
          'e2ee',
        ]),
      );

      print('✅ defaultColumns 包含所有字段，共 ${MessageRepo.defaultColumns.length} 个');
      print('  字段列表: ${MessageRepo.defaultColumns.join(", ")}');
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

      print('✅ MessageRepo 可以使用新表名创建实例');

      // 测试使用旧表名应该抛出异常（不在白名单中）
      expect(
        () => MessageRepo(tableName: 'message'),
        throwsArgumentError,
      );

      expect(
        () => MessageRepo(tableName: 'group_message'),
        throwsArgumentError,
      );

      expect(
        () => MessageRepo(tableName: 'invalid_table'),
        throwsArgumentError,
      );

      print('✅ 旧表名和非法表名被正确拒绝');
    });

    test('字段常量一致性', () {
      // 验证所有字段常量有正确的值
      expect(MessageRepo.autoId, equals('auto_id'));
      expect(MessageRepo.id, equals('id'));
      expect(MessageRepo.type, equals('type'));
      expect(MessageRepo.from, equals('from_id'));
      expect(MessageRepo.to, equals('to_id'));
      expect(MessageRepo.payload, equals('payload'));
      expect(MessageRepo.createdAt, equals('created_at'));
      expect(MessageRepo.conversationUk3, equals('conversation_uk3'));
      expect(MessageRepo.status, equals('status'));
      expect(MessageRepo.isAuthor, equals('is_author'));
      expect(MessageRepo.topicId, equals('topic_id'));

      print('✅ 所有字段常量定义正确');
    });

    test('v2.0 迁移总结', () {
      print('\n📊 MessageRepo v2.0 迁移总结:');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ 表名常量已更新为 v2.0 规范');
      print('✅ getTableName 方法支持所有消息类型');
      print('✅ 新增字段: msg_type, action, e2ee');
      print('✅ defaultColumns 已包含新字段');
      print('✅ 表名白名单验证机制正常');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // 最终验证
      expect(MessageRepo.c2cTable, equals('msg_c2c'));
      expect(MessageRepo.defaultColumns, contains('msg_type'));
      expect(MessageRepo.defaultColumns, contains('action'));
      expect(MessageRepo.defaultColumns, contains('e2ee'));
    });
  });
}
