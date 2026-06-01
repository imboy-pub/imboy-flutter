/// 社交关系域值对象 barrel / social_graph value objects（T0.3）。
///
/// 社交关系（好友/拉黑）以 UserId 为键，复用 identity 域的权威 UserId，
/// 避免「双实现漂移」（计划风险项）。如后续出现 social_graph 专属 VO
/// （如 FriendshipId），在此目录新增并经本 barrel 导出。
library;

export 'package:imboy/modules/identity/domain/value/user_id.dart';
