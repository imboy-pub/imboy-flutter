import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/group/vote/group_vote_detail_page.dart';
import 'package:imboy/page/group/vote/group_vote_page.dart';

List<RouteBase> groupVoteRoutes() => <RouteBase>[
  GoRoute(
    path: '/group/:groupId/vote',
    name: 'group_vote',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: GroupVotePage(
        groupId: state.pathParameters['groupId'] ?? '',
        autoCreate: state.uri.queryParameters['create'] == '1',
      ),
    ),
  ),
  GoRoute(
    path: '/group/:groupId/vote/:voteId',
    name: 'group_vote_detail',
    pageBuilder: (context, state) => CupertinoPage(
      key: state.pageKey,
      child: GroupVoteDetailPage(
        groupId: state.pathParameters['groupId'] ?? '',
        voteId: state.pathParameters['voteId'] ?? '',
      ),
    ),
  ),
];
