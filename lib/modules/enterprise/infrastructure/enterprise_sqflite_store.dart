/// 企业存储 sqflite 薄实现（amendment §1 owned path / plan EB-D05）
///
/// 设计：只做"表 + 行"的最薄映射，构造时注入 [Database]（生产由
/// SqliteService 主库提供，测试可注入 ffi 内存库），不自行开库、不注册
/// 迁移清单——企业表与个人表物理同库但表名严格 `enterprise_` 前缀
/// （APP-A02 表级隔离）。
///
/// ACK 语义落点：[markDelivered] 只 UPDATE delivery 标记列，永不
/// DELETE（真源不删，plan EB-D05 delivery-only 契约）。
library;

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/component/helper/datetime.dart' show ApiTime;
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 企业表 DDL（表名全部 `enterprise_` 前缀——表级隔离的唯一定义点）。
const List<String> kEnterpriseTableDdl = <String>[
  '''
  CREATE TABLE IF NOT EXISTS enterprise_org (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    member_status TEXT NOT NULL DEFAULT 'active',
    default_workspace_id TEXT NOT NULL DEFAULT ''
  )''',
  '''
  CREATE TABLE IF NOT EXISTS enterprise_identity (
    organization_id TEXT NOT NULL,
    id TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    function_key TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'active',
    PRIMARY KEY (organization_id, id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS enterprise_contact (
    organization_id TEXT NOT NULL,
    id TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    user_id TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (organization_id, id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS enterprise_conversation (
    organization_id TEXT NOT NULL,
    id TEXT NOT NULL,
    contact_id TEXT NOT NULL DEFAULT '',
    business_identity_id TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (organization_id, id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS enterprise_message (
    organization_id TEXT NOT NULL,
    conversation_id TEXT NOT NULL,
    id TEXT NOT NULL,
    sender_type TEXT NOT NULL DEFAULT 'contact',
    sender_contact_id TEXT NOT NULL DEFAULT '',
    sender_business_identity_id TEXT NOT NULL DEFAULT '',
    sender_business_identity_name TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    asset_id TEXT NOT NULL DEFAULT '',
    retain_until TEXT NOT NULL DEFAULT '',
    policy_snapshot TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT '',
    delivered INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (organization_id, conversation_id, id)
  )''',
];

/// 在给定库上创建企业表（幂等）。
Future<void> createEnterpriseTables(DatabaseExecutor db) async {
  for (final ddl in kEnterpriseTableDdl) {
    await db.execute(ddl);
  }
}

/// R08-FL 时间列编码/解码（DB 新写与旧读兼容，不迁 schema）。
///
/// `enterprise_message.created_at / retain_until` 为 TEXT 列，历史上写入的是
/// **wire 原样字符串化的 epoch 秒**（旧模型 `parseModelString(json['created_at'])`
/// 直通落库，来源已知）。R08 起模型持有 epoch 毫秒，新写改存**带时区的
/// RFC3339 字符串**（UTC `toIso8601String`，毫秒精度），读回按**形态**分流：
///
/// 1. 带 zone 的 RFC3339 → [ApiTime.parseIsoZoned]（新写形态，直取毫秒）；
/// 2. 纯数字字符串 → [ApiTime.parseEpochSeconds]（旧形态，**已知来源是秒**，
///    ×1000 归一为毫秒——不是按位数猜任意字段，是该列唯一历史来源）；
/// 3. 空/其他 → 0（未知）。
///
/// 往返不双乘：读→模型（毫秒）→再写（RFC3339）→再读走分支 1，值稳定；
/// 旧行首次读出即归一为毫秒，后续被覆写后收敛到新形态。
String encodeEpochMsColumn(int millis) {
  if (millis <= 0) return '';
  return DateTime.fromMillisecondsSinceEpoch(
    millis,
    isUtc: true,
  ).toIso8601String();
}

int decodeEpochMsColumn(dynamic raw) {
  if (raw is String) {
    final iso = ApiTime.parseIsoZoned(raw);
    if (iso != null) return iso.millisecondsSinceEpoch;
    return ApiTime.parseEpochSeconds(raw) ?? 0;
  }
  if (raw is int) return ApiTime.parseEpochMillis(raw) ?? 0;
  return 0;
}

/// 企业存储 sqflite 薄实现。
class EnterpriseSqfliteStore implements EnterpriseStore {
  final DatabaseExecutor db;

  EnterpriseSqfliteStore(this.db);

  /// 兼容旧名：等价 [createEnterpriseTables]。
  static Future<void> createTables(DatabaseExecutor db) =>
      createEnterpriseTables(db);

  @override
  Future<void> saveOrg(EnterpriseOrg org) async {
    await db.insert('enterprise_org', {
      'id': org.id,
      'name': org.name,
      'member_status': org.memberStatus.wireName,
      'default_workspace_id': org.defaultWorkspaceId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<EnterpriseOrg?> org(EntityId id) async {
    final rows = await db.query(
      'enterprise_org',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return EnterpriseOrg.fromJson(rows.first);
  }

  @override
  Future<List<EnterpriseOrg>> orgs() async {
    final rows = await db.query('enterprise_org');
    return rows.map(EnterpriseOrg.fromJson).toList(growable: false);
  }

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    await db.insert('enterprise_identity', {
      'organization_id': identity.organizationId,
      'id': identity.id,
      'display_name': identity.displayName,
      'function_key': identity.functionKey,
      'status': identity.status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<BusinessIdentity>> identities(EntityId orgId) async {
    final rows = await db.query(
      'enterprise_identity',
      where: 'organization_id = ?',
      whereArgs: [orgId],
    );
    return rows.map(BusinessIdentity.fromJson).toList(growable: false);
  }

  @override
  Future<void> saveContact(EnterpriseContact contact) async {
    await db.insert('enterprise_contact', {
      'organization_id': contact.organizationId,
      'id': contact.id,
      'display_name': contact.displayName,
      'user_id': contact.userId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<EnterpriseContact>> contacts(EntityId orgId) async {
    final rows = await db.query(
      'enterprise_contact',
      where: 'organization_id = ?',
      whereArgs: [orgId],
    );
    return rows.map(EnterpriseContact.fromJson).toList(growable: false);
  }

  @override
  Future<void> saveConversation(EnterpriseConversation conversation) async {
    await db.insert('enterprise_conversation', {
      'organization_id': conversation.organizationId,
      'id': conversation.id,
      'contact_id': conversation.contactId,
      'business_identity_id': conversation.businessIdentityId,
      'updated_at': conversation.updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<EnterpriseConversation>> conversations(EntityId orgId) async {
    final rows = await db.query(
      'enterprise_conversation',
      where: 'organization_id = ?',
      whereArgs: [orgId],
    );
    return rows.map(EnterpriseConversation.fromJson).toList(growable: false);
  }

  @override
  Future<void> saveMessage(EnterpriseMessage message) async {
    await db.insert('enterprise_message', {
      'organization_id': message.organizationId,
      'conversation_id': message.conversationId,
      'id': message.id,
      'sender_type': message.senderType.wireName,
      'sender_contact_id': message.senderContactId,
      'sender_business_identity_id': message.senderBusinessIdentityId,
      'sender_business_identity_name': message.senderBusinessIdentityName,
      'content': message.content,
      'asset_id': message.assetId,
      'retain_until': encodeEpochMsColumn(message.retainUntilMs),
      'policy_snapshot': message.policySnapshot,
      'created_at': encodeEpochMsColumn(message.createdAtMs),
      'delivered': message.delivered ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<EnterpriseMessage>> messages(
    EntityId orgId,
    EntityId conversationId, {
    EntityId afterId = '',
  }) async {
    final rows = afterId.isEmpty
        ? await db.query(
            'enterprise_message',
            where: 'organization_id = ? AND conversation_id = ?',
            whereArgs: [orgId, conversationId],
            orderBy: 'id ASC',
          )
        : await db.query(
            'enterprise_message',
            where: 'organization_id = ? AND conversation_id = ? AND id > ?',
            whereArgs: [orgId, conversationId, afterId],
            orderBy: 'id ASC',
          );
    return rows.map(_messageFromRow).toList(growable: false);
  }

  @override
  Future<void> markDelivered(
    EntityId orgId,
    EntityId conversationId,
    List<EntityId> messageIds,
  ) async {
    // delivery-only：仅 UPDATE 标记列，禁止 DELETE
    await db.update(
      'enterprise_message',
      {'delivered': 1},
      where:
          'organization_id = ? AND conversation_id = ? AND id IN (${messageIds.map((_) => '?').join(',')})',
      whereArgs: [orgId, conversationId, ...messageIds],
    );
  }

  @override
  Future<void> clear() async {
    for (final ddl in kEnterpriseTableDdl) {
      final table = RegExp(r'CREATE TABLE IF NOT EXISTS (\S+)')
          .firstMatch(ddl)
          ?.group(1);
      if (table != null) {
        await db.delete(table);
      }
    }
  }

  @override
  Iterable<String> debugKeys() {
    // sqflite 实现的"键"即表名（全部 enterprise_ 前缀），供审计断言复用。
    return kEnterpriseTableDdl
        .map(
          (ddl) =>
              RegExp(r'CREATE TABLE IF NOT EXISTS (\S+)')
                  .firstMatch(ddl)
                  ?.group(1),
        )
        .whereType<String>();
  }

  static EnterpriseMessage _messageFromRow(Map<String, Object?> row) {
    return EnterpriseMessage(
      id: entityIdOf(row['id']),
      conversationId: entityIdOf(row['conversation_id']),
      organizationId: entityIdOf(row['organization_id']),
      senderType: EnterpriseSenderType.parse(row['sender_type']),
      senderContactId: parseModelString(row['sender_contact_id']),
      senderBusinessIdentityId: parseModelString(
        row['sender_business_identity_id'],
      ),
      senderBusinessIdentityName: parseModelString(
        row['sender_business_identity_name'],
      ),
      content: parseModelString(row['content']),
      assetId: parseModelString(row['asset_id']),
      retainUntilMs: decodeEpochMsColumn(row['retain_until']),
      policySnapshot: parseModelString(row['policy_snapshot']),
      createdAtMs: decodeEpochMsColumn(row['created_at']),
      delivered: parseModelInt(row['delivered']) == 1,
    );
  }
}
