/// 坐席工作台页（§12.5.1 / CSM-01 + APP-M01）
///
/// - APP-M01-A01：入口上下文由 `GET /api/v1/cs/me/seat-contexts` 列表驱动，
///   组织选择器列出全部「active assignment + enabled seat」上下文，不再
///   固定首个 Org；
/// - APP-M01-A02：queued / active / closed 三视图全部真实分页
///   （sessions/queue 与 seats/sessions?status=...），刷新 / 触底 / 空态 /
///   错误重试；徽标计数**只取服务端键**（total / total_by_status），服务端
///   未提供显示占位符（i18n `countUnavailable`），禁止本地行数推断；
/// - APP-M01-A03：切换 Org 后三视图以新 Key 重建（列表 / 游标 / 计数
///   全部清空重载），不串租户缓存；
/// - Tab overflow 修复：Tab 内容 FittedBox(scaleDown)（320 宽 × textScale
///   2.0 不溢出，UX 矩阵钉住）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_paged_list.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_list_view.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class CsWorkspacePage extends StatefulWidget {
  const CsWorkspacePage({super.key});

  @override
  State<CsWorkspacePage> createState() => _CsWorkspacePageState();
}

class _CsWorkspacePageState extends State<CsWorkspacePage>
    with SingleTickerProviderStateMixin {
  final CsApi _api = CsApi();

  late final TabController _tabController;

  /// 可用坐席上下文（active assignment + enabled seat；服务端权威）。
  List<CsSeatContext> _contexts = const <CsSeatContext>[];
  bool _contextsLoading = true;
  String? _contextsError;

  /// 当前选中 Org（seat-contexts 列表驱动；切换即清空重载）。
  String? _selectedOrgId;

  /// 服务端计数（逐 Tab；null = 服务端未提供，UI 显示占位符）。
  int? _queuedTotal;
  int? _activeTotal;
  int? _closedTotal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadContexts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 拉取坐席上下文清单（seat-contexts 列表驱动，APP-M01-A01）。
  Future<void> _loadContexts() async {
    setState(() {
      _contextsLoading = true;
      _contextsError = null;
    });
    try {
      final result = await _api.seatContexts();
      if (!mounted) return;
      // 只列可用坐席上下文（active assignment + enabled seat 同时成立）。
      final eligible = result.contexts
          .where((c) => c.isEligible)
          .toList(growable: false);
      setState(() {
        _contexts = eligible;
        _contextsLoading = false;
        _selectedOrgId = eligible.isEmpty
            ? null
            : eligible.first.organizationId;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _contextsError = e.toString();
        _contextsLoading = false;
        _contexts = const <CsSeatContext>[];
        _selectedOrgId = null;
      });
    }
  }

  /// APP-M01-A03：切换 Org → 计数清空 + 三视图以新 Key 重建（列表/游标
  /// 随组件销毁清空），并以新 org 作用域重载。
  void _switchOrg(String orgId) {
    if (orgId == _selectedOrgId) return;
    setState(() {
      _selectedOrgId = orgId;
      _queuedTotal = null;
      _activeTotal = null;
      _closedTotal = null;
    });
  }

  void _onQueuedMeta(CsQueuePage page) {
    if (!mounted) return;
    setState(() => _queuedTotal = page.total ?? page.totalByStatus?['queued']);
  }

  void _onActiveMeta(CsQueuePage page) {
    if (!mounted) return;
    setState(() => _activeTotal = page.total ?? page.totalByStatus?['active']);
  }

  void _onClosedMeta(CsQueuePage page) {
    if (!mounted) return;
    setState(() => _closedTotal = page.total ?? page.totalByStatus?['closed']);
  }

  Widget _badge(int? count) {
    final t = context.t.customerService;
    final label = count == null ? t.countUnavailable : '$count';
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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

  /// Tab 内容：文字 + 徽标整体 FittedBox(scaleDown)（320x568 @ textScale
  /// 2.0 不溢出——Tab overflow 修复）。
  Widget _tab(Widget text, int? count) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [text, _badge(count)],
      ),
    );
  }

  /// 组织选择器（AppBar 动作；seat-contexts 列表驱动，A01/A03）。
  Widget _orgSelector() {
    final t = context.t.customerService;
    CsSeatContext? selected;
    for (final c in _contexts) {
      if (c.organizationId == _selectedOrgId) {
        selected = c;
        break;
      }
    }
    final label = selected == null
        ? t.orgSelectorLabel
        : (selected.organizationName.isNotEmpty
              ? selected.organizationName
              : selected.organizationId);
    return PopupMenuButton<String>(
      tooltip: t.orgSelectorLabel,
      onSelected: _switchOrg,
      itemBuilder: (context) => [
        for (final c in _contexts)
          PopupMenuItem<String>(
            value: c.organizationId,
            child: Row(
              children: [
                Icon(
                  c.organizationId == _selectedOrgId
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.tiny),
                Flexible(
                  child: Text(
                    c.organizationName.isNotEmpty
                        ? c.organizationName
                        : c.organizationId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.primary,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final orgId = _selectedOrgId;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.title),
        actions: [if (!_contextsLoading && orgId != null) _orgSelector()],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(child: _tab(Text(t.tabQueued), _queuedTotal)),
            Tab(child: _tab(Text(t.tabActive), _activeTotal)),
            Tab(child: _tab(Text(t.tabClosed), _closedTotal)),
          ],
        ),
      ),
      body: _buildBody(orgId),
    );
  }

  Widget _buildBody(String? orgId) {
    if (_contextsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_contextsError != null) {
      return CsListErrorView(detail: '', onRetry: _loadContexts);
    }
    if (orgId == null || _contexts.isEmpty) {
      // fail-closed 诚实空态：无「active assignment + enabled seat」上下文
      //（普通用户 / seat disabled / 无组织），不猜不垫。
      return Center(
        child: CsListEmptyView(
          icon: CupertinoIcons.person_crop_circle_badge_xmark,
          title: context.t.customerService.noSeatTitle,
          hint: context.t.customerService.noSeatHint,
        ),
      );
    }
    // Key 内嵌 orgId：切 Org 即销毁重建（列表/游标/计数清空重载，A03）。
    return TabBarView(
      controller: _tabController,
      children: [
        CsQueueView(
          key: ValueKey('cs_queued_$orgId'),
          orgId: orgId,
          onPageMeta: _onQueuedMeta,
        ),
        CsSessionListView(
          key: ValueKey('cs_active_$orgId'),
          orgId: orgId,
          status: CsSeatSessionViewStatus.active,
          onPageMeta: _onActiveMeta,
        ),
        CsSessionListView(
          key: ValueKey('cs_closed_$orgId'),
          orgId: orgId,
          status: CsSeatSessionViewStatus.closed,
          onPageMeta: _onClosedMeta,
        ),
      ],
    );
  }
}
