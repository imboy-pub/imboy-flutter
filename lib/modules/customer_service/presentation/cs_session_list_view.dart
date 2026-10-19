/// 坐席 active / closed 会话列表（CSB-02R + APP-M01-A02）
///
/// 数据源：GET /api/v1/cs/organizations/:org_id/seats/sessions
/// （status 必填，仅接受 active|closed；queued 视图冻结在 sessions/queue）。
/// 分页/刷新/触底/空态/错误重试复用 [CsPagedSessionList]（单一实现）；
/// 徽标计数只取服务端键（onPageMeta 原样上报）。
///
/// 行点击进入坐席会话页：query 只携带服务端投影事实（org / conversation /
/// 经办 identity）作展示种子，会话页以服务端 detail 为权威
///（APP-M01-A04：路由 query 不作授权事实）。
library;

import 'dart:async' show StreamSubscription;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_paged_list.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_row_content.dart';
import 'package:imboy/modules/customer_service/presentation/cs_source_label.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart'
    show csQueuePreviewText;
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart'
    show kCsWorkspacePath;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 视图状态 wire 值白名单（服务端显式必填且仅接受这两值）。
enum CsSeatSessionViewStatus { active, closed }

String csSeatSessionViewStatusWire(CsSeatSessionViewStatus status) =>
    status == CsSeatSessionViewStatus.active ? 'active' : 'closed';

class CsSessionListView extends StatefulWidget {
  /// 组织作用域（seat-contexts 列表选中项；服务端逐字校验）。
  final String orgId;

  /// 视图状态（active | closed）。
  final CsSeatSessionViewStatus status;

  /// Workspace 作用域（SSE 事件流 query 种子；可空，会话页权威解析）。
  final String workspaceId;

  /// 服务端计数元数据上报（Tab 徽标唯一数据来源）。
  final ValueChanged<CsQueuePage>? onPageMeta;

  /// 外部刷新信号（坐席事件流 session.changed 等触发权威刷新）。
  final Stream<void>? refreshSignal;

  const CsSessionListView({
    super.key,
    required this.orgId,
    required this.status,
    this.workspaceId = '',
    this.onPageMeta,
    this.refreshSignal,
  });

  @override
  State<CsSessionListView> createState() => _CsSessionListViewState();
}

class _CsSessionListViewState extends State<CsSessionListView> {
  final CsApi _api = CsApi();
  final GlobalKey<CsPagedSessionListState> _listKey =
      GlobalKey<CsPagedSessionListState>();
  StreamSubscription<void>? _refreshSub;

  late CsPagedFetch _fetchPage;

  @override
  void initState() {
    super.initState();
    final wire = csSeatSessionViewStatusWire(widget.status);
    _fetchPage = ({String? afterId, int? limit}) => _api.seatSessionsPage(
      widget.orgId,
      status: wire,
      afterId: afterId,
      limit: limit,
    );
    _refreshSub = widget.refreshSignal?.listen((_) {
      _listKey.currentState?.refresh();
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  void _open(CsQueueItem item) {
    context.push(
      '$kCsWorkspacePath/sessions/${item.sessionId}'
      '?org_id=${Uri.encodeComponent(widget.orgId)}'
      '&conversation_id=${Uri.encodeComponent(item.conversationId)}'
      '&identity_id=${Uri.encodeComponent(item.assigneeIdentityId)}'
      '&workspace_id=${Uri.encodeComponent(widget.workspaceId)}'
      '&contact_name=${Uri.encodeComponent(item.contactName)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final isActive = widget.status == CsSeatSessionViewStatus.active;
    return CsPagedSessionList(
      key: _listKey,
      fetchPage: _fetchPage,
      onPageMeta: widget.onPageMeta,
      emptyView: CsListEmptyView(
        icon: isActive
            ? CupertinoIcons.chat_bubble_2
            : CupertinoIcons.archivebox,
        title: isActive ? t.activeEmptyTitle : t.closedEmptyTitle,
        hint: isActive ? t.activeEmptyHint : t.closedEmptyHint,
      ),
      itemBuilder: (context, item) =>
          _SessionTile(item: item, onOpen: () => _open(item)),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final CsQueueItem item;
  final VoidCallback onOpen;

  const _SessionTile({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    // T19：信息布局抽入共用 CsSessionRowContent（名→摘要→来源）；
    // 头像与打开动作仍是会话列表行专属，留在本页。
    final maskedName = csMaskContactName(item.contactName);
    final Widget rowPreview = csQueuePreviewText(context, item);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        // 左缘对齐共用布局的 horizontal padding
        padding: const EdgeInsets.only(left: AppSpacing.regular),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.iosSkyBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                CupertinoIcons.person_crop_circle,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            Expanded(
              child: CsSessionRowContent(
                maskedName: maskedName,
                preview: rowPreview,
                source: item.source.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.tiny),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.chat_bubble,
                              size: AppSpacing.regular,
                              color: AppColors.iosGray,
                            ),
                            const SizedBox(width: AppSpacing.tiny),
                            Flexible(
                              child: Text(
                                csSourceDisplayLabel(context, item.source),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyle(
                                  FontSizeType.caption2,
                                  color: AppColors.iosGray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                trailing: const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppColors.iosGray3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
