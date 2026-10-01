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

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_presence_controller.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final CsApi _api = CsApi();

  late final TabController _tabController;

  /// 可用坐席上下文（active assignment + enabled seat；服务端权威）。
  List<CsSeatContext> _contexts = const <CsSeatContext>[];
  bool _contextsLoading = true;
  String? _contextsError;
  int _contextsGeneration = 0;

  /// 当前选中 Org（seat-contexts 列表驱动；切换即清空重载）。
  String? _selectedOrgId;

  /// 当前选中 Org 的首个 workspace（SSE 事件流 query 种子；可空由流
  /// 权威解析）。
  String _selectedWorkspaceId = '';

  /// APP-M02-A02：坐席事件流（org 作用域）。queue/session/assignment/
  /// seat 事件只触发三视图权威刷新（debounce 合并，无请求风暴）；
  /// 信封 payload 不是业务真源。
  CsSeatEventsStream? _events;
  final StreamController<void> _refreshSignal =
      StreamController<void>.broadcast();
  Timer? _refreshDebounce;

  /// CS-APP-02：presence 控制器（前台心跳 / 后台停发 / resume 重同步）。
  CsPresenceController? _presence;
  bool _presenceBusy = false;

  /// 服务端计数（逐 Tab；null = 服务端未提供，UI 显示占位符）。
  int? _queuedTotal;
  int? _activeTotal;
  int? _closedTotal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _loadContexts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopEvents();
    _refreshSignal.close();
    _tabController.dispose();
    super.dispose();
  }

  /// CS-RUNTIME-04：App lifecycle → presence 门控。前台周期心跳、进后台
  /// 停发（90 秒无心跳服务端自然 offline——不保持假 online）、resume
  /// 立即补跳 + 三视图权威重同步（onResync）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _presence == null) {
      unawaited(_loadContexts());
      return;
    }
    unawaited(
      _presence?.onAppLifecycleStateChanged(state.name) ?? Future<void>.value(),
    );
  }

  /// 拉取坐席上下文清单（seat-contexts 列表驱动，APP-M01-A01）。
  Future<void> _loadContexts() async {
    final generation = ++_contextsGeneration;
    _stopEvents();
    setState(() {
      _contextsLoading = true;
      _contextsError = null;
      _queuedTotal = _activeTotal = _closedTotal = null;
    });
    try {
      final result = await _api.seatContexts();
      if (!mounted || generation != _contextsGeneration) return;
      // 只列可用坐席上下文（active assignment + enabled seat 同时成立）。
      final eligible = result.contexts
          .where((c) => c.isEligible)
          .toList(growable: false);
      final selected =
          eligible
              .where((c) => c.organizationId == _selectedOrgId)
              .firstOrNull ??
          eligible.firstOrNull;
      setState(() {
        _contexts = eligible;
        _contextsLoading = false;
        _selectedOrgId = selected?.organizationId;
        _selectedWorkspaceId = selected?.workspaces.firstOrNull?.id ?? '';
      });
      _startEvents();
    } on Object catch (e) {
      if (!mounted || generation != _contextsGeneration) return;
      setState(() {
        _contextsError = e.toString();
        _contextsLoading = false;
        _contexts = const <CsSeatContext>[];
        _selectedOrgId = null;
        _selectedWorkspaceId = '';
      });
    }
  }

  /// APP-M02-A02：按当前 Org（及其首个 workspace）启动坐席事件流；
  /// CS-APP-02 同时启动 presence 心跳（同 org 作用域；切 Org 重建）。
  void _startEvents() {
    _stopEvents();
    final orgId = _selectedOrgId;
    if (orgId == null) return;
    final stream = CsSeatEventsStream(
      orgId: orgId,
      workspaceId: _selectedWorkspaceId,
    );
    _events = stream;
    stream.start(
      onEvent: (event) {
        if (mounted && identical(stream, _events)) _onSeatEvent(event);
      },
      onError: (error) {
        if (!mounted || !identical(stream, _events)) return;
        if (error is CsSseOpenException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          _stopEvents();
          setState(() {
            _contextsError = error.toString();
            _contexts = const [];
            _selectedOrgId = null;
            _selectedWorkspaceId = '';
            _queuedTotal = _activeTotal = _closedTotal = null;
          });
        }
      },
    );
    _startPresence(orgId);
  }

  void _stopEvents() {
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
    _events?.dispose();
    _events = null;
    _presence?.stop();
    _presence = null;
    _presenceBusy = false;
  }

  /// 启动 presence 心跳（resume 重同步 = 三视图权威刷新，与 SSE 事件
  /// 同一信号通道；presence 变化即重建状态条）。workspaceId 与 SSE 同源
  /// （CSB-02R workspace 门必填——缺失时控制器诚实不发）。
  void _startPresence(String orgId) {
    final controller = CsPresenceController(
      csApi: _api,
      orgId: orgId,
      workspaceId: _selectedWorkspaceId,
      onResync: () async {
        if (mounted) await _loadContexts();
      },
      onPresenceChanged: () {
        if (mounted) setState(() {});
      },
    );
    _presence = controller;
    controller.start();
  }

  void _onSeatEvent(CsSseEnvelope e) {
    switch (e.type) {
      case CsSseEnvelope.typeAssignmentChanged:
      case CsSseEnvelope.typeSeatChanged:
      case CsSseEnvelope.typeResyncRequired:
        unawaited(_loadContexts());
        break;
      case CsSseEnvelope.typeQueueChanged:
      case CsSseEnvelope.typeSessionChanged:
        // 事件只触发权威刷新；250ms debounce 合并事件突发（无风暴）。
        _refreshDebounce?.cancel();
        _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
          if (mounted && !_refreshSignal.isClosed) {
            _refreshSignal.add(null);
          }
        });
      default:
        break;
    }
  }

  /// APP-M01-A03：切换 Org → 计数清空 + 三视图以新 Key 重建（列表/游标
  /// 随组件销毁清空），并以新 org 作用域重载。
  void _switchOrg(String orgId) {
    if (orgId == _selectedOrgId) return;
    String wsId = '';
    for (final c in _contexts) {
      if (c.organizationId == orgId) {
        wsId = c.workspaces.isNotEmpty ? c.workspaces.first.id : '';
        break;
      }
    }
    setState(() {
      _selectedOrgId = orgId;
      _selectedWorkspaceId = wsId;
      _queuedTotal = null;
      _activeTotal = null;
      _closedTotal = null;
    });
    _startEvents();
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

  // ==================== presence 状态条（CS-APP-02 / CS-RUNTIME-04） ====================

  /// presence 运行态展示语义（服务端派生值，客户端只读）：
  /// - 治理开关（enabled）与运行态（online/away/busy/offline）**分离**——
  ///   enabled=false 显示「席位已停用」（治理事实），不显示任何运行态；
  /// - lastPresence == null（从未成功/心跳失败）→「状态不可用」（诚实
  ///   降级：本地不造状态，断网不显示 online）；
  /// - 手动 away / 恢复自动经 PUT（manual_status），回填服务端派生结果。
  Widget? _presenceAction() {
    if (_contextsLoading || _selectedOrgId == null) return null;
    return PopupMenuButton<String>(
      tooltip: context.t.customerService.presenceMenuLabel,
      onSelected: _onPresenceMenuSelected,
      itemBuilder: _presenceMenuItems,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        child: _presenceChip(),
      ),
    );
  }

  Widget _presenceChip() {
    final t = context.t.customerService;
    final presence = _presence?.lastPresence;
    if (presence == null) {
      // 从未成功 / 心跳失败：诚实降级（不显示任何运行态）。
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.minus_circle,
            size: 14,
            color: AppColors.iosGray,
          ),
          const SizedBox(width: AppSpacing.tiny),
          Text(
            t.presenceUnavailable,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
        ],
      );
    }
    if (!presence.enabled) {
      // 治理开关关闭：治理事实展示（非运行态）。
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.lock_circle,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.tiny),
          Text(
            t.seatDisabledNotice,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.warning,
            ),
          ),
        ],
      );
    }
    final (label, color) = switch (presence.status) {
      CsPresenceStatus.online => (t.presenceStatusOnline, AppColors.iosGreen),
      CsPresenceStatus.away => (t.presenceStatusAway, AppColors.iosYellow),
      CsPresenceStatus.busy => (t.presenceStatusBusy, AppColors.iosOrange),
      CsPresenceStatus.offline => (t.presenceStatusOffline, AppColors.iosGray),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.circle_fill, size: 8, color: color),
        const SizedBox(width: AppSpacing.tiny),
        Text(
          label,
          style: context.textStyle(FontSizeType.footnote, color: color),
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _presenceMenuItems(BuildContext context) {
    final t = context.t.customerService;
    final presence = _presence?.lastPresence;
    final header = presence == null
        ? t.presenceUnavailable
        : !presence.enabled
        ? t.seatDisabledNotice
        : switch (presence.status) {
            CsPresenceStatus.online => t.presenceStatusOnline,
            CsPresenceStatus.away => t.presenceStatusAway,
            CsPresenceStatus.busy => t.presenceStatusBusy,
            CsPresenceStatus.offline => t.presenceStatusOffline,
          };
    return [
      PopupMenuItem<String>(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(header, style: context.textStyle(FontSizeType.footnote)),
            if (presence != null && presence.enabled)
              Text(
                t.presenceCapacityLabel(
                  active: presence.activeCount,
                  max: presence.maxConcurrent,
                ),
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: AppColors.iosGray,
                ),
              ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      if (presence != null && presence.enabled && _presence != null)
        PopupMenuItem<String>(
          value: presence.manualStatus == 'away' ? 'clear' : 'away',
          child: Text(
            presence.manualStatus == 'away'
                ? t.presenceResumeAction
                : t.presenceAwayAction,
          ),
        ),
    ];
  }

  Future<void> _onPresenceMenuSelected(String value) async {
    final controller = _presence;
    if (controller == null || _presenceBusy) return;
    setState(() => _presenceBusy = true);
    try {
      // away=手动离开（优先于自动派生）；clear=恢复自动（心跳/负载派生）。
      await controller.setManualStatus(value == 'away' ? 'away' : null);
    } on Object {
      // 失败保底：回填当前视图（诚实——不伪成功）。
    } finally {
      if (mounted && identical(controller, _presence)) {
        setState(() => _presenceBusy = false);
      }
    }
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
        actions: [
          ?_presenceAction(),
          if (!_contextsLoading && orgId != null) _orgSelector(),
        ],
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
          workspaceId: _selectedWorkspaceId,
          onPageMeta: _onQueuedMeta,
          refreshSignal: _refreshSignal.stream,
        ),
        CsSessionListView(
          key: ValueKey('cs_active_$orgId'),
          orgId: orgId,
          status: CsSeatSessionViewStatus.active,
          workspaceId: _selectedWorkspaceId,
          onPageMeta: _onActiveMeta,
          refreshSignal: _refreshSignal.stream,
        ),
        CsSessionListView(
          key: ValueKey('cs_closed_$orgId'),
          orgId: orgId,
          status: CsSeatSessionViewStatus.closed,
          workspaceId: _selectedWorkspaceId,
          onPageMeta: _onClosedMeta,
          refreshSignal: _refreshSignal.stream,
        ),
      ],
    );
  }
}
