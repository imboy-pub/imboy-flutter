/// 坐席会话列表通用分页骨架（APP-M01-A02）
///
/// queued / active / closed 三个视图共用同一套力学（单一实现，防三处
/// 漂移）：
/// - 服务端键集分页（`after_id`/`limit`）+ 下拉刷新 + 触底加载；
/// - 空态 / 初载错误（含离线提示与重试）/ 加载更多静默保页；
/// - 计数纪律：徽标计数**只取服务端键**（`total` / `total_by_status`），
///   通过 [CsPagedSessionList.onPageMeta] 原样上报，禁止本地行数推断。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 键集分页请求（游标语义与 A0 冻结一致：after_id = 上一页末条 id）。
typedef CsPagedFetch = Future<CsQueuePage> Function({
  String? afterId,
  int? limit,
});

/// 行构建（列表持有 items，逐行交付服务端投影）。
typedef CsPagedItemBuilder = Widget Function(
  BuildContext context,
  CsQueueItem item,
);

class CsPagedSessionList extends StatefulWidget {
  /// 服务端分页取数（org 作用域在调用方闭包内固定，切换 Org 由外部
  /// 以新 Key 重建本组件 → 状态整体清空，不串租户缓存）。
  final CsPagedFetch fetchPage;

  /// 每页元数据（items + 游标 + 服务端计数）原样上报。
  final ValueChanged<CsQueuePage>? onPageMeta;

  /// 行构建（index < items.length）。
  final CsPagedItemBuilder itemBuilder;

  /// 空态视图（服务端首页返回 0 行）。
  final Widget emptyView;

  const CsPagedSessionList({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    required this.emptyView,
    this.onPageMeta,
  });

  @override
  CsPagedSessionListState createState() => CsPagedSessionListState();
}

class CsPagedSessionListState extends State<CsPagedSessionList> {
  final ScrollController _scrollController = ScrollController();

  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  String? _error;
  String _offlineDetail = '';

  List<CsQueueItem> _items = const <CsQueueItem>[];

  /// 下一页游标（服务端 next_after_id；空 = 无更多页）。
  String _nextAfterId = '';

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

  /// 下拉刷新：回到第一页（无 after_id），整页替换（清空旧游标与列表）。
  Future<void> refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final page = await widget.fetchPage(limit: kCsQueuePageSize);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextAfterId = page.nextAfterId;
        _error = null;
        _offlineDetail = '';
      });
      widget.onPageMeta?.call(page);
    } on Object catch (e) {
      if (!mounted) return;
      _setError(e);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _offlineDetail = '';
    });
    try {
      final page = await widget.fetchPage(limit: kCsQueuePageSize);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextAfterId = page.nextAfterId;
        _initialLoading = false;
      });
      widget.onPageMeta?.call(page);
    } on Object catch (e) {
      if (!mounted) return;
      _setError(e);
      setState(() => _initialLoading = false);
    }
  }

  void _setError(Object e) {
    final t = context.t.customerService;
    _error = e.toString();
    _offlineDetail = csIsNetworkError(e) ? t.offlineHint : '';
  }

  /// 触底加载下一页（after_id = 服务端游标；无游标则不请求）。
  Future<void> _loadMore() async {
    if (_loadingMore || _refreshing || _initialLoading) return;
    if (_nextAfterId.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await widget.fetchPage(
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

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return CsListErrorView(detail: _offlineDetail, onRetry: _loadFirstPage);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [widget.emptyView],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: refresh,
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
          return widget.itemBuilder(context, _items[index]);
        },
      ),
    );
  }
}

/// 列表错误视图（含离线提示与重试）。
class CsListErrorView extends StatelessWidget {
  final String detail;
  final VoidCallback onRetry;

  const CsListErrorView({
    super.key,
    required this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
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
            if (detail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.tiny),
              Text(
                detail,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.iosGray,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.regular),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(CupertinoIcons.arrow_clockwise, size: 16),
              label: Text(context.t.common.buttonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表空态视图（图标 + 标题 + 提示；文案由调用方给，本文件不硬编码）。
class CsListEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;

  const CsListEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.iosGray3),
          const SizedBox(height: AppSpacing.medium),
          Text(title, style: context.textStyle(FontSizeType.subheadline)),
          const SizedBox(height: AppSpacing.tiny),
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
    );
  }
}

/// 网络类失败启发判定（离线提示；与既有 cs_queue_view 口径一致）。
bool csIsNetworkError(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('socket') ||
      s.contains('network') ||
      s.contains('connection');
}
