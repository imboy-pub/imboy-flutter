import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/service/event_bus.dart' show AppEventBus;
import 'package:imboy/service/events/base_event.dart';
import 'package:imboy/store/api/group_vote_api.dart';

/// 群投票服务
///
/// 负责协调 API 和本地存储，处理群投票业务逻辑
///
/// Temporary compatibility wrapper for the group_collab module shell.
/// New callers should prefer `package:imboy/modules/group_collab/public.dart`.
class GroupVoteService {
  static final GroupVoteService to = GroupVoteService._privateConstructor();
  GroupVoteService._privateConstructor();

  final GroupVoteApi _api = GroupVoteApi();

  // ==================== 投票创建与管理 ====================

  /// 创建投票
  Future<Map<String, dynamic>?> createVote({
    required String groupId,
    required String title,
    required List<String> options,
    bool anonymous = false,
    bool allowMultiple = false,
    int? endTime,
  }) async {
    try {
      final result = await _api.createVote(
        groupId: groupId,
        title: title,
        options: options,
        anonymous: anonymous,
        allowMultiple: allowMultiple,
        endTime: endTime,
      );
      if (result != null) {
        iPrint('GroupVoteService: 创建投票成功 - $title');
        AppEventBus.fire(VoteCreatedEvent(groupId: groupId, data: result));
      }
      return result;
    } catch (e) {
      iPrint('GroupVoteService: 创建投票失败 - $e');
      return null;
    }
  }

  /// 获取投票详情
  Future<Map<String, dynamic>?> getVote({
    required String groupId,
    required dynamic voteId,
  }) async {
    try {
      return await _api.getVote(groupId: groupId, voteId: voteId);
    } catch (e) {
      iPrint('GroupVoteService: 获取投票详情失败 - $e');
      return null;
    }
  }

  /// 获取群的投票列表
  Future<List<Map<String, dynamic>>> getVotes({
    required String groupId,
    int page = 1,
    int size = 20,
    int? status,
  }) async {
    try {
      return await _api.getVotes(
        groupId: groupId,
        page: page,
        size: size,
        status: status,
      );
    } catch (e) {
      iPrint('GroupVoteService: 获取投票列表失败 - $e');
      return [];
    }
  }

  /// 获取我参与的投票列表
  Future<List<Map<String, dynamic>>> getMyVotes({dynamic voteId}) async {
    try {
      return await _api.getMyVotes(voteId: voteId);
    } catch (e) {
      iPrint('GroupVoteService: 获取我的投票失败 - $e');
      return [];
    }
  }

  // ==================== 投票操作 ====================

  /// 投票
  Future<bool> castVote({
    required String groupId,
    required dynamic voteId,
    required List<dynamic> optionIds,
  }) async {
    try {
      final success = await _api.castVote(
        groupId: groupId,
        voteId: voteId,
        optionIds: optionIds,
      );
      if (success) {
        iPrint('GroupVoteService: 投票成功 - $voteId');
        AppEventBus.fire(
          VoteCastEvent(groupId: groupId, voteId: voteId.toString()),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupVoteService: 投票失败 - $e');
      return false;
    }
  }

  /// 更新投票
  Future<bool> updateVote({
    required String groupId,
    required dynamic voteId,
    required List<dynamic> optionIds,
  }) async {
    try {
      final success = await _api.updateVote(
        groupId: groupId,
        voteId: voteId,
        optionIds: optionIds,
      );
      if (success) {
        iPrint('GroupVoteService: 更新投票成功 - $voteId');
        AppEventBus.fire(
          VoteCastEvent(groupId: groupId, voteId: voteId.toString()),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupVoteService: 更新投票失败 - $e');
      return false;
    }
  }

  /// 关闭投票
  Future<bool> closeVote({
    required String groupId,
    required dynamic voteId,
  }) async {
    try {
      final success = await _api.closeVote(groupId: groupId, voteId: voteId);
      if (success) {
        iPrint('GroupVoteService: 关闭投票成功 - $voteId');
        AppEventBus.fire(
          VoteEndedEvent(groupId: groupId, voteId: voteId.toString()),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupVoteService: 关闭投票失败 - $e');
      return false;
    }
  }

  /// 取消投票
  Future<bool> cancelVote({
    required String groupId,
    required dynamic voteId,
  }) async {
    try {
      final success = await _api.cancelVote(groupId: groupId, voteId: voteId);
      if (success) {
        iPrint('GroupVoteService: 取消投票成功 - $voteId');
        AppEventBus.fire(
          VoteDeletedEvent(groupId: groupId, voteId: voteId.toString()),
        );
      }
      return success;
    } catch (e) {
      iPrint('GroupVoteService: 取消投票失败 - $e');
      return false;
    }
  }

  // ==================== WebSocket 消息处理 ====================

  /// 处理 WebSocket 推送的新投票消息
  Future<void> handleNewVote(Map<String, dynamic> data) async {
    try {
      final groupId = data['group_id'];
      final voteId = data['vote_id'];
      iPrint('GroupVoteService: 收到新投票 - $voteId, 群: $groupId');
      AppEventBus.fire(NewVoteEvent(data: data));
    } catch (e) {
      iPrint('GroupVoteService: 处理新投票消息失败 - $e');
    }
  }

  /// 处理 WebSocket 推送的投票结束消息
  Future<void> handleVoteEnded(Map<String, dynamic> data) async {
    try {
      final groupId = data['group_id'];
      final voteId = data['vote_id'];
      iPrint('GroupVoteService: 投票已结束 - $voteId, 群: $groupId');
      AppEventBus.fire(
        VoteEndedEvent(groupId: groupId, voteId: voteId.toString()),
      );
    } catch (e) {
      iPrint('GroupVoteService: 处理投票结束消息失败 - $e');
    }
  }
}

/// 投票创建事件
class VoteCreatedEvent extends AppEvent {
  final String groupId;
  final Map<String, dynamic> data;
  const VoteCreatedEvent({required this.groupId, required this.data});

  @override
  List<Object?> get props => [groupId, data];
}

/// 投票事件
class VoteCastEvent extends AppEvent {
  final String groupId;
  final String voteId;
  const VoteCastEvent({required this.groupId, required this.voteId});

  @override
  List<Object?> get props => [groupId, voteId];
}

/// 投票结束事件
class VoteEndedEvent extends AppEvent {
  final String groupId;
  final String voteId;
  const VoteEndedEvent({required this.groupId, required this.voteId});

  @override
  List<Object?> get props => [groupId, voteId];
}

/// 投票删除事件
class VoteDeletedEvent extends AppEvent {
  final String groupId;
  final String voteId;
  const VoteDeletedEvent({required this.groupId, required this.voteId});

  @override
  List<Object?> get props => [groupId, voteId];
}

/// 新投票事件（WebSocket 推送）
class NewVoteEvent extends AppEvent {
  final Map<String, dynamic> data;
  const NewVoteEvent({required this.data});

  @override
  List<Object?> get props => [data];
}
