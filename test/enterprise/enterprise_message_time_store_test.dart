/// R08-FL — 企业消息时间列 DB 往返（新写 + 旧读兼容）。
///
/// `enterprise_message.created_at / retain_until`（TEXT 列，不迁 schema）：
/// - **新写**：zoned RFC3339（UTC toIso8601String，毫秒精度）；
/// - **旧读**：历史行是 wire 原样字符串化的 **epoch 秒**（已知来源），
///   读时 ×1000 归一为毫秒——按形态分流（RFC3339 vs 纯数字），不是位数猜测；
/// - **往返一致**：读→写→读不双乘、不断值。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/modules/enterprise/public.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('encodeEpochMsColumn / decodeEpochMsColumn', () {
    test('新形态往返：毫秒 → RFC3339 → 毫秒，值稳定不双乘', () {
      const millis = 1789600000000; // 计划 6.1 T1 = 2026-09-16T23:06:40Z
      final encoded = encodeEpochMsColumn(millis);
      expect(encoded, '2026-09-16T23:06:40.000Z');
      expect(decodeEpochMsColumn(encoded), millis);
      // 二次往返（读→写→读）仍不双乘。
      expect(decodeEpochMsColumn(encodeEpochMsColumn(millis)), millis);
    });

    test('旧形态读：秒数字字符串（已知历史来源）×1000 归一', () {
      expect(decodeEpochMsColumn('1789600000'), 1789600000000);
      expect(decodeEpochMsColumn('0'), 0);
      expect(decodeEpochMsColumn(''), 0);
      expect(decodeEpochMsColumn(null), 0);
      expect(decodeEpochMsColumn('garbage'), 0);
    });

    test('旧行归一后覆写收敛：秒 → 毫秒 → RFC3339，再读走新形态', () {
      final normalized = decodeEpochMsColumn('1789600000');
      expect(normalized, 1789600000000);
      final rewritten = encodeEpochMsColumn(normalized);
      expect(rewritten, startsWith('2026-09-16T23:06:40'));
      expect(decodeEpochMsColumn(rewritten), 1789600000000);
    });

    test('0/未知编码为空串（不出站哨兵）', () {
      expect(encodeEpochMsColumn(0), '');
      expect(decodeEpochMsColumn(''), 0);
    });
  });

  group('EnterpriseSqfliteStore 消息时间往返', () {
    late Database db;
    late EnterpriseSqfliteStore store;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await EnterpriseSqfliteStore.createTables(db);
      store = EnterpriseSqfliteStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('新写→读回：模型毫秒经 RFC3339 落库，读回同值（R08-3 往返）', () async {
      await store.saveMessage(
        EnterpriseMessage.fromJson(const {
          'id': 7266418340025468934,
          'conversation_id': 7266418340025468933,
          'organization_id': 7266418340025468930,
          'sender_type': 'contact',
          'sender_contact_id': 7266418340025468932,
          'body': 'hello',
          'created_at': 1789600000, // wire 秒
          'retain_until': 2000000000,
        }),
      );
      final msgs = await store.messages(
        '7266418340025468930',
        '7266418340025468933',
      );
      expect(msgs.single.createdAtMs, 1789600000000);
      expect(msgs.single.retainUntilMs, 2000000000000);

      // 读回的对象再写一次（模拟 ACK/投影覆写），往返不双乘不断值。
      await store.saveMessage(msgs.single);
      final again = await store.messages(
        '7266418340025468930',
        '7266418340025468933',
      );
      expect(again.single.createdAtMs, 1789600000000);
      expect(again.single.retainUntilMs, 2000000000000);
    });

    test('旧读兼容：直插历史秒数字字符串行，读出为正确毫秒', () async {
      // 模拟 R08 之前的行：store 原样写 parseModelString(wire int 秒) 的结果。
      await db.insert('enterprise_message', {
        'organization_id': '7266418340025468930',
        'conversation_id': '7266418340025468933',
        'id': '7266418340025468934',
        'sender_type': 'contact',
        'sender_contact_id': '7266418340025468932',
        'sender_business_identity_id': '',
        'sender_business_identity_name': '',
        'content': 'legacy row',
        'asset_id': '',
        'retain_until': '2000000000',
        'policy_snapshot': '',
        'created_at': '1789600000',
        'delivered': 0,
      });
      final msgs = await store.messages(
        '7266418340025468930',
        '7266418340025468933',
      );
      expect(msgs.single.createdAtMs, 1789600000000, reason: '旧秒行 ×1000 一次');
      expect(msgs.single.retainUntilMs, 2000000000000);
      expect(msgs.single.content, 'legacy row');

      // 旧行经读→写后收敛为 RFC3339 新形态，再读不双乘。
      await store.saveMessage(msgs.single);
      final rawRow = await db.query(
        'enterprise_message',
        where: 'id = ?',
        whereArgs: ['7266418340025468934'],
        limit: 1,
      );
      expect(
        rawRow.single['created_at'] as String,
        startsWith('2026-09-16T23:06:40'),
        reason: '覆写后收敛为 RFC3339 新形态',
      );
      final reread = await store.messages(
        '7266418340025468930',
        '7266418340025468933',
      );
      expect(reread.single.createdAtMs, 1789600000000);
    });

    test('旧行与新行混读：各自正确，互不污染', () async {
      await db.insert('enterprise_message', {
        'organization_id': '1',
        'conversation_id': '2',
        'id': 'legacy',
        'sender_type': 'contact',
        'content': 'old',
        'created_at': '1789600000', // 旧形态秒
        'delivered': 0,
      });
      await store.saveMessage(
        EnterpriseMessage.fromJson(const {
          'id': 99,
          'conversation_id': 2,
          'organization_id': 1,
          'sender_type': 'contact',
          'body': 'new',
          'created_at': 1789600000, // 同一瞬间，wire 秒
        }),
      );
      final msgs = await store.messages('1', '2');
      expect(msgs, hasLength(2));
      expect(
        msgs.every((m) => m.createdAtMs == 1789600000000),
        isTrue,
        reason: '新旧形态读出同一瞬间，均不双乘',
      );
    });
  });
}
