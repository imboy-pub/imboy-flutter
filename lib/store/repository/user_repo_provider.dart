import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// UserRepoLocal 的 Riverpod Provider
/// 提供对用户本地仓库的访问
final userRepoProvider = Provider<UserRepoLocal>((ref) {
  return UserRepoLocal.to;
});

/// 当前用户（响应式）。
///
/// UserRepoLocal（ChangeNotifier）在本地用户缓存变更（changeInfo /
/// changeSetting / loginAfter / quitLogin）后 notifyListeners，本桥接
/// provider invalidateSelf 重建，所有 watch 方（工作区壳顶栏头像、账户
/// Sheet、我的页等）随之刷新——上传头像等资料变更即时可见，无需等整页
/// 刷新。Riverpod 3 已移除 ChangeNotifierProvider，故用显式 listener 桥接；
/// 单例由裸 Provider 持有、无人调 dispose，监听随 provider 生命周期增删。
final currentUserProvider = Provider<UserModel?>((ref) {
  final repo = ref.watch(userRepoProvider);
  void onChange() => ref.invalidateSelf();
  repo.addListener(onChange);
  ref.onDispose(() => repo.removeListener(onChange));
  return repo.currentUser;
});
