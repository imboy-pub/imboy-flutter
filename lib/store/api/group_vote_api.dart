import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
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
    debugPrint("GroupVoteApi_createVote resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload;
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
    debugPrint("GroupVoteApi_getVotes resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
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
    debugPrint("GroupVoteApi_getVote resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return resp.payload;
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
    debugPrint("GroupVoteApi_castVote resp: ok=${resp.ok}");
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
    debugPrint("GroupVoteApi_updateVote resp: ok=${resp.ok}");
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
    debugPrint("GroupVoteApi_cancelVote resp: ok=${resp.ok}");
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
    debugPrint("GroupVoteApi_closeVote resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 获取我参与的投票列表
  Future<List<Map<String, dynamic>>> getMyVotes({dynamic voteId}) async {
    final voteIdText = _toVoteId(voteId);
    if (voteIdText.isEmpty) {
      return [];
    }
    final resp = await get(
      API.groupVoteMyVote,
      queryParameters: {'vote_id': voteIdText},
    );
    debugPrint("GroupVoteApi_getMyVotes resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return [];
    }

    return [Map<String, dynamic>.from(resp.payload)];
  }
}
