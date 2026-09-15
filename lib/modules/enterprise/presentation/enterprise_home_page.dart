/// 企业入口页（amendment §2.2 / §2.4）
///
/// 显式「企业」入口：身份列表 + 联系人 + 会话入口；个人 IM 导航与页面
/// 不受影响（只新增，不改写个人域语义）。
///
/// suspend/offboarding 降级（amendment §2.4）：org.memberStatus 非 active
/// 时整页只读并展示提示条；后续企业 API 返回 403/409 时同样降级。
///
/// UI 保持最简（纵切验收优先）；文案暂用中文字面量，i18n 迁移走共享
/// 文件申报流程，本期不做。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/theme/default/app_spacing.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_store.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';

/// 企业入口路由。
const String kEnterpriseHomePath = '/enterprise';

class EnterpriseHomePage extends StatefulWidget {
  const EnterpriseHomePage({super.key});

  @override
  State<EnterpriseHomePage> createState() => _EnterpriseHomePageState();
}

class _EnterpriseHomePageState extends State<EnterpriseHomePage> {
  final EnterpriseApi _api = EnterpriseApi();

  /// 模块级存储单例（不注册进 lib/store，保持 owned path 内闭环）。
  final EnterpriseStore _store = EnterpriseStoreHolder.instance;

  EnterpriseOrg? _org;
  List<BusinessIdentity> _identities = const [];
  List<EnterpriseContact> _contacts = const [];
  List<EnterpriseConversation> _conversations = const [];
  bool _loading = false;
  bool _readOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orgs = await _api.myOrganizations();
      final org = orgs.isEmpty ? null : orgs.first;
      if (org != null) {
        await _store.saveOrg(org);
      }

      // suspend / removed：入口降级只读，不再发起后续企业业务请求
      if (org == null || org.isReadOnly) {
        if (!mounted) return;
        setState(() {
          _org = org;
          _readOnly = org != null;
          _identities = const [];
          _contacts = const [];
          _conversations = const [];
        });
        return;
      }

      final orgId = org.id;
      final identities = await _api.businessIdentities(orgId);
      final contacts = await _api.contacts(orgId);
      final conversations = await _api.conversations(orgId);
      for (final i in identities) {
        await _store.saveIdentity(i);
      }
      for (final c in contacts) {
        await _store.saveContact(c);
      }
      for (final c in conversations) {
        await _store.saveConversation(c);
      }
      if (!mounted) return;
      setState(() {
        _org = org;
        _readOnly = false;
        _identities = identities;
        _contacts = contacts;
        _conversations = conversations;
      });
    } on EnterpriseApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.message} (code=${e.code})';
        _readOnly = _readOnly || e.isForbidden || e.isOffboardingRequired;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _contactName(EntityId contactId) {
    for (final c in _contacts) {
      if (c.id == contactId) {
        return c.displayName;
      }
    }
    return contactId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('企业')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
          children: [
            if (_org != null)
              ListTile(
                leading: const Icon(CupertinoIcons.briefcase),
                title: Text(_org!.name),
                subtitle: Text('成员状态：${_org!.memberStatus.wireName}'),
              ),
            if (_readOnly)
              const ListTile(
                leading: Icon(CupertinoIcons.lock),
                title: Text('企业入口已降级为只读'),
                subtitle: Text('当前成员被暂停（suspend）或正在离职交接，仅可查看'),
              ),
            if (_error != null)
              ListTile(
                leading: const Icon(CupertinoIcons.exclamationmark_circle),
                title: const Text('加载失败'),
                subtitle: Text(_error!),
              ),
            const Divider(),
            const ListTile(title: Text('业务身份')),
            for (final i in _identities)
              ListTile(
                leading: const Icon(CupertinoIcons.tag),
                title: Text(i.displayName),
                subtitle: Text('${i.functionKey} · ${i.status}'),
              ),
            const Divider(),
            const ListTile(title: Text('联系人')),
            for (final c in _contacts)
              ListTile(
                leading: const Icon(CupertinoIcons.person),
                title: Text(c.displayName),
              ),
            const Divider(),
            const ListTile(title: Text('企业会话')),
            for (final c in _conversations)
              ListTile(
                leading: const Icon(CupertinoIcons.chat_bubble),
                title: Text(_contactName(c.contactId)),
                subtitle: Text('会话 ${c.id}'),
                // 企业会话入口：进入模块内会话页（不进个人 IM 壳）
                onTap: () => context.push(
                  '$kEnterpriseHomePath/${c.organizationId}/conversations/${c.id}'
                  '?contact_name=${Uri.encodeComponent(_contactName(c.contactId))}',
                ),
              ),
            if (!_readOnly && _conversations.isEmpty && !_loading)
              const ListTile(
                title: Text('暂无企业会话'),
                subtitle: Text('下拉刷新或联系管理员'),
              ),
          ],
        ),
      ),
    );
  }
}
