/// 企业本地存储抽象（amendment §2.2 / plan EB-D03~D05）
///
/// 隔离契约（APP-A02）：所有底层键/表强制 `enterprise_` 前缀；禁止写
/// 个人 `message`/`conversation`/好友存储。前缀由本抽象统一拼接，实现
/// 不得接受裸键名。
///
/// ACK 语义落点（plan EB-D05）：[markDelivered] 只写本地 delivery 标记，
/// 绝不删除/覆盖企业消息真源（canonical message 只在服务端；本地缓存
/// 的删除只服从服务端 tombstone/可见性语义，V1 不实现）。
library;

import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

/// 企业存储抽象。所有键/表由实现统一加 `enterprise_` 前缀。
abstract class EnterpriseStore {
  Future<void> saveOrg(EnterpriseOrg org);

  Future<EnterpriseOrg?> org(EntityId id);

  Future<List<EnterpriseOrg>> orgs();

  Future<void> saveIdentity(BusinessIdentity identity);

  Future<List<BusinessIdentity>> identities(EntityId orgId);

  Future<void> saveContact(EnterpriseContact contact);

  Future<List<EnterpriseContact>> contacts(EntityId orgId);

  Future<void> saveConversation(EnterpriseConversation conversation);

  Future<List<EnterpriseConversation>> conversations(EntityId orgId);

  Future<void> saveMessage(EnterpriseMessage message);

  /// [afterId] 非空时只返回游标之后的消息（after_id 增量）。
  Future<List<EnterpriseMessage>> messages(
    EntityId orgId,
    EntityId conversationId, {
    EntityId afterId = '',
  });

  /// delivery-only ACK：仅标记已投递，不删除消息真源。
  Future<void> markDelivered(
    EntityId orgId,
    EntityId conversationId,
    List<EntityId> messageIds,
  );

  /// 清空企业本地缓存（仅 enterprise_ 前缀数据）。
  Future<void> clear();

  /// 审计/测试口：全部底层键（必须 `enterprise_` 前缀）。
  Iterable<String> debugKeys();
}

/// 统一 key 拼接（结构性隔离的唯一入口）。
String enterpriseKey(String kind, List<String> parts) {
  final buf = StringBuffer('enterprise_')..write(kind);
  for (final p in parts) {
    buf.write(':');
    buf.write(p);
  }
  return buf.toString();
}

/// 内存实现（单测 / 无 sqflite 场景）。
class EnterpriseMemoryStore implements EnterpriseStore {
  final Map<String, Object> _kv = <String, Object>{};

  @override
  Future<void> saveOrg(EnterpriseOrg org) async {
    _kv[enterpriseKey('org', [org.id])] = org;
  }

  @override
  Future<EnterpriseOrg?> org(EntityId id) async =>
      _kv[enterpriseKey('org', [id])] as EnterpriseOrg?;

  @override
  Future<List<EnterpriseOrg>> orgs() async =>
      _kv.values.whereType<EnterpriseOrg>().toList(growable: false);

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    _kv[enterpriseKey('identity', [identity.organizationId, identity.id])] =
        identity;
  }

  @override
  Future<List<BusinessIdentity>> identities(EntityId orgId) async {
    final prefix = enterpriseKey('identity', [orgId, '']);
    return _kv.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => e.value as BusinessIdentity)
        .toList(growable: false);
  }

  @override
  Future<void> saveContact(EnterpriseContact contact) async {
    _kv[enterpriseKey('contact', [contact.organizationId, contact.id])] =
        contact;
  }

  @override
  Future<List<EnterpriseContact>> contacts(EntityId orgId) async {
    final prefix = enterpriseKey('contact', [orgId, '']);
    return _kv.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => e.value as EnterpriseContact)
        .toList(growable: false);
  }

  @override
  Future<void> saveConversation(EnterpriseConversation conversation) async {
    _kv[enterpriseKey('conversation', [
          conversation.organizationId,
          conversation.id,
        ])] =
        conversation;
  }

  @override
  Future<List<EnterpriseConversation>> conversations(EntityId orgId) async {
    final prefix = enterpriseKey('conversation', [orgId, '']);
    return _kv.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => e.value as EnterpriseConversation)
        .toList(growable: false);
  }

  @override
  Future<void> saveMessage(EnterpriseMessage message) async {
    _kv[enterpriseKey('message', [
          message.organizationId,
          message.conversationId,
          message.id,
        ])] =
        message;
  }

  @override
  Future<List<EnterpriseMessage>> messages(
    EntityId orgId,
    EntityId conversationId, {
    EntityId afterId = '',
  }) async {
    final prefix = enterpriseKey('message', [orgId, conversationId, '']);
    final all =
        _kv.entries
            .where((e) => e.key.startsWith(prefix))
            .map((e) => e.value as EnterpriseMessage)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (afterId.isEmpty) {
      return all;
    }
    return all
        .where((m) => m.id.compareTo(afterId) > 0)
        .toList(growable: false);
  }

  @override
  Future<void> markDelivered(
    EntityId orgId,
    EntityId conversationId,
    List<EntityId> messageIds,
  ) async {
    for (final mid in messageIds) {
      final key = enterpriseKey('message', [orgId, conversationId, mid]);
      final msg = _kv[key] as EnterpriseMessage?;
      // delivery-only：原地替换为已投递副本，键不消失（真源不删）
      if (msg != null) {
        _kv[key] = msg.withDelivered();
      }
    }
  }

  @override
  Future<void> clear() async {
    _kv.removeWhere((k, _) => k.startsWith('enterprise_'));
  }

  @override
  Iterable<String> debugKeys() => _kv.keys.toList(growable: false);
}

/// 模块级存储持有者（页面默认入口）。
///
/// 刻意不注册进 `lib/store/**` 全局容器（保持 amendment owned path 内
/// 闭环、不动共享 store 注册行）；生产可切 [EnterpriseSqfliteStore]。
class EnterpriseStoreHolder {
  EnterpriseStoreHolder._();

  static final EnterpriseStore instance = EnterpriseMemoryStore();
}
