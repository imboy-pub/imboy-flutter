import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/api/contact_api.dart' as contact_provider;
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:azlistview/azlistview.dart';

part 'contact_provider.g.dart';

// 特殊联系人功能入口的虚拟 peerId 常量（使用负数以区别真实用户ID）
const int kPeerIdMomentFeed = -5;
const int kPeerIdPeopleNearby = -1;
const int kPeerIdNewFriend = -2;
const int kPeerIdGroup = -3;
const int kPeerIdTag = -4;
const int kPeerIdAssistantPlaza = -6;

/// 是否是真实好友（而非上面那些功能入口占位）。
///
/// `ContactState.contactList` 里混着 6 个功能入口的伪 [ContactModel]
/// （朋友圈 / 找附近的人 / AI 助手广场 / 新的朋友 / 群聊 / 标签），
/// 它们只在联系人首页当菜单用。任何"选人"场景（加群成员、@提醒、转发等）
/// 直接消费整份列表都会把这些入口一并渲染出来 —— 真机实测：
/// 群详情 `+` 加成员，列表里赫然躺着"朋友圈""找附近的人"。
bool isRealContact(ContactModel c) => c.peerId > 0;

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

    // 朋友圈（首位，社交动态入口）
    // 视觉装饰（bgColor/iconData）由 presentation 层 contactMenuDecorationOf
    // 按 peerId 派生，模型仅保留纯数据。
    topItems.add(
      ContactModel(
        peerId: kPeerIdMomentFeed,
        nickname: t.discovery.moments,
        nameIndex: '↑',
      ),
    );

    if (AppFeatureRegistry.isEnabled(FeatureKeys.location)) {
      topItems.add(
        ContactModel(
          peerId: kPeerIdPeopleNearby,
          nickname: t.discovery.findNearbyPeople,
          nameIndex: '↑',
        ),
      );
    }

    topItems.addAll([
      // AI 助手广场（透明 AI 冷启动入口）
      ContactModel(
        peerId: kPeerIdAssistantPlaza,
        nickname: t.agent.plazaTitle,
        nameIndex: '↑',
      ),
      ContactModel(
        peerId: kPeerIdNewFriend,
        nickname: t.contact.newFriend,
        nameIndex: '↑',
      ),
      ContactModel(
        peerId: kPeerIdGroup,
        nickname: t.chat.groupChat,
        nameIndex: '↑',
      ),
      ContactModel(
        peerId: kPeerIdTag,
        nickname: t.contact.tags,
        nameIndex: '↑',
      ),
    ]);

    return topItems;
  }

  // 获取好友列表
  //
  // BUG#66：此前只有本地表为空时才请求服务端，本地一旦有任意一条记录，
  // 好友列表就永远停在那一刻——新加的好友再也不会出现（选人/加群成员/
  // @提及等所有"选好友"页面一并受害）。改为本地优先返回 + 后台补同步。
  Future<List<ContactModel>> listFriend(bool onRefresh) async {
    List<ContactModel> contact = [];
    if (onRefresh == false) {
      contact = await ContactRepo().findFriend();
    }
    if (contact.isNotEmpty) {
      unawaited(_syncFriendFromServer());
      return contact;
    }
    await _syncFriendFromServer();
    return ContactRepo().findFriend();
  }

  // 从服务端同步好友到本地库；成功后刷新页面状态。
  // 网络失败不应影响已展示的本地列表，故整体吞掉异常但留日志。
  Future<void> _syncFriendFromServer() async {
    try {
      final repo = ContactRepo();
      final dataMap = await contact_provider.ContactApi().listFriend();
      for (var json in dataMap) {
        await repo.save(json as Map<String, dynamic>);
      }
      if (!ref.mounted) return;
      handleList(await repo.findFriend());
    } on Object catch (e) {
      debugPrint('[contact_provider] listFriend sync error: $e');
    }
  }

  // 判断是否为好友
  Future<bool> isFriend(String peerId) async {
    final peerIdInt = int.tryParse(peerId) ?? 0;
    for (var ct in state.contactList) {
      if (ct.peerId == peerIdInt) {
        return ct.isFriend == 1;
      }
    }
    final ct = await ContactRepo().findByUid(peerId);
    return ct?.isFriend == 1;
  }

  // 接收确认好友
  void receivedConfirmFriend(Map<String, dynamic> data) {
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
      if (data.containsKey(ContactRepo.accountType))
        ContactRepo.accountType: data[ContactRepo.accountType],
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
