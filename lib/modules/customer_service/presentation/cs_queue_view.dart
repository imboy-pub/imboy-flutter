/// 待接队列视图（§12.5.1 / CSM-01 + APP-M01）
///
/// - 列表项：客户掩码名、等待时长、来源渠道、最后一条安全摘要；
/// - 分页/刷新/触底/空态/错误重试复用 [CsPagedSessionList]（单一实现）；
/// - 服务端计数原样上报（Tab 徽标唯一数据来源，禁止本地推断）；
/// - CAS 接单：claim 带 expected_version；409 冲突 → 刷新真实状态并提示，
///   不做乐观伪成功；
/// - APP-M01-A04：claim 成功后跳转会话页只携带**服务端权威事实**
///   （org / session / claim 回显经办 identity / 服务端投影 conversation），
///   路由 query 仅作展示种子，会话页以服务端 detail 为准。
library;

import 'dart:async' show StreamSubscription;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_queue_format.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_paged_list.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_row_content.dart';
import 'package:imboy/modules/customer_service/presentation/cs_source_label.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart'
    show kCsWorkspacePath;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/font_types.dart';

class CsQueueView extends StatefulWidget {
  /// 组织作用域（seat-contexts 列表选中项；服务端逐字校验）。
  final String orgId;

  /// Workspace 作用域（SSE 事件流 query 种子；可空，会话页权威解析）。
  final String workspaceId;

  /// 服务端计数元数据上报（Tab 徽标唯一数据来源）。
  final ValueChanged<CsQueuePage>? onPageMeta;

  /// 外部刷新信号（坐席事件流 queue.changed 等触发权威刷新）。
  final Stream<void>? refreshSignal;

  const CsQueueView({
    super.key,
    required this.orgId,
    this.workspaceId = '',
    this.onPageMeta,
    this.refreshSignal,
  });

  @override
  State<CsQueueView> createState() => _CsQueueViewState();
}

class _CsQueueViewState extends State<CsQueueView> {
  final CsApi _api = CsApi();
  final GlobalKey<CsPagedSessionListState> _listKey =
      GlobalKey<CsPagedSessionListState>();
  StreamSubscription<void>? _refreshSub;

  /// claim 进行中的会话（防重复点击）。
  String? _claimingSessionId;

  late CsPagedFetch _fetchPage;

  @override
  void initState() {
    super.initState();
    _fetchPage = ({String? afterId, int? limit}) =>
        _api.queuePage(widget.orgId, afterId: afterId, limit: limit);
    _refreshSub = widget.refreshSignal?.listen((_) {
      _listKey.currentState?.refresh();
    });
  }

  @override
  void dispose() {
    _refreshSub?.cancel();
    super.dispose();
  }

  /// CAS 接单：成功 → 提示 + 刷新真实队列；409 → 刷新真实状态并提示。
  Future<void> _claim(CsQueueItem item) async {
    if (_claimingSessionId != null) return;
    if (item.version <= 0) {
      // 服务端未回显 version：无法安全发起 CAS，先刷新拿真实版本。
      AppLoading.showToast(context.t.customerService.claimConflict);
      await _listKey.currentState?.refresh();
      return;
    }
    setState(() => _claimingSessionId = item.sessionId);
    final t = context.t.customerService;
    String? assigneeIdentityId;
    try {
      final result = await _api.claim(
        widget.orgId,
        item.sessionId,
        expectedVersion: item.version,
        // CSB-02R workspace 门（claim 无 optional 声明，缺省必 422）——
        // 真机 A02 实证 2026-09-30：按钮可用但 claim 422 的根因即此漏接线。
        workspaceId: widget.workspaceId,
      );
      assigneeIdentityId = result.assigneeIdentityId;
      if (!mounted) return;
      AppLoading.showToast(t.claimSuccess);
      // 接单成功后刷新：徽标与列表以服务端真实状态为准。
      await _listKey.currentState?.refresh();
      if (!mounted) return;
      // 接单即经办（CSM-02）：进入坐席会话页。query 只携带服务端权威事实
      //（claim 回显 identity、服务端投影 conversation）作展示种子；会话页
      // 以服务端 detail 为权威（APP-M01-A04，路由 query 不作授权事实）。
      context.push(
        '$kCsWorkspacePath/sessions/${item.sessionId}'
        '?org_id=${Uri.encodeComponent(widget.orgId)}'
        '&conversation_id=${Uri.encodeComponent(item.conversationId)}'
        '&identity_id=${Uri.encodeComponent(assigneeIdentityId)}'
        '&workspace_id=${Uri.encodeComponent(widget.workspaceId)}'
        '&contact_name=${Uri.encodeComponent(item.contactName)}',
      );
    } on CsApiException catch (e) {
      if (!mounted) return;
      // 不做乐观伪成功：先刷新真实状态，再按语义提示。
      await _listKey.currentState?.refresh();
      if (!mounted) return;
      if (e.isForbidden) {
        AppLoading.showToast(t.claimForbidden);
      } else if (e.isSeatAtCapacity) {
        // 容量满 ≠ 并发冲突：刷新重试无效，必须先关闭处理中会话（联调
        // 实证 2026-10-02：坐席 3/3 满时每单必 409，曾误报"已被其他坐席接单"）。
        AppLoading.showToast(t.seatAtCapacity);
      } else if (e.isConflict) {
        AppLoading.showToast(t.claimConflict);
      } else {
        AppLoading.showToast(t.claimFailed);
      }
    } on Object {
      if (!mounted) return;
      AppLoading.showToast(t.claimFailed);
    } finally {
      if (mounted) {
        setState(() => _claimingSessionId = null);
      }
    }
  }

  String _waitingLabel(CsQueueItem item) {
    final waiting = csWaitingSince(item.waitingSince, DateTime.now());
    final t = context.t.customerService;
    switch (waiting.unit) {
      case 'minutes':
        return t.waitingMinutes(n: waiting.n);
      case 'hoursMinutes':
        return t.waitingHoursMinutes(h: waiting.n, m: waiting.m ?? 0);
      case 'daysHours':
        return t.waitingDaysHours(d: waiting.n, h: waiting.m ?? 0);
      default:
        return t.waitingJustNow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    return CsPagedSessionList(
      key: _listKey,
      fetchPage: _fetchPage,
      onPageMeta: widget.onPageMeta,
      emptyView: CsListEmptyView(
        icon: CupertinoIcons.tray,
        title: t.queuedEmptyTitle,
        hint: t.queuedEmptyHint,
      ),
      itemBuilder: (context, item) {
        return _QueueTile(
          item: item,
          waitingLabel: _waitingLabel(item),
          claiming: _claimingSessionId == item.sessionId,
          onClaim: () => _claim(item),
        );
      },
    );
  }
}

/// 队列/会话预览文案（产品裁决 2026-10-02：不再展示「[加密消息]」占位）。
/// 服务端 preview 非空 → 真实摘要；摘要不可用（附件-only/解密降级）→
/// 不渲染文本；无末条消息 → 沿用 dataNotFound 兜底。
///
/// 待接队列与处理中/已关闭会话列表共用（信息密度口径一致）。
Widget csQueuePreviewText(BuildContext context, CsQueueItem item) {
  if (item.lastMessagePreview.isNotEmpty) {
    return Text(
      item.lastMessagePreview,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textStyle(FontSizeType.footnote, color: AppColors.iosGray),
    );
  }
  if (item.hasLastMessage) {
    return const SizedBox.shrink();
  }
  return Text(
    context.t.common.dataNotFound,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.textStyle(FontSizeType.footnote, color: AppColors.iosGray),
  );
}

class _QueueTile extends StatelessWidget {
  final CsQueueItem item;
  final String waitingLabel;
  final bool claiming;
  final VoidCallback onClaim;

  const _QueueTile({
    required this.item,
    required this.waitingLabel,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final maskedName = csMaskContactName(item.contactName);
    // T19：信息布局抽入共用 CsSessionRowContent（名→摘要→来源）；
    // 等待时长与接单动作仍是队列行专属，留在本页。
    final Widget rowPreview = csQueuePreviewText(context, item);
    return CsSessionRowContent(
      maskedName: maskedName,
      preview: Wrap(
        spacing: AppSpacing.tiny,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          rowPreview,
          Text(
            waitingLabel,
            style: context.textStyle(
              FontSizeType.caption2,
              color: AppColors.iosOrange,
            ),
          ),
        ],
      ),
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
      trailing: FilledButton(
        onPressed: claiming ? null : onClaim,
        style: FilledButton.styleFrom(
          foregroundColor: AppColors.sentMessageText,
          backgroundColor: AppColors.primary,
          minimumSize: const Size(
            AppSizes.buttonMinWidth,
            AppSizes.buttonHeightXLarge,
          ),

          textStyle: context
              .textStyle(FontSizeType.footnote, fontWeight: FontWeight.w600)
              .copyWith(fontSize: FontSizeType.footnote.size),
        ),
        child: claiming
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(t.claimAction),
      ),
    );
  }
}
