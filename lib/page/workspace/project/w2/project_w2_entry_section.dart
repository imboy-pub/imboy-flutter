/// W2 (ZC-06) — 项目详情页「项目协作」入口区
///
/// 仅在 W0 详情页挂导航入口（成员 / 里程碑 / 项目频道 / 内容聚合），
/// 不改变既有交互与布局语义；workspaceId 缺失（同栈直达）时不渲染
/// ——路由需要工作区上下文。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show WorkspaceSectionCard;

class ProjectW2EntrySection extends StatelessWidget {
  final EntityId projectId;
  final EntityId workspaceId;

  const ProjectW2EntrySection({
    super.key,
    required this.projectId,
    required this.workspaceId,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // 路由需要工作区上下文；缺失时整区不渲染（详情行可后续兜底）
    if (workspaceId.isEmpty) return const SizedBox.shrink();
    return WorkspaceSectionCard(
      title: t.workspace.projectW2SectionTitle,
      child: Column(
        children: [
          _EntryTile(
            keyValue: 'project-w2-entry-members',
            iconData: CupertinoIcons.person_2,
            label: t.workspace.projectMembersEntry,
            onTap: () => context.push(
              '/workspace/$workspaceId/projects/$projectId/members',
            ),
          ),
          _EntryTile(
            keyValue: 'project-w2-entry-milestones',
            iconData: CupertinoIcons.flag,
            label: t.workspace.projectMilestonesEntry,
            onTap: () => context.push(
              '/workspace/$workspaceId/projects/$projectId/milestones',
            ),
          ),
          _EntryTile(
            keyValue: 'project-w2-entry-channels',
            iconData: CupertinoIcons.volume_up,
            label: t.workspace.projectChannelsEntry,
            onTap: () => context.push(
              '/workspace/$workspaceId/projects/$projectId/channels',
            ),
          ),
          _EntryTile(
            keyValue: 'project-w2-entry-insights',
            iconData: CupertinoIcons.doc_text_search,
            label: t.workspace.projectInsightsEntry,
            onTap: () => context.push(
              '/workspace/$workspaceId/projects/$projectId/insights',
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final String keyValue;
  final IconData iconData;
  final String label;
  final VoidCallback onTap;

  const _EntryTile({
    required this.keyValue,
    required this.iconData,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // ListTile 需要最近 Material 祖先渲染水波纹（见 WP5 同注释）
      type: MaterialType.transparency,
      child: ListTile(
        key: ValueKey(keyValue),
        contentPadding: EdgeInsets.zero,
        leading: Icon(iconData),
        title: Text(label),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
        onTap: onTap,
      ),
    );
  }
}
