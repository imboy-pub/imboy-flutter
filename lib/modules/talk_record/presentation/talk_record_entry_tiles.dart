/// 面聊记录入口行组件（T10 交付可嵌入件；非新 Tab）。
///
/// 契约源：UI-SPEC.md §2 + DESIGN.md §9：
/// - 个人入口：「我 → 个人工具 → 面聊记录」，个人上下文进列表；
/// - 企业入口：「工作台 → 协作工具 → 面聊记录」，带当前企业，
///   不带未知工作区、不暗示全员可读。
///
/// ===================== 嵌入点说明（主控制器归并时执行） =====================
///
/// 1. 个人入口（我 → 个人工具）：
///    `lib/page/mine/mine/mine_page.dart` 个人模式「功能组」
///    ImBoySettingsSection 的 children 中加入
///    `const TalkRecordPersonalToolEntry(),`
///    （与「收藏/存储空间/登录设备」同组；归并时可把该组命名为
///    「个人工具」。）
///
/// 2. 企业入口（工作台 → 协作工具）：
///    `lib/page/workspace_shell/enterprise_shell_page.dart`
///    `_page(EnterpriseShellDestination.workbench)` 的
///    EnterpriseWorkbenchPage.resourceEntries 列表中加入：
///    `TalkRecordOrgToolEntry(
///       organizationId: widget.organizationId,
///       organizationName: <当前企业名>,
///       workspaceId/workspaceName: 当前工作区（可空）,
///     ),`
///    （与 CsWorkspaceEntryTile 同款 ResourceEntryTile 形态。）
///
/// 3. 路由注册（app_router.dart，两行）：
///    `import '.../config/router/routes/talk_record_routes.dart';`
///    `...talkRecordRoutes(),`（与 ...groupRoutes() 并列。）
///
/// 入口行只负责导航与上下文传参；权限与数据由列表/准备页按服务端
/// 返回如实降级，不在入口做能力预判。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/resource_entry_tile.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 面聊记录列表路径（含入口 query）。
String talkRecordListPathFor(TalkRecordEntryContext context) {
  final query = context
      .toQuery()
      .entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return '$kTalkRecordListPath?$query';
}

/// 个人入口行（我 → 个人工具）：mine 页设置组同款视觉与触达。
///
/// 个人上下文进入列表，不默认企业（UI-SPEC §2）。
class TalkRecordPersonalToolEntry extends StatelessWidget {
  const TalkRecordPersonalToolEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ImBoySettingsTile(
      key: const ValueKey('talk_record_personal_entry'),
      title: Text(t.talkRecord.entryTitle),
      leading: Icon(
        CupertinoIcons.mic,
        color: AppColors.getIosBlue(brightness),
      ),
      onTap: () => context.push(
        talkRecordListPathFor(const TalkRecordEntryContext.personal()),
      ),
    );
  }
}

/// 企业入口行（工作台 → 协作工具）：ResourceEntryTile 同款视觉。
///
/// 带当前企业；工作区仅在外壳已明确给出时携带（不默认未知工作区）。
class TalkRecordOrgToolEntry extends StatelessWidget {
  const TalkRecordOrgToolEntry({
    super.key,
    required this.organizationId,
    this.organizationName = '',
    this.workspaceId = '',
    this.workspaceName = '',
    this.showDivider = true,
  });

  final String organizationId;

  /// 企业展示名（空则列表页按通用文案展示，不猜名字）。
  final String organizationName;

  /// 可选工作区（外壳明确给出才传）。
  final String workspaceId;
  final String workspaceName;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return ResourceEntryTile(
      key: const ValueKey('talk_record_org_entry'),
      showDivider: showDivider,
      title: t.talkRecord.entryTitle,
      subtitle: t.talkRecord.entrySubtitleOrg,
      icon: CupertinoIcons.mic,
      onTap: () => context.push(
        talkRecordListPathFor(
          TalkRecordEntryContext(
            scope: TalkRecordScope.organization,
            organizationId: organizationId,
            organizationName: organizationName,
            workspaceId: workspaceId,
            workspaceName: workspaceName,
          ),
        ),
      ),
    );
  }
}
