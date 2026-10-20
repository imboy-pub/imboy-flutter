/// 通讯录 · 成员详情（GZAPP-C3，计划 §5.2）。
///
/// §5.2 要求：「通讯录」提供部门树、成员列表、**成员详情**和**有权 Workspace
/// 信息**，且**所有企业成员可见**。此前成员行直接跳通用 IM 联系人页
/// `/contact/people/:id`，那里没有企业/工作区信息——本条即为补齐该缺口。
///
/// 数据源分工（为什么不是复用治理面的成员列表）：
/// - 资料/角色：来自通讯录已加载的 [OrganizationMember]（治理面 403 时为 null，
///   此时只展示 IM 资料与工作区）；
/// - 有权 Workspace：走 `GET /organizations/:id/members/:uid/workspaces`，
///   服务端只要求调用者是本 Org active 成员（任意角色）→ 普通成员同样可见。
///
/// 保留通往通用 IM 资料页的次级入口（发消息/加好友等 IM 能力仍在那边）。
library;

import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_ui.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class OrganizationMemberDetailPage extends StatefulWidget {
  const OrganizationMemberDetailPage({
    super.key,
    required this.orgId,
    required this.userId,
    this.member,
    this.orgName = '',
  });

  final EntityId orgId;
  final EntityId userId;

  /// 通讯录已加载到的成员行（治理面 403 时为 null → 只展示 IM 资料）。
  final OrganizationMember? member;
  final String orgName;

  @override
  State<OrganizationMemberDetailPage> createState() =>
      _OrganizationMemberDetailPageState();
}

class _OrganizationMemberDetailPageState
    extends State<OrganizationMemberDetailPage> {
  final OrganizationApi _api = OrganizationApi();

  bool _loading = true;
  String? _error;
  List<OrganizationMemberWorkspace> _workspaces =
      const <OrganizationMemberWorkspace>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.memberWorkspaces(widget.orgId, widget.userId);
      if (!mounted) return;
      setState(() {
        _workspaces = list;
        _loading = false;
      });
    } on OrganizationApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final m = widget.member;
    final title = (m != null && m.displayName.isNotEmpty)
        ? m.displayName
        : widget.userId;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ResourcePageLayout(
        child: ListView(
          padding: AppSpacing.allRegular,
          children: [
            _ProfileCard(
              member: m,
              userId: widget.userId,
              orgName: widget.orgName,
            ),
            AppSpacing.verticalRegular,
            _WorkspacesCard(
              loading: _loading,
              error: _error,
              workspaces: _workspaces,
              onRetry: _load,
            ),
            AppSpacing.verticalRegular,
            // 次级入口：IM 侧能力（发消息/加好友/资料）仍在通用联系人页。
            // 通用资料页路由注册在 /contact 子树：/contact/people/:id，
            // 裸写 /people/:id 会命中 GoRouter errorPage（Page not found）。
            ListTile(
              key: const ValueKey('org-member-detail-im-profile'),
              leading: const Icon(CupertinoIcons.person_crop_circle),
              title: Text(t.organization.directory.imProfileEntry),
              trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
              onTap: () => context.push('/contact/people/${widget.userId}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final OrganizationMember? member;
  final EntityId userId;
  final String orgName;

  const _ProfileCard({
    required this.member,
    required this.userId,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final m = member;
    final name = (m != null && m.displayName.isNotEmpty)
        ? m.displayName
        : userId;
    final avatar = m?.avatar ?? '';
    return Card(
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: avatar.isNotEmpty
                      ? avatarImageProvider(avatar)
                      : null,
                  child: avatar.isEmpty
                      ? Icon(
                          CupertinoIcons.person_fill,
                          color: theme.colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                AppSpacing.horizontalSmall,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (orgName.isNotEmpty)
                        Text(
                          orgName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.verticalSmall,
            if (m == null)
              // 治理面 403（普通成员视角）：不给角色结论，明确说明受限
              _InfoRow(
                label: t.organization.memberDetail.roleLabel,
                value: t.organization.memberDetail.roleRestricted,
              )
            else ...[
              _InfoRow(
                label: t.organization.memberDetail.roleLabel,
                value: orgRoleLabel(m.role),
              ),
              if (m.account.isNotEmpty)
                _InfoRow(
                  label: t.organization.memberDetail.accountLabel,
                  value: m.account,
                ),
              if (m.joinedAt.isNotEmpty)
                _InfoRow(
                  label: t.organization.memberDetail.joinedLabel,
                  value: m.joinedAt,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tiny),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// 有权 Workspace（§5.2 的核心交付面）。三态：加载中 / 失败可重试 / 列表或空态。
class _WorkspacesCard extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<OrganizationMemberWorkspace> workspaces;
  final Future<void> Function() onRetry;

  const _WorkspacesCard({
    required this.loading,
    required this.error,
    required this.workspaces,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('org-member-detail-workspaces'),
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.organization.memberDetail.workspacesTitle,
              style: theme.textTheme.titleSmall,
            ),
            AppSpacing.verticalSmall,
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.organization.memberDetail.workspacesFailed,
                    style: theme.textTheme.bodySmall,
                  ),
                  AppSpacing.verticalSmall,
                  OutlinedButton(
                    key: const ValueKey('org-member-detail-workspaces-retry'),
                    onPressed: () => onRetry(),
                    child: Text(t.common.retry),
                  ),
                ],
              )
            else if (workspaces.isEmpty)
              Text(
                t.organization.memberDetail.workspacesEmpty,
                style: theme.textTheme.bodySmall,
              )
            else
              for (final ws in workspaces)
                ListTile(
                  key: ValueKey('org-member-detail-ws-${ws.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(CupertinoIcons.folder, size: 18),
                  title: Text(
                    ws.name.isEmpty ? ws.id : ws.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
