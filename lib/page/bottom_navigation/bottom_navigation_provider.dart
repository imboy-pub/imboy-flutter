import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

part 'bottom_navigation_provider.g.dart';

/// 底部导航状态提供者
@riverpod
class BottomNavigationNotifier extends _$BottomNavigationNotifier {
  @override
  int build() => 0;

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
  Set<String> build() => <String>{};

  /// 计算新好友提醒计数
  Future<void> countReminders() async {
    if (!UserRepoLocal.to.isLoggedIn) return;

    final items = await SqliteService.to.query(
      NewFriendRepo.tableName,
      columns: [NewFriendRepo.from],
      where:
          '${NewFriendRepo.status}=? AND ${NewFriendRepo.uid}=? AND ${NewFriendRepo.to}=?',
      whereArgs: [0, UserRepoLocal.to.currentUid, UserRepoLocal.to.currentUid],
      orderBy: "${NewFriendRepo.createdAt} desc",
      limit: 1000,
    );

    // 检查 provider 是否仍然 mounted
    if (!ref.mounted) return;

    final Set<String> newFroms = {
      for (var e in items)
        if (e[NewFriendRepo.from] != null) e[NewFriendRepo.from],
    };

    // 再次检查（防止在异步间隙中被 disposed）
    if (!ref.mounted) return;

    state = newFroms;
  }
}
