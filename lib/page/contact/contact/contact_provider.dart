import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/api/contact_api.dart' as contact_provider;
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/feature_registry.dart';
import 'package:azlistview/azlistview.dart';

part 'contact_provider.g.dart';

// 联系人状态类
class ContactState {
  final List<ContactModel> contactList;
  final bool isLoading;
  final Set<String> indexBarData;

  const ContactState({
    this.contactList = const [],
    this.isLoading = true,
    this.indexBarData = const {},
  });

  ContactState copyWith({
    List<ContactModel>? contactList,
    bool? isLoading,
    Set<String>? indexBarData,
  }) {
    return ContactState(
      contactList: contactList ?? this.contactList,
      isLoading: isLoading ?? this.isLoading,
      indexBarData: indexBarData ?? this.indexBarData,
    );
  }
}

// 联系人 Notifier
@riverpod
class ContactNotifier extends _$ContactNotifier {
  @override
  ContactState build() {
    // 不在 build() 中调用异步方法
    return const ContactState();
  }

  // 加载数据
  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await listFriend(false);
      if (ref.mounted) {
        handleList(list);
      }
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  // 处理联系人列表
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

    // A-Z sort
    SuspensionUtil.sortListBySuspensionTag(list);
    SuspensionUtil.setShowSuspensionStatus(list);

    // 添加顶部功能项
    final topList = _buildTopItems();
    list.insertAll(0, topList);

    state = state.copyWith(contactList: list, indexBarData: indexBarData);
  }

  // 构建顶部功能项

  List<ContactModel> _buildTopItems() {
    final topItems = <ContactModel>[];

    if (AppFeatureRegistry.isEnabled('location')) {
      topItems.add(
        ContactModel(
          peerId: 'people_nearby',
          nickname: t.findNearbyPeople,
          nameIndex: '↑',
          bgColor: Colors.orange,
          iconData: const Center(
            child: Icon(Icons.person_pin_circle, size: 24, color: Colors.white),
          ),
        ),
      );
    }

    topItems.addAll([
      ContactModel(
        peerId: 'new_friend',
        nickname: t.newFriend,
        nameIndex: '↑',
        bgColor: Colors.orange,
        iconData: const Center(child: Icon(Icons.person_add, size: 24)),
      ),
      ContactModel(
        peerId: 'group',
        nickname: t.groupChat,
        nameIndex: '↑',
        bgColor: Colors.green,
        iconData: const Icon(Icons.people, size: 24, color: Colors.white),
      ),
      ContactModel(
        peerId: 'tag',
        nickname: t.tags,
        nameIndex: '↑',
        bgColor: Colors.blue,
        iconData: const Icon(Icons.local_offer, size: 24, color: Colors.white),
      ),
    ]);

    return topItems;
  }

  // 获取好友列表
  Future<List<ContactModel>> listFriend(bool onRefresh) async {
    List<ContactModel> contact = [];
    if (onRefresh == false) {
      contact = await ContactRepo().findFriend();
    }
    if (contact.isNotEmpty) {
      return contact;
    }
    final repo = ContactRepo();
    final dataMap = await contact_provider.ContactApi().listFriend();
    for (var json in dataMap) {
      await repo.save(json);
    }
    contact = await ContactRepo().findFriend();
    return contact;
  }

  // 判断是否为好友
  Future<bool> isFriend(String peerId) async {
    for (var ct in state.contactList) {
      if (ct.peerId == peerId) {
        return ct.isFriend == 1;
      }
    }
    final ct = await ContactRepo().findByUid(peerId);
    return ct?.isFriend == 1;
  }

  // 接收确认好友
  void receivedConfirmFriend(Map data) {
    if (!ref.mounted) return;
    final repo = ContactRepo();
    final json = {
      ContactRepo.peerId: data['id'],
      'account': data['account'],
      'nickname': data['nickname'],
      'avatar': data['avatar'],
      'sign': data['sign'],
      'gender': data['gender'],
      'remark': data['remark'] ?? '',
      'region': data['region'],
      'source': data['source'],
      ContactRepo.tag: data[ContactRepo.tag] ?? '',
      ContactRepo.isFrom: 1,
      ContactRepo.isFriend: 1,
    };
    final newList = List<ContactModel>.from(state.contactList);
    newList.add(ContactModel.fromMap(json));
    repo.save(json);
    state = state.copyWith(contactList: newList);
  }
}

// 当前索引栏数据 Provider
@riverpod
Set<String> currentIndexBarData(Ref ref) {
  return ref.watch(contactProvider).indexBarData;
}

// 导出生成的类型（如果需要）
// Ref, contactProvider 等类型由 .g.dart 文件生成
