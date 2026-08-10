import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// 群投票 API 客户端
///
/// 负责与后端 API 通信，处理群投票相关的网络请求
class GroupVoteApi extends HttpClient {
  String _toVoteId(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  List<String> _toOptionIds(List<dynamic> optionIds) {
    return optionIds
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String? _toRfc3339(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.isEmpty) return null;
      final dt = DateTime.tryParse(value);
      if (dt != null) {
        return dt.toUtc().toIso8601String();
      }
      return value;
    }
    if (value is int) {
      final ms = value > 1000000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms).toUtc().toIso8601String();
    }
    return null;
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// 创建投票
  Future<Map<String, dynamic>?> createVote({
    required String groupId,
    required String title,
    required List<String> options,
    bool anonymous = false,
    bool allowMultiple = false,
    int? endTime,
  }) async {
    final optionItems = options
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => {'option_text': entry.value, 'sort_order': entry.key + 1},
        )
        .toList();

    final data = <String, dynamic>{
      'gid': groupId,
      'title': title,
      'options': optionItems,
      'is_anonymous': anonymous,
      'vote_type': allowMultiple ? 2 : 1,
    };
    final endAt = _toRfc3339(endTime);
    if (endAt != null) data['end_at'] = endAt;

    final resp = await post(API.groupVoteCreate, data: data);

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload as Map<String, dynamic>?;
  }

  /// 获取投票列表
  Future<List<Map<String, dynamic>>> getVotes({
    required String groupId,
    int page = 1,
    int size = 20,
    int? status,
  }) async {
    final query = <String, dynamic>{'gid': groupId, 'page': page, 'size': size};
    if (status != null) query['status'] = status;

    final resp = await get(API.groupVoteList, queryParameters: query);

    // 链路：GroupVoteService.getVotes(rethrow) → group_vote_page(_loadFailed)
    resp.throwIfFailed();

    if (resp.payload == null) {
      return [];
    }

    return _parseList(resp.payload['list']);
  }

  /// 获取投票详情
  Future<Map<String, dynamic>?> getVote({
    required String groupId,
    required dynamic voteId,
  }) async {
    final voteIdText = _toVoteId(voteId);
    if (voteIdText.isEmpty) return null;
    final resp = await get(
      API.groupVoteDetail,
      queryParameters: {'gid': groupId, 'vote_id': voteIdText},
    );

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload as Map<String, dynamic>?;
  }

  /// 投票
  Future<bool> castVote({
    required String groupId,
    required dynamic voteId,
    required List<dynamic> optionIds,
  }) async {
    final voteIdText = _toVoteId(voteId);
    final optionIdsText = _toOptionIds(optionIds);
    if (voteIdText.isEmpty || optionIdsText.isEmpty) return false;
    final resp = await post(
      API.groupVoteCast,
      data: {
        'gid': groupId,
        'vote_id': voteIdText,
        'option_ids': optionIdsText,
      },
    );
    return resp.ok;
  }

  /// 更新投票
  Future<bool> updateVote({
    required String groupId,
    required dynamic voteId,
    required List<dynamic> optionIds,
  }) async {
    final voteIdText = _toVoteId(voteId);
    final optionIdsText = _toOptionIds(optionIds);
    if (voteIdText.isEmpty || optionIdsText.isEmpty) return false;
    final data = <String, dynamic>{
      'gid': groupId,
      'vote_id': voteIdText,
      'option_ids': optionIdsText,
    };

    final resp = await post(API.groupVoteUpdate, data: data);
    return resp.ok;
  }

  /// 取消投票
  Future<bool> cancelVote({
    required String groupId,
    required dynamic voteId,
  }) async {
    final voteIdText = _toVoteId(voteId);
    if (voteIdText.isEmpty) return false;
    final resp = await post(
      API.groupVoteCancel,
      data: {'gid': groupId, 'vote_id': voteIdText},
    );
    return resp.ok;
  }

  /// 结束投票
  Future<bool> closeVote({
    required String groupId,
    required dynamic voteId,
  }) async {
    final voteIdText = _toVoteId(voteId);
    if (voteIdText.isEmpty) return false;
    final resp = await post(
      API.groupVoteClose,
      data: {'gid': groupId, 'vote_id': voteIdText},
    );
    return resp.ok;
  }

  /// 获取我参与的投票列表。
  ///
  /// 生产接口的历史兼容层对 `vote_id` 同时存在外部 TSID 和数值主键
  /// 两种契约；详情/投票操作使用外部 ID，而 my_vote 可能只接受数值 ID。
  Future<List<Map<String, dynamic>>> getMyVotes({
    dynamic voteId,
    dynamic numericVoteId,
  }) async {
    final candidates = <String>{_toVoteId(voteId), _toVoteId(numericVoteId)}
      ..removeWhere((value) => value.isEmpty);
    if (candidates.isEmpty) {
      return [];
    }

    IMBoyHttpResponse? lastResponse;
    for (final candidate in candidates) {
      final resp = await get(
        API.groupVoteMyVote,
        queryParameters: {'vote_id': candidate},
      );
      lastResponse = resp;
      if (resp.ok) {
        if (resp.payload == null) return [];
        return [
          Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
        ];
      }
      if (resp.msg.contains('未投票') ||
          resp.msg.toLowerCase().contains('not voted')) {
        return [];
      }
    }

    // 空列表 == "你还没投票"，网络失败绝不能压成这个：已投票的人会看到
    // 可投票界面并重复提交。链路：GroupVoteService.getMyVotes(rethrow)
    // → group_vote_detail_page(_loadFailed)
    lastResponse!.throwIfFailed();
    return [];
  }
}
