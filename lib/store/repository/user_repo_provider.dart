import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// UserRepoLocal 的 Riverpod Provider
/// 提供对用户本地仓库的访问
final userRepoProvider = Provider<UserRepoLocal>((ref) {
  return UserRepoLocal.to;
});
