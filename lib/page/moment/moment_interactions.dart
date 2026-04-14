import 'package:imboy/store/model/model_parse_utils.dart';

/// 返回一个新 moment map，切换 `liked` 并相应增减 `stats.like_count`。
///
/// - 输入 map 和其子 `stats` map 都不会被修改（调用方可保留原对象用于回滚）。
/// - `like_count` 不会下溢到负数；取消点赞时下限为 0。
/// - 缺失字段按默认值处理：`liked` 缺失视为 false，`stats` 缺失视为空 map。
///
/// Feed / Detail 页面共用的乐观更新辅助。
Map<String, dynamic> applyOptimisticLikeToggle(Map<String, dynamic> moment) {
  final liked = parseModelBool(moment['liked']);
  final rawStats = moment['stats'];
  final oldStats = rawStats is Map
      ? Map<String, dynamic>.from(rawStats)
      : <String, dynamic>{};
  final likeCount = parseModelInt(oldStats['like_count']);
  final nextLikeCount = liked
      ? (likeCount > 0 ? likeCount - 1 : 0)
      : likeCount + 1;
  final nextStats = Map<String, dynamic>.from(oldStats);
  nextStats['like_count'] = nextLikeCount;
  final next = Map<String, dynamic>.from(moment);
  next['liked'] = !liked;
  next['stats'] = nextStats;
  return next;
}
