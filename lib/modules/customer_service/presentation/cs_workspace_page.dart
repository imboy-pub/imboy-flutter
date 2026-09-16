/// 坐席工作台页（§12.5.1 / CSM-01 第一卡）
///
/// 三视图 Tab：待接(queued) / 处理中(active) / 已关闭(closed)，各自稳定
/// 计数徽标。计数纪律：只取服务端返回的计数（`total` / `total_by_status`）；
/// 服务端未提供的计数显示占位符（i18n `countUnavailable`），**禁止**用
/// 已加载行数或全表行数差推断。
///
/// 本卡范围：queued 视图为待接队列（键集分页 + CAS 接单）；active/closed
/// 无坐席侧列表端点（后端仅平台面 p_session_list），诚实呈现空态。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 服务端计数（nullable：null = 服务端未提供，UI 显示占位符）。
class CsWorkspaceCounters {
  final int? queuedTotal;
  final int? active;
  final int? closed;

  const CsWorkspaceCounters({this.queuedTotal, this.active, this.closed});
}

class CsWorkspacePage extends StatefulWidget {
  const CsWorkspacePage({super.key});

  @override
  State<CsWorkspacePage> createState() => _CsWorkspacePageState();
}

class _CsWorkspacePageState extends State<CsWorkspacePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  CsWorkspaceCounters _counters = const CsWorkspaceCounters();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// queued 视图回调：把服务端计数元数据上报给 Tab 徽标。
  void _onQueueCounters(CsWorkspaceCounters counters) {
    if (!mounted) return;
    setState(() => _counters = counters);
  }

  Widget _badge(int? count) {
    final t = context.t.customerService;
    final label = count == null ? t.countUnavailable : '$count';
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: context.textStyle(
          FontSizeType.caption2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(t.tabQueued), _badge(_counters.queuedTotal)],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(t.tabActive), _badge(_counters.active)],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(t.tabClosed), _badge(_counters.closed)],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CsQueueView(onCounters: _onQueueCounters),
          const _HonestEmptyView(kind: _EmptyKind.active),
          const _HonestEmptyView(kind: _EmptyKind.closed),
        ],
      ),
    );
  }
}

enum _EmptyKind { active, closed }

/// active / closed 视图：本卡无坐席侧列表端点，诚实空态（不造伪数据）。
class _HonestEmptyView extends StatelessWidget {
  final _EmptyKind kind;

  const _HonestEmptyView({required this.kind});

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final title = kind == _EmptyKind.active
        ? t.activeEmptyTitle
        : t.closedEmptyTitle;
    final hint = kind == _EmptyKind.active
        ? t.activeEmptyHint
        : t.closedEmptyHint;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              kind == _EmptyKind.active
                  ? CupertinoIcons.chat_bubble_2
                  : CupertinoIcons.archivebox,
              size: 40,
              color: AppColors.iosGray3,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: context.textStyle(FontSizeType.subheadline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
