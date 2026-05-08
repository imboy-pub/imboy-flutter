/// 朋友圈通知中心 Provider（Slice A-3）。
///
/// 持有 [MomentNotifyState]，提供 CRUD 操作并监听
/// [MomentNotifyUnreadChangedEvent] 自动刷新红点。
///
/// 设计要点：
///   - `currentUid` 快照在 build 阶段一次性读取，避免中途切换账号污染
///   - `markAllRead` / `clearAll` 成功后发 `refresh` trigger 事件让其他消费者
///     （如底部导航红点）同步
///   - 订阅在 `ref.onDispose` 时取消，防泄漏
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/moment/moment_notify/moment_notify_state.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/repository/moment_notify_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MomentNotifyNotifier extends Notifier<MomentNotifyState> {
  static const int _pageSize = 30;
  late final MomentNotifyRepo _repo;
  late final String _currentUid;
  StreamSubscription<MomentNotifyUnreadChangedEvent>? _unreadSub;

  @override
  MomentNotifyState build() {
    _repo = MomentNotifyRepo();
    _currentUid = UserRepoLocal.to.currentUid;

    _unreadSub = AppEventBus.on<MomentNotifyUnreadChangedEvent>().listen((e) {
      // S2C 插入或跨页操作触发的红点刷新 → 重读未读数
      // 列表数据则由 refresh() 显式调用方决定是否刷新（避免频繁抖动）
      state = state.copyWith(unreadCount: e.unreadCount);
    });

    ref.onDispose(() {
      _unreadSub?.cancel();
    });

    // 首次构建异步加载未读数（不阻塞 build），保证 app 启动即能正确显示红点。
    // 失败容忍：repo 抛异常时保持 unreadCount=0，由后续 S2C 事件或手动刷新修复。
    unawaited(_seedInitialUnread());

    return const MomentNotifyState();
  }

  Future<void> _seedInitialUnread() async {
    if (_currentUid.isEmpty) return;
    try {
      final unread = await _repo.unreadCount(_currentUid);
      if (unread > 0) {
        state = state.copyWith(unreadCount: unread);
      }
    } on Exception {
      // 静默失败：首次种子读不影响后续事件驱动的红点更新
    }
  }

  /// 消费完 errorMessage 后清除（配合 UI ref.listen 消费后调用）。
  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(clearError: true);
  }

  /// 下拉刷新：重置分页并加载第一页 + 同步未读数。
  Future<void> refresh() async {
    if (_currentUid.isEmpty) return;
    state = state.copyWith(
      isLoading: true,
      page: 0,
      hasMore: true,
      clearError: true,
    );
    try {
      final items = await _repo.page(
        userId: _currentUid,
        limit: _pageSize,
        offset: 0,
      );
      final unread = await _repo.unreadCount(_currentUid);
      state = state.copyWith(
        items: items,
        page: 1,
        hasMore: items.length >= _pageSize,
        unreadCount: unread,
        isLoading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'refresh_failed: $e',
      );
    }
  }

  /// 触底加载更多。
  Future<void> loadMore() async {
    if (_currentUid.isEmpty) return;
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.page(
        userId: _currentUid,
        limit: _pageSize,
        offset: state.items.length,
      );
      state = state.copyWith(
        items: [...state.items, ...items],
        page: state.page + 1,
        hasMore: items.length >= _pageSize,
        isLoading: false,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'load_more_failed: $e',
      );
    }
  }

  /// 标记单条已读。内存与 DB 同步。
  Future<void> markRead(int id) async {
    if (_currentUid.isEmpty) return;
    final affected = await _repo.markRead(id);
    if (affected <= 0) return;
    final updated = state.items
        .map((m) => m.id == id ? m.copyWith(isRead: true) : m)
        .toList(growable: false);
    final newUnread = await _repo.unreadCount(_currentUid);
    state = state.copyWith(items: updated, unreadCount: newUnread);
    AppEventBus.fire(
      MomentNotifyUnreadChangedEvent(
        unreadCount: newUnread,
        trigger: 'mark_read',
      ),
    );
  }

  /// 标记当前用户全部已读。
  Future<void> markAllRead() async {
    if (_currentUid.isEmpty) return;
    final affected = await _repo.markAllRead(_currentUid);
    if (affected <= 0 && state.unreadCount == 0) return;
    final updated = state.items
        .map((m) => m.isRead ? m : m.copyWith(isRead: true))
        .toList(growable: false);
    state = state.copyWith(items: updated, unreadCount: 0);
    AppEventBus.fire(
      const MomentNotifyUnreadChangedEvent(
        unreadCount: 0,
        trigger: 'mark_all_read',
      ),
    );
  }

  /// 删除单条通知。
  Future<void> delete(int id) async {
    if (_currentUid.isEmpty) return;
    final affected = await _repo.delete(id);
    if (affected <= 0) return;
    final filtered = state.items
        .where((m) => m.id != id)
        .toList(growable: false);
    final newUnread = await _repo.unreadCount(_currentUid);
    state = state.copyWith(items: filtered, unreadCount: newUnread);
    AppEventBus.fire(
      MomentNotifyUnreadChangedEvent(
        unreadCount: newUnread,
        trigger: 'refresh',
      ),
    );
  }

  /// 清空全部。
  Future<void> clearAll() async {
    if (_currentUid.isEmpty) return;
    final affected = await _repo.clearAll(_currentUid);
    if (affected <= 0 && state.items.isEmpty) return;
    state = state.copyWith(items: const [], unreadCount: 0, hasMore: false);
    AppEventBus.fire(
      const MomentNotifyUnreadChangedEvent(
        unreadCount: 0,
        trigger: 'clear_all',
      ),
    );
  }
}

final momentNotifyProvider =
    NotifierProvider<MomentNotifyNotifier, MomentNotifyState>(
      MomentNotifyNotifier.new,
    );
