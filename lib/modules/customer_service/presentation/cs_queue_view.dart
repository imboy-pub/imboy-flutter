/// 待接队列视图（§12.5.1 / CSM-01）
///
/// - 列表项：客户掩码名、等待时长、来源渠道、最后一条安全摘要；
/// - 服务端键集分页（after_id/limit）+ 下拉刷新 + 触底加载；
/// - CAS 接单：claim 带 expected_version；409 冲突 → 刷新真实状态并提示，
///   不做乐观伪成功；空态/加载态/错误态/离线重试。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_queue_format.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_page.dart'
    show CsWorkspaceCounters;
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart'
    show kCsWorkspacePath;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class CsQueueView extends StatefulWidget {
  /// 服务端计数元数据上报（Tab 徽标唯一数据来源）。
  final ValueChanged<CsWorkspaceCounters>? onCounters;

  const CsQueueView({super.key, this.onCounters});

  @override
  State<CsQueueView> createState() => _CsQueueViewState();
}

class _CsQueueViewState extends State<CsQueueView> {
  final CsApi _api = CsApi();
  final ScrollController _scrollController = ScrollController();

  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  String? _error;
  String _offlineDetail = '';

  List<CsQueueItem> _items = const <CsQueueItem>[];

  /// 下一页游标（服务端 next_after_id；空 = 无更多页）。
  String _nextAfterId = '';

  /// 服务端计数元数据（原样上报，不本地推断）。
  int? _serverTotal;
  Map<String, int>? _serverTotalByStatus;

  /// claim 进行中的会话（防重复点击）。
  String? _claimingSessionId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  /// 把服务端计数元数据原样上报（徽标唯一数据来源）。
  void _emitCounters() {
    widget.onCounters?.call(
      CsWorkspaceCounters(
        queuedTotal: _serverTotal ?? _serverTotalByStatus?['queued'],
        // active/closed 计数本卡服务端未提供（无坐席侧列表端点）。
        active: _serverTotalByStatus?['active'],
        closed: _serverTotalByStatus?['closed'],
      ),
    );
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _offlineDetail = '';
    });
    try {
      final page = await _api.queuePage(limit: kCsQueuePageSize);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextAfterId = page.nextAfterId;
        _serverTotal = page.total;
        _serverTotalByStatus = page.totalByStatus;
        _initialLoading = false;
      });
      _emitCounters();
    } on Object catch (e) {
      if (!mounted) return;
      final t = context.t.customerService;
      setState(() {
        _error = e.toString();
        _offlineDetail = _isNetworkError(e) ? t.offlineHint : '';
        _initialLoading = false;
      });
    }
  }

  bool _isNetworkError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection');
  }

  /// 下拉刷新：回到第一页（无 after_id），整页替换。
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final page = await _api.queuePage(limit: kCsQueuePageSize);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextAfterId = page.nextAfterId;
        _serverTotal = page.total;
        _serverTotalByStatus = page.totalByStatus;
        _error = null;
        _offlineDetail = '';
      });
      _emitCounters();
    } on Object catch (e) {
      if (!mounted) return;
      final t = context.t.customerService;
      setState(() {
        _error = e.toString();
        _offlineDetail = _isNetworkError(e) ? t.offlineHint : '';
      });
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  /// 触底加载下一页（after_id = 服务端游标；无游标则不请求）。
  Future<void> _loadMore() async {
    if (_loadingMore || _refreshing || _initialLoading) return;
    if (_nextAfterId.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.queuePage(
        afterId: _nextAfterId,
        limit: kCsQueuePageSize,
      );
      if (!mounted) return;
      // 键集分页防重：游标之后追加，按 sessionId 去重兜底（乱序重放保护）。
      final known = _items.map((e) => e.sessionId).toSet();
      final merged = List<CsQueueItem>.from(_items)
        ..addAll(page.items.where((e) => !known.contains(e.sessionId)));
      setState(() {
        _items = merged;
        _nextAfterId = page.nextAfterId;
      });
    } on Object {
      // 加载更多失败静默保留当前页（触底会重试），不打断浏览。
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  /// CAS 接单：成功 → 提示 + 刷新真实队列；409 → 刷新真实状态并提示。
  Future<void> _claim(CsQueueItem item) async {
    if (_claimingSessionId != null) return;
    if (item.version <= 0) {
      // 服务端未回显 version：无法安全发起 CAS，先刷新拿真实版本。
      AppLoading.showToast(context.t.customerService.claimConflict);
      await _refresh();
      return;
    }
    setState(() => _claimingSessionId = item.sessionId);
    final t = context.t.customerService;
    try {
      await _api.claim(item.sessionId, expectedVersion: item.version);
      if (!mounted) return;
      AppLoading.showToast(t.claimSuccess);
      // 接单成功后刷新：徽标与列表以服务端真实状态为准。
      await _refresh();
      if (!mounted) return;
      // 接单即经办（CSM-02）：进入坐席会话页（企业消息通道 + 转接/关闭）。
      context.push(
        '$kCsWorkspacePath/sessions/${item.sessionId}'
        '?org_id=${Uri.encodeComponent(item.organizationId)}'
        '&conversation_id=${Uri.encodeComponent(item.conversationId)}'
        '&contact_name=${Uri.encodeComponent(item.contactName)}',
      );
    } on CsApiException catch (e) {
      if (!mounted) return;
      // 不做乐观伪成功：先刷新真实状态，再按语义提示。
      await _refresh();
      if (!mounted) return;
      if (e.isForbidden) {
        AppLoading.showToast(t.claimForbidden);
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
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.wifi_exclamationmark,
                size: 40,
                color: AppColors.iosGray3,
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                t.loadFailedTitle,
                style: context.textStyle(FontSizeType.subheadline),
              ),
              if (_offlineDetail.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.tiny),
                Text(
                  _offlineDetail,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.iosGray,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.regular),
              OutlinedButton.icon(
                onPressed: _loadFirstPage,
                icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
                label: Text(context.t.common.buttonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 96),
              child: Column(
                children: [
                  const Icon(
                    CupertinoIcons.tray,
                    size: 40,
                    color: AppColors.iosGray3,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    t.queuedEmptyTitle,
                    style: context.textStyle(FontSizeType.subheadline),
                  ),
                  const SizedBox(height: AppSpacing.tiny),
                  Text(
                    t.queuedEmptyHint,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: AppColors.iosGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
        itemCount: _items.length + (_nextAfterId.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.regular),
              child: Center(
                child: Text(
                  t.loadingMore,
                  style: context.textStyle(
                    FontSizeType.caption2,
                    color: AppColors.iosGray,
                  ),
                ),
              ),
            );
          }
          return _QueueTile(
            item: _items[index],
            waitingLabel: _waitingLabel(_items[index]),
            claiming: _claimingSessionId == _items[index].sessionId,
            onClaim: () => _claim(_items[index]),
          );
        },
      ),
    );
  }
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        maskedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.subheadline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.tiny),
                    Text(
                      waitingLabel,
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: AppColors.iosOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.tiny),
                Row(
                  children: [
                    if (item.source.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.iosSkyBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${t.sourceLabel}: ${item.source}',
                          style: context.textStyle(
                            FontSizeType.caption2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.tiny),
                    ],
                    Expanded(
                      child: Text(
                        item.hasLastMessage
                            ? context.t.chat.encryptedMessagePlaceholder
                            : context.t.common.dataNotFound,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.iosGray,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          FilledButton.tonal(
            onPressed: claiming ? null : onClaim,
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              textStyle: TextStyle(
                fontSize: FontSizeType.footnote.size,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: claiming
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.claimAction),
          ),
        ],
      ),
    );
  }
}
