/// 客服工作台入口（§12.5.1 / CSM-01）
///
/// 权限驱动的可见入口：登录用户具有 active Organization member +
/// active customer_service assignment + enabled seat 时渲染入口，否则
/// 完全不渲染（含加载失败/无组织/普通用户）。
///
/// 判定数据来源：既有企业身份 API（`myOrganizations` +
/// `businessIdentities`，会话内已有用户域数据）。客户端隐藏只是 UX，
/// 服务端 cs_seat 面 fail-closed；判定逻辑集中在
/// `csWorkspaceEntryVisible`（纯函数，四态单测见 cs_seat_gate_test）。
///
/// seat enabled：坐席域无自助 seat 查询面（seats 列表属 owner/admin 治理面，
/// 不进客户端），客户端按 unknown 保守放行、由服务端权威裁决；输入模型
/// [CsSeatGateInput.seatEnabled] 保留该轴以覆盖 disabled-seat 四态测试。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 由会话内已有用户域数据组装判定输入（纯函数，可单测）。
///
/// [seatEnabled] 缺省 true（客户端 unknown 保守放行，服务端 fail-closed）。
bool csSeatGateFromUserData({
  required EnterpriseOrg? org,
  required List<BusinessIdentity> identities,
  bool seatEnabled = true,
}) {
  if (org == null) return false;
  final csIdentity = identities
      .where((i) => i.functionKey == kCsFunctionKey && i.isActive)
      .toList(growable: false);
  if (csIdentity.isEmpty) return false;
  return csWorkspaceEntryVisible(
    CsSeatGateInput(
      memberStatus: org.memberStatus.wireName,
      functionKey: csIdentity.first.functionKey,
      identityStatus: csIdentity.first.status,
      seatEnabled: seatEnabled,
    ),
  );
}

/// 「客服工作台」入口 Tile：不可见时渲染为空（普通用户零占位）。
class CsWorkspaceEntryTile extends StatefulWidget {
  const CsWorkspaceEntryTile({super.key});

  @override
  State<CsWorkspaceEntryTile> createState() => _CsWorkspaceEntryTileState();
}

class _CsWorkspaceEntryTileState extends State<CsWorkspaceEntryTile> {
  final EnterpriseApi _api = EnterpriseApi();

  bool? _visible;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    bool visible = false;
    try {
      final orgs = await _api.myOrganizations();
      final org = orgs.isEmpty ? null : orgs.first;
      final identities = org == null
          ? const <BusinessIdentity>[]
          : await _api.businessIdentities(org.id);
      visible = csSeatGateFromUserData(org: org, identities: identities);
    } on Object {
      // fail-closed UX：任何失败（含 401/403）都不显示入口。
      visible = false;
    }
    if (!mounted) return;
    setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    if (_visible == null || _visible == false) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: AppColors.iosSkyBlue,
          borderRadius: BorderRadius.circular(7.2),
        ),
        child: const Icon(
          CupertinoIcons.chat_bubble_2_fill,
          color: AppColors.onPrimary,
          size: 19,
        ),
      ),
      title: Text(t.entryTitle, style: context.textStyle(FontSizeType.normal)),
      subtitle: Text(
        t.entrySubtitle,
        style: context.textStyle(
          FontSizeType.footnote,
          color: AppColors.iosGray,
        ),
      ),
      trailing: const Icon(
        CupertinoIcons.chevron_right,
        size: 14,
        color: AppColors.iosGray3,
      ),
      onTap: () => context.push(kCsWorkspacePath),
    );
  }
}
