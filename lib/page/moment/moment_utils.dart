import 'package:imboy/store/repository/user_repo_local.dart';

/// 归一化动态的媒体字段(raw List to `List<Map<String, dynamic>>`)
List<Map<String, dynamic>> normalizeMedia(dynamic rawMedia) {
  if (rawMedia is! List) return const [];
  return rawMedia
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

/// 安全获取当前用户 UID，未登录时返回空字符串
/// 直接使用 UserRepoLocal.to.currentUid（不会抛异常）
String currentUidOrEmpty() => UserRepoLocal.to.currentUid;
