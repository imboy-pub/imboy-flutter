import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
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

  const LaunchChatState({
    this.items = const [],
    this.currIndexBarData = const {},
    this.selectsTips = '',
    this.selects = const [],
    this.isLoading = false,
  });

  LaunchChatState copyWith({
    List<ContactModel>? items,
    Set<String>? currIndexBarData,
    String? selectsTips,
    List<ContactModel>? selects,
    bool? isLoading,
  }) {
    return LaunchChatState(
      items: items ?? this.items,
      currIndexBarData: currIndexBarData ?? this.currIndexBarData,
      selectsTips: selectsTips ?? this.selectsTips,
      selects: selects ?? this.selects,
      isLoading: isLoading ?? this.isLoading,
    );
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
      String tag = pinyin.substring(0, 1).toUpperCase();
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
    } finally {
      setLoading(false);
    }
  }
}

/// 发起聊天服务
class LaunchChatService {
  Future<GroupModel?> groupAdd(List<String> memberUserIds) async {
    final provider = GroupApi();
    final payload = await provider.groupAdd(memberUserIds: memberUserIds);

    if (payload != null) {
      final groupRepo = GroupRepo();
      final group = await groupRepo.save(
        '',
        payload['group'] as Map<String, dynamic>,
      );

      final gmRepo = GroupMemberRepo();
      final memberList = payload['member_list'] ?? <Map<String, dynamic>>[];
      for (var json in (memberList as List)) {
        await gmRepo.save(json as Map<String, dynamic>);
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
    final payload = await provider.join(gid: gid, memberUserIds: memberUserIds);

    if (payload != null) {
      final gRepo = GroupRepo();
      final g = await gRepo.findById(gid);
      final gmRepo = GroupMemberRepo();

      final sum = (payload['user_id_sum'] ?? 0) as int;
      final memberList = payload['member_list'] ?? <Map<String, dynamic>>[];

      final gData = <String, dynamic>{
        GroupRepo.memberCount:
            (g?.memberCount ?? 0) + (memberList.length as num),
      };
      if (sum > 0) {
        gData[GroupRepo.userIdSum] = sum;
      }
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

      final sum = (payload['user_id_sum'] ?? 0) as int;
      final memberList = payload['member_list'] ?? <Map<String, dynamic>>[];

      final gData = <String, dynamic>{
        GroupRepo.memberCount:
            (g?.memberCount ?? 0) - (memberList.length as num),
      };
      if (sum > 0) {
        gData[GroupRepo.userIdSum] = sum;
      }
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
