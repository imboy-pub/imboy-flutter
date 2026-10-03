import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

part 'bottom_navigation_provider.g.dart';

/// 底部导航状态提供者
@Riverpod(keepAlive: true)
class BottomNavigationNotifier extends _$BottomNavigationNotifier {
  @override
  int build() {
    ref.watch(currentUserProvider.select((user) => user?.uid ?? ''));
    return 0;
  }

  /// 改变底部导航栏索引
  void changeIndex(int index) {
    // 检查WS链接状态
    WebSocketService.to.openSocket(from: 'changeBottomBarIndex_$index');
    state = index;
  }
}

/// 新好友提醒计数器提供者
@riverpod
class NewFriendRemindNotifier extends _$NewFriendRemindNotifier {
  @override
  Set<String> build() {
    ref.watch(currentUserProvider.select((user) => user?.uid ?? ''));
    _requestGeneration++;
    return <String>{};
  }

  int _requestGeneration = 0;

  /// 计算新好友提醒计数
  Future<void> countReminders() async {
    final user = UserRepoLocal.to;
    final uid = user.currentUid;
    final session = user.sessionGeneration;
    final request = ++_requestGeneration;
    if (uid.isEmpty || user.isClearingSession) return;

    final items = await SqliteService.to.query(
      NewFriendRepo.tableName,
      columns: [NewFriendRepo.from],
      where:
          '${NewFriendRepo.status}=? AND ${NewFriendRepo.uid}=? AND ${NewFriendRepo.to}=?',
      whereArgs: [0, uid, uid],
      orderBy: "${NewFriendRepo.createdAt} desc",
      limit: 1000,
    );

    // 检查 provider 是否仍然 mounted
    if (!ref.mounted ||
        request != _requestGeneration ||
        uid != user.currentUid ||
        !user.isCurrentSession(session) ||
        user.isClearingSession) {
      return;
    }

    final Set<String> newFroms = {
      for (var e in items)
        if (e[NewFriendRepo.from] != null) '${e[NewFriendRepo.from]}',
    };
    state = newFroms;
  }
}
