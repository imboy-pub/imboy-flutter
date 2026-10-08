/// 客服工作台入口（§12.5.1 / CSM-01 + APP-M01-A01）
///
/// 权限驱动的可见入口：仅当 `GET /api/v1/cs/me/seat-contexts` 返回**任一**
/// 「active assignment（business_identity_id 非空）+ enabled seat」上下文时
/// 渲染入口，否则完全不渲染（含加载失败/无组织/普通用户/seat disabled）。
///
/// 判定数据来源（APP-M01-A01）：seat-contexts 是服务端权威聚合（active
/// member + active workspace + active customer_service assignment + seat
/// 四张事实表逐 Org 复核），**不再**取「首个 Org」的 enterprise 侧身份
/// 列表近似推断。判定逻辑集中在 `csEntryVisibleFromContexts`（纯函数，
/// 单测见 cs_seat_gate_test / cs_seat_contexts_test）。
///
/// 安全口径：客户端隐藏只是 UX；服务端对 cs_seat 面 fail-closed
///（cs_actions 的 required_function / seat_enabled 校验），本判定只决定
/// 入口是否渲染，绝不放大服务端授权。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 「客服工作台」入口 Tile：不可见时渲染为空（普通用户零占位）。
class CsWorkspaceEntryTile extends StatefulWidget {
  const CsWorkspaceEntryTile({super.key});

  @override
  State<CsWorkspaceEntryTile> createState() => _CsWorkspaceEntryTileState();
}

class _CsWorkspaceEntryTileState extends State<CsWorkspaceEntryTile> {
  final CsApi _api = CsApi();

  bool? _visible;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    bool visible = false;
    try {
      final contexts = await _api.seatContexts();
      visible = csEntryVisibleFromContexts(contexts.contexts);
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
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
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
        title: Text(
          t.entryTitle,
          style: context.textStyle(FontSizeType.normal),
        ),
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
      ),
    );
  }
}
