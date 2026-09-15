/// APP-A01 — 企业 DTO TSID 精度单测
///
/// 契约（plan §5.1 / amendment §2.1）：企业 API 的 64-bit TSID 以 JSON
/// integer 传输；App 端一律经仓内 entityIdOf（safeParseBigIntJson 语义）
/// 转 String（EntityId）持有，全程不回转 int/num，无 double 精度损失。
///
/// 超过 2^53 的 TSID 若被解析为 double 会丢精度——本文件所有断言 ID
/// 均取 > 2^53 的 64-bit 值。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise/public.dart';

/// > 2^53（double 安全整数上限）的 TSID 样本
const int bigOrgId = 7266418340025468930;
const int bigIdentityId = 7266418340025468931;
const int bigContactId = 7266418340025468932;
const int bigConversationId = 7266418340025468933;
const int bigMessageId = 7266418340025468934;
const int bigAssetId = 7266418340025468935;

void main() {
  group('APP-A01 企业 DTO TSID 精度', () {
    test('entityIdOf：int 入参精确保留（>2^53）', () {
      expect(entityIdOf(bigOrgId), '7266418340025468930');
      expect(entityIdOf(bigMessageId), '7266418340025468934');
    });

    test('entityIdOf：String 入参原样透传；null/非法返回空串', () {
      expect(entityIdOf('7266418340025468930'), '7266418340025468930');
      expect(entityIdOf(null), '');
      expect(entityIdOf(''), '');
    });

    test('EnterpriseOrg.fromJson：id/default_workspace_id 全程 string', () {
      final org = EnterpriseOrg.fromJson(const {
        'id': bigOrgId,
        'name': 'Acme Inc',
        'member_status': 'active',
        'default_workspace_id': 7266418340025468900,
      });

      expect(org.id, '7266418340025468930');
      expect(org.defaultWorkspaceId, '7266418340025468900');
      // 反向防呆：类型必须是 String（EntityId），不是 int/num
      expect(org.id, isA<String>());
      expect(org.defaultWorkspaceId, isA<String>());
    });

    test('BusinessIdentity.fromJson：TSID 字段无精度损失', () {
      final identity = BusinessIdentity.fromJson(const {
        'id': bigIdentityId,
        'organization_id': bigOrgId,
        'display_name': '客服甲',
        'function_key': 'customer_service',
        'status': 'active',
      });

      expect(identity.id, '7266418340025468931');
      expect(identity.organizationId, '7266418340025468930');
    });

    test('EnterpriseMessage.fromJson：sender 字段 + XOR 约束', () {
      // 入站：sender_type=contact，恰好一个 sender 非空
      final inbound = EnterpriseMessage.fromJson(const {
        'id': bigMessageId,
        'conversation_id': bigConversationId,
        'organization_id': bigOrgId,
        'sender_type': 'contact',
        'sender_contact_id': bigContactId,
        'sender_business_identity_id': null,
        'sender_business_identity_name': '客服甲',
        'content': 'hello',
        'asset_id': null,
        'retain_until': '1799999999000',
        'policy_snapshot': 'retain=1095d',
        'created_at': '1789000000000',
      });

      expect(inbound.id, '7266418340025468934');
      expect(inbound.conversationId, '7266418340025468933');
      expect(inbound.senderType, EnterpriseSenderType.contact);
      expect(inbound.senderContactId, '7266418340025468932');
      expect(inbound.senderBusinessIdentityId, '');
      expect(inbound.senderBusinessIdentityName, '客服甲');
      expect(inbound.retainUntil, '1799999999000');
      expect(inbound.policySnapshot, 'retain=1095d');
      expect(inbound.senderXorValid, isTrue);

      // 出站：sender_type=business_identity
      final outbound = EnterpriseMessage.fromJson(const {
        'id': bigMessageId,
        'conversation_id': bigConversationId,
        'organization_id': bigOrgId,
        'sender_type': 'business_identity',
        'sender_contact_id': null,
        'sender_business_identity_id': bigIdentityId,
        'sender_business_identity_name': '客服甲',
        'content': 'reply',
        'created_at': '1789000000001',
      });

      expect(outbound.senderType, EnterpriseSenderType.businessIdentity);
      expect(outbound.senderBusinessIdentityId, '7266418340025468931');
      expect(outbound.senderContactId, '');
      expect(outbound.senderXorValid, isTrue);
    });

    test('EnterpriseAsset.fromJson：TSID string + 初始 pending', () {
      final asset = EnterpriseAsset.fromJson(const {
        'id': bigAssetId,
        'organization_id': bigOrgId,
        'conversation_id': bigConversationId,
        'message_id': bigMessageId,
        'mime': 'text/plain',
        'size': 42,
        'status': 'pending',
      });

      expect(asset.id, '7266418340025468935');
      expect(asset.messageId, '7266418340025468934');
      expect(asset.isPending, isTrue);
    });

    test('端到端：jsonDecode 大整数 envelope → DTO 全程 string 不丢精度', () {
      // 模拟服务端返回体：TSID 为 JSON integer；jsonDecode 后是 Dart int，
      // DTO 解析必须原样转 string 而非经 double 往返
      final body = jsonDecode(
        '{"list":[{"id":$bigConversationId,'
        '"organization_id":$bigOrgId,'
        '"contact_id":$bigContactId,'
        '"business_identity_id":$bigIdentityId,'
        '"updated_at":"1789000000000"}]}',
      ) as Map<String, dynamic>;
      final list = (body['list'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();

      final conv = EnterpriseConversation.fromJson(list.first);
      expect(conv.id, '7266418340025468933');
      expect(conv.organizationId, '7266418340025468930');
      expect(conv.contactId, '7266418340025468932');
      expect(conv.businessIdentityId, '7266418340025468931');
    });

    test('序列化：DTO toJson 的 TSID 以 string 落 JSON（不回转 int）', () {
      final msg = EnterpriseMessage.fromJson(const {
        'id': bigMessageId,
        'conversation_id': bigConversationId,
        'organization_id': bigOrgId,
        'sender_type': 'business_identity',
        'sender_business_identity_id': bigIdentityId,
        'sender_business_identity_name': '客服甲',
        'content': 'reply',
        'created_at': '1789000000001',
      });

      final encoded = jsonEncode(msg.toJson());
      // string 形式带引号；若回转 int 则引号消失
      expect(encoded, contains('"id":"7266418340025468934"'));
      expect(encoded, contains('"conversation_id":"7266418340025468933"'));
      expect(encoded, contains('"organization_id":"7266418340025468930"'));
    });
  });
}
