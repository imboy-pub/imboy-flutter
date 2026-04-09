import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:azlistview/azlistview.dart';

part 'add_member_provider.g.dart';

/// 添加群成员状态
class AddMemberState {
  final List<GroupMemberModel> groupMemberList;
  final List<ContactModel> contactItems;
  final Set<String> currIndexBarData;
  final List<ContactModel> selects;
  final String selectsTips;
  final bool isLoading;

  const AddMemberState({
    this.groupMemberList = const [],
    this.contactItems = const [],
    this.currIndexBarData = const {},
    this.selects = const [],
    this.selectsTips = '',
    this.isLoading = false,
  });

  AddMemberState copyWith({
    List<GroupMemberModel>? groupMemberList,
    List<ContactModel>? contactItems,
    Set<String>? currIndexBarData,
    List<ContactModel>? selects,
    String? selectsTips,
    bool? isLoading,
  }) {
    return AddMemberState(
      groupMemberList: groupMemberList ?? this.groupMemberList,
      contactItems: contactItems ?? this.contactItems,
      currIndexBarData: currIndexBarData ?? this.currIndexBarData,
      selects: selects ?? this.selects,
      selectsTips: selectsTips ?? this.selectsTips,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 添加群成员 Notifier
@Riverpod(keepAlive: false)
class AddMemberNotifier extends _$AddMemberNotifier {
  @override
  AddMemberState build() {
    return const AddMemberState();
  }

  /// 设置加载状态
  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  /// 设置群成员列表
  void setGroupMemberList(List<GroupMemberModel> list) {
    final memberUserIds = list.map((m) => m.userId).toSet();
    state = state.copyWith(groupMemberList: list);
    // 更新联系人列表中的成员状态
    _updateMemberStatus(memberUserIds);
  }

  /// 处理联系人列表（添加拼音索引）
  void handleContactList(List<ContactModel> list) {
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

    state = state.copyWith(contactItems: list, currIndexBarData: indexBarData);
  }

  /// 更新成员状态
  void _updateMemberStatus(Set<int> memberUserIds) {
    final updatedContacts = state.contactItems.map((contact) {
      contact.selected = memberUserIds.contains(contact.peerId);
      return contact;
    }).toList();

    state = state.copyWith(contactItems: updatedContacts);
  }

  /// 切换联系人选中状态
  void toggleSelection(ContactModel model, String groupId) {
    final memberUserIds = state.groupMemberList.map((m) => m.userId).toSet();
    if (memberUserIds.contains(model.peerId)) {
      return; // 已经是成员，不能选择
    }

    final newList = List<ContactModel>.from(state.contactItems);
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

    final newSelectsTips = newSelects.isNotEmpty
        ? '(${newSelects.length})'
        : '';

    state = state.copyWith(
      contactItems: newList,
      selects: newSelects,
      selectsTips: newSelectsTips,
    );
  }

  /// 检查是否是群成员
  bool isMember(int peerId) {
    return state.groupMemberList.any((m) => m.userId == peerId);
  }

  /// 重置数据
  void resetData() {
    final newList = state.contactItems.map((item) {
      item.selected = false;
      return item;
    }).toList();

    state = state.copyWith(contactItems: newList, selects: [], selectsTips: '');
  }

  /// 加入群组
  Future<bool> joinGroup(String groupId, List<ContactModel> items) async {
    if (items.isEmpty) {
      return false;
    }

    final memberUserIds =
        items.map((item) => item.peerId.toString()).toList();

    // 调用服务层
    final service = AddMemberService();
    return await service.joinGroup(groupId, memberUserIds);
  }

  /// 加载联系人列表
  Future<void> loadContacts() async {
    final service = AddMemberService();
    final contacts = await service.listFriend();
    handleContactList(contacts);
  }
}

/// 添加群成员服务
class AddMemberService {
  Future<bool> joinGroup(String groupId, List<String> memberUserIds) async {
    final provider = GroupMemberApi();
    final payload = await provider.join(
      gid: groupId,
      memberUserIds: memberUserIds,
    );

    if (payload != null) {
      final gRepo = GroupRepo();
      final g = await gRepo.findById(groupId);
      final gmRepo = GroupMemberRepo();

      final sum = payload['user_id_sum'] ?? 0;
      final memberList = payload['member_list'] ?? [];

      final gData = {
        GroupRepo.memberCount: (g?.memberCount ?? 0) + memberList.length,
      };
      if (sum > 0) {
        gData[GroupRepo.userIdSum] = sum;
      }
      await gRepo.update(groupId, gData);

      for (var json in memberList) {
        await gmRepo.save(json as Map<String, dynamic>);
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
