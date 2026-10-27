import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';
import 'package:imboy/service/creation_receipt/group_creation_receipt_service.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:azlistview/azlistview.dart';

part 'launch_chat_provider.g.dart';

/// 发起聊天状态
class LaunchChatState {
  final List<ContactModel> items;
  final Set<String> currIndexBarData;
  final String selectsTips;
  final List<ContactModel> selects;
  final bool isLoading;

  /// W05/F18：联系人加载失败标记。失败不等同空好友——页面据此区分
  /// 「真的没有联系人」与「加载失败需重试」，旧列表（可能为空）保留。
  final bool loadError;

  /// W05/F18：搜索关键词（客户端过滤，不触发网络）。
  final String query;

  const LaunchChatState({
    this.items = const [],
    this.currIndexBarData = const {},
    this.selectsTips = '',
    this.selects = const [],
    this.isLoading = false,
    this.loadError = false,
    this.query = '',
  });

  LaunchChatState copyWith({
    List<ContactModel>? items,
    Set<String>? currIndexBarData,
    String? selectsTips,
    List<ContactModel>? selects,
    bool? isLoading,
    bool? loadError,
    String? query,
  }) {
    return LaunchChatState(
      items: items ?? this.items,
      currIndexBarData: currIndexBarData ?? this.currIndexBarData,
      selectsTips: selectsTips ?? this.selectsTips,
      selects: selects ?? this.selects,
      isLoading: isLoading ?? this.isLoading,
      loadError: loadError ?? this.loadError,
      query: query ?? this.query,
    );
  }

  /// W05/F18：按关键词过滤的可见列表（昵称与拼音包含匹配，大小写
  /// 不敏感）。items 全量保留，搜索只影响视图，已选不受影响（已选保持）。
  List<ContactModel> get visibleItems {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((m) {
      if (m.title.toLowerCase().contains(q)) return true;
      final pinyin = (m.namePinyin ?? '').toLowerCase();
      return pinyin.contains(q);
    }).toList();
  }
}

/// 发起聊天 Notifier
@Riverpod(keepAlive: false)
class LaunchChatNotifier extends _$LaunchChatNotifier {
  @override
  LaunchChatState build() {
    return const LaunchChatState();
  }

  /// 设置加载状态
  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  /// 处理联系人列表（添加拼音索引）
  void handleList(List<ContactModel> list) {
    final indexBarData = <String>{};

    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.isEmpty ? '#' : pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        indexBarData.add(tag);
      } else {
        list[i].nameIndex = '#';
      }
    }
    indexBarData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(list);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(list);

    state = state.copyWith(items: list, currIndexBarData: indexBarData);
  }

  /// 切换联系人选中状态
  void toggleSelection(ContactModel model) {
    final newList = List<ContactModel>.from(state.items);
    final index = newList.indexWhere((m) => m.peerId == model.peerId);
    if (index != -1) {
      newList[index].selected = !newList[index].selected;
    }

    final newSelects = List<ContactModel>.from(state.selects);
    if (model.selected) {
      newSelects.insert(0, model);
    } else {
      newSelects.removeWhere((m) => m.peerId == model.peerId);
    }

    state = state.copyWith(
      items: newList,
      selects: newSelects,
      selectsTips: newSelects.isNotEmpty ? '(${newSelects.length})' : '',
    );
  }

  /// 重置数据
  void resetData() {
    final newList = state.items.map((item) {
      item.selected = false;
      return item;
    }).toList();

    state = state.copyWith(items: newList, selects: [], selectsTips: '');
  }

  /// 设置选中列表
  void setSelects(List<ContactModel> selects) {
    final newSelectsTips = selects.isNotEmpty ? '(${selects.length})' : '';
    state = state.copyWith(selects: selects, selectsTips: newSelectsTips);
  }

  /// 创建群组
  Future<GroupModel?> groupAdd(List<ContactModel> items) async {
    if (items.isEmpty) {
      return null;
    }

    final memberUserIds = items.map((item) => item.peerId.toString()).toList();
    final service = LaunchChatService();
    return await service.groupAdd(memberUserIds);
  }

  /// 加入群组
  Future<bool> joinGroup(String gid, List<ContactModel> items) async {
    if (items.isEmpty) {
      return false;
    }

    final memberUserIds = items.map((item) => item.peerId.toString()).toList();
    final service = LaunchChatService();
    return await service.joinGroup(gid, memberUserIds);
  }

  /// 离开群组
  Future<bool> leaveGroup(String gid, List<dynamic> items) async {
    if (items.isEmpty) {
      return false;
    }

    final memberUserIds = items.map((item) {
      if (item is ContactModel) {
        return item.peerId.toString();
      }
      return item.toString();
    }).toList();

    final service = LaunchChatService();
    return await service.leaveGroup(gid, memberUserIds);
  }

  /// 加载联系人列表
  Future<void> loadContacts() async {
    setLoading(true);
    try {
      final service = LaunchChatService();
      final contacts = await service.listFriend();
      handleList(contacts);
      state = state.copyWith(loadError: false);
    } catch (e) {
      // W05/F18：加载失败不等同空好友——保留旧列表并置错误态，
      // 页面据此展示重试入口，而不是显示"暂无数据"成功空态。
      iPrint('loadContacts failed: $e');
      state = state.copyWith(loadError: true);
    } finally {
      setLoading(false);
    }
  }

  /// W05/F18：更新搜索关键词（客户端过滤）。
  void setQuery(String q) => state = state.copyWith(query: q);
}

/// 发起聊天服务
class LaunchChatService {
  Future<GroupModel?> groupAdd(List<String> memberUserIds) async {
    // W04.d.g：受理合同路径（manifest 能力门开启时启用）。个人域语义
    // 不变——成员载荷同旧路径，仅按合同附加 request_id/recover_only；
    // 恢复重放一律原键原载荷。capabilityMissing 且无未知意图时回落既有
    // 键less调用；已有未知意图绝不剥键走旧 POST。
    final receipt = await GroupCreationReceiptService().createOrRecoverGroup(
      account: UserRepoLocal.to.currentUid,
      workspaceId: null,
      memberUserIds: memberUserIds,
    );
    Map<String, dynamic>? payload;
    if (receipt.ok) {
      payload = receipt.payload;
    } else if (receipt.failure == CreationFlowFailure.capabilityMissing &&
        !receipt.pendingIntentBlocked) {
      payload = await GroupApi().groupAdd(memberUserIds: memberUserIds);
    } else {
      // conflict/notAccepted/unknownPending：意图保留，重试继续恢复；
      // expired/unavailable：意图已清，可重新发起（新键）。
      // capabilityMissing+未知意图：不剥键，返回 null 走既有失败态。
      iPrint(
        '[LaunchChatService] groupAdd receipt failure: '
        '${receipt.failure} ${receipt.errorText ?? ''}',
      );
      return null;
    }

    if (payload != null) {
      final groupRepo = GroupRepo();
      final group = await groupRepo.save(
        '',
        IMBoyHttpResponse.payloadAsMap(payload['group']),
      );

      final gmRepo = GroupMemberRepo();
      for (var json in IMBoyHttpResponse.payloadList(payload, 'member_list')) {
        await gmRepo.save(json);
      }

      if (group.title.isEmpty) {
        final groupListService = GroupListService();
        group.computeTitle = await groupListService.computeTitle(
          group.groupId.toString(),
        );
      }

      return group;
    }
    return null;
  }

  Future<bool> joinGroup(String gid, List<String> memberUserIds) async {
    final provider = GroupMemberApi();
    // join 失败改为抛 GroupMemberApiException（批次152）；此处保持既有
    // 「失败返回 false」语义
    Map<String, dynamic>? payload;
    try {
      payload = await provider.join(gid: gid, memberUserIds: memberUserIds);
    } on GroupMemberApiException {
      return false;
    }

    if (payload != null) {
      final gRepo = GroupRepo();
      final g = await gRepo.findById(gid);
      final gmRepo = GroupMemberRepo();

      final memberList = payload['member_list'] ?? <Map<String, dynamic>>[];

      final gData = <String, dynamic>{
        GroupRepo.memberCount:
            (g?.memberCount ?? 0) + (memberList.length as num),
      };
      await gRepo.update(gid, gData);

      for (var json in (memberList as List)) {
        await gmRepo.save(json as Map<String, dynamic>);
      }
      return true;
    }
    return false;
  }

  Future<bool> leaveGroup(String gid, List<String> memberUserIds) async {
    final provider = GroupMemberApi();
    final payload = await provider.leave(
      gid: gid,
      memberUserIds: memberUserIds,
    );

    if (payload != null) {
      final gRepo = GroupRepo();
      final g = await gRepo.findById(gid);
      final gmRepo = GroupMemberRepo();

      final memberList = payload['member_list'] ?? <Map<String, dynamic>>[];

      final gData = <String, dynamic>{
        GroupRepo.memberCount:
            (g?.memberCount ?? 0) - (memberList.length as num),
      };
      await gRepo.update(gid, gData);

      for (var userId in memberUserIds) {
        await gmRepo.delete(gid, userId);
      }
      return true;
    }
    return false;
  }

  Future<List<ContactModel>> listFriend() async {
    final repo = ContactRepo();
    return await repo.findFriend();
  }
}
