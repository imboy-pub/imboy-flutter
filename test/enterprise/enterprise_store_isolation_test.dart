/// APP-A02 — 企业数据本地存储隔离单测
///
/// 契约（plan EB-D03/EB-D05 / amendment §2.2）：企业数据本地缓存只写
/// `enterprise_` 前缀的键/表；禁止写个人 `message`/`conversation`/好友
/// 存储。隔离是结构性保证：
/// - 键级：EnterpriseStore 所有底层键强制 `enterprise_` 前缀；
/// - 表级：EnterpriseSqfliteStore 的表名全部 `enterprise_` 前缀，
///   不存在 `message`/`conversation` 等个人表。
/// 附加断言：delivery ACK（markDelivered）不删除企业消息真源。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/modules/enterprise/public.dart';

void main() {
  group('APP-A02 内存存储隔离（EnterpriseMemoryStore）', () {
    late EnterpriseMemoryStore store;

    setUp(() {
      store = EnterpriseMemoryStore();
    });

    test('写入企业数据后：全部底层键带 enterprise_ 前缀', () async {
      await store.saveOrg(
        const EnterpriseOrg(
          id: '7266418340025468930',
          name: 'Acme Inc',
          memberStatus: EnterpriseMemberStatus.active,
        ),
      );
      await store.saveIdentity(
        const BusinessIdentity(
          id: '7266418340025468931',
          organizationId: '7266418340025468930',
          displayName: '客服甲',
          functionKey: 'customer_service',
        ),
      );
      await store.saveContact(
        const EnterpriseContact(
          id: '7266418340025468932',
          organizationId: '7266418340025468930',
          displayName: '客户乙',
        ),
      );
      await store.saveConversation(
        const EnterpriseConversation(
          id: '7266418340025468933',
          organizationId: '7266418340025468930',
          contactId: '7266418340025468932',
          businessIdentityId: '7266418340025468931',
        ),
      );
      await store.saveMessage(
        const EnterpriseMessage(
          id: '7266418340025468934',
          conversationId: '7266418340025468933',
          organizationId: '7266418340025468930',
          senderType: EnterpriseSenderType.contact,
          senderContactId: '7266418340025468932',
          content: 'hello',
        ),
      );

      final keys = store.debugKeys();
      expect(keys, isNotEmpty);
      for (final k in keys) {
        expect(k.startsWith('enterprise_'), isTrue, reason: '违规键: $k');
      }
    });

    test('负例：底层键与个人存储键空间零交集', () async {
      await store.saveMessage(
        const EnterpriseMessage(
          id: '1',
          conversationId: '2',
          organizationId: '3',
          senderType: EnterpriseSenderType.contact,
          senderContactId: '4',
          content: 'x',
        ),
      );

      // 个人域既有存储键/表名（个人 message/conversation/好友真源）
      const personalNames = <String>[
        'message',
        'conversation',
        'friend',
        'msg_c2c',
        'msg_c2g',
        'user_friend',
      ];
      final keys = store.debugKeys().toSet();
      // 键名不得等于个人名，也不得以个人名开头/包含 `:<personal>:` 段
      for (final name in personalNames) {
        expect(keys.contains(name), isFalse);
        expect(
          keys.any((k) => k.startsWith(name) && !k.startsWith('enterprise_')),
          isFalse,
        );
      }
      // 全部键都以前缀开头（结构性隔离）
      expect(keys.every((k) => k.startsWith('enterprise_')), isTrue);
    });

    test('ACK delivery-only：markDelivered 不删除企业消息真源', () async {
      const orgId = '7266418340025468930';
      const convId = '7266418340025468933';
      await store.saveMessage(
        const EnterpriseMessage(
          id: '7266418340025468934',
          conversationId: convId,
          organizationId: orgId,
          senderType: EnterpriseSenderType.contact,
          senderContactId: '7266418340025468932',
          content: 'hello',
        ),
      );

      await store.markDelivered(orgId, convId, const ['7266418340025468934']);

      final after = await store.messages(orgId, convId);
      // canonical 真源仍在：ACK 只写 delivery 状态，不删除消息
      expect(after, hasLength(1));
      expect(after.single.id, '7266418340025468934');
      expect(after.single.delivered, isTrue);
    });

    test('after_id 增量：只返回游标之后的消息', () async {
      const orgId = '7266418340025468930';
      const convId = '7266418340025468933';
      await store.saveMessage(
        const EnterpriseMessage(
          id: '100',
          conversationId: convId,
          organizationId: orgId,
          senderType: EnterpriseSenderType.contact,
          senderContactId: '4',
          content: 'm1',
        ),
      );
      await store.saveMessage(
        const EnterpriseMessage(
          id: '200',
          conversationId: convId,
          organizationId: orgId,
          senderType: EnterpriseSenderType.contact,
          senderContactId: '4',
          content: 'm2',
        ),
      );

      final all = await store.messages(orgId, convId);
      expect(all, hasLength(2));

      final incremental = await store.messages(orgId, convId, afterId: '100');
      expect(incremental.map((m) => m.id), ['200']);
    });
  });

  group('APP-A02 sqflite 薄实现隔离（EnterpriseSqfliteStore）', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
    });

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    test('建表后：sqlite_master 中企业表全部 enterprise_ 前缀，无个人表', () async {
      await EnterpriseSqfliteStore.createTables(db);

      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = rows
          .map((r) => r['name'] as String)
          .where((n) => !n.startsWith('sqlite_'))
          .toList();

      expect(names, isNotEmpty);
      expect(
        names.every((n) => n.startsWith('enterprise_')),
        isTrue,
        reason: '存在非 enterprise_ 前缀表: $names',
      );

      // 个人域既有表名不得出现
      for (final personal in const ['message', 'conversation', 'user_friend']) {
        expect(names.contains(personal), isFalse);
      }
    });

    test('写入后可读回；表清单仍保持前缀隔离', () async {
      await EnterpriseSqfliteStore.createTables(db);
      final store = EnterpriseSqfliteStore(db);

      await store.saveOrg(
        const EnterpriseOrg(
          id: '7266418340025468930',
          name: 'Acme Inc',
          memberStatus: EnterpriseMemberStatus.active,
        ),
      );
      await store.saveMessage(
        const EnterpriseMessage(
          id: '7266418340025468934',
          conversationId: '7266418340025468933',
          organizationId: '7266418340025468930',
          senderType: EnterpriseSenderType.contact,
          senderContactId: '7266418340025468932',
          content: 'hello',
        ),
      );

      final org = await store.org('7266418340025468930');
      expect(org, isNotNull);
      expect(org!.name, 'Acme Inc');

      final msgs = await store.messages(
        '7266418340025468930',
        '7266418340025468933',
      );
      expect(msgs, hasLength(1));
      expect(msgs.single.content, 'hello');

      await store.markDelivered(
        '7266418340025468930',
        '7266418340025468933',
        const ['7266418340025468934'],
      );
      final after = await store.messages(
        '7266418340025468930',
        '7266418340025468933',
      );
      expect(after.single.delivered, isTrue);

      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = rows
          .map((r) => r['name'] as String)
          .where((n) => !n.startsWith('sqlite_'))
          .toList();
      expect(names.every((n) => n.startsWith('enterprise_')), isTrue);
    });
  });
}
